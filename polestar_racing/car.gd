class_name PlayerCar
extends VehicleBody3D
## Carro com fisica (VehicleBody3D) v3: cambio com marchas, curva de torque,
## limite de tracao, ABS progressivo, transferencia de peso, anti-rolagem,
## estabilidade lateral e deteccao de colisao (faiscas + sinal "crashed").

signal crashed(strength: float)
signal flipped()

var def: Dictionary = {}
var paint_color := Color.WHITE
var lights_on := false
var racer_id := 0
var build_interior := false

var is_ai := false
var ai_throttle := 0.0
var ai_brake := 0.0
var ai_steer := 0.0
var ai_hand := 0.0

var controls_enabled := false
var speed_kmh := 0.0
var forward_speed := 0.0      # m/s (negativo = re)
var rpm_norm := 0.0
var gear := 1
var braking := false
var lateral_g := 0.0
var longitudinal_g := 0.0
var drifting := false
var interior: CarInterior

# --- parametros (preenchidos de CarsData) ---
var max_speed_kmh := 100.0
var total_engine_force := 9000.0
var reverse_force := 3500.0
var brake_strength := 40.0
var grip_front := 3.4
var grip_rear := 3.6
var drift_grip := 1.5
var steer_max := 0.5
var steer_min := 0.07
var steer_rate := 2.4
var drag := 0.30
var downforce := 1.2
var ride_height := 0.03       # folga extra entre chassi e pneu (m)

const GEAR_FRAC := [0.0, 0.20, 0.36, 0.52, 0.68, 0.84, 1.0]
const TIRE_MU := 1.25

var _wheels: Array = []
var _rear: Array = []
var _front: Array = []
var _tail_mats: Array = []
var _was_braking := false
var _brake_smooth := 0.0
var _throttle_smooth := 0.0
var _steer_smooth := 0.0
var _gear_t := 0.0
var _shift_cool := 0.0
var _prev_vel := Vector3.ZERO
var _flip_t := 0.0
var _crash_cool := 0.0
var _sparks: CPUParticles3D
var _model: Node3D
var _flames: Array = []
var _prev_th := 0.0
var _flame_cool := 0.0


func _ready() -> void:
    GameInput.ensure()
    if def.is_empty():
        def = Catalog.car_def("p911ts")
    mass = float(def["mass"])
    max_speed_kmh = float(def["max_kmh"])
    total_engine_force = float(def["engine"])
    reverse_force = total_engine_force * 0.45
    brake_strength = float(def["brake"])
    grip_front = float(def["grip_front"])
    grip_rear = float(def["grip_rear"])
    steer_max = float(def["steer"])
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    var com: Vector3 = def["com"]
    center_of_mass = Vector3(com.x, com.y - 0.05, com.z)   # centro de massa baixo
    linear_damp = 0.015
    angular_damp = 1.1
    continuous_cd = true
    can_sleep = false
    contact_monitor = true
    max_contacts_reported = 6
    var pm := PhysicsMaterial.new()
    pm.friction = 0.25      # raspa nas paredes em vez de grudar
    pm.bounce = 0.05
    physics_material_override = pm
    _build_collision()
    _build_model_and_wheels()
    _build_sparks()
    if lights_on:
        _build_lights()
    _build_exhaust()
    if build_interior and not bool(def.get("own_interior", false)):
        interior = CarInterior.new()
        interior.car = self
        add_child(interior)
    body_entered.connect(_on_body_entered)


func _build_collision() -> void:
    for c in def["collision"]:
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = c["size"]
        cs.shape = bs
        cs.position = Vector3(c["pos"].x, c["pos"].y + ride_height, c["pos"].z)
        add_child(cs)


func _build_model_and_wheels() -> void:
    _model = CarVisual.load_model(def)
    add_child(_model)
    # carroceria sobe um pouco: sobra espaco visivel entre o chassi e o pneu
    _model.position.y += ride_height
    CarVisual.apply_paint(_model, paint_color)
    _tail_mats = CarVisual.override_materials(_model, "Taillight")
    var wheel_defs: Dictionary = def["wheels"]
    var stiff := mass * 0.030            # molas proporcionais a massa
    var crit := 2.0 * sqrt(stiff)        # amortecimento critico (referencia)
    for key in ["FL", "FR", "RL", "RR"]:
        var front: bool = key.begins_with("F")
        var w := VehicleWheel3D.new()
        w.name = "Wheel" + key
        w.position = wheel_defs[key]
        w.use_as_steering = front
        w.use_as_traction = false      # forca motriz e aplicada pelo carro
        w.wheel_radius = float(def.get("wheel_radius_rear", def["wheel_radius"])) if not front else float(def["wheel_radius"])
        w.wheel_rest_length = 0.20 + ride_height
        w.suspension_travel = 0.22
        w.suspension_stiffness = stiff * (1.08 if front else 1.0)
        w.suspension_max_force = mass * 9.81 * 0.9
        w.damping_compression = clampf(0.30 * crit / maxf(stiff, 1.0) * 6.0, 0.35, 0.9)
        w.damping_relaxation = clampf(w.damping_compression * 1.25, 0.45, 1.1)
        w.wheel_roll_influence = 0.12
        w.wheel_friction_slip = grip_front if front else grip_rear
        add_child(w)
        _wheels.append(w)
        if front:
            _front.append(w)
        else:
            _rear.append(w)
        var vis := _model.find_child("Wheel_" + key, true, false)
        if vis:
            vis.reparent(w, false)
            vis.transform = Transform3D.IDENTITY


func _build_lights() -> void:
    for p in def["headlights"]:
        var sp := SpotLight3D.new()
        sp.spot_range = 70.0
        sp.spot_angle = 30.0
        sp.spot_attenuation = 0.8
        sp.light_energy = 4.0
        sp.shadow_enabled = false
        add_child(sp)
        sp.position = Vector3(p.x, p.y + ride_height, p.z - 0.2)
        sp.rotation_degrees = Vector3(-3.0, 0.0, 0.0)


func set_headlights(on: bool) -> void:
    lights_on = on
    for c in get_children():
        if c is SpotLight3D:
            c.visible = on
    if on and get_children().filter(func(n): return n is SpotLight3D).is_empty():
        _build_lights()


func _build_exhaust() -> void:
    if not def.has("exhaust"):
        return
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.6, 0.15)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.4, 0.05)
    mat.emission_energy_multiplier = 3.0
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    var quad := QuadMesh.new()
    quad.size = Vector2(0.2, 0.2)
    quad.material = mat
    for p in def["exhaust"]:
        var f := CPUParticles3D.new()
        f.mesh = quad
        f.amount = 14
        f.lifetime = 0.22
        f.one_shot = true
        f.explosiveness = 1.0
        f.emitting = false
        f.direction = Vector3(0, 0.05, 1)
        f.spread = 12.0
        f.initial_velocity_min = 4.0
        f.initial_velocity_max = 9.0
        f.gravity = Vector3.ZERO
        f.scale_amount_min = 0.5
        f.scale_amount_max = 1.3
        add_child(f)
        f.position = Vector3(p.x, p.y + ride_height, p.z)
        _flames.append(f)


func _pop_flames() -> void:
    if _flame_cool > 0.0:
        return
    _flame_cool = 0.5
    for f in _flames:
        (f as CPUParticles3D).restart()
        (f as CPUParticles3D).emitting = true


func _build_sparks() -> void:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.75, 0.25)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.6, 0.1)
    var quad := QuadMesh.new()
    quad.size = Vector2(0.05, 0.05)
    quad.material = mat
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    _sparks = CPUParticles3D.new()
    _sparks.mesh = quad
    _sparks.amount = 30
    _sparks.lifetime = 0.5
    _sparks.one_shot = true
    _sparks.explosiveness = 0.9
    _sparks.emitting = false
    _sparks.direction = Vector3(0, 1, 0)
    _sparks.spread = 70.0
    _sparks.initial_velocity_min = 3.0
    _sparks.initial_velocity_max = 8.0
    _sparks.gravity = Vector3(0, -12, 0)
    _sparks.local_coords = false
    add_child(_sparks)


func _on_body_entered(_b: Node) -> void:
    if _crash_cool > 0.0:
        return
    var dv := (linear_velocity - _prev_vel).length()
    if dv < 2.5:
        return
    _crash_cool = 0.3
    _sparks.restart()
    _sparks.emitting = true
    crashed.emit(clampf(dv / 15.0, 0.0, 1.0))


func rear_wheels() -> Array:
    return _rear


func _grounded_ratio() -> float:
    var n := 0
    for w in _wheels:
        if (w as VehicleWheel3D).is_in_contact():
            n += 1
    return float(n) / 4.0


## Curva de torque: sobe ate ~65% do giro e cai perto do limitador.
func _torque_curve(r: float) -> float:
    return clampf(0.55 + 1.6 * r - 1.35 * r * r, 0.35, 1.0)


func _physics_process(delta: float) -> void:
    var xf := global_transform
    var forward := -xf.basis.z.normalized()
    var right := xf.basis.x.normalized()
    var up := xf.basis.y.normalized()
    var velocity := linear_velocity
    forward_speed = velocity.dot(forward)
    speed_kmh = velocity.length() * 3.6
    var lat_speed := velocity.dot(right)
    var grounded := _grounded_ratio()
    _crash_cool = maxf(_crash_cool - delta, 0.0)

    var accel := (velocity - _prev_vel) / maxf(delta, 0.0001)
    longitudinal_g = accel.dot(forward) / 9.81
    lateral_g = lerpf(lateral_g, accel.dot(right) / 9.81, 0.15)
    _prev_vel = velocity

    var throttle_in := 0.0
    var brake_in := 0.0
    var steer_in := 0.0
    var hand := 0.0
    if controls_enabled:
        if is_ai:
            throttle_in = clampf(ai_throttle, 0.0, 1.0)
            brake_in = clampf(ai_brake, 0.0, 1.0)
            steer_in = clampf(ai_steer, -1.0, 1.0)
            hand = clampf(ai_hand, 0.0, 1.0)
        else:
            throttle_in = Input.get_action_strength("accelerate")
            brake_in = Input.get_action_strength("brake")
            steer_in = Input.get_axis("steer_right", "steer_left")
            hand = Input.get_action_strength("handbrake")

    # pedais com curva suave (sem "tudo ou nada")
    _throttle_smooth = move_toward(_throttle_smooth, throttle_in, (3.2 if throttle_in > _throttle_smooth else 6.0) * delta)
    _brake_smooth = move_toward(_brake_smooth, brake_in, (4.5 if brake_in > _brake_smooth else 8.0) * delta)

    var kmh_long := forward_speed * 3.6
    var weight := mass * 9.81
    var load_rear := 0.5 + clampf(accel.dot(forward) / 9.81, -0.8, 0.8) * 0.12
    var drive_force := 0.0
    var brake_force := 0.0
    var reversing := false

    engine_force = 0.0
    if controls_enabled:
        var th := _throttle_smooth
        var br := _brake_smooth
        if th > 0.01 and forward_speed > -0.8:
            if kmh_long < max_speed_kmh:
                var frac := clampf(maxf(kmh_long, 0.0) / maxf(max_speed_kmh, 1.0), 0.0, 1.0)
                # rpm dentro da marcha atual
                var g := gear
                var lo: float = GEAR_FRAC[g - 1]
                var hi: float = GEAR_FRAC[g]
                var in_gear := clampf((frac - lo) / maxf(hi - lo, 0.01), 0.0, 1.0)
                var gear_mult := lerpf(1.35, 0.80, float(g - 1) / 5.0)
                var raw := total_engine_force * 1.7 * th * _torque_curve(in_gear) * gear_mult
                # fim de curso suave perto da velocidade maxima
                raw *= clampf((1.0 - pow(frac, 6.0)) * 1.05, 0.0, 1.0)
                # limite de tracao: nao passa do que o pneu aguenta
                var traction_cap := weight * TIRE_MU * clampf(0.5 + load_rear * 0.5, 0.4, 0.75) * maxf(grounded, 0.25)
                drive_force = minf(raw, traction_cap)
        elif th > 0.01 and forward_speed <= -0.8:
            brake_force = brake_strength * mass * 0.28 * th
        if br > 0.01:
            if forward_speed > 0.8:
                # ABS: desaceleracao limitada pela aderencia + aerodinamica
                var max_decel := TIRE_MU * 9.81 * maxf(grounded, 0.3) + speed_kmh * 0.012
                var want := brake_strength * 0.30 * br
                brake_force = maxf(brake_force, minf(want, max_decel) * mass)
            else:
                reversing = true
                if kmh_long > -30.0:
                    var rr := clampf(absf(minf(kmh_long, 0.0)) / 30.0, 0.0, 1.0)
                    drive_force = -reverse_force * br * (1.0 - rr * 0.8)
    else:
        brake_force = brake_strength * mass * 0.30

    if absf(drive_force) > 0.1:
        apply_central_force(forward * drive_force * maxf(grounded, 0.25))
    if brake_force > 0.1 and velocity.length() > 0.05:
        apply_central_force(-velocity.normalized() * brake_force)
    # freio das rodas: so ajuda a travar de vez (rodas param de girar)
    brake = brake_strength * 0.35 * _brake_smooth if forward_speed > 0.8 else 0.0

    # --- aderencia: transferencia de peso (acelerar tira do eixo da frente, frear tira de tras)
    var lon_g := clampf(accel.dot(forward) / 9.81, -1.0, 1.0)
    var front_mul := clampf(1.0 + lon_g * 0.18, 0.75, 1.15)
    var rear_mul := clampf(1.0 - lon_g * 0.18, 0.75, 1.15)
    for w in _front:
        (w as VehicleWheel3D).wheel_friction_slip = grip_front * front_mul
    for w in _rear:
        var rw := w as VehicleWheel3D
        # handbrake: so tira aderencia traseira, de forma progressiva
        rw.wheel_friction_slip = lerpf(grip_rear * rear_mul, drift_grip, hand)

    # --- direcao: sensivel devagar, firme rapido, resposta suave
    var speed_factor := clampf(speed_kmh / 140.0, 0.0, 1.0)
    var limit := lerpf(steer_max, steer_min, pow(speed_factor, 0.7))
    var rate := steer_rate * lerpf(1.0, 0.55, speed_factor)
    if absf(steer_in) < 0.02:
        rate *= 1.6                   # volta ao centro mais rapido
    var target := steer_in * limit
    # contra-esterco automatico quando a traseira escorrega
    if absf(lat_speed) > 2.0 and speed_kmh > 25.0 and hand < 0.1:
        target += clampf(lat_speed / maxf(absf(forward_speed), 5.0), -0.6, 0.6) * limit * 0.35
    _steer_smooth = move_toward(_steer_smooth, clampf(target, -steer_max, steer_max), rate * delta)
    steering = _steer_smooth

    # --- estabilidade lateral no eixo traseiro (reduz rodopios aleatorios)
    if grounded > 0.4 and speed_kmh > 4.0:
        var grip_k := lerpf(1.0, 0.18, hand)
        var lat_cap := weight * TIRE_MU * 0.55 * grip_k
        var lat_f := clampf(-lat_speed * mass * 3.2 * grip_k, -lat_cap, lat_cap)
        var rear_off: Vector3 = xf.basis * Vector3(0, 0, 1.2)
        apply_force(right * lat_f * 0.6, rear_off)
        var front_off: Vector3 = xf.basis * Vector3(0, 0, -1.2)
        apply_force(right * lat_f * 0.4, front_off)

    # --- drift controlado: pequeno torque de entrada, depois o proprio carro segura
    drifting = absf(lat_speed) > 3.0 and speed_kmh > 30.0
    if hand > 0.05 and absf(steer_in) > 0.05 and speed_kmh > 15.0:
        var t := steer_in * hand * clampf(speed_kmh / 70.0, 0.0, 1.0) * mass * 1.1
        apply_torque(Vector3.UP * t)

    # --- anti-rolagem e controle de arfagem
    if grounded > 0.5:
        apply_torque(forward * right.y * mass * 14.0)
        apply_torque(right * -forward.y * mass * 5.0 * clampf(speed_kmh / 80.0, 0.0, 1.0))
        var wv := angular_velocity
        apply_torque(-forward * wv.dot(forward) * mass * 2.5)
    else:
        # no ar: amortece o giro para nao capotar do nada
        apply_torque(-angular_velocity * mass * 1.2)

    # --- resistencia do ar, downforce (cresce com v^2) e rolagem
    var v2 := velocity.length_squared()
    apply_central_force(-velocity.normalized() * v2 * drag * 0.9)
    apply_central_force(Vector3.DOWN * v2 * downforce)
    if controls_enabled and throttle_in < 0.01 and brake_in < 0.01 and velocity.length() > 0.2:
        apply_central_force(-velocity.normalized() * mass * 0.55)   # freio-motor

    # --- cambio automatico com histerese (sem ficar trocando toda hora)
    _shift_cool = maxf(_shift_cool - delta, 0.0)
    var frac_s := clampf(absf(kmh_long) / maxf(max_speed_kmh, 1.0), 0.0, 1.0)
    if _shift_cool <= 0.0:
        if gear < 6 and frac_s > GEAR_FRAC[gear] * 0.97:
            gear += 1
            _shift_cool = 0.25
        elif gear > 1 and frac_s < GEAR_FRAC[gear - 1] * 0.82:
            gear -= 1
            _shift_cool = 0.25
    var lo2: float = GEAR_FRAC[gear - 1]
    var hi2: float = GEAR_FRAC[gear]
    var target_rpm := lerpf(0.30, 1.0, clampf((frac_s - lo2) / maxf(hi2 - lo2, 0.01), 0.0, 1.0))
    if _throttle_smooth < 0.05 and not reversing:
        target_rpm = lerpf(target_rpm, 0.25, 0.5)
    if _shift_cool > 0.12:
        target_rpm *= 0.8
    rpm_norm = lerpf(rpm_norm, target_rpm, 1.0 - exp(-12.0 * delta))

    _flame_cool = maxf(_flame_cool - delta, 0.0)
    if controls_enabled and _prev_th > 0.6 and _throttle_smooth < 0.25 and rpm_norm > 0.55 and speed_kmh > 35.0:
        _pop_flames()
    _prev_th = _throttle_smooth

    braking = (brake_force > 5.0 or hand > 0.1) and controls_enabled
    if braking != _was_braking:
        _was_braking = braking
        for m in _tail_mats:
            (m as StandardMaterial3D).emission_energy_multiplier = 3.5 if braking else 1.0

    # --- capotou? volta sozinho depois de uns segundos
    if up.y < 0.25 and speed_kmh < 12.0 and controls_enabled:
        _flip_t += delta
        if _flip_t > 2.5:
            _flip_t = 0.0
            flipped.emit()
    else:
        _flip_t = 0.0


## Teleporta o carro (reset / respawn).
func place(t: Transform3D) -> void:
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    steering = 0.0
    _steer_smooth = 0.0
    _prev_vel = Vector3.ZERO
    global_transform = t
