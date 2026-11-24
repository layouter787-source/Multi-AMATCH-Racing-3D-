class_name CarPreview
extends SubViewportContainer
## Visualizacao 3D giratoria do carro (menu e garagem).

var _vp: SubViewport
var _pivot: Node3D
var _model: Node3D


func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _vp = SubViewport.new()
    _vp.own_world_3d = true
    _vp.transparent_bg = true
    _vp.msaa_3d = Viewport.MSAA_2X
    add_child(_vp)

    var env := Environment.new()
    env.background_mode = Environment.BG_CLEAR_COLOR
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62, 0.68, 0.8)
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var we := WorldEnvironment.new()
    we.environment = env
    _vp.add_child(we)

    var l1 := DirectionalLight3D.new()
    l1.rotation_degrees = Vector3(-35, 40, 0)
    l1.light_energy = 1.5
    _vp.add_child(l1)
    var l2 := DirectionalLight3D.new()
    l2.rotation_degrees = Vector3(-20, -140, 0)
    l2.light_energy = 0.7
    _vp.add_child(l2)

    var cam := Camera3D.new()
    cam.fov = 36.0
    _vp.add_child(cam)
    cam.look_at_from_position(Vector3(0, 1.5, 8.0), Vector3(0, 0.5, 0), Vector3.UP)

    _pivot = Node3D.new()
    _vp.add_child(_pivot)


func set_car(car_id: String, color_idx: int) -> void:
    if _model != null:
        _model.queue_free()
        _model = null
    var def: Dictionary = Catalog.car_def(car_id)
    _model = CarVisual.load_model(def)
    _pivot.add_child(_model)
    CarVisual.apply_paint(_model, Catalog.color_of(car_id, color_idx))
    _pivot.rotation.y = 0.6


func _process(delta: float) -> void:
    if _pivot != null:
        _pivot.rotate_y(delta * 0.45)
