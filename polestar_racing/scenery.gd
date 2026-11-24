class_name Scenery
extends Node3D
## Substitui o "mato" por areas tropicais (palmeiras, folhagem) e, na cidade,
## por arranha-ceus com janelas acesas, postes e neon. Posiciona tudo com raycast
## no terreno. Chame build() depois que o mundo e a fisica estiverem prontos.

var track: TrackInfo
var world: Node3D
var emissive_mats: Array = []     # materiais que acendem a noite (DayNight controla)
var _rng := RandomNumberGenerator.new()


func build() -> void:
    _rng.seed = hash(track.id)
    var veg := world.find_child("Vegetation", true, false)
    if veg:
        veg.visible = false                       # chega de mato
    await get_tree().physics_frame
    await get_tree().physics_frame
    var space := get_world_3d().direct_space_state
    var q := Game.quality
    var step_pts: int = [14, 9, 6][clampi(q, 0, 2)]
    match track.id:
        "cidade":
            _build_city(space, step_pts)
        "neve":
            _build_lamps(space, 12)
        "deserto":
            _build_palms(space, step_pts * 3, 14.0, 60.0, 0.6)    # oasis esparsos
            _build_lamps(space, 14)
        _:
            _build_palms(space, step_pts, 11.0, 55.0, 1.0)
            _build_bushes(space, step_pts)
            _build_lamps(space, 16)


func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float, ref_y: float) -> Variant:
    var rq := PhysicsRayQueryParameters3D.create(Vector3(x, ref_y + 45.0, z), Vector3(x, ref_y - 70.0, z))
    var hit := space.intersect_ray(rq)
    if hit.is_empty():
        return null
    var col: Node = hit["collider"]
    if col == null or not str(col.name).begins_with("Terrain"):
        return null
    return hit["position"]


# ------------------------------------------------------------ palmeiras
func _build_palms(space: PhysicsDirectSpaceState3D, every: int, d0: float, d1: float, density: float) -> void:
    var xs: Array = []
    for i in range(0, track.n, every):
        for side: float in [-1.0, 1.0]:
            if _rng.randf() > density:
                continue
            var p: Vector3 = track.point(i)
            var nrm: Vector3 = track.normal(i)
            var d := _rng.randf_range(d0, d1) * side
            var pos := p + nrm * d + track.tangent(i) * _rng.randf_range(-4.0, 4.0)
            var g = _ground(space, pos.x, pos.z, p.y)
            if g == null:
                continue
            var s := _rng.randf_range(0.8, 1.45)
            var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
            xs.append(Transform3D(b, g))
    _multimesh(xs, _palm_mesh())


func _palm_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var h := 7.0
    var rings := 7
    var seg := 6
    var prev: Array = []
    for r in rings + 1:
        var t := float(r) / float(rings)
        var rad := lerpf(0.30, 0.15, t)
        var cx := 0.9 * t * t
        var y := h * t
        var ring: Array = []
        for k in seg:
            var a := TAU * float(k) / float(seg)
            ring.append(Vector3(cx + cos(a) * rad, y, sin(a) * rad))
        if r > 0:
            for k in seg:
                var k2 := (k + 1) % seg
                var col := Color(0.38, 0.27, 0.16).lerp(Color(0.5, 0.38, 0.24), float(r % 2))
                _quad(st, prev[k], prev[k2], ring[k2], ring[k], col)
        prev = ring
    var top := Vector3(0.9, h, 0.0)
    for f in 10:
        var a := TAU * float(f) / 10.0
        var dir := Vector3(cos(a), 0.0, sin(a))
        var side := Vector3(-dir.z, 0.0, dir.x)
        var col := Color(0.10, 0.42, 0.12).lerp(Color(0.25, 0.6, 0.18), _rng.randf())
        var last_l := top
        var last_r := top
        for s in range(1, 6):
            var u := float(s) / 5.0
            var out := dir * (3.4 * u)
            var droop := Vector3(0, 0.9 * u - 1.9 * u * u, 0)
            var w := 0.55 * sin(u * PI * 0.9 + 0.2)
            var c := top + out + droop
            var l := c - side * w
            var rr := c + side * w
            _quad(st, last_l, last_r, rr, l, col.darkened(0.15 * u))
            last_l = l
            last_r = rr
    st.generate_normals()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.85
    st.set_material(mat)
    return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
    for v in [a, b, c, a, c, d]:
        st.set_color(col)
        st.add_vertex(v)


# ------------------------------------------------------------ folhagem tropical
func _build_bushes(space: PhysicsDirectSpaceState3D, every: int) -> void:
    var xs: Array = []
    for i in range(0, track.n, maxi(every / 2, 3)):
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = track.point(i)
            var d := _rng.randf_range(10.5, 22.0) * side
            var pos := p + track.normal(i) * d
            var g = _ground(space, pos.x, pos.z, p.y)
            if g == null:
                continue
            var s := _rng.randf_range(0.7, 1.5)
            xs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), g))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for f in 7:
        var a := TAU * float(f) / 7.0
        var dir := Vector3(cos(a), 0, sin(a))
        var side := Vector3(-dir.z, 0, dir.x)
        var col := Color(0.12, 0.5, 0.14).lerp(Color(0.3, 0.68, 0.2), _rng.randf())
        var base := Vector3.ZERO
        var tip := dir * 1.3 + Vector3(0, 0.9, 0)
        var mid := dir * 0.7 + Vector3(0, 0.85, 0)
        _quad(st, base - side * 0.05, base + side * 0.05, mid + side * 0.3, mid - side * 0.3, col)
        _quad(st, mid - side * 0.3, mid + side * 0.3, tip, tip, col.darkened(0.12))
    st.generate_normals()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    st.set_material(mat)
    _multimesh(xs, st.commit())


# ------------------------------------------------------------ postes de luz
func _build_lamps(space: PhysicsDirectSpaceState3D, every: int) -> void:
    var xs: Array = []
    for i in range(0, track.n, every):
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = track.point(i)
            var t: Vector3 = track.tangent(i)
            var nrm := Vector3(-t.z, 0.0, t.x)
            var pos := p + nrm * 10.5 * side
            var g = _ground(space, pos.x, pos.z, p.y)
            if g == null:
                continue
            # o braco do poste aponta para a pista
            var yaw := atan2(nrm.x * -side, nrm.z * -side)
            xs.append(Transform3D(Basis(Vector3.UP, yaw), g))
    var pole := SurfaceTool.new()
    pole.begin(Mesh.PRIMITIVE_TRIANGLES)
    var gray := Color(0.18, 0.19, 0.22)
    _add_box(pole, Vector3(0, 3.5, 0), Vector3(0.18, 7.0, 0.18), gray)
    _add_box(pole, Vector3(0, 7.0, 0.9), Vector3(0.12, 0.12, 1.9), gray)
    pole.generate_normals()
    var pm := StandardMaterial3D.new()
    pm.vertex_color_use_as_albedo = true
    pm.metallic = 0.5
    pm.roughness = 0.5
    pole.set_material(pm)
    var mesh := pole.commit()
    var head := SurfaceTool.new()
    head.begin(Mesh.PRIMITIVE_TRIANGLES)
    _add_box(head, Vector3(0, 6.94, 1.7), Vector3(0.5, 0.1, 0.9), Color.WHITE)
    head.generate_normals()
    var lm := StandardMaterial3D.new()
    lm.vertex_color_use_as_albedo = true
    lm.emission_enabled = true
    lm.emission = Color(1.0, 0.85, 0.55)
    lm.emission_energy_multiplier = 0.0           # DayNight acende ao anoitecer
    head.set_material(lm)
    head.commit(mesh)
    lm.set_meta("neon", 4.0)
    emissive_mats.append(lm)
    _multimesh(xs, mesh)


func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
    var h := s * 0.5
    var p := [
        c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
        c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]
    for f in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
        _quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], col)


# ------------------------------------------------------------ cidade
func _build_city(space: PhysicsDirectSpaceState3D, every: int) -> void:
    _build_lamps(space, 10)
    var tex: Array = []
    for v in 4:
        tex.append(_window_texture(v))
    for i in range(0, track.n, maxi(every, 8)):
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = track.point(i)
            var d := _rng.randf_range(26.0, 70.0) * side
            var pos := p + track.normal(i) * d
            var g = _ground(space, pos.x, pos.z, p.y)
            if g == null:
                continue
            var w := _rng.randf_range(14.0, 28.0)
            var dep := _rng.randf_range(14.0, 28.0)
            var hgt := _rng.randf_range(35.0, 120.0)
            var mi := MeshInstance3D.new()
            var bm := BoxMesh.new()
            bm.size = Vector3(w, hgt, dep)
            mi.mesh = bm
            var m := StandardMaterial3D.new()
            m.albedo_color = Color(0.10, 0.11, 0.15).lerp(Color(0.2, 0.22, 0.3), _rng.randf())
            m.metallic = 0.4
            m.roughness = 0.35
            m.emission_enabled = true
            m.emission_texture = tex[_rng.randi() % 4]
            m.emission = Color.WHITE
            m.emission_energy_multiplier = 0.0
            m.uv1_scale = Vector3(w / 7.0, hgt / 7.0, 1.0)
            m.texture_repeat = true
            mi.material_override = m
            mi.position = g + Vector3(0, hgt * 0.5 - 0.5, 0)
            mi.rotation.y = track.tangent(i).angle_to(Vector3.FORWARD) + _rng.randf_range(-0.1, 0.1)
            add_child(mi)
            emissive_mats.append(m)
            # coroa luminosa no topo (neon)
            if _rng.randf() < 0.5:
                var neon := MeshInstance3D.new()
                var nb := BoxMesh.new()
                nb.size = Vector3(w * 1.02, 0.6, dep * 1.02)
                neon.mesh = nb
                var nm := StandardMaterial3D.new()
                var hue: Color = [Color(1.0, 0.15, 0.5), Color(0.1, 0.8, 1.0), Color(0.6, 0.3, 1.0), Color(1.0, 0.6, 0.1)][_rng.randi() % 4]
                nm.albedo_color = hue
                nm.emission_enabled = true
                nm.emission = hue
                nm.emission_energy_multiplier = 0.0
                neon.material_override = nm
                neon.position = mi.position + Vector3(0, hgt * 0.5 + 0.2, 0)
                neon.rotation = mi.rotation
                add_child(neon)
                emissive_mats.append(nm)
                nm.set_meta("neon", 3.0)


func _window_texture(variant: int) -> ImageTexture:
    var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
    img.fill(Color.BLACK)
    var r := RandomNumberGenerator.new()
    r.seed = 100 + variant
    for gy in 8:
        for gx in 8:
            if r.randf() < 0.55:
                var warm := Color(1.0, 0.85, 0.55) if r.randf() < 0.7 else Color(0.6, 0.85, 1.0)
                for py in 2:
                    for px in 2:
                        img.set_pixel(gx * 4 + px + 1, gy * 4 + py + 1, warm * r.randf_range(0.6, 1.0))
    return ImageTexture.create_from_image(img)


# ------------------------------------------------------------ util
func _multimesh(xs: Array, mesh: Mesh) -> void:
    if xs.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xs.size()
    for i in xs.size():
        mm.set_instance_transform(i, xs[i])
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    add_child(mi)
