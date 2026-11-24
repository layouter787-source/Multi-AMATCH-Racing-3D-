class_name DayNight
extends Node
## Ciclo dia/noite: o sol desce, o ceu fica laranja no entardecer, as estrelas e a
## lua aparecem, os postes/janelas/neon acendem e os faróis ligam sozinhos.

const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, fog_disabled;
uniform float night = 0.0;
varying vec3 dir;
void vertex() { dir = normalize(VERTEX); }
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void fragment() {
    vec3 d = normalize(dir);
    vec3 g = floor(d * 230.0);
    float s = step(0.9965, h(g));
    float tw = 0.6 + 0.4 * sin(TIME * 3.0 + h(g) * 30.0);
    ALBEDO = vec3(s * tw) * night * step(0.02, d.y);
}
"""

var env_d: Dictionary = {}
var theme: Dictionary = {}
var scenery: Scenery
var cars_fn: Callable
var cam: Camera3D
var hour := 17.0
var hours_per_second := 0.025
var frozen := false

var _stars: MeshInstance3D
var _star_mat: ShaderMaterial
var _moon: MeshInstance3D
var _label: Label
var _lights_on := false
var _day_sky_top: Color
var _day_hor: Color
var _day_fog: Color
var _day_sun: Color
var _day_sun_e: float
var _day_amb: float
var _day_fog_d: float


func setup(d: Dictionary, th: Dictionary, c: Camera3D, track_id: String) -> void:
    env_d = d
    theme = th
    cam = c
    _day_sky_top = th["sky_top"]
    _day_hor = th["sky_horizon"]
    _day_fog = th["fog"]
    _day_sun = th["sun_color"]
    _day_sun_e = float(th["sun_energy"])
    _day_amb = float(th["ambient"])
    _day_fog_d = float(th["fog_density"])
    var starts := {"verde": 15.5, "deserto": 16.5, "costa": 16.0, "neve": 11.0, "cidade": 22.0}
    hour = float(starts.get(track_id, 16.0))
    if th.get("night", false):
        frozen = true
        hour = 22.0
    _build_sky_objects()
    var cl := CanvasLayer.new()
    cl.layer = 5
    add_child(cl)
    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 22)
    _label.add_theme_color_override("font_color", Color.WHITE)
    _label.add_theme_color_override("font_outline_color", Color.BLACK)
    _label.add_theme_constant_override("outline_size", 6)
    _label.anchor_left = 1.0
    _label.anchor_right = 1.0
    _label.offset_left = -190.0
    _label.offset_right = -16.0
    _label.offset_top = 70.0
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    cl.add_child(_label)
    _apply(0.0)


func _build_sky_objects() -> void:
    var sm := SphereMesh.new()
    sm.radius = 2000.0
    sm.height = 4000.0
    sm.radial_segments = 24
    sm.rings = 12
    _stars = MeshInstance3D.new()
    _stars.mesh = sm
    var sh := Shader.new()
    sh.code = STAR_SHADER
    _star_mat = ShaderMaterial.new()
    _star_mat.shader = sh
    _stars.material_override = _star_mat
    _stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_stars)
    var mm := SphereMesh.new()
    mm.radius = 55.0
    mm.height = 110.0
    _moon = MeshInstance3D.new()
    _moon.mesh = mm
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.95, 0.96, 1.0)
    mat.fog_disabled = true
    _moon.material_override = mat
    _moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_moon)


func _process(delta: float) -> void:
    if not frozen:
        hour = fposmod(hour + hours_per_second * delta, 24.0)
    _apply(delta)


func night_factor() -> float:
    var elev := _sun_elev()
    return clampf(1.0 - (elev + 0.12) / 0.3, 0.0, 1.0)


func _sun_elev() -> float:
    return sin((hour - 6.0) / 12.0 * PI)      # -1..1 (positivo = dia)


func _apply(_delta: float) -> void:
    var elev := _sun_elev()
    var night := night_factor()
    var dusk := clampf(1.0 - absf(elev) / 0.35, 0.0, 1.0)     # entardecer/amanhecer
    var sun: DirectionalLight3D = env_d["sun"]
    var env: Environment = env_d["env"]
    var sky: ProceduralSkyMaterial = env_d["sky"]
    var az: float = (theme["sun_rot"] as Vector3).y
    var ang := clampf(elev, -1.0, 1.0)
    # de dia o sol ilumina; de noite a "luz" vira a lua (azul e fraca)
    if elev > -0.05:
        sun.rotation_degrees = Vector3(-maxf(rad_to_deg(asin(clampf(ang, 0.0, 1.0))), 4.0), az, 0.0)
        sun.light_color = _day_sun.lerp(Color(1.0, 0.55, 0.3), dusk * 0.8)
        sun.light_energy = _day_sun_e * clampf(elev * 2.2 + 0.2, 0.0, 1.0)
    else:
        sun.rotation_degrees = Vector3(-45.0, az + 180.0, 0.0)
        sun.light_color = Color(0.45, 0.55, 1.0)
        sun.light_energy = 0.28 * night
    var night_top := Color(0.01, 0.02, 0.06)
    var night_hor := Color(0.05, 0.07, 0.15)
    var dusk_hor := Color(1.0, 0.45, 0.2)
    var top := _day_sky_top.lerp(Color(0.25, 0.2, 0.4), dusk * 0.6).lerp(night_top, night)
    var hor := _day_hor.lerp(dusk_hor, dusk * 0.85).lerp(night_hor, night)
    sky.sky_top_color = top
    sky.sky_horizon_color = hor
    sky.ground_horizon_color = hor
    sky.ground_bottom_color = Color(theme["ground"]).lerp(Color(0.02, 0.02, 0.04), night)
    env.fog_light_color = _day_fog.lerp(dusk_hor, dusk * 0.6).lerp(night_hor, night)
    env.fog_density = _day_fog_d * lerpf(1.0, 1.4, night)
    env.ambient_light_energy = lerpf(_day_amb, 0.45, night)
    env.ambient_light_color = Color(1, 1, 1).lerp(Color(0.5, 0.6, 1.0), night)
    # estrelas e lua seguem a camera (sem girar com ela)
    _star_mat.set_shader_parameter("night", night)
    if cam != null and is_instance_valid(cam):
        _stars.global_position = cam.global_position
        var moon_dir := Vector3(sin(deg_to_rad(az + 180.0)) * 0.7, 0.55, cos(deg_to_rad(az + 180.0)) * 0.7).normalized()
        _moon.global_position = cam.global_position + moon_dir * 1500.0
    _moon.visible = night > 0.3
    # luzes artificiais
    var glow := night
    for m in (scenery.emissive_mats if scenery != null else []):
        var sm := m as StandardMaterial3D
        sm.emission_energy_multiplier = glow * float(sm.get_meta("neon", 1.6))
    # farois ligam com histerese
    var want_on := night > 0.45 if not _lights_on else night > 0.3
    if want_on != _lights_on:
        _lights_on = want_on
        if cars_fn.is_valid():
            for c in cars_fn.call():
                if is_instance_valid(c):
                    (c as PlayerCar).set_headlights(_lights_on)
    var hh := int(hour)
    var mn := int((hour - float(hh)) * 60.0)
    if _label != null:
        _label.text = "%02d:%02d" % [hh, mn]
