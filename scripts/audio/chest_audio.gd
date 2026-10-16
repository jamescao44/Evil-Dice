extends Node
## Persistent chest voices avoid stacked one-shots and preserve the authored tempo.
const ROLL = preload("res://assets/audio/item/arcade_slot_roll.wav")
const GREED_ROLL = preload("res://assets/audio/item/arcade_slot_roll2.wav")
const PAYOUTS = [preload("res://assets/audio/item/reward_level1.wav"),preload("res://assets/audio/item/reward_level2.wav"),preload("res://assets/audio/item/reward_level3.wav")]
const ROLL_DB := -10.0
const PAYOUT_DB := -3.0
const BEAT := 60.0/160.0
const ROLL_PERIOD := 9*BEAT/4
const TimedLoop = preload("res://scripts/audio/timed_audio_loop.gd")
static var roll_loop: AudioStreamWAV
static var greed_roll_loop: AudioStreamWAV
# Final five note onsets in the authored level-3 clip (after its lead-in phrase).
const ULTRA_NOTES := [8*BEAT,8.5*BEAT,9*BEAT,9.5*BEAT,10*BEAT]
var rolling: AudioStreamPlayer
var payout: AudioStreamPlayer
var ultra_started: bool = false
var reveal_count: int = 0
var enabled: bool = true
var output_latency: float = 0.0
var ultra_clock: float = 0.0
var clock_stall: float = 0.0
var clock_failed: bool = false

## Create persistent rolling and payout voices and prepare the two timed reel loops.
func _ready() -> void:
	rolling = _voice()
	payout = _voice()
	if roll_loop == null: roll_loop = TimedLoop.build(ROLL,ROLL_PERIOD)
	if greed_roll_loop == null: greed_roll_loop = TimedLoop.build(GREED_ROLL,ROLL_PERIOD)
	rolling.stream = roll_loop

## Create a chest audio player routed through the combat sound bus.
func _voice() -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.bus = "Combat" if AudioServer.get_bus_index("Combat") >= 0 else "Master"
	add_child(voice)
	return voice

## Start the rolling texture for the currently visible chest tier.
func start_rolling(tier: int = 0) -> void:
	# An automatic Ultra intro may already be playing before reels appear.
	set_roll_tier(tier)
	rolling.play()

## Switch rolling textures on upgrades while preserving whether audio is playing.
func set_roll_tier(tier: int) -> void:
	var stream: AudioStreamWAV = greed_roll_loop if tier == 2 else roll_loop
	if rolling.stream == stream: return
	var was_playing: bool = rolling.playing
	rolling.stream = stream
	if was_playing: rolling.play()

## Start the Ultra buildup and reset its musical reveal clock.
func begin_ultra(offset: float = 0.0) -> void:
	ultra_started = true
	ultra_clock = offset
	clock_stall = 0
	clock_failed = false
	output_latency = AudioServer.get_output_latency()
	payout.stream = PAYOUTS[2]
	if offset < payout.stream.get_length(): payout.play(offset)

## Read a monotonic audio clock for synchronizing the five Ultra prize reveals.
func ultra_position(delta: float = 0.0) -> float:
	# Compensate the mix buffer and speaker latency; ignore clock jitter backwards.
	# https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html
	var at: float = payout.get_playback_position()+AudioServer.get_time_since_last_mix()-output_latency
	clock_stall = clock_stall+delta if at <= ultra_clock else 0.0
	if clock_stall > 0.5: clock_failed = true # An unavailable audio device must not block rewards.
	ultra_clock = maxf(ultra_clock,at)
	return ultra_clock

## Stop rolling and play the first payout once, preserving an existing Ultra intro.
func reveal(tier: int) -> void:
	if reveal_count > 0: return
	reveal_count += 1
	rolling.stop()
	if tier == 3 and ultra_started: return # Its first two bars lead into this landing.
	payout.stream = PAYOUTS[clampi(tier-1,0,2)]
	payout.play()

## Apply mute and pause changes without restarting browser audio each frame.
func sync(muted: bool, paused: bool) -> void:
	enabled = not muted
	for voice in [rolling,payout]:
		# Web Sample playback restarts its source on every unpause call.
		# Sync runs each frame, so send pause/resume only on a state change.
		if voice.stream_paused != paused: voice.stream_paused = paused
		if AudioServer.get_bus_index("Combat") >= 0: voice.bus = "Combat"
	rolling.volume_db = ROLL_DB if enabled else -80.0
	payout.volume_db = PAYOUT_DB if enabled else -80.0
	# Never pitch-shift the 160 BPM buildup or payout recordings.

## Stop both chest voices and clear paused playback for the next opening.
func stop() -> void:
	ultra_started = false
	rolling.stop()
	payout.stop()
	rolling.stream_paused = false
	payout.stream_paused = false

## Silence chest audio when its scene is removed.
func _exit_tree() -> void:
	stop()
