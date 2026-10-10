extends Node
## Continuous texture under the dice clicks; volume follows the live meter.
const LOOP = preload("res://assets/audio/magic_leak_loop.wav")
const EDGE_DB := -38.0
const CENTER_DB := -14.0
const FADE_IN := 0.04
const FADE_OUT := 0.08
var player: AudioStreamPlayer
var envelope: float = 0.0
var level: float = 0.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var stream := LOOP.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.bus = "Combat"
	player.volume_db = -80.0
	add_child(player)

func update(delta: float, active: bool, power: float, muted: bool) -> void:
	if muted:
		silence()
		return
	if active:
		if not player.playing: player.play()
		# The sample is a texture, so keep its pitch stable. The meter itself
		# controls the swell, including any changes to its timing or speed.
		level = db_to_linear(lerpf(EDGE_DB, CENTER_DB, smoothstep(0.0, 1.0, power)))
	envelope = move_toward(envelope, 1.0 if active else 0.0, delta / (FADE_IN if active else FADE_OUT))
	player.volume_linear = level * envelope
	if not active and envelope <= 0.0: player.stop()

func silence() -> void:
	envelope = 0.0
	player.volume_linear = 0.0
	player.stop()
