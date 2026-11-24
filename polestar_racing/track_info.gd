class_name TrackInfo
extends RefCounted
## Acesso rapido aos dados de uma pista (linha central, velocidades, grid).

var id := ""
var data: Dictionary = {}
var pts: Array = []
var speeds: Array = []
var n := 0
var step := 2.0
var length := 0.0
var theme: Dictionary = {}
var glb := ""
var _tan: Array = []


func _init(track_id: String) -> void:
    id = track_id
    data = Catalog.track_data(track_id)
    pts = data["pts"]
    speeds = data["speed"]
    n = pts.size()
    step = data["step"]
    length = data["length"]
    theme = data["theme"]
    glb = data["glb"]
    for i in n:
        var a: Vector3 = pts[(i - 1 + n) % n]
        var b: Vector3 = pts[(i + 1) % n]
        var t := b - a
        t.y = 0.0
        _tan.append(t.normalized())


func _wrap_index(i: int) -> int:
    return ((i % n) + n) % n


func point(i: int) -> Vector3:
    return pts[_wrap_index(i)]


func tangent(i: int) -> Vector3:
    return _tan[_wrap_index(i)]


func normal(i: int) -> Vector3:
    var t: Vector3 = _tan[_wrap_index(i)]
    return Vector3(-t.z, 0.0, t.x)


func speed_at(i: int) -> float:
    return speeds[_wrap_index(i)]


func nearest_global(p: Vector3) -> int:
    var best := 0
    var bd := INF
    for i in n:
        var q: Vector3 = pts[i]
        var d := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
        if d < bd:
            bd = d
            best = i
    return best


func nearest_window(p: Vector3, hint: int, back: int, fwd: int) -> int:
    var best: int = _wrap_index(hint)
    var bd := INF
    for k in range(-back, fwd + 1):
        var i: int = _wrap_index(hint + k)
        var q: Vector3 = pts[i]
        var d := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
        if d < bd:
            bd = d
            best = i
    return best


func dist_xz(p: Vector3, i: int) -> float:
    var q: Vector3 = pts[_wrap_index(i)]
    return Vector2(q.x - p.x, q.z - p.z).length()


func transform_at(i: int, lift: float, lateral: float = 0.0) -> Transform3D:
    var t := tangent(i)
    var pos := point(i) + normal(i) * lateral + Vector3.UP * lift
    return Transform3D(Basis(Vector3.UP, atan2(-t.x, -t.z)), pos)


func grid_transform(slot: int) -> Transform3D:
    var g: Array = data["grid"]
    var gy: Array = data["grid_yaw"]
    var s := mini(slot, g.size() - 1)
    var p: Vector3 = g[s]
    return Transform3D(Basis(Vector3.UP, float(gy[s])), p + Vector3.UP * 0.7)
