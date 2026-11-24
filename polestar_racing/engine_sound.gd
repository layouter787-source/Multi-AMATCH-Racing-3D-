class_name EngineSound
extends Node
## Audio de motor com seis amostras CC0 por faixa de RPM e crossfade suave.

const ENGINE_FILES := [
    "res://assets/audio/engine/loop_0.wav.b64",
    "res://assets/audio/engine/loop_1_0.wav.b64",
    "res://assets/audio/engine/loop_2_0.wav.b64",
    "res://assets/audio/engine/loop_3_0.wav.b64",
    "res://assets/audio/engine/loop_4_0.wav.b64",
    "res://assets/audio/engine/loop_5_0.wav.b64",
]
const SKID_FILE := "res://assets/audio/tires_gravel.mp3.b64"

var car: PlayerCar
var _engines: Array[AudioStreamPlayer] = []
var _skid: AudioStreamPlayer
var _skid_level := 0.0
var _audio_ready := false


func _ready() -> void:
    _load_engine_samples()
    _load_skid_sample()


func _read_base64(path: String) -> PackedByteArray:
    if not FileAccess.file_exists(path):
        push_warning("Audio em falta: " + path)
        return PackedByteArray()
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return PackedByteArray()
    var encoded := f.get_as_text().strip_edges()
    f.close()
    return Marshalls.base64_to_raw(encoded)


func _load_engine_samples() -> void:
    for path in ENGINE_FILES:
        var bytes := _read_base64(path)
        if bytes.is_empty():
            continue
        var stream := AudioStreamWAV.load_from_buffer(bytes)
        if stream == null:
            push_warning("Amostra WAV invalida: " + path)
            continue
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        var player := AudioStreamPlayer.new()
        player.stream = stream
        player.bus = "Master"
        player.volume_db = -80.0
        player.max_polyphony = 1
        add_child(player)
        player.play()
        _engines.append(player)
    _audio_ready = not _engines.is_empty()
    if not _audio_ready:
        push_warning("Sem amostras de motor; o carro continua jogavel.")


func _load_skid_sample() -> void:
    var bytes := _read_base64(SKID_FILE)
    if bytes.is_empty():
        return
    var stream := AudioStreamMP3.load_from_buffer(bytes)
    if stream == null:
        push_warning("Amostra de pneus invalida.")
        return
    _skid = AudioStreamPlayer.new()
    _skid.stream = stream
    _skid.bus = "Master"
    _skid.volume_db = -80.0
    _skid.max_polyphony = 1
    _skid.finished.connect(_on_skid_finished)
    add_child(_skid)


func _on_skid_finished() -> void:
    if _skid_level > 0.12 and _skid != null:
        _skid.play()


func _process(_delta: float) -> void:
    if car == null or not is_instance_valid(car):
        return
    if _audio_ready:
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
            _engines[i].volume_db = linear_to_db(maxf(gain * 0.32, 0.0001))
            _engines[i].pitch_scale = clampf(0.90 + car.rpm_norm * 0.22, 0.85, 1.15)
    if _skid != null:
        _skid_level = clampf((absf(car.lateral_g) - 0.20) / 0.95, 0.0, 1.0)
        _skid.volume_db = linear_to_db(maxf(_skid_level * 0.30, 0.0001))
        if _skid_level > 0.12 and not _skid.playing:
            _skid.play()
        elif _skid_level <= 0.12 and _skid.playing:
            _skid.stop()
