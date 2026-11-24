class_name EnvBuilder
extends RefCounted
## Cria ceu, neblina, sol/lua e neve de acordo com o tema da pista.


static func build(parent: Node3D, theme: Dictionary, quality: int) -> Dictionary:
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = theme["sky_top"]
    sky_mat.sky_horizon_color = theme["sky_horizon"]
    sky_mat.ground_horizon_color = theme["sky_horizon"]
    sky_mat.ground_bottom_color = theme["ground"]
    var sky := Sky.new()
    sky.sky_material = sky_mat
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = float(theme["ambient"])
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = theme["fog"]
    env.fog_density = float(theme["fog_density"])
    env.glow_enabled = quality > 0
    env.glow_intensity = 0.8
    env.glow_bloom = 0.15
    env.glow_hdr_threshold = 1.0
    var we := WorldEnvironment.new()
    we.environment = env
    parent.add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = theme["sun_rot"]
    sun.light_color = theme["sun_color"]
    sun.light_energy = float(theme["sun_energy"])
    sun.shadow_enabled = quality > 0
    sun.directional_shadow_max_distance = 140.0 if quality == 1 else 260.0
    parent.add_child(sun)
    return {"env": env, "sky": sky_mat, "sun": sun}


static func add_snow(cam: Camera3D) -> void:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1, 1, 1, 0.9)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    var quad := QuadMesh.new()
    quad.size = Vector2(0.09, 0.09)
    quad.material = mat
    var p := CPUParticles3D.new()
    p.mesh = quad
    p.amount = 450
    p.lifetime = 5.0
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    p.emission_box_extents = Vector3(25, 1, 25)
    p.direction = Vector3(0.2, -1, 0)
    p.spread = 15.0
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 5.0
    p.gravity = Vector3(0, -1.0, 0)
    p.local_coords = false
    cam.add_child(p)
    p.position = Vector3(0, 12, -12)
