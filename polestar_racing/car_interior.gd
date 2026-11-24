class_name CarInterior
extends Node3D
## Interior procedural: bancos com laterais, volante que gira com a direcao,
## painel, conta-giros e velocimetro com ponteiros, pedais, console, retrovisor,
## colunas, forro do teto e um piloto com capacete. Tudo medido pela cabine do carro.

var car: PlayerCar
var _wheel: Node3D
var _needle_rpm: Node3D
var _needle_spd: Node3D
var _driver_arms: Array = []
var eye := Vector3(-0.36, 1.0, 0.0)   # posicao do olho do piloto (camera de cockpit)
var driver: Node3D
var _leather: StandardMaterial3D
var _alcantara: StandardMaterial3D
var _carbon: StandardMaterial3D
var _accent: StandardMaterial3D
var _glow: StandardMaterial3D


func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    m.metallic = metal
    return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m
    mi.position = pos
    mi.rotation_degrees = rot
    parent.add_child(mi)
    return mi


func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = h
    cm.radial_segments = 16
    mi.mesh = cm
    mi.material_override = m
    mi.position = pos
    mi.rotation_degrees = rot
    parent.add_child(mi)
    return mi


func _sphere(parent: Node3D, pos: Vector3, r: float, m: Material, scl := Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 16
    sm.rings = 8
    mi.mesh = sm
    mi.material_override = m
    mi.position = pos
    mi.scale = scl
    parent.add_child(mi)
    return mi


func _ready() -> void:
    _leather = _mat(Color(0.05, 0.05, 0.055), 0.55)
    _alcantara = _mat(Color(0.09, 0.09, 0.10), 0.95)
    _carbon = _mat(Color(0.03, 0.03, 0.035), 0.3, 0.6)
    var pc: Color = car.paint_color
    _accent = _mat(pc.lightened(0.1), 0.5)
    _glow = StandardMaterial3D.new()
    _glow.albedo_color = Color(0.9, 0.95, 1.0)
    _glow.emission_enabled = true
    _glow.emission = Color(0.7, 0.85, 1.0)
    _glow.emission_energy_multiplier = 1.6

    var cab: Dictionary = car.def["collision"][1]
    var cp: Vector3 = cab["pos"]
    var cs: Vector3 = cab["size"]
    var rh := car.ride_height
    var roof_y := cp.y + cs.y * 0.5 + rh
    var floor_y := 0.26 + rh
    var eye_z := cp.z + cs.z * 0.12
    var wheel_z := eye_z - 0.58
    var dash_z := wheel_z - 0.30
    var half_w := cs.x * 0.5 + 0.28            # largura interna aproximada
    var dx := -0.36                             # volante a esquerda
    var seat_y := floor_y + 0.12

    # assoalho + tapete
    _box(self, Vector3(0, floor_y, cp.z), Vector3(half_w * 2.0, 0.04, cs.z + 0.9), _alcantara)
    # forro do teto
    _box(self, Vector3(0, roof_y - 0.03, cp.z + 0.05), Vector3(cs.x + 0.4, 0.03, cs.z * 0.9), _alcantara)
    # colunas A e C
    for sx in [-1.0, 1.0]:
        _box(self, Vector3(sx * (half_w - 0.04), roof_y - 0.28, dash_z + 0.35), Vector3(0.07, 0.55, 0.08), _carbon, Vector3(-52, 0, sx * 6.0))
        _box(self, Vector3(sx * (half_w - 0.02), roof_y - 0.25, cp.z + cs.z * 0.45), Vector3(0.08, 0.5, 0.12), _carbon, Vector3(35, 0, 0))
    # portas (painel interno)
    for sx in [-1.0, 1.0]:
        _box(self, Vector3(sx * (half_w - 0.02), floor_y + 0.32, eye_z - 0.1), Vector3(0.05, 0.5, cs.z * 0.7), _leather)
        _box(self, Vector3(sx * (half_w - 0.05), floor_y + 0.50, eye_z - 0.1), Vector3(0.03, 0.05, cs.z * 0.55), _accent)

    # painel de instrumentos
    var dash := Node3D.new()
    dash.position = Vector3(0, 0, dash_z)
    add_child(dash)
    _box(dash, Vector3(0, floor_y + 0.46, 0.0), Vector3(half_w * 2.0 - 0.1, 0.20, 0.42), _leather, Vector3(-8, 0, 0))
    _box(dash, Vector3(0, floor_y + 0.58, 0.08), Vector3(half_w * 2.0 - 0.14, 0.05, 0.3), _alcantara)
    # cluster (atras do volante)
    var cluster := Node3D.new()
    cluster.position = Vector3(dx, floor_y + 0.62, 0.22)
    cluster.rotation_degrees = Vector3(-18, 0, 0)
    dash.add_child(cluster)
    _box(cluster, Vector3.ZERO, Vector3(0.46, 0.17, 0.04), _carbon)
    var face := _mat(Color(0.02, 0.02, 0.03), 0.4)
    _cyl(cluster, Vector3(-0.11, 0, 0.022), 0.065, 0.006, face, Vector3(90, 0, 0))
    _cyl(cluster, Vector3(0.11, 0, 0.022), 0.065, 0.006, face, Vector3(90, 0, 0))
    _needle_rpm = _needle(cluster, Vector3(-0.11, 0, 0.028))
    _needle_spd = _needle(cluster, Vector3(0.11, 0, 0.028))
    # tela central
    _box(dash, Vector3(0.0, floor_y + 0.60, 0.20), Vector3(0.30, 0.15, 0.03), _glow, Vector3(-15, 0, 0))
    # saidas de ar
    for sx in [-0.62, 0.62, -0.18, 0.18]:
        _box(dash, Vector3(sx, floor_y + 0.52, 0.22), Vector3(0.12, 0.05, 0.03), _carbon)
    # visera do painel (reflete menos no vidro)
    _box(dash, Vector3(dx, floor_y + 0.72, 0.18), Vector3(0.55, 0.03, 0.2), _alcantara, Vector3(-18, 0, 0))

    # console central + alavanca
    _box(self, Vector3(0, floor_y + 0.17, eye_z - 0.05), Vector3(0.26, 0.28, cs.z * 0.55), _carbon)
    _box(self, Vector3(0, floor_y + 0.33, eye_z - 0.18), Vector3(0.10, 0.04, 0.22), _leather)
    _cyl(self, Vector3(0, floor_y + 0.40, eye_z - 0.22), 0.022, 0.12, _carbon)
    _sphere(self, Vector3(0, floor_y + 0.47, eye_z - 0.22), 0.04, _leather)

    # pedais
    for i in 3:
        var px := dx - 0.08 + i * 0.11
        var w := 0.10 if i < 2 else 0.05
        _box(self, Vector3(px, floor_y + 0.12, wheel_z - 0.26), Vector3(w, 0.01, 0.12), _carbon, Vector3(55, 0, 0))

    # bancos
    _seat(Vector3(dx, seat_y, eye_z + 0.28), roof_y)
    _seat(Vector3(0.36, seat_y, eye_z + 0.28), roof_y)

    # volante (gira com a direcao)
    _wheel = Node3D.new()
    _wheel.position = Vector3(dx, floor_y + 0.60, wheel_z)
    _wheel.rotation_degrees = Vector3(-62, 0, 0)       # inclinado para o piloto
    add_child(_wheel)
    var ring := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.125
    tm.outer_radius = 0.155
    tm.rings = 24
    tm.ring_segments = 10
    ring.mesh = tm
    ring.material_override = _leather
    ring.rotation_degrees = Vector3(90, 0, 0)
    _wheel.add_child(ring)
    _cyl(_wheel, Vector3.ZERO, 0.045, 0.04, _carbon, Vector3(90, 0, 0))
    _box(_wheel, Vector3(0, 0, 0), Vector3(0.28, 0.02, 0.025), _carbon)
    _box(_wheel, Vector3(0, -0.07, 0), Vector3(0.025, 0.12, 0.02), _carbon)
    _box(_wheel, Vector3(0, 0.145, 0.0), Vector3(0.02, 0.02, 0.03), _accent)   # marcacao das 12h
    # coluna de direcao
    _cyl(self, Vector3(dx, floor_y + 0.50, wheel_z - 0.12), 0.03, 0.30, _carbon, Vector3(-62, 0, 0))

    # retrovisor interno
    _box(self, Vector3(0, roof_y - 0.12, dash_z + 0.45), Vector3(0.22, 0.06, 0.02), _carbon)
    _box(self, Vector3(0, roof_y - 0.06, dash_z + 0.45), Vector3(0.02, 0.06, 0.02), _carbon)

    # roll bar discreto atras dos bancos
    _cyl(self, Vector3(0, roof_y - 0.10, eye_z + 0.62), 0.018, half_w * 2.0 - 0.1, _carbon, Vector3(0, 0, 90))

    _build_driver(Vector3(dx, seat_y, eye_z + 0.28), wheel_z)
    eye = Vector3(dx, seat_y + 0.76, eye_z + 0.18)


func _needle(parent: Node3D, pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    parent.add_child(n)
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(1, 0.15, 0.1)
    red.emission_enabled = true
    red.emission = Color(1, 0.1, 0.05)
    _box(n, Vector3(0, 0.03, 0), Vector3(0.006, 0.06, 0.004), red)
    return n


func _seat(pos: Vector3, roof_y: float) -> void:
    var s := Node3D.new()
    s.position = pos
    add_child(s)
    _box(s, Vector3(0, 0.0, 0), Vector3(0.50, 0.12, 0.52), _alcantara)                         # assento
    _box(s, Vector3(-0.22, 0.05, 0), Vector3(0.07, 0.16, 0.50), _leather)                      # abas
    _box(s, Vector3(0.22, 0.05, 0), Vector3(0.07, 0.16, 0.50), _leather)
    _box(s, Vector3(0, 0.34, 0.27), Vector3(0.50, 0.62, 0.10), _alcantara, Vector3(-12, 0, 0)) # encosto
    _box(s, Vector3(-0.24, 0.36, 0.25), Vector3(0.08, 0.50, 0.14), _leather, Vector3(-12, 0, 0))
    _box(s, Vector3(0.24, 0.36, 0.25), Vector3(0.08, 0.50, 0.14), _leather, Vector3(-12, 0, 0))
    _box(s, Vector3(0, 0.34, 0.275), Vector3(0.14, 0.50, 0.02), _accent, Vector3(-12, 0, 0))   # faixa na cor do carro
    _box(s, Vector3(0, 0.72, 0.31), Vector3(0.24, 0.17, 0.08), _leather, Vector3(-12, 0, 0))   # encosto de cabeca
    _cyl(s, Vector3(0, -0.12, 0.0), 0.05, 0.2, _carbon)                                        # trilho


func _build_driver(seat_pos: Vector3, wheel_z: float) -> void:
    var d := Node3D.new()
    d.position = seat_pos
    add_child(d)
    driver = d
    var suit := _mat(Color(0.08, 0.08, 0.10), 0.8)
    var helmet := _mat(car.paint_color.lightened(0.15), 0.25, 0.4)
    var visor := _mat(Color(0.02, 0.03, 0.05), 0.05, 0.8)
    _box(d, Vector3(0, 0.40, 0.17), Vector3(0.36, 0.50, 0.20), suit, Vector3(-12, 0, 0))     # tronco
    _sphere(d, Vector3(0, 0.80, 0.14), 0.125, helmet, Vector3(1, 1.05, 1.1))                  # capacete
    _box(d, Vector3(0, 0.80, 0.03), Vector3(0.17, 0.05, 0.06), visor)                         # viseira
    for sx in [-1.0, 1.0]:
        _box(d, Vector3(sx * 0.12, 0.05, -0.18), Vector3(0.11, 0.11, 0.42), suit)             # coxas
        _box(d, Vector3(sx * 0.12, -0.03, -0.45), Vector3(0.10, 0.10, 0.34), suit, Vector3(-30, 0, 0))
        var arm := Node3D.new()
        arm.position = Vector3(sx * 0.20, 0.55, 0.05)
        d.add_child(arm)
        _box(arm, Vector3(0, 0, -0.25), Vector3(0.09, 0.09, 0.5), suit, Vector3(0, 0, 0))
        _driver_arms.append(arm)


func _process(_delta: float) -> void:
    if car == null or not is_instance_valid(car):
        return
    # volante: 1 volta e meia de batente para o steering real do carro
    if _wheel != null:
        _wheel.rotation.z = -car.steering * 3.2
    if _needle_rpm != null:
        _needle_rpm.rotation.z = deg_to_rad(120.0 - car.rpm_norm * 240.0)
    if _needle_spd != null:
        _needle_spd.rotation.z = deg_to_rad(120.0 - clampf(car.speed_kmh / maxf(car.max_speed_kmh, 1.0), 0.0, 1.0) * 240.0)


func set_cockpit_view(on: bool) -> void:
    if driver != null:
        driver.visible = not on
