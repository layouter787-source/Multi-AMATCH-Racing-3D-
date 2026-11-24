class_name ChaseCamera
extends Camera3D
## Camera de perseguicao com 3 modos: perto, longe e capo.

var target: PlayerCar
var mode := 0
var _first := true
var _shake := 0.0

const CHASE := [
    {"dist": 6.5, "height": 2.3, "look": 1.1},
    {"dist": 10.5, "height": 4.2, "look": 1.0},
]


func next_mode() -> void:
    mode = (mode + 1) % 3
    _first = true
    if target != null and target.interior != null:
        target.interior.set_cockpit_view(mode == 2)


func shake(strength: float) -> void:
    _shake = maxf(_shake, strength)


func _physics_process(delta: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    var t := target.global_transform
    if mode == 2:
        var eye_local := Vector3(0.0, float(target.def["height"]) * 0.85, -0.4)
        if target.interior != null:
            eye_local = target.interior.eye
        elif target.def.has("eye"):
            eye_local = (target.def["eye"] as Vector3) + Vector3(0.0, target.ride_height, 0.0)
        var sh := Vector3(randf() - 0.5, randf() - 0.5, 0.0) * _shake * 0.12
        # a cabeca acompanha a forca lateral (sensacao de curva)
        var lean := Basis(Vector3(0, 0, 1), -target.lateral_g * 0.02)
        global_transform = Transform3D(t.basis * lean, t * (eye_local + sh))
        _shake = move_toward(_shake, 0.0, delta * 2.5)
        fov = lerpf(fov, 82.0 + minf(target.speed_kmh, 120.0) * 0.05, 1.0 - exp(-4.0 * delta))
        return

    var fwd := -t.basis.z
    fwd.y = 0.0
    fwd = fwd.normalized()
    var vel := target.linear_velocity
    vel.y = 0.0
    var dir := fwd
    if vel.length() > 6.0 and target.forward_speed > 0.0:
        dir = fwd.slerp(vel.normalized(), 0.35).normalized()

    var cfg: Dictionary = CHASE[mode]
    var desired := t.origin - dir * float(cfg["dist"]) + Vector3.UP * float(cfg["height"])
    var pos := desired
    if not _first:
        pos = global_position.lerp(desired, 1.0 - exp(-6.0 * delta))
    _first = false
    pos += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * _shake * 0.25
    _shake = move_toward(_shake, 0.0, delta * 2.5)
    look_at_from_position(pos, t.origin + Vector3.UP * float(cfg["look"]) + fwd * 3.0, Vector3.UP)
    var want_fov := 68.0 + minf(target.speed_kmh, 120.0) * 0.12
    fov = lerpf(fov, want_fov, 1.0 - exp(-4.0 * delta))
