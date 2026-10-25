extends Node
## Preserve authored effect levels; only simultaneous corpse sounds merge into one cue.
const DUPLICATE_WINDOW_MS := 25
const MAX_VOICES := 12
const MAX_PITCH := 1.6
const COALESCED_CLIPS := ["enemy/chop"]
var voices: Array = []
var last_started: Dictionary = {}

## Repeated rolls, attacks and pickups keep their original gain and playback rhythm.
func play(clip: String, stream: AudioStream, pitch: float, volume: float) -> AudioStreamPlayer:
	voices = voices.filter(func(voice): return is_instance_valid(voice) and not voice.is_queued_for_deletion() and voice.playing)
	var now: int = Time.get_ticks_msec()
	if clip in COALESCED_CLIPS and now-int(last_started.get(clip,-DUPLICATE_WINDOW_MS)) < DUPLICATE_WINDOW_MS: return null
	# Match the original voice cap: newest feedback replaces the oldest tail.
	if voices.size() >= MAX_VOICES:
		var oldest: AudioStreamPlayer = voices.pop_front()
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.bus = "Combat" if AudioServer.get_bus_index("Combat") >= 0 else "Master"
	voice.pitch_scale = clampf(pitch,0.1,MAX_PITCH)
	voice.volume_db = volume
	voice.set_meta("clip",clip)
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voices.append(voice)
	if clip in COALESCED_CLIPS: last_started[clip] = now
	voice.play()
	return voice

## Muting and restarting stop owned one-shots and discard their short burst history.
func clear() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()
	voices.clear()
	last_started.clear()
