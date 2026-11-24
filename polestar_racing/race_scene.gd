class_name RaceScene
extends Node3D
## Monta a corrida: mundo (GLB), ambiente, carros (jogador, IA, remotos),
## camera, HUD, som e sincronizacao online.

var track: TrackInfo
var theme: Dictionary = {}
var mgr: RaceManager
var hud: GameHUD
var cam: ChaseCamera
var cars := {}              # id -> PlayerCar ou RemoteCar
var sim_ids: Array = []     # ids simulados nesta maquina
var local_id := 1
var local_car: PlayerCar
var started := false

var _world: Node3D
var _rotors: Array = []
var _clouds: Node3D
var _send_t := 0.0
var _autopilot: AIDriver
var _env_d: Dictionary = {}
var _line: RacingLine
var _day: DayNight
var _scenery: Scenery
var _ai_list: Array = []


func _ready() -> void:
    GameInput.ensure()
    if Game.race_setup.is_empty():
        Game.race_setup = Game.make_solo_setup()
    var setup: Dictionary = Game.race_setup
    track = TrackInfo.new(str(setup["track"]))
    theme = track.theme
    local_id = multiplayer.get_unique_id()
    get_viewport().msaa_3d = Viewport.MSAA_2X if Game.quality >= 2 else Viewport.MSAA_DISABLED
    _build_world()
    _env_d = EnvBuilder.build(self, theme, Game.quality)
    mgr = RaceManager.new()
    mgr.track = track
    mgr.total_laps = int(setup["laps"])
    mgr.local_id = local_id
    add_child(mgr)
    _build_cars(setup)
    _build_systems()
    Net.race_scene = self
    if Game.mode == "online":
        Net.player_left.connect(_on_player_left)
        Net.server_closed.connect(_exit_to_menu)
        Net.scene_ready()
        hud.show_message("Aguardando os outros jogadores...", 4.0)
    else:
        begin_countdown()


func _exit_tree() -> void:
    if Net.race_scene == self:
        Net.race_scene = null


# ------------------------------------------------------------ construcao
func _build_world() -> void:
    var ps := load(track.glb) as PackedScene
    _world = ps.instantiate() as Node3D
    add_child(_world)
    var shader := load("res://water.gdshader") as Shader
    for n in _world.find_children("Water*", "MeshInstance3D", true, false):
        var m := ShaderMaterial.new()
        m.shader = shader
        (n as MeshInstance3D).set_surface_override_material(0, m)
    _clouds = _world.find_child("Clouds", true, false) as Node3D
    for r in _world.find_children("Rotor_*", "Node3D", true, false):
        _rotors.append(r)


func _build_cars(setup: Dictionary) -> void:
    var night: bool = theme.get("night", false)
    var racers_arr: Array = setup["racers"]
    for e in racers_arr:
        var id: int = int(e["id"])
        var def: Dictionary = Catalog.car_def(str(e["car"]))
        var col: Color = Catalog.color_of(str(e["car"]), int(e["color"]))
        var xf: Transform3D = track.grid_transform(int(e["slot"]))
        var owner_id: int = int(e["owner"])
        var is_human: bool = str(e["kind"]) == "human"
        var node: Node3D
        if owner_id == local_id:
            var car := PlayerCar.new()
            car.def = def
            car.paint_color = col
            car.lights_on = night
            car.racer_id = id
            car.is_ai = not is_human
            car.build_interior = is_human
            add_child(car)
            car.place(xf)
            cars[id] = car
            sim_ids.append(id)
            node = car
            if is_human:
                local_car = car
                car.flipped.connect(reset_car)
            else:
                var ai := AIDriver.new()
                ai.car = car
                ai.track = track
                ai.skill = Game.ai_skill() * (0.97 + 0.06 * randf())
                if Game.race_setup.has("difficulty"):
                    ai.skill = [0.86, 0.94, 1.0][clampi(int(Game.race_setup["difficulty"]), 0, 2)] * (0.97 + 0.06 * randf())
                ai.base_lane = randf_range(-2.2, 2.2)
                ai.others = cars.values()
                add_child(ai)
                _ai_list.append(ai)
        else:
            var rc := RemoteCar.new()
            rc.def = def
            rc.paint_color = col
            add_child(rc)
            rc.global_transform = xf
            cars[id] = rc
            node = rc
        mgr.add_racer(id, str(e["name"]), int(e["color"]), str(e["car"]), node, is_human, owner_id == local_id)
    for ai in _ai_list:
        (ai as AIDriver).others = cars.values()


func _build_systems() -> void:
    cam = ChaseCamera.new()
    cam.far = 2500.0
    cam.near = 0.05
    cam.current = true
    add_child(cam)
    cam.target = local_car
    if local_car != null:
        local_car.crashed.connect(cam.shake)
    if theme.get("snow", false):
        EnvBuilder.add_snow(cam)

    hud = GameHUD.new()
    add_child(hud)
    hud.setup(mgr, local_car, local_id, track)
    hud.touch.camera_pressed.connect(cam.next_mode)
    hud.touch.reset_pressed.connect(reset_car)
    hud.restart_requested.connect(func(): get_tree().reload_current_scene())
    hud.menu_requested.connect(_exit_to_menu)

    mgr.go.connect(_on_go)
    mgr.racer_finished.connect(_on_finished)

    if local_car != null:
        var snd := EngineSound.new()
        snd.car = local_car
        add_child(snd)
    for id in sim_ids:
        var c: PlayerCar = cars[id]
        var fx := TireFX.new()
        fx.car = c
        fx.tint = Color(theme["dust"]) if track.id in ["deserto", "neve", "costa"] else Color(0.85, 0.85, 0.85, 0.5)
        add_child(fx)


    # linha vermelha do tracado
    _line = RacingLine.new()
    add_child(_line)
    _line.build(track)

    # cenario tropical / cidade (sem mato) + ciclo dia/noite
    _scenery = Scenery.new()
    _scenery.track = track
    _scenery.world = _world
    add_child(_scenery)
    _scenery.build()
    _day = DayNight.new()
    add_child(_day)
    _day.scenery = _scenery
    _day.cars_fn = func(): return cars.values().filter(func(c): return c is PlayerCar)
    _day.setup(_env_d, theme, cam, track.id)
    if DisplayServer.is_touchscreen_available():
        var cl := CanvasLayer.new()
        cl.layer = 6
        add_child(cl)
        var lb := Button.new()
        lb.text = "Linha"
        lb.anchor_left = 1.0
        lb.anchor_right = 1.0
        lb.offset_left = -120.0
        lb.offset_right = -16.0
        lb.offset_top = 110.0
        lb.offset_bottom = 160.0
        lb.pressed.connect(func(): _line.visible = not _line.visible)
        cl.add_child(lb)


# ------------------------------------------------------------ fluxo
func begin_countdown() -> void:
    if started:
        return
    started = true
    mgr.start_countdown()


func _on_go() -> void:
    for id in sim_ids:
        (cars[id] as PlayerCar).controls_enabled = true


func _on_finished(id: int, _place: int, _time: float) -> void:
    if id != local_id or local_car == null:
        return
    # depois de cruzar a linha, o carro segue sozinho
    local_car.is_ai = true
    var ai := AIDriver.new()
    ai.car = local_car
    ai.track = track
    ai.skill = 0.6
    ai.others = cars.values()
    add_child(ai)
    _autopilot = ai


func reset_car() -> void:
    if local_car != null and mgr.running and not mgr.get_racer(local_id).finished:
        local_car.place(mgr.get_respawn(local_id))


func _exit_to_menu() -> void:
    if Game.mode == "online" and Net.is_online() and Net.return_to_lobby:
        Net.finish_race_to_lobby()      # volta para a sala, sem derrubar a conexao
    elif Game.mode == "online":
        Net.leave()
    Game.go_menu()


func _on_player_left(id: int) -> void:
    if cars.has(id):
        var n: Node = cars[id]
        cars.erase(id)
        mgr.remove_racer(id)
        if is_instance_valid(n):
            n.queue_free()
        hud.show_message("Um jogador saiu da corrida", 2.0)


func on_states(states: Array) -> void:
    for e in states:
        var id: int = int(e[0])
        if sim_ids.has(id):
            continue
        var rc = cars.get(id)
        if rc is RemoteCar:
            rc.push_state(e[1], e[2], e[3], float(e[4]), bool(e[5]))


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("racing_line") and _line != null:
        _line.visible = not _line.visible
    elif event.is_action_pressed("reset"):
        reset_car()
    elif event.is_action_pressed("camera"):
        cam.next_mode()


func _process(delta: float) -> void:
    for r in _rotors:
        (r as Node3D).rotate_z(-delta * 1.1)
    if _clouds != null:
        _clouds.rotate_y(delta * 0.004)
    # elastico da IA
    for ai in _ai_list:
        var a := ai as AIDriver
        if is_instance_valid(a.car):
            a.rubber = mgr.rubber_for(a.car.racer_id)


func _physics_process(delta: float) -> void:
    if Game.mode != "online":
        return
    _send_t += delta
    if _send_t < 0.05:
        return
    _send_t = 0.0
    var arr: Array = []
    for id in sim_ids:
        var c: PlayerCar = cars[id]
        if is_instance_valid(c):
            arr.append([id, c.global_position, c.global_transform.basis.get_rotation_quaternion(),
                    c.linear_velocity, c.steering, c.braking])
    Net.send_states(arr)
