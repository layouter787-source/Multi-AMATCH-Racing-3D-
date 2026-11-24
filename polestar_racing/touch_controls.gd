class_name TouchControls
extends Control
## HUD de toque multitoque com dois esquemas configuráveis.

signal pause_pressed
signal camera_pressed
signal reset_pressed

const ACTIONS := {
    "left": "steer_left", "right": "steer_right",
    "gas": "accelerate", "brake": "brake", "hand": "handbrake",
}
const LABELS := {
    "left": "◀", "right": "▶", "gas": "ACELERAR",
    "brake": "TRAVAR", "hand": "DRIFT",
    "pause": "Ⅱ", "camera": "CÂM.", "reset": "RESET",
}
const CYAN := Color(0.18, 0.78, 0.96, 1.0)
const ORANGE := Color(1.0, 0.48, 0.19, 1.0)

@export var force_show := false

var _fingers: Dictionary = {}
var _held: Dictionary = {}


func _ready() -> void:
    GameInput.ensure()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = force_show or DisplayServer.is_touchscreen_available()
    set_process_input(visible)
    set_process(visible)


func _zones() -> Dictionary:
    var s := get_viewport_rect().size
    var u := clampf(minf(s.x, s.y) / 6.0, 66.0, 116.0)
    var left_side := Game.control_layout == 0
    var steer_x := u * 0.28 if left_side else s.x - u * 2.75
    var pedal_x := s.x - u * 2.65 if left_side else u * 0.28
    var top := s.y - u * 1.75
    var zones := {
        "left": Rect2(steer_x, top, u * 1.05, u * 1.05),
        "right": Rect2(steer_x + u * 1.12, top, u * 1.05, u * 1.05),
        "gas": Rect2(pedal_x + u * 1.12, s.y - u * 2.15, u * 1.05, u * 1.75),
        "brake": Rect2(pedal_x, s.y - u * 1.45, u * 1.05, u * 1.05),
        "hand": Rect2(pedal_x, s.y - u * 2.62, u * 1.05, u * 0.92),
        "pause": Rect2(s.x - u * 0.88, 12.0, u * 0.72, u * 0.55),
        "camera": Rect2(s.x - u * 1.82, 12.0, u * 0.82, u * 0.55),
        "reset": Rect2(s.x - u * 2.82, 12.0, u * 0.88, u * 0.55),
    }
    return zones


func _zone_at(pos: Vector2) -> String:
    for key in _zones():
        if (_zones()[key] as Rect2).has_point(pos):
            return key
    return ""


func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            var zone := _zone_at(event.position)
            match zone:
                "pause": pause_pressed.emit()
                "camera": camera_pressed.emit()
                "reset": reset_pressed.emit()
                "":
                    pass
                _:
                    _fingers[event.index] = zone
        else:
            _fingers.erase(event.index)
    elif event is InputEventScreenDrag and _fingers.has(event.index):
        var next_zone := _zone_at(event.position)
        if ACTIONS.has(next_zone):
            _fingers[event.index] = next_zone
        else:
            _fingers.erase(event.index)


func _process(_delta: float) -> void:
    var active := _fingers.values()
    for zone in ACTIONS:
        var action: String = ACTIONS[zone]
        if zone in active:
            if not _held.get(action, false):
                Input.action_press(action)
            _held[action] = true
        elif _held.get(action, false):
            Input.action_release(action)
            _held[action] = false
    queue_redraw()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var active := _fingers.values()
    for key in _zones():
        var r: Rect2 = _zones()[key]
        var pressed := key in active
        var center := r.get_center()
        var radius := minf(r.size.x, r.size.y) * 0.47
        var base := CYAN
        if key == "gas":
            base = Color(0.16, 0.78, 0.48)
        elif key == "brake":
            base = ORANGE
        elif key == "hand":
            base = Color(0.95, 0.72, 0.22)
        elif key in ["pause", "camera", "reset"]:
            base = Color(0.24, 0.32, 0.42)
        var alpha := 0.88 if pressed else 0.38
        if key in ["pause", "camera", "reset"]:
            var rr := Rect2(r.position, r.size)
            draw_rect(rr, Color(0.035, 0.07, 0.11, 0.72), true)
            draw_rect(rr, Color(base.r, base.g, base.b, 0.85), false, 2.0)
            draw_string(font, center + Vector2(-r.size.x * 0.45, 7.0), LABELS[key],
                HORIZONTAL_ALIGNMENT_CENTER, r.size.x * 0.9, 15, Color.WHITE)
        else:
            draw_circle(center, radius, Color(0.025, 0.045, 0.07, 0.78))
            draw_circle(center, radius - 4.0, Color(base.r, base.g, base.b, alpha))
            draw_arc(center, radius - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.75), 2.5, true)
            var font_size := 17 if key in ["gas", "brake", "hand"] else 34
            var label_y := center.y + font_size * 0.34
            draw_string(font, Vector2(r.position.x, label_y), LABELS[key],
                HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, Color.WHITE)
