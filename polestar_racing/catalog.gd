class_name Catalog
extends RefCounted
## Catalogo de carros (CarsData), pistas (TracksData) e cores.

const COLORS := [
    {"name": "Branco", "color": Color(0.93, 0.93, 0.95)},
    {"name": "Preto", "color": Color(0.06, 0.06, 0.07)},
    {"name": "Prata", "color": Color(0.62, 0.64, 0.68)},
    {"name": "Vermelho", "color": Color(0.85, 0.05, 0.04)},
    {"name": "Azul", "color": Color(0.07, 0.16, 0.42)},
    {"name": "Amarelo", "color": Color(0.95, 0.78, 0.03)},
    {"name": "Laranja", "color": Color(1.0, 0.45, 0.04)},
    {"name": "Verde lima", "color": Color(0.45, 0.85, 0.10)},
    {"name": "Verde escuro", "color": Color(0.14, 0.24, 0.20)},
    {"name": "Roxo", "color": Color(0.35, 0.10, 0.60)},
    {"name": "Rosa", "color": Color(0.95, 0.30, 0.60)},
    {"name": "Turquesa", "color": Color(0.05, 0.65, 0.70)},
]
const TRACK_ORDER := ["verde", "deserto", "costa", "neve", "cidade"]


static func car_def(id: String) -> Dictionary:
    if CarsData.ALL.has(id):
        return CarsData.ALL[id]
    return CarsData.ALL["p911ts"]


static func car_ids() -> Array:
    return CarsData.ALL.keys()


static func color_of(car_id: String, idx: int) -> Color:
    if idx < 0 or idx >= COLORS.size():
        var d: Dictionary = car_def(car_id)
        return d["paint"]
    var c: Dictionary = COLORS[idx]
    return c["color"]


static func track_data(id: String) -> Dictionary:
    if TracksData.ALL.has(id):
        return TracksData.ALL[id]
    return TracksData.ALL["verde"]
