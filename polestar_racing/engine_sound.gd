class_name EngineSound
extends AudioStreamPlayer
## Som de motor sintetizado (sem arquivos de audio).

var car: PlayerCar
var _playback: AudioStreamGeneratorPlayback
var _gen := AudioStreamGenerator.new()
var _phase := 0.0


func _ready() -> void:
    _gen.mix_rate = 22050.0
    _gen.buffer_length = 0.12
    stream = _gen
    volume_db = -12.0
    play()
    _playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
    if car == null or _playback == null or not is_instance_valid(car):
        return
    var freq := lerpf(40.0, 190.0, car.rpm_norm)
    var inc := freq / _gen.mix_rate
    var n := _playback.get_frames_available()
    for i in n:
        _phase = fmod(_phase + inc, 1.0)
        var s := (_phase * 2.0 - 1.0) * 0.45 + sin(_phase * TAU * 2.0) * 0.25 + sin(_phase * TAU * 0.5) * 0.15
        _playback.push_frame(Vector2(s, s))
