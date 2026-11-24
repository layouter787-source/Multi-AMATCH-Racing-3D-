class_name TireFX
extends Node
## Fumaca/poeira nas rodas traseiras quando o carro derrapa.

var car: PlayerCar
var tint := Color(0.85, 0.85, 0.85, 0.55)
var _parts: Array = []
var _wheels: Array = []


func _ready() -> void:
    var grad := Gradient.new()
    grad.set_color(0, Color(1, 1, 1, 0.6))
    grad.set_color(1, Color(1, 1, 1, 0.0))
    var tex := GradientTexture2D.new()
    tex.gradient = grad
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(0.5, 0.0)
    tex.width = 64
    tex.height = 64
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture = tex
    mat.vertex_color_use_as_albedo = true
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.billboard_keep_scale = true
    var quad := QuadMesh.new()
    quad.size = Vector2(1, 1)
    quad.material = mat
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0.7))
    ramp.set_color(1, Color(1, 1, 1, 0.0))
    for w in car.rear_wheels():
        var p := CPUParticles3D.new()
        p.mesh = quad
        p.amount = 24
        p.lifetime = 1.1
        p.emitting = false
        p.direction = Vector3(0, 1, 0)
        p.spread = 30.0
        p.initial_velocity_min = 0.6
        p.initial_velocity_max = 1.6
        p.gravity = Vector3(0, 0.4, 0)
        p.scale_amount_min = 1.2
        p.scale_amount_max = 2.4
        p.color = tint
        p.color_ramp = ramp
        p.local_coords = false
        car.add_child(p)
        p.position = Vector3((w as Node3D).position.x, 0.05, (w as Node3D).position.z)
        _parts.append(p)
        _wheels.append(w)


func _physics_process(_delta: float) -> void:
    if car == null or not is_instance_valid(car):
        return
    for i in _wheels.size():
        var w := _wheels[i] as VehicleWheel3D
        var slip := w.get_skidinfo()
        (_parts[i] as CPUParticles3D).emitting = w.is_in_contact() and slip < 0.55 and car.speed_kmh > 8.0
