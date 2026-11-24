class_name RacingLine
extends MeshInstance3D
## Linha vermelha no asfalto: segue o tracado ideal da pista. Fica mais forte e
## mais larga nas zonas de frenagem (onde a velocidade ideal cai adiante).

var width := 1.15


func build(track: TrackInfo) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := track.n
    var verts: Array = []
    var cols: Array = []
    for i in n:
        var p: Vector3 = track.point(i)
        var t: Vector3 = track.tangent(i)
        var side := Vector3(-t.z, 0.0, t.x)
        # olha ~14 pontos adiante: se a velocidade cai, e zona de frenagem
        var v_now: float = track.speed_at(i)
        var v_ahead: float = track.speed_at(i + 14)
        var brake := clampf((v_now - v_ahead) / 6.0, 0.0, 1.0)
        var w := width * (0.5 + 0.25 * brake)
        var col := Color(0.85, 0.03, 0.03, 0.55).lerp(Color(1.0, 0.25, 0.15, 0.9), brake)
        var up := Vector3.UP * 0.07
        verts.append([p - side * w + up, p + side * w + up])
        cols.append(col)
    for i in n:
        var j := (i + 1) % n
        var a: Array = verts[i]
        var b: Array = verts[j]
        var ca: Color = cols[i]
        var cb: Color = cols[j]
        _tri(st, a[0], a[1], b[0], ca, ca, cb)
        _tri(st, a[1], b[1], b[0], ca, cb, cb)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.no_depth_test = false
    mat.render_priority = 2
    st.set_material(mat)
    mesh = st.commit()
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
    st.set_color(ca)
    st.add_vertex(a)
    st.set_color(cb)
    st.add_vertex(b)
    st.set_color(cc)
    st.add_vertex(c)
