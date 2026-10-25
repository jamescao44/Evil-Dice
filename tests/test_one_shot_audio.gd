extends SceneTree
## Reproduce mass-kill bursts and staggered tails with actual audio voices.
const Audio = preload("res://scripts/audio/one_shot_audio.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func wait_for_audio_tick() -> void:
	var until: int = Time.get_ticks_msec()+45
	while Time.get_ticks_msec() < until: await process_frame
func run() -> void:
	var audio = Audio.new(); root.add_child(audio)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	var data := PackedByteArray(); data.resize(44100); data.fill(128)
	stream.data = data
	var capped = audio.play("item/pluck_001",stream,20,-22)
	check(is_equal_approx(capped.pitch_scale,audio.MAX_PITCH),"Extreme pitches are capped for every one-shot")
	check(AudioServer.get_bus_effect_count(0) == 0,"Master preserves the original high end without global EQ or low-pass filtering")
	audio.clear()
	var first = audio.play("enemy/chop",stream,0.7,-15)
	check(first != null and is_equal_approx(first.volume_db,-15),"Single death cue retains authored volume")
	for i in range(12): audio.play("enemy/chop",stream,0.7,-15)
	check(audio.voices.size() == 1,"Simultaneous deaths coalesce to one sound")
	await wait_for_audio_tick()
	var second = audio.play("enemy/chop",stream,0.9,-15)
	await wait_for_audio_tick()
	check(second != null and audio.voices.size() == 2,"Separated cues retain rhythm and pitch variation")
	check(is_equal_approx(first.volume_db,-15) and is_equal_approx(second.volume_db,-15),"Separate deaths never reduce one another's volume")
	var third = audio.play("enemy/chop",stream,1.1,-12)
	await wait_for_audio_tick()
	check(third != null and is_equal_approx(third.volume_db,-12) and is_equal_approx(first.volume_db,-15),"Each later death keeps its requested level, with no tail normalization")
	check(audio.play("enemy/chop",stream,1,-15) != null,"Sequential deaths are not suppressed by a per-clip voice cap")
	for clip in ["dice/click_001","dice/soft_sweep","player/hit","item/card_draw","item/deck_flip","item/crystal_collect","ui/click_001"]:
		audio.clear()
		for i in range(6):
			var voice = audio.play(clip,stream,1.0+i*0.05,-12.0+i)
			check(voice != null and is_equal_approx(voice.volume_db,-12.0+i),"Ordinary repeated effects always play at authored volume: "+clip)
		check(audio.voices.size() == 6,"Ordinary effects have no duplicate window or per-clip limit: "+clip)
		await wait_for_audio_tick()
		for i in range(6): check(is_equal_approx(audio.voices[i].volume_db,-12.0+i),"Overlapping ordinary tails are never faded: "+clip)
	audio.clear()
	var oldest = audio.play("player/hit",stream,1,-15)
	for i in range(20):
		check(audio.play("player/hit",stream,1,-15) != null,"Newest feedback still plays at the overall voice limit")
	check(audio.voices.size() == audio.MAX_VOICES and not oldest.playing,"Overall voice cap replaces the oldest tail, as before")
	audio.clear()
	check(audio.voices.is_empty(),"Mute or restart immediately clears all one-shots")
	check(audio.play("enemy/chop",stream,1,-15) != null,"Restart clears duplicate history")
	audio.clear(); audio.queue_free(); await process_frame
	await wait_for_audio_tick()
	await wait_for_audio_tick()
	print("One-shot audio: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
