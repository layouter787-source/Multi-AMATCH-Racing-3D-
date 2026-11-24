class_name AIDriver
extends Node
## Piloto automatico: segue a linha da pista, freia nas curvas (perfil de velocidade
## pre-calculado), desvia de outros carros e se recupera quando fica preso.

var car: PlayerCar
var track: TrackInfo
var skill := 1.0
var rubber := 1.0
var base_lane := 0.0
var others: Array = []

var idx := 0
var _lane := 0.0
var _stuck := 0.0
var _flip := 0.0
var _off := 0.0


func _ready() -> void:
    idx = track.nearest_global(car.global_position)
    _lane = base_lane


func _physics_process(delta: float) -> void:
    if car == null or track == null or not is_instance_valid(car):
        return
    if not car.is_ai or not car.controls_enabled:
        car.ai_throttle = 0.0
        car.ai_brake = 0.0
        car.ai_steer = 0.0
        return
    var pos := car.global_position
    idx = track.nearest_window(pos, idx, 12, 40)
    var spd := maxf(car.forward_speed, 0.0)
    var inv := car.global_transform.affine_inverse()

    # desvio de carros a frente
    var want_lane := base_lane
    var slow_to := 999.0
    var ln := inv.basis * track.normal(idx)
    for o in others:
        if o == car or not is_instance_valid(o):
            continue
        var rel: Vector3 = inv * o.global_position
        if rel.z < 0.0 and rel.z > -18.0 and absf(rel.x) < 2.8:
            var side := -signf(rel.x)
            if absf(rel.x) < 0.3:
                side = 1.0 if _lane < 0.0 else -1.0
            want_lane = clampf(_lane + side * signf(ln.x) * 3.2, -4.2, 4.2)
            if rel.z > -9.0:
                slow_to = minf(slow_to, float(o.forward_speed))
    _lane = move_toward(_lane, want_lane, delta * 3.0)

    # ponto alvo
    var ld := 7.0 + spd * 0.75
    var la := int(ld / track.step)
    var tgt := track.point(idx + la) + track.normal(idx + la) * _lane
    var local := inv * tgt
    var ang := atan2(local.x, -local.z)
    var steer := clampf(-ang * 2.2, -1.0, 1.0)

    # velocidade alvo
    var horizon := int((spd * 1.4 + 12.0) / track.step) + 4
    var vt := 999.0
    for k in range(0, horizon, 2):
        vt = minf(vt, track.speed_at(idx + k))
    vt = minf(vt, car.max_speed_kmh / 3.6) * skill * rubber
    vt = minf(vt, slow_to + 1.5)
    var err := vt - spd
    var thr := clampf(err * 0.6, 0.0, 1.0)
    var brk := 0.0
    if err < -1.0:
        brk = clampf(-err * 0.35, 0.0, 1.0)
        thr = 0.0
    car.ai_throttle = thr
    car.ai_brake = brk
    car.ai_steer = steer
    car.ai_hand = 0.0

    # recuperacao: preso, capotado ou fora da pista
    if spd < 1.2 and thr > 0.5:
        _stuck += delta
    else:
        _stuck = 0.0
    if car.global_transform.basis.y.y < 0.35:
        _flip += delta
    else:
        _flip = 0.0
    if track.dist_xz(pos, idx) > 16.0:
        _off += delta
    else:
        _off = 0.0
    if _stuck > 2.5 or _flip > 2.0 or _off > 5.0:
        _stuck = 0.0
        _flip = 0.0
        _off = 0.0
        car.place(track.transform_at(idx, 0.7, _lane * 0.5))
