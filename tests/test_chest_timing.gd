extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Chests = preload("res://scripts/rewards/chest_rules.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/chest-timing-"+label+".png")

func start(chest, game, tier: int, wave: bool = false, reduce: bool = false) -> void:
	var values: Array = []
	values.resize(Chests.COUNTS[tier])
	values.fill(6)
	chest.start(values,game.fx.canvas_size,game.description_font,reduce,[],tier,wave)
	check(chest.roll_phase == "closed" and not chest.audio.rolling.playing and not chest.audio.payout.playing,"New chest waits closed and silent")
	chest._process(10)
	chest.click(Vector2(10,10))
	check(chest.roll_phase == "closed" and chest.elapsed == 0 and not chest.did_open,"Waiting or tapping outside the chest cannot open it")
	chest.click(chest.closed_rect().get_center())
	check(chest.roll_phase == ("settling" if tier == 3 and not wave else "spinning") and chest.tier == (0 if wave else tier),"Opening starts the automatic Ultra finale or the ordinary reel without upgrading")
	check(not chest.audio.rolling.playing,"Opening the chest does not start reel audio early")
	chest.paused = true
	chest._process(1)
	check(not chest.audio.rolling.playing and chest.elapsed == 0,"Paused opening cannot start reel audio")
	chest.paused = false
	chest._process(chest.OPEN_TIME-0.01)
	check(not chest.audio.rolling.playing and chest.emergence(0) == 0,"Reel preparation remains silent")
	chest._process(0.02)
	check(chest.audio.rolling.playing and chest.emergence(0) > 0,"Audio starts on the first visible reel motion")
	await process_frame
	if wave:
		for i in range(tier):
			chest.request_stop()
			chest._process(chest.UPGRADE_BEAT+0.01)

func scene_checks(portrait: bool) -> void:
	var game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = true
	game.set_process(false)
	var chest = game.chest
	chest.set_process(false)
	chest.audio_clock_enabled = false
	var audio = chest.audio
	var label: String = "portrait" if portrait else "landscape"
	for clip in ["arcade_slot_roll","arcade_slot_roll2","reward_level1","reward_level2","reward_level3"]:
		var stream: AudioStreamWAV = game.sounds["item/"+clip]
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 48000 and stream.stereo,"Uncompressed full-resolution stereo source: "+clip)
	chest.start([6,6,6,6,6],game.fx.canvas_size,game.description_font,false,[],3)
	chest.open_chest()
	chest.request_stop()
	check(not audio.rolling.playing and audio.ultra_started and audio.payout.playing,"Opening Ultra immediately starts level 3 while its reels prepare")
	chest._process(chest.OPEN_TIME+0.01)
	check(audio.rolling.playing and audio.ultra_started and audio.payout.playing,"Starting the visible reels preserves the already-playing Ultra intro")
	chest.cancel()
	await process_frame
	for wave in [false,true]:
		for tier in range(4):
			await start(chest,game,tier,wave)
			var state: int = game.model.reward_rng.state
			check(audio.rolling.playing and audio.rolling.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Rolling uses one continuous loop")
			check(audio.rolling.pitch_scale == 1 and audio.payout.pitch_scale == 1,"Audio retains the original tempo")
			check(audio.reveal_count == 0 and audio.payout.playing == (tier == 3),"Only Ultra automatically plays its payout intro as soon as it appears")
			check(audio.rolling.stream == (audio.greed_roll_loop if tier == 2 else audio.roll_loop),"Greed uses the second rolling sound; all other tiers use the original")
			chest.request_stop()
			check(chest.active and chest.roll_phase == "settling" and audio.reveal_count == 0,"First stop tap starts anticipation without revealing")
			check(audio.ultra_started == (tier == 3),"Only Ultra begins its musical buildup before landing")
			if tier == 3: check(is_equal_approx(chest.stop_duration(),3.0),"Ultra reveal starts after two bars at 160 BPM")
			var beginning: float = chest.elapsed
			chest.paused = true
			chest._process(1)
			chest.request_stop()
			check(chest.elapsed == beginning and audio.rolling.stream_paused and (not audio.payout.playing or audio.payout.stream_paused),"Pausing freezes both music and reveal timeline")
			chest.paused = false
			if tier == 3:
				chest._process(chest.stop_duration()*0.4)
				var at: float = chest.travel(0)
				chest._process(chest.stop_duration()*0.1)
				check(is_equal_approx(fposmod(chest.travel(0)-at,chest.reel_steps),fposmod(chest.stop_duration()*0.1*chest.REEL_SPEED,chest.reel_steps)),"Ultra keeps constant speed before its note")
			else:
				var first: int = chest.stop_order()[0]
				chest._process(chest.stop_duration()*0.2)
				var at: float = chest.travel(first)
				chest._process(chest.stop_duration()*0.2)
				var mid: float = chest.travel(first)
				chest._process(chest.stop_duration()*0.2)
				check(chest.travel(first)-mid < mid-at,"Normal, Perfect and Greed progressively slow down")
				chest._process(chest.stop_duration()*0.18)
				check(chest.travel(first) > chest.reel_steps and chest.travel(first) < chest.reel_steps+0.3,"Reel overshoots the prize slightly")
				if tier == 2 and not wave: await capture(label+"-greed-overshoot")
				chest._process(chest.stop_duration()*0.14)
				check(chest.travel(first) < chest.reel_steps and chest.travel(first) > chest.reel_steps-0.04,"Reel springs gently back through the prize")
			check(audio.reveal_count == 0 and chest.announced == 0,"No prize reveals before its cue")
			if tier == 3:
				var before: float = chest.elapsed
				for i in range(10): chest.skip_animation()
				check(chest.elapsed == before and chest.active,"Ultra cannot be skipped through any input path")
				if not wave: await capture(label+"-ultra-buildup")
			var order: Array = chest.stop_order()
			for note in range(order.size()):
				var reel: int = order[note]
				chest._process(chest.stop_time(reel)-chest.elapsed-0.001)
				check(chest.announced == note,"Prize waits until its exact stop cue")
				chest._process(0.002)
				check(chest.announced == note+1 and is_equal_approx(chest.travel(reel),chest.reel_steps),"Each reel finishes exactly centered on its stop cue")
				check(chest.landing_bursts.back().color == chest.reward_color(chest.rewards[reel]) and chest.landing_bursts.back().at == chest.reel_rect(reel).get_center(),"Each stopped prize explodes in its own rarity color")
				if tier == 3: check(is_equal_approx(chest.stop_time(reel)-chest.settle_started,chest.ChestAudio.ULTRA_NOTES[note]),"Ultra prize matches its authored note time")
				if tier < 3:
					check(audio.reveal_count == 1 and audio.payout.playing,"Non-Ultra payout starts with the first explosion and plays once across later landings")
				if note < order.size()-1:
					check(chest.reveal_age < 0,"Full chest reveal waits for the final prize")
					if tier == 3: check(audio.reveal_count == 0,"Ultra keeps its existing musical finale")
			check(audio.reveal_count == 1 and not audio.rolling.playing and audio.payout.playing,"Payout plays once through the completed reveal")
			for i in range(chest.rewards.size()): check(is_equal_approx(chest.travel(i),chest.reel_steps),"Stopped reward is exactly centered")
			check(audio.payout.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,"Every payout recording plays once")
			var revealed_elapsed: float = chest.elapsed
			chest.paused = true
			chest._process(0.2)
			check(chest.elapsed == revealed_elapsed and not audio.payout.stream_paused and audio.payout.playing,"Reward overlay freezes chest visuals while every tier's payout keeps playing")
			chest.paused = false
			chest._process(0)
			check(audio.reveal_count == 1 and not audio.payout.stream_paused,"Closing reward overlay does not replay the payout")
			if tier == 3 and not wave:
				chest._process(0.08)
				await capture(label+"-ultra-impact")
			chest._process(1)
			check(not chest.active and audio.reveal_count == 1 and game.model.reward_rng.state == state,"Reveal completes once without touching reward RNG")
			chest.cancel()
			await process_frame
			check(not audio.rolling.playing and not audio.payout.playing,"Leaving the chest stops all persistent audio")
	# Skip lands through the same event path, including sound, without duplication.
	for tier in range(3):
		await start(chest,game,tier)
		chest.request_stop()
		chest._process(0.1)
		chest.request_stop()
		check(not chest.active and audio.reveal_count == 1,"Second tap skips non-Ultra stop sequence and plays its payout")
		chest.request_stop()
		check(audio.reveal_count == 1,"Further taps cannot replay the reveal")
	await start(chest,game,3,false,true)
	chest.request_stop()
	chest.request_stop()
	check(chest.active and chest.reveal_age < 0,"Reduced effects preserve the unskippable Ultra rhythm")
	chest._process(4.126)
	check(audio.reveal_count == 1,"Reduced effects still reveal all five prizes on their musical notes")
	game.muted = false
	chest._process(0.01)
	check(audio.payout.volume_db == audio.PAYOUT_DB and audio.payout.bus == "Combat","Unmute restores the original mix through the limiter")
	game.muted = true
	chest._process(0.01)
	check(audio.payout.volume_db == -80 and audio.rolling.volume_db == -80,"Mute silences both chest voices")
	await start(chest,game,0)
	game.muted = false
	chest._process(0)
	var rolling_db: float = audio.rolling.volume_db
	chest.request_stop()
	chest._process(0.04)
	check(audio.rolling.volume_db == rolling_db and rolling_db == audio.ROLL_DB,"Slowdown never fades the rolling sound")
	game.muted = true
	chest._process(0)
	game._restart()
	check(not audio.payout.playing and not audio.rolling.playing,"Restart cannot leak chest music into combat")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		# Real frames/mixer, in addition to the deterministic timing assertions above.
		await start(chest,game,3)
		chest.audio_clock_enabled = true
		chest.set_process(true)
		var note_times: Array = []
		var on_note := func(index): note_times.append({"index":index,"time":audio.ultra_position()})
		chest.landed.connect(on_note)
		chest.request_stop()
		var deadline: int = Time.get_ticks_msec()+5500
		while audio.reveal_count == 0 and Time.get_ticks_msec() < deadline: await process_frame
		# Sample at the landing signal, not the following frame after rendering.
		var audio_time: float = note_times.back().time if not note_times.is_empty() else INF
		check(audio.reveal_count == 1 and absf(audio_time-audio.ULTRA_NOTES[-1]) < 0.04,"Real final note and last Ultra landing align within one display frame")
		check(note_times.size() == 5,"All five prizes emit a live audio-synced landing")
		for i in range(note_times.size()):
			check(note_times[i].index == chest.stop_order()[i] and absf(note_times[i].time-chest.ChestAudio.ULTRA_NOTES[i]) < 0.04,"Each live prize lands left to right within one display frame of its note")
		print("Ultra landing audio position (%s): %.3f s" % [label,audio_time])
		chest.landed.disconnect(on_note)
		chest.cancel()
	game.free()
	await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	await scene_checks(false)
	await scene_checks(true)
	await create_timer(0.15).timeout # Let the mixer release stopped loop voices.
	print("Chest timing and audio: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
