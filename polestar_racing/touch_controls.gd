class_name TouchControls
extends Control
## Controles de toque multitoque (acelerar + virar ao mesmo tempo).
## Aparece sozinho em celular/tablet. No PC, marque force_show para testar.

signal pause_pressed
signal camera_pressed
signal reset_pressed

const ACTIONS := {
    "left": "steer_left", "right": "steer_right",
    "gas": "accelerate", "brake": "brake", "hand": "handbrake",
}
const LABELS := {
    "left": "<", "right": ">", "gas": "ACEL.", "brake": "RÉ / FREIO", "hand": "DRIFT",
    "pause": "II", "camera": "CAM", "reset": "RESET",
}

@export var force_show := false

var _fingers := {}   # indice do dedo -> zona
var _held := {}      # acao -> true se NOS a pressionamos


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
    var u := clampf(minf(s.x, s.y) / 6.0, 70.0, 150.0)
    return {
        "left": Rect2(u * 0.3, s.y - u * 1.6, u * 1.3, u * 1.3),
        "right": Rect2(u * 1.75, s.y - u * 1.6, u * 1.3, u * 1.3),
        "gas": Rect2(s.x - u * 1.7, s.y - u * 2.3, u * 1.4, u * 2.0),
        "brake": Rect2(s.x - u * 3.2, s.y - u * 1.6, u * 1.4, u * 1.3),
        "hand": Rect2(s.x - u * 3.2, s.y - u * 2.9, u * 1.4, u * 1.1),
        "pause": Rect2(s.x - u * 0.95, 8.0, u * 0.85, u * 0.55),
        "camera": Rect2(s.x - u * 1.95, 8.0, u * 0.9, u * 0.55),
        "reset": Rect2(s.x - u * 3.15, 8.0, u * 1.1, u * 0.55),
    }


func _zone_at(pos: Vector2) -> String:
    var z := _zones()
    for key in z:
        var r: Rect2 = z[key]
        if r.has_point(pos):
            return key
    return ""


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            var zone := _zone_at(event.position)
            match zone:
                "pause":
                    pause_pressed.emit()
                "camera":
                    camera_pressed.emit()
                "reset":
                    reset_pressed.emit()
                "":
                    pass
                _:
                    _fingers[event.index] = zone
        else:
            _fingers.erase(event.index)
    elif event is InputEventScreenDrag:
        if _fingers.has(event.index):
            var z2 := _zone_at(event.position)
            if ACTIONS.has(z2):
                _fingers[event.index] = z2
            else:
                _fingers.erase(event.index)


func _process(_delta: float) -> void:
    var active := _fingers.values()
    for zone in ACTIONS:
        var action: String = ACTIONS[zone]
        if zone in active:
            Input.action_press(action)
            _held[action] = true
        elif _held.get(action, false):
            Input.action_release(action)
            _held[action] = false
    queue_redraw()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var active := _fingers.values()
    var z := _zones()
    for key in z:
        var r: Rect2 = z[key]
        var on: bool = key in active
        draw_rect(r, Color(1, 1, 1, 0.32 if on else 0.14), true)
        draw_rect(r, Color(1, 1, 1, 0.6), false, 3.0)
        draw_string(font, r.position + Vector2(0.0, r.size.y * 0.5 + 10.0), LABELS[key],
                HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color.WHITE)
