class_name CarVisual
extends RefCounted
## Utilidades para carregar o modelo GLB e trocar materiais (pintura, lanternas).


static func load_model(def: Dictionary) -> Node3D:
    var ps := load(str(def["model"])) as PackedScene
    return ps.instantiate() as Node3D


## Duplica (e devolve) todos os materiais com esse nome para poder alterar so neste carro.
static func override_materials(root: Node, mat_name: String) -> Array:
    var out: Array = []
    for n in root.find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        if mi == null or mi.mesh == null:
            continue
        for s in mi.mesh.get_surface_count():
            var m := mi.mesh.surface_get_material(s)
            if m != null and _name_matches(m.resource_name, mat_name):
                var dup := m.duplicate() as StandardMaterial3D
                mi.set_surface_override_material(s, dup)
                out.append(dup)
    return out


static func apply_paint(root: Node, color: Color) -> void:
    for m in override_materials(root, "Paint"):
        (m as StandardMaterial3D).albedo_color = color


## Aceita "Paint" e tambem "Paint_2", "Paint_3"... (o Godot renomeia duplicados).
static func _name_matches(n: String, base: String) -> bool:
    if n == base:
        return true
    return n.begins_with(base + "_") and n.substr(base.length() + 1).is_valid_int()
