extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Audio = preload("res://scripts/audio/chest_audio.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func audio_checks() -> void:
	var source := AudioStreamWAV.new()
	source.format = AudioStreamWAV.FORMAT_16_BITS
	source.stereo = true
	source.mix_rate = 1000
	var data := PackedByteArray()
	data.resize(250*4)
	for frame in range(250):
		data.encode_s16(frame*4,1000)
		data.encode_s16(frame*4+2,-500)
	source.data = data
	var loop: AudioStreamWAV = Audio.TimedLoop.build(source,0.1)
	check(loop.loop_end-loop.loop_begin == 100,"Repeat interval is independent of the tail's length")
	check(loop.data.decode_s16(25*4) == 1000,"Initial playback has no phantom tail from a previous repeat")
	check(loop.data.decode_s16(125*4) == 2000 and loop.data.decode_s16(225*4) == 3000,"Successive repeats overlap the complete existing tails")
	check(loop.data.decode_s16(275*4) == 2000 and loop.data.decode_s16(225*4+2) == -1500,"Expired tails end naturally and stereo channels stay separate")
	check(source.data == data,"Loop preparation never modifies the original source")
	var real: AudioStreamWAV = Audio.TimedLoop.build(Audio.ROLL,Audio.ROLL_PERIOD)
	check(real.loop_end-real.loop_begin == 40500,"Nine sixteenth notes at 160 BPM are exactly 40500 samples at 48 kHz")
	check(Audio.ROLL.get_length() > 2.6 and real.loop_begin > 0,"Updated full-tail source has an intro before the steady overlap loop")
	var largest_step: int = 0
	for frame in range(real.loop_begin+1,real.loop_end):
		for channel in range(2): largest_step = maxi(largest_step,absi(real.data.decode_s16(frame*4+channel*2)-real.data.decode_s16((frame-1)*4+channel*2)))
	for channel in range(2):
		var seam: int = absi(real.data.decode_s16(real.loop_begin*4+channel*2)-real.data.decode_s16((real.loop_end-1)*4+channel*2))
		check(seam < 200 and seam < largest_step,"Loop wrap has no sharp sample discontinuity")
	var greed: AudioStreamWAV = Audio.TimedLoop.build(Audio.GREED_ROLL,Audio.ROLL_PERIOD)
	check(greed.loop_end-greed.loop_begin == 40500 and Audio.GREED_ROLL.get_length() == 2.25,"Greed's full-tail alternate uses the same exact musical interval")
	for channel in range(2):
		var seam: int = absi(greed.data.decode_s16(greed.loop_begin*4+channel*2)-greed.data.decode_s16((greed.loop_end-1)*4+channel*2))
		check(seam < 200,"Greed loop also wraps without a sharp sample discontinuity")

func capture(game, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game.queue_redraw()
	game.chest.queue_redraw()
	game.wave_chest.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/chest-reels-"+label+".png")

func layout_checks(portrait: bool) -> void:
	var game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = true
	game.set_process(false)
	game.view_phase = "reward"
	var chest = game.chest
	chest.set_process(false)
	chest.audio_clock_enabled = false
	var layout: String = "portrait" if portrait else "landscape"
	var prizes: Array = []
	for rarity in range(5):
		for id in Relics.ITEMS:
			if Relics.ITEMS[id].rarity == rarity:
				prizes.append({"relic_id":id})
				break
	chest.start([1,1,1,1,1],game.fx.canvas_size,game.description_font,false,prizes,3,true)
	chest.open_chest()
	chest._process(chest.OPEN_TIME+0.01)
	check(chest.emergence(0) == 1 and chest.prize_origin(0) == chest.reel_rect(0).get_center(),"Initial reel appears at full size in its final position")
	var center: Vector2 = chest.reel_rect(0).get_center()
	chest.request_stop()
	chest._process(chest.UPGRADE_BEAT)
	chest.request_stop()
	check(chest.visible_reel_count() == 3 and chest.reel_rect(0).get_center() == center,"Greed keeps the original spinner centered")
	check(chest.reel_rect(1).end.x <= 0 and chest.reel_rect(2).position.x >= game.fx.canvas_size.x,"Greed's extra spinners enter from opposite screen sides")
	var side_size: Vector2 = chest.reel_rect(1).size
	chest._process(chest.UPGRADE_BEAT*0.5)
	check(chest.reel_rect(1).size == side_size and chest.reel_rect(2).size == side_size,"Entering reels never zoom or change height")
	await capture(game,layout+"-greed-entering")
	chest._process(chest.UPGRADE_BEAT*0.5)
	await capture(game,layout+"-greed")
	chest.request_stop()
	check(chest.tier == 3 and chest.roll_phase == "settling" and chest.audio.ultra_started,"Reaching Ultra automatically starts its musical reveal")
	chest._process(chest.UPGRADE_BEAT)
	for i in range(5):
		check(Rect2(Vector2.ZERO,game.fx.canvas_size).encloses(chest.reel_rect(i)),"Every Ultra reel fits the viewport")
		check(chest.selection_rect(i).size.x == chest.selection_rect(i).size.y,"Selection indicator is a square")
		check(chest.selection_rect(i).size.x >= (88 if portrait else 44),"Even the five-reel selection stays at least 44 screen pixels wide")
		for j in range(i): check(not chest.reel_rect(i).intersects(chest.reel_rect(j)),"All reel hit areas remain separate")
	chest.request_stop()
	var state: int = game.model.reward_rng.state
	var order: Array = chest.stop_order()
	for i in range(5):
		chest._process(chest.stop_time(order[i])-chest.elapsed+0.05)
		check(chest.announced == i+1 and chest.landing_bursts.size() == i+1,"Each note creates exactly one prize burst")
		check(chest.landing_bursts.back().color == Relics.rarity_color(prizes[order[i]].relic_id),"Burst uses the prize rarity, independent of chest color")
		await capture(game,layout+"-ultra-note-"+str(i+1))
	check(game.model.reward_rng.state == state,"Particle bursts never consume gameplay randomness")
	chest.cancel()
	check(chest.landing_bursts.is_empty(),"Closing clears all reveal particles")
	await process_frame
	game.view_phase = "wave_reward"
	for enemy in game.model.enemies: enemy.hp = 0
	game.model.begin_wave_reward()
	game.model.open_wave_chest()
	game.model.discard_unclaimed_rewards()
	game.model.close_chest()
	game.model.rubies = 30
	game.wave_chest.after_chest(0)
	check(game.model.can_buy_wave_tarot(),"A Normal chest's 30 crystals afford the tarot deck")
	check(not game.wave_chest.tarot_rect().intersects(game.wave_chest.action_rect()),"Large deck hit area leaves Continue separate")
	check(not game.wave_chest.action_rect().intersects(game.tarot_ui.icon_rect()),"Continue never overlaps the persistent tarot inventory icon")
	check(Rect2(Vector2.ZERO,game.fx.canvas_size).encloses(game.wave_chest.tarot_rect()),"Deck and price fit the screen")
	check(game.wave_chest.tarot_card_size().x >= (180 if portrait else 100),"Tarot deck stays large in both layouts")
	for language in ["zh_CN","en"]:
		GameText.set_language(language,false)
		await capture(game,layout+"-deck-"+language)
	game.wave_chest.click(game.wave_chest.tarot_rect().get_center())
	check(game.model.rubies == 0 and game.tarot_ui.ceremony.active(),"Tapping the deck spends exactly 30 and opens the draw")
	game.free()
	await process_frame

func run() -> void:
	audio_checks()
	GameText.set_language("zh_CN",false)
	await layout_checks(false)
	await layout_checks(true)
	await create_timer(0.15).timeout
	print("Chest reel layout and audio loop: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
