extends Node
## Autoload "Game": estado global, configuracoes salvas e recordes.

const SAVE_PATH := "user://settings.cfg"
const MAX_RACERS := 12
const AI_NAMES := ["Rafa", "Luna", "Theo", "Maya", "Caio", "Zoe", "Dante", "Iris", "Nico", "Vera", "Otto"]

var player_name := "Piloto"
var track_id := "verde"
var laps := 3
var ai_count := 5
var difficulty := 1          # 0 facil, 1 normal, 2 dificil
var car_id := "p911ts"
var car_color := -1          # -1 = cor original do carro
var mode := "solo"           # solo | online
var quality := 1             # 0 baixa, 1 media, 2 alta
var volume := 0.8
var control_layout := 0       # 0: direção à esquerda; 1: direção à direita
var race_setup := {}
var records := {}            # track_id -> melhor volta (s)


func _ready() -> void:
    load_settings()
    apply_audio()


func load_settings() -> void:
    var cf := ConfigFile.new()
    if cf.load(SAVE_PATH) != OK:
        return
    player_name = str(cf.get_value("player", "name", player_name))
    car_id = str(cf.get_value("player", "car", car_id))
    car_color = int(cf.get_value("player", "color", car_color))
    quality = int(cf.get_value("settings", "quality", quality))
    volume = float(cf.get_value("settings", "volume", volume))
    control_layout = clampi(int(cf.get_value("settings", "control_layout", control_layout)), 0, 1)
    laps = int(cf.get_value("race", "laps", laps))
    ai_count = int(cf.get_value("race", "ai", ai_count))
    difficulty = int(cf.get_value("race", "difficulty", difficulty))
    track_id = str(cf.get_value("race", "track", track_id))
    var rec = cf.get_value("records", "all", {})
    if rec is Dictionary:
        records = rec
    if not CarsData.ALL.has(car_id):
        car_id = "p911ts"
    if not TracksData.ALL.has(track_id):
        track_id = "verde"


func save_settings() -> void:
    var cf := ConfigFile.new()
    cf.set_value("player", "name", player_name)
    cf.set_value("player", "car", car_id)
    cf.set_value("player", "color", car_color)
    cf.set_value("settings", "quality", quality)
    cf.set_value("settings", "volume", volume)
    cf.set_value("settings", "control_layout", control_layout)
    cf.set_value("race", "laps", laps)
    cf.set_value("race", "ai", ai_count)
    cf.set_value("race", "difficulty", difficulty)
    cf.set_value("race", "track", track_id)
    cf.set_value("records", "all", records)
    cf.save(SAVE_PATH)


func apply_audio() -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(clampf(volume, 0.0001, 1.0)))


func record_lap(track: String, t: float) -> bool:
    var best: float = records.get(track, INF)
    if t < best:
        records[track] = t
        save_settings()
        return true
    return false


func ai_skill() -> float:
    return [0.86, 0.94, 1.0][clampi(difficulty, 0, 2)]


func make_solo_setup() -> Dictionary:
    var racers: Array = []
    var total := mini(ai_count + 1, MAX_RACERS)
    var player_slot := int(total / 2.0)
    var ai_i := 0
    var ids: Array = CarsData.ALL.keys()
    for slot in total:
        if slot == player_slot:
            racers.append({"id": 1, "name": player_name, "color": car_color, "car": car_id,
                    "slot": slot, "kind": "human", "owner": 1})
        else:
            var cid: String = ids[(ai_i * 5 + 1) % ids.size()]
            var col := -1 if ai_i % 2 == 0 else (ai_i * 3 + 1) % Catalog.COLORS.size()
            racers.append({"id": 1000 + ai_i, "name": AI_NAMES[ai_i % AI_NAMES.size()], "color": col,
                    "car": cid, "slot": slot, "kind": "ai", "owner": 1})
            ai_i += 1
    return {"track": track_id, "laps": laps, "difficulty": difficulty, "racers": racers}


func make_online_setup(players: Dictionary, lobby: Dictionary) -> Dictionary:
    var racers: Array = []
    var slot := 0
    var pids: Array = players.keys()
    pids.sort()
    for pid in pids:
        var p: Dictionary = players[pid]
        racers.append({"id": pid, "name": p["name"], "color": p["color"], "car": p["car"],
                "slot": slot, "kind": "human", "owner": pid})
        slot += 1
    var ids: Array = CarsData.ALL.keys()
    var n_ai := mini(int(lobby.get("ai", 0)), MAX_RACERS - slot)
    for i in n_ai:
        var cid: String = ids[(i * 5 + 2) % ids.size()]
        racers.append({"id": 1000 + i, "name": AI_NAMES[i % AI_NAMES.size()],
                "color": -1 if i % 2 == 0 else (i * 3 + 2) % Catalog.COLORS.size(), "car": cid,
                "slot": slot, "kind": "ai", "owner": 1})
        slot += 1
    return {"track": lobby.get("track", "verde"), "laps": int(lobby.get("laps", 3)),
            "difficulty": int(lobby.get("diff", 1)), "racers": racers}


func start_race(setup: Dictionary) -> void:
    race_setup = setup
    track_id = str(setup["track"])
    get_tree().paused = false
    get_tree().change_scene_to_file("res://race.tscn")


func go_menu() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://menu.tscn")
