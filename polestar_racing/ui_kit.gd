class_name UI
extends RefCounted
## Tema visual e helpers de interface (botoes grandes para toque).

const ACCENT := Color(0.25, 0.85, 1.0)
const PANEL := Color(0.05, 0.07, 0.11, 0.93)


static func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius := 14) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(2 if border.a > 0.0 else 0)
    sb.set_corner_radius_all(radius)
    sb.content_margin_left = 20
    sb.content_margin_right = 20
    sb.content_margin_top = 12
    sb.content_margin_bottom = 12
    return sb


static func make_theme() -> Theme:
    var t := Theme.new()
    t.set_default_font_size(24)
    t.set_stylebox("normal", "Button", _sb(Color(0.12, 0.17, 0.25, 0.95), Color(1, 1, 1, 0.12)))
    t.set_stylebox("hover", "Button", _sb(Color(0.16, 0.24, 0.35, 0.95), ACCENT))
    t.set_stylebox("pressed", "Button", _sb(Color(0.12, 0.45, 0.6, 0.98), ACCENT))
    t.set_stylebox("disabled", "Button", _sb(Color(0.1, 0.12, 0.16, 0.7)))
    t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), ACCENT))
    t.set_color("font_color", "Button", Color.WHITE)
    t.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.6))
    t.set_stylebox("panel", "PanelContainer", _sb(PANEL, Color(1, 1, 1, 0.1), 18))
    t.set_stylebox("normal", "LineEdit", _sb(Color(0.08, 0.1, 0.15, 1.0), Color(1, 1, 1, 0.2), 10))
    t.set_stylebox("focus", "LineEdit", _sb(Color(0.08, 0.1, 0.15, 1.0), ACCENT, 10))
    t.set_color("font_color", "Label", Color.WHITE)
    t.set_constant("separation", "VBoxContainer", 10)
    return t


static func btn(text: String, cb: Callable, accent := false) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 62)
    b.add_theme_font_size_override("font_size", 26)
    if accent:
        b.add_theme_stylebox_override("normal", _sb(Color(0.08, 0.5, 0.68, 0.98), ACCENT))
        b.add_theme_stylebox_override("hover", _sb(Color(0.1, 0.6, 0.8, 0.98), Color.WHITE))
    b.pressed.connect(cb)
    return b


static func label(text: String, size := 24, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l


static func row(caption: String, control: Control) -> HBoxContainer:
    var h := HBoxContainer.new()
    var l := label(caption, 22)
    l.custom_minimum_size = Vector2(190, 0)
    h.add_child(l)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(control)
    return h
