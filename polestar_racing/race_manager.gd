class_name RaceManager
extends Node
## Contagem regressiva, progresso de TODOS os pilotos (humanos, IA, remotos),
## voltas, tempos, posicoes e fim de corrida. Funciona igual em todas as maquinas
## porque usa apenas a posicao dos carros.

signal countdown_tick(n: int)        # 3, 2, 1, 0 (= VAI!)
signal go()
signal lap_completed(id: int, lap: int, lap_time: float, is_best: bool)
signal racer_finished(id: int, place: int, time: float)
signal standings_changed()


class Racer:
    var id := 0
    var name := ""
    var color_idx := -1
    var car_id := ""
    var node: Node3D
    var is_human := false
    var local := false
    var idx := 0
    var unwrapped := 0.0
    var max_unwrapped := 0.0
    var laps := 0
    var lap_time := 0.0
    var best_lap := INF
    var finished := false
    var finish_time := 0.0
    var place := 0
    var rank := 0
    var off_t := 0.0
    var wrong_t := 0.0
    var wrong_way := false
    var good_idx := 0
    var good_t := 0.0


var track: TrackInfo
var total_laps := 3
var local_id := 1
var racers: Dictionary = {}
var standings: Array = []
var running := false
var race_time := 0.0
var finish_count := 0
var _rank_t := 0.0


func add_racer(id: int, rname: String, color_idx: int, car_id: String, node: Node3D, is_human: bool, local: bool) -> void:
    var r := Racer.new()
    r.id = id
    r.name = rname
    r.color_idx = color_idx
    r.car_id = car_id
    r.node = node
    r.is_human = is_human
    r.local = local
    r.idx = track.nearest_global(node.global_position)
    r.unwrapped = float(r.idx) - (float(track.n) if float(r.idx) > float(track.n) * 0.5 else 0.0)
    r.max_unwrapped = r.unwrapped
    r.good_idx = r.idx
    racers[id] = r


func remove_racer(id: int) -> void:
    racers.erase(id)
    _compute_standings()


func get_racer(id: int) -> Racer:
    return racers.get(id)


func start_countdown() -> void:
    for n in [3, 2, 1]:
        countdown_tick.emit(n)
        await get_tree().create_timer(1.0, false).timeout
    countdown_tick.emit(0)
    running = true
    go.emit()


func _physics_process(delta: float) -> void:
    for id in racers:
        var r: Racer = racers[id]
        if is_instance_valid(r.node):
            _update(r, delta)
    _rank_t += delta
    if _rank_t > 0.2:
        _rank_t = 0.0
        _compute_standings()
    if running:
        race_time += delta


func _update(r: Racer, delta: float) -> void:
    var pos := r.node.global_position
    var n := track.n
    var cand := track.nearest_window(pos, r.idx, 15, 60)
    var d := track.dist_xz(pos, cand)
    if d > 45.0:
        r.off_t += delta
        if r.off_t > 3.0:
            cand = track.nearest_global(pos)
            r.off_t = 0.0
        else:
            cand = r.idx
    else:
        r.off_t = 0.0
    var di := cand - r.idx
    var half := int(n * 0.5)
    if di > half:
        di -= n
    elif di < -half:
        di += n
    r.unwrapped += float(di)
    r.idx = cand

    if running and r.unwrapped > r.max_unwrapped:
        var before := int(floor(r.max_unwrapped / float(n)))
        r.max_unwrapped = r.unwrapped
        var after := int(floor(r.max_unwrapped / float(n)))
        if after > before:
            _on_cross(r, after)
    if running and not r.finished:
        r.lap_time += delta

    if r.node is PlayerCar:
        var c: PlayerCar = r.node
        var tv := track.tangent(r.idx)
        var vv := Vector3(c.linear_velocity.x, 0.0, c.linear_velocity.z)
        if vv.length() > 3.0 and vv.normalized().dot(tv) < -0.4:
            r.wrong_t += delta
        else:
            r.wrong_t = 0.0
        r.wrong_way = r.wrong_t > 1.5
        r.good_t += delta
        if r.good_t > 0.5:
            r.good_t = 0.0
            if d < 8.0 and c.global_transform.basis.y.y > 0.7:
                r.good_idx = r.idx


func _on_cross(r: Racer, k: int) -> void:
    if k <= 0:
        r.lap_time = 0.0
        return
    r.laps = k
    var t := r.lap_time
    var best := t < r.best_lap
    if best:
        r.best_lap = t
    r.lap_time = 0.0
    lap_completed.emit(r.id, k, t, best)
    if r.local and r.is_human and r.id == local_id:
        Game.record_lap(track.id, t)
    if k >= total_laps and not r.finished:
        r.finished = true
        r.finish_time = race_time
        finish_count += 1
        r.place = finish_count
        racer_finished.emit(r.id, r.place, r.finish_time)


func _compute_standings() -> void:
    var arr: Array = racers.values()
    arr.sort_custom(func(a, b):
        if a.finished != b.finished:
            return a.finished
        if a.finished:
            return a.place < b.place
        return a.unwrapped > b.unwrapped)
    standings = arr
    for i in arr.size():
        arr[i].rank = i + 1
    standings_changed.emit()


## Transform para recolocar o carro: ultimo ponto bom da pista.
func get_respawn(id: int) -> Transform3D:
    var r: Racer = racers.get(id)
    if r == null:
        return track.grid_transform(0)
    return track.transform_at(r.good_idx - 2, 0.7)


## Ajuste leve de velocidade da IA (elastico): quem esta muito a frente do jogador alivia, quem esta atras acelera.
func rubber_for(id: int) -> float:
    var me: Racer = racers.get(local_id)
    var r: Racer = racers.get(id)
    if me == null or r == null:
        return 1.0
    var gap := r.unwrapped - me.unwrapped
    return clampf(1.0 - gap * 0.0007, 0.93, 1.04)
