class_name GameHUD
extends CanvasLayer
## HUD da corrida: velocimetro, posicao, voltas, tempos, ranking, minimapa,
## contagem regressiva, pausa e tela de resultados.

signal restart_requested
signal menu_requested

var race: RaceManager
var car: PlayerCar
var track: TrackInfo
var local_id := 1
var touch: TouchControls

var _ui: Control
var _pos_label: Label
var _lap_label: Label
var _time_label: Label
var _best_label: Label
var _msg_label: Label
var _wrong_label: Label
var _board: VBoxContainer
var _gauge: Gauge
var _minimap: Minimap
var _panel: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _resume_btn: Button
var _restart_btn: Button
var _results_box: GridContainer
var _msg_tween: Tween
var _results_open := false
var _board_t := 0.0


# ---------------------------------------------------------------- widgets
class Gauge extends Control:
    var speed := 0.0
    var gear := 1
    var max_speed := 120.0

    func _init() -> void:
        custom_minimum_size = Vector2(230, 230)
        size = custom_minimum_size
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var c := size / 2.0
        var r := minf(size.x, size.y) * 0.45
        draw_arc(c, r, deg_to_rad(135.0), deg_to_rad(405.0), 64, Color(0, 0, 0, 0.5), 18.0, true)
        var f := clampf(speed / max_speed, 0.0, 1.0)
        var col := Color(0.2, 0.8, 1.0).lerp(Color(1.0, 0.3, 0.2), clampf((f - 0.75) / 0.25, 0.0, 1.0))
        if f > 0.01:
            draw_arc(c, r, deg_to_rad(135.0), deg_to_rad(135.0 + 270.0 * f), 64, col, 12.0, true)
        var font := ThemeDB.fallback_font
        draw_string(font, c + Vector2(-70, 14), str(int(speed)), HORIZONTAL_ALIGNMENT_CENTER, 140, 60, Color.WHITE)
        draw_string(font, c + Vector2(-70, 44), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 140, 22, Color(0.8, 0.8, 0.8))
        var g := "R" if gear < 0 else str(gear)
        draw_string(font, c + Vector2(-70, 80), "Marcha " + g, HORIZONTAL_ALIGNMENT_CENTER, 140, 22, Color.WHITE)


class Minimap extends Control:
    var pts := PackedVector2Array()
    var dots: Array = []          # [Vector2 mundo, Color, bool local]
    var _min := Vector2.ZERO
    var _scale := 1.0

    func _init() -> void:
        custom_minimum_size = Vector2(170, 170)
        size = custom_minimum_size
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func setup(line: Array) -> void:
        pts.clear()
        for p in line:
            pts.append(Vector2(p.x, p.z))
        var mn := pts[0]
        var mx := pts[0]
        for p in pts:
            mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
            mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
        _min = mn
        var span := mx - mn
        _scale = minf((size.x - 20.0) / span.x, (size.y - 20.0) / span.y)

    func _map(p: Vector2) -> Vector2:
        return (p - _min) * _scale + Vector2(10, 10)

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.38), true)
        if pts.size() < 2:
            return
        var line := PackedVector2Array()
        for p in pts:
            line.append(_map(p))
        line.append(line[0])
        draw_polyline(line, Color(1, 1, 1, 0.8), 4.0, true)
        draw_circle(line[0], 5.0, Color(1, 1, 0.2))
        for d in dots:
            draw_circle(_map(d[0]), 6.0 if d[2] else 4.0, d[1])
            if d[2]:
                draw_arc(_map(d[0]), 8.0, 0.0, TAU, 20, Color.WHITE, 2.0)


# ---------------------------------------------------------------- build
func _ready() -> void:
    GameInput.ensure()
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    _ui = Control.new()
    _ui.theme = UI.make_theme()
    _ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    _ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_ui)

    _pos_label = _make_label(54)
    _pos_label.position = Vector2(16, 6)
    _lap_label = _make_label(26)
    _lap_label.position = Vector2(16, 76)
    _time_label = _make_label(22)
    _time_label.position = Vector2(16, 110)
    _best_label = _make_label(22)
    _best_label.position = Vector2(16, 140)
    _board = VBoxContainer.new()
    _board.position = Vector2(16, 180)
    _board.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ui.add_child(_board)

    _msg_label = _make_label(90)
    _msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _msg_label.modulate.a = 0.0
    _wrong_label = _make_label(44)
    _wrong_label.text = "CONTRAMAO!"
    _wrong_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
    _wrong_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _wrong_label.position = Vector2(540, 90)
    _wrong_label.visible = false

    _gauge = Gauge.new()
    _ui.add_child(_gauge)
    _minimap = Minimap.new()
    _ui.add_child(_minimap)

    touch = TouchControls.new()
    _ui.add_child(touch)
    touch.pause_pressed.connect(toggle_pause)

    _build_panel()


func _make_label(font_size: int) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", Color.WHITE)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 6)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ui.add_child(l)
    return l


func _build_panel() -> void:
    _panel = PanelContainer.new()
    _panel.visible = false
    _panel.set_anchors_preset(Control.PRESET_CENTER)
    _panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    _panel_body = VBoxContainer.new()
    _panel_body.custom_minimum_size = Vector2(420, 0)
    _panel_body.add_theme_constant_override("separation", 12)
    _panel.add_child(_panel_body)
    _panel_title = Label.new()
    _panel_title.text = "PAUSADO"
    _panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _panel_title.add_theme_font_size_override("font_size", 34)
    _panel_body.add_child(_panel_title)
    _results_box = GridContainer.new()
    _results_box.columns = 4
    _results_box.add_theme_constant_override("h_separation", 22)
    _results_box.visible = false
    _panel_body.add_child(_results_box)
    _resume_btn = UI.btn("Continuar", toggle_pause)
    _panel_body.add_child(_resume_btn)
    _restart_btn = UI.btn("Reiniciar", func(): _on_restart())
    _panel_body.add_child(_restart_btn)
    _panel_body.add_child(UI.btn("Sair para o menu", func(): menu_requested.emit()))
    _ui.add_child(_panel)


# ---------------------------------------------------------------- logic
func setup(r: RaceManager, c: PlayerCar, lid: int, t: TrackInfo) -> void:
    race = r
    car = c
    local_id = lid
    track = t
    _minimap.setup(t.pts)
    race.countdown_tick.connect(_on_countdown)
    race.lap_completed.connect(_on_lap)
    race.racer_finished.connect(_on_finished)
    _restart_btn.visible = Game.mode != "online"


static func fmt(t: float) -> String:
    if t == INF or t < 0.0:
        return "--:--.--"
    return "%d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]


func _process(delta: float) -> void:
    if car == null or race == null:
        return
    var me: RaceManager.Racer = race.get_racer(local_id)
    _gauge.speed = car.speed_kmh
    _gauge.gear = car.gear if car.forward_speed > -0.5 else -1
    _gauge.queue_redraw()
    var s := get_viewport().get_visible_rect().size
    _gauge.position = Vector2(s.x * 0.5 - _gauge.size.x * 0.5, s.y - _gauge.size.y - 8.0)
    _minimap.position = Vector2(s.x - _minimap.size.x - 12.0, 84.0)
    _wrong_label.position = Vector2(s.x * 0.5 - 160.0, 90.0)
    var dots: Array = []
    for id in race.racers:
        var rr: RaceManager.Racer = race.racers[id]
        if is_instance_valid(rr.node):
            dots.append([Vector2(rr.node.global_position.x, rr.node.global_position.z),
                    Catalog.color_of(rr.car_id, rr.color_idx), id == local_id])
    _minimap.dots = dots
    _minimap.queue_redraw()
    if me != null:
        _pos_label.text = "%d/%d" % [me.rank if me.rank > 0 else 1, race.racers.size()]
        _lap_label.text = "VOLTA %d/%d" % [mini(me.laps + 1, race.total_laps), race.total_laps]
        _time_label.text = "Volta  " + fmt(me.lap_time)
        _best_label.text = "Melhor  " + fmt(me.best_lap)
        _wrong_label.visible = me.wrong_way and not me.finished
    _board_t += delta
    if _board_t > 0.4:
        _board_t = 0.0
        _update_board()
        if _results_open:
            _fill_results()


func _update_board() -> void:
    for c in _board.get_children():
        c.queue_free()
    var n := 0
    for r in race.standings:
        var rr: RaceManager.Racer = r
        if n >= 6:
            break
        var l := Label.new()
        l.text = "%d. %s%s" % [rr.rank, rr.name, "  ✓" if rr.finished else ""]
        l.add_theme_font_size_override("font_size", 20)
        l.add_theme_color_override("font_color", Color(1, 0.9, 0.3) if rr.id == local_id else Color.WHITE)
        l.add_theme_color_override("font_outline_color", Color.BLACK)
        l.add_theme_constant_override("outline_size", 5)
        _board.add_child(l)
        n += 1


func show_message(text: String, duration := 1.5, size := 90) -> void:
    _msg_label.add_theme_font_size_override("font_size", size)
    _msg_label.text = text
    _msg_label.modulate.a = 1.0
    if _msg_tween:
        _msg_tween.kill()
    _msg_tween = create_tween()
    _msg_tween.tween_interval(duration)
    _msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.4)


func _on_countdown(n: int) -> void:
    show_message("VAI!" if n == 0 else str(n), 0.8)


func _on_lap(id: int, lap: int, lap_time: float, is_best: bool) -> void:
    if id != local_id:
        return
    var extra := "\nMELHOR VOLTA!" if is_best else ""
    show_message("Volta %d: %s%s" % [lap, fmt(lap_time), extra], 2.5, 52)


func _on_finished(id: int, place: int, _t: float) -> void:
    if id != local_id:
        return
    _results_open = true
    _panel_title.text = "CORRIDA FINALIZADA\nVocê chegou em %dº" % place
    _resume_btn.visible = false
    _results_box.visible = true
    _fill_results()
    _panel.visible = true


func _fill_results() -> void:
    for c in _results_box.get_children():
        c.queue_free()
    for h in ["Pos", "Piloto", "Tempo", "Melhor volta"]:
        var hl := Label.new()
        hl.text = h
        hl.add_theme_color_override("font_color", UI.ACCENT)
        hl.add_theme_font_size_override("font_size", 20)
        _results_box.add_child(hl)
    var shown := 0
    for r in race.standings:
        var rr: RaceManager.Racer = r
        if shown >= 8:
            break
        shown += 1
        var vals := [str(rr.rank), rr.name, (fmt(rr.finish_time) if rr.finished else "em prova"), fmt(rr.best_lap)]
        for v in vals:
            var l := Label.new()
            l.text = str(v)
            l.add_theme_font_size_override("font_size", 20)
            if rr.id == local_id:
                l.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
            _results_box.add_child(l)


func toggle_pause() -> void:
    if race != null and _results_open:
        return
    var opened := not _panel.visible
    _panel_title.text = "PAUSADO"
    _resume_btn.visible = true
    _results_box.visible = false
    _panel.visible = opened
    if Game.mode != "online":
        get_tree().paused = opened


func _on_restart() -> void:
    get_tree().paused = false
    restart_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause()
