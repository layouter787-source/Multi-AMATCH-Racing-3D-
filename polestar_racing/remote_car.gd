class_name RemoteCar
extends AnimatableBody3D
## Carro de outro jogador (ou IA do anfitriao) visto pela rede.
## Interpola os pacotes recebidos com um pequeno atraso para ficar suave.

const DELAY := 0.12

var def: Dictionary = {}
var paint_color := Color.WHITE
var speed := 0.0
var forward_speed := 0.0

var _model: Node3D
var _buf: Array = []
var _spin := 0.0
var _wheels := {}
var _steers := {}
var _tail_mats: Array = []
var _brake := false
var _was_brake := false


func _ready() -> void:
    if def.is_empty():
        def = Catalog.car_def("p911ts")
    for c in def["collision"]:
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = c["size"]
        cs.shape = bs
        cs.position = c["pos"]
        add_child(cs)
    _model = CarVisual.load_model(def)
    add_child(_model)
    CarVisual.apply_paint(_model, paint_color)
    _tail_mats = CarVisual.override_materials(_model, "Taillight")
    for k in ["FL", "FR", "RL", "RR"]:
        _wheels[k] = _model.find_child("Wheel_" + k, true, false)
    for k in ["FL", "FR"]:
        _steers[k] = _model.find_child("Wheel_%s_Steer" % k, true, false)


func push_state(pos: Vector3, quat: Quaternion, vel: Vector3, steer: float, brake_on: bool) -> void:
    _buf.append([Time.get_ticks_msec() / 1000.0, pos, quat, vel, steer])
    if _buf.size() > 30:
        _buf.pop_front()
    _brake = brake_on


func _physics_process(delta: float) -> void:
    if _buf.is_empty():
        return
    var now := Time.get_ticks_msec() / 1000.0 - DELAY
    var a = null
    var b = null
    for i in range(_buf.size() - 1):
        if float(_buf[i][0]) <= now and float(_buf[i + 1][0]) >= now:
            a = _buf[i]
            b = _buf[i + 1]
            break
    var pos := Vector3.ZERO
    var q := Quaternion.IDENTITY
    var vel := Vector3.ZERO
    var st := 0.0
    if a != null:
        var span: float = float(b[0]) - float(a[0])
        var t: float = 0.0 if span <= 0.0001 else (now - float(a[0])) / span
        var pa: Vector3 = a[1]
        var pb: Vector3 = b[1]
        var qa: Quaternion = a[2]
        var qb: Quaternion = b[2]
        pos = pa.lerp(pb, t)
        q = qa.slerp(qb, t)
        vel = (a[3] as Vector3).lerp(b[3], t)
        st = lerpf(float(a[4]), float(b[4]), t)
    else:
        var last: Array = _buf[_buf.size() - 1]
        var dt := clampf(now - float(last[0]), 0.0, 0.3)
        var lp: Vector3 = last[1]
        var lv: Vector3 = last[3]
        pos = lp + lv * dt
        q = last[2]
        vel = lv
        st = float(last[4])
    global_transform = Transform3D(Basis(q), pos)
    speed = vel.length()
    forward_speed = -global_transform.basis.z.dot(vel)

    _spin += forward_speed / float(def["wheel_radius"]) * delta
    for k in _wheels:
        var w = _wheels[k]
        if w != null:
            w.rotation.x = -_spin
    for k in _steers:
        var s = _steers[k]
        if s != null:
            s.rotation.y = st
    if _brake != _was_brake:
        _was_brake = _brake
        for m in _tail_mats:
            (m as StandardMaterial3D).emission_energy_multiplier = 3.5 if _brake else 1.0
