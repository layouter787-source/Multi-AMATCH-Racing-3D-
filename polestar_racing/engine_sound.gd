class_name EngineSound
extends Node
## Audio real de motor com seis amostras CC0 por faixa de RPM e crossfade suave.
## Os recursos sao guardados em Base64 para manter o transporte textual do repositorio;
## na primeira execucao sao descodificados para user:// e carregados pelo Godot.

const ENGINE_FILES := [
    "res://assets/audio/engine/loop_0.wav.b64",
    "res://assets/audio/engine/loop_1_0.wav.b64",
    "res://assets/audio/engine/loop_2_0.wav.b64",
    "res://assets/audio/engine/loop_3_0.wav.b64",
    "res://assets/audio/engine/loop_4_0.wav.b64",
    "res://assets/audio/engine/loop_5_0.wav.b64",
]
const SKID_B64 := "res://assets/audio/tires_gravel.mp3.b64"

var car: PlayerCar
var _engines: Array[AudioStreamPlayer] = []
var _skid: AudioStreamPlayer
var _ready_audio := false


func _ready() -> void:
    _load_engine_samples()
    _load_skid_sample()


func _decode_to_user(source_path: String, target_path: String) -> bool:
    if FileAccess.file_exists(target_path):
        return true
    if not FileAccess.file_exists(source_path):
        push_warning("Audio asset em falta: " + source_path)
        return false
    var file := FileAccess.open(source_path, FileAccess.READ)
    if file == null:
        return false
    var encoded := file.get_as_text().strip_edges()
    file.close()
    var bytes := Marshalls.base64_to_raw(encoded)
    if bytes.is_empty():
        push_warning("Audio Base64 invalido: " + source_path)
        return false
    var out := FileAccess.open(target_path, FileAccess.WRITE)
    if out == null:
        return false
    out.store_buffer(bytes)
    out.close()
    return true


func _load_engine_samples() -> void:
    for i in ENGINE_FILES.size():
        var path := "user://amatch_engine_%d.wav" % i
        if not _decode_to_user(ENGINE_FILES[i], path):
            continue
        var stream := AudioStreamWAV.load_from_file(path)
        if stream == null:
            push_warning("Nao foi possivel carregar " + path)
            continue
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        var player := AudioStreamPlayer.new()
        player.stream = stream
        player.bus = "Master"
        player.volume_db = -60.0
        player.max_polyphony = 1
        add_child(player)
        player.play()
        _engines.append(player)
    _ready_audio = not _engines.is_empty()
    if not _ready_audio:
        push_warning("Amostras de motor indisponiveis; o carro continuara sem som de motor.")


func _load_skid_sample() -> void:
    var path := "user://amatch_tires_gravel.mp3"
    if not _decode_to_user(SKID_B64, path):
        return
    var stream := AudioStreamMP3.load_from_file(path)
    if stream == null:
        return
    _skid = AudioStreamPlayer.new()
    _skid.stream = stream
    _skid.bus = "Master"
    _skid.volume_db = -35.0
    _skid.max_polyphony = 1
    add_child(_skid)


func _process(_delta: float) -> void:
    if car == null or not is_instance_valid(car):
        return
    if _ready_audio:
        var rpm := clampf(car.rpm_norm, 0.0, 1.0) * float(maxi(_engines.size() - 1, 1))
        var lower := clampi(int(floor(rpm)), 0, _engines.size() - 1)
        var upper := mini(lower + 1, _engines.size() - 1)
        var blend := rpm - float(lower)
        for i in _engines.size():
            var gain := 0.0
            if i == lower:
                gain = cos(blend * PI * 0.5)
            elif i == upper:
                gain = sin(blend * PI * 0.5)
            var player := _engines[i]
            player.volume_db = linear_to_db(maxf(gain * 0.34, 0.0001))
            player.pitch_scale = clampf(0.88 + car.rpm_norm * 0.28, 0.85, 1.18)
    if _skid != null:
        var skid_amount := clampf((absf(car.lateral_g) - 0.18) / 1.0, 0.0, 1.0)
        _skid.volume_db = linear_to_db(maxf(skid_amount * 0.32, 0.0001))
        if skid_amount > 0.08 and not _skid.playing:
            _skid.play()
        elif skid_amount <= 0.08 and _skid.playing:
            _skid.stop()
