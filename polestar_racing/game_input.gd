class_name GameInput
extends RefCounted
## Cria as acoes de input por codigo (nao precisa mexer em Project Settings).

static func ensure() -> void:
    _add("accelerate", [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
    _add("brake", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
    _add("steer_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
    _add("steer_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
    _add("handbrake", [KEY_SPACE], [JOY_BUTTON_A])
    _add("reset", [KEY_R], [JOY_BUTTON_X])
    _add("camera", [KEY_C], [JOY_BUTTON_Y])
    _add("racing_line", [KEY_L], [JOY_BUTTON_LEFT_SHOULDER])
    _add("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


static func _add(action: String, keys: Array, joy_buttons: Array = [], joy_axes: Array = []) -> void:
    if InputMap.has_action(action):
        return
    InputMap.add_action(action, 0.2)
    for k in keys:
        var e := InputEventKey.new()
        e.physical_keycode = k
        InputMap.action_add_event(action, e)
    for b in joy_buttons:
        var j := InputEventJoypadButton.new()
        j.button_index = b
        InputMap.action_add_event(action, j)
    for a in joy_axes:
        var m := InputEventJoypadMotion.new()
        m.axis = a[0]
        m.axis_value = a[1]
        InputMap.action_add_event(action, m)
