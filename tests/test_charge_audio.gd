extends SceneTree
const Battle = preload("res://scripts/battle.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Battle.new()
	root.add_child(game)
	game.set_process(false)
	var layer = game.charge_audio
	check(layer.player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Texture loops continuously")
	check(layer.player.stream.loop_end == 76800, "Loop covers the entire crossfaded 1.6 second sample")
	game._start_charge()
	game._process(0.04)
	check(layer.player.playing, "Charging starts the additional texture")
	layer.update(0.04, true, 0.0, false)
	var edge: float = layer.player.volume_linear
	layer.update(0.04, true, 1.0, false)
	check(is_equal_approx(layer.player.volume_linear, db_to_linear(layer.CENTER_DB)*0.25), "Charging loop is now one quarter of its original volume at full power")
	check(is_equal_approx(edge, db_to_linear(layer.EDGE_DB)*0.25), "The additional volume reduction also applies at the edge")
	check(layer.player.volume_linear > edge * 10, "Center is louder than the edge")
	check(layer.player.pitch_scale == 1.0, "Texture stays at its original pitch")
	game._cancel_charge()
	game._process(0.04)
	check(layer.player.playing and layer.envelope > 0, "Cancel fades out instead of cutting the texture")
	game._process(0.05)
	check(not layer.player.playing, "Canceled texture stops after the fade")
	game._start_charge()
	game._process(0.04)
	game._handle_click(game.AUDIO_RECT.get_center())
	check(not layer.player.playing, "Mute immediately silences the texture")
	check(is_instance_valid(layer.player), "Mute retains the persistent player")
	game._handle_click(game.AUDIO_RECT.get_center())
	game._process(0.04)
	check(layer.player.playing, "Unmute resumes the active charge")
	game.guide = true
	game._process(0.1)
	check(not layer.player.playing, "Modal pauses silence the texture")
	check(game.sounds.has("click_001"), "Existing dice click sound remains available")
	for clip in ["soft_sweep", "perfect"]:
		check(game.sounds[clip] is AudioStreamWAV and game.sounds[clip].resource_path.ends_with(clip+".wav"), "Finished WAV is imported for "+clip)
	game.queue_free()
	await process_frame
	# Let the audio mixer release stopped playback voices before exiting.
	await create_timer(0.15).timeout
	print("Charge audio: ", failures, " failures")
	quit(1 if failures else 0)
