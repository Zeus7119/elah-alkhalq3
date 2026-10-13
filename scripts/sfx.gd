class_name Sfx
extends Node

var players := {}

func _ready() -> void:
	_add("click", [900.0], 0.06, 0.35, 30.0)
	_add("create", [620.0, 930.0], 0.22, 0.4, 14.0, 0.5)
	_add("hit", [190.0], 0.28, 0.6, 10.0, -0.6)
	_add("win", [523.25, 659.25, 783.99], 0.6, 0.3, 4.5)
	_add("lose", [392.0, 311.13, 261.63], 0.7, 0.35, 5.5)

func play(n: String) -> void:
	if players.has(n) and is_instance_valid(players[n]):
		players[n].play()

func _add(n: String, freqs: Array, dur: float, vol: float, decay: float, sweep := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = make_tone(freqs, dur, vol, decay, sweep)
	add_child(p)
	players[n] = p

func make_tone(freqs: Array, dur: float, vol: float, decay: float, sweep: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * dur)
	var data := PackedByteArray()
	data.resize(frames)
	for i in range(frames):
		var t := float(i) / rate
		var env := exp(-t * decay)
		var v := 0.0
		for f in freqs:
			var ff: float = f * (1.0 + sweep * t / dur)
			v += sin(TAU * ff * t)
		v = v / freqs.size() * env * vol
		data[i] = int(clamp(127.0 + v * 120.0, 0.0, 255.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
