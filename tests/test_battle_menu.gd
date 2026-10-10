extends SceneTree
const Run = preload("res://scripts/run_rules.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var checks := 0
var failures := 0

class SoundBattle:
	extends "res://scripts/battle.gd"
	var played: Array = []
	var levels: Dictionary = {}
	func _sound(clip: String, _pitch: float = 1.0, _volume: float = -15.0) -> void:
		played.append(clip)
		levels[clip] = _volume

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func snapshot(g, label: String, portrait: bool) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/menu-"+label+("-portrait" if portrait else "-landscape")+".png")

func model_checks() -> void:
	var m = Run.new(193)
	for wave in range(1,11):
		m.hp = 0
		m.perfect_combo = 8
		m.perfect_progress = 6
		m.saved_skill = m.classify([5,5,5])
		m.statuses[6].count = 5
		check(m.load_debug_wave(wave),"Each supported wave loads")
		check(m.stage == wave-1 and m.hp == 100+(wave-1)*30 and m.hp == m.max_hp,"Wave gets matching full player health")
		check(m.power == [1.0,1.5,3.0,5.625,6.75,7.875,9.0,10.125,11.25,12.375][wave-1],"Wave gets matching growth")
		check(m.phase == "new" and m.round_number == 0 and m.pending.is_empty() and m.saved_skill.is_empty() and m.perfect_combo == 0 and m.perfect_progress == 0 and m.status_count(6) == 0,"Wave starts with fresh turn, treasure, skills and statuses")
		check(m.city_hp == 10000 and m.troops == 0,"Fresh city has 10000 HP and fresh siege clocks")
		if wave < 10:
			check(m.enemies.size() == Run.WAVE_COUNTS[wave-1][0]+Run.WAVE_COUNTS[wave-1][1],"Wave gets its enemy formation")
		else: check(m.is_city() and m.enemies.is_empty(),"Wave ten loads the city")
	for invalid in [-1,0,11,999]:
		var state: int = m.rng.state
		check(not m.load_debug_wave(invalid) and m.stage == 9 and m.rng.state == state,"Invalid wave leaves the run untouched")

func scene_checks(portrait: bool) -> void:
	if not portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.home_enabled = true
	g._restart(10)
	check(g.model.is_city() and g.monster_side == 288 and g.model.hp == 370 and g.model.phase == "roll","Scene prepares the requested city immediately")
	g._start_charge()
	g._handle_click(g.MENU_RECT.get_center())
	var elapsed: float = g.throw_meter.elapsed
	var volley: float = g.model.volley_clock
	await create_timer(0.08).timeout
	check(g.menu_open and g.throw_meter.elapsed == elapsed and g.model.volley_clock == volley,"Menu pauses both charge and city attacks")
	check(g.dice.all(func(d): return d.visible and d.self_modulate.r > 0 and d.self_modulate.r < 0.4) and not g.fx.visible,"Menu keeps the dice dimmed and pauses foreground effects")
	await snapshot(g,"page",portrait)
	var old_reduced: bool = g.reduced
	g._handle_click(g.FX_RECT.get_center())
	check(g.reduced != old_reduced and g.fx.reduced == g.reduced and g.menu_open,"Effects toggle lives on the menu page")
	g._handle_click(g.GUIDE_RECT.get_center())
	check(g.guide and not g.menu_open,"Help opens from the menu")
	g._handle_click(g.GUIDE_CLOSE.get_center())
	check(g.menu_open and not g.guide,"Help returns to the menu")
	g._handle_click(g.DEBUG_RECT.get_center())
	check(g.debug_open and g.debug_wave_input.visible and g.debug_wave_input.text == "10","Debug shows a wave number field")
	check(g.DEBUG_WAVE_INPUT.encloses(g.debug_wave_input.get_rect()),"Native number field fits the debug layout")
	await snapshot(g,"debug",portrait)
	for invalid in ["", "x", "0", "11", "1.5"]:
		g._debug_load_wave(invalid)
		check(g.debug_open and g.model.stage == 9 and not g.debug_wave_error.is_empty(),"Invalid text shows an error without loading")
	g.debug_wave_input.text = "4"
	g._handle_click(g.DEBUG_WAVE_LOAD.get_center())
	check(g.model.stage == 3 and g.visual_stage == 3 and g.monster_side == g.HORROR_SIZES[3] and g.model.phase == "roll","Load button prepares the selected fight and visuals")
	check(not g._menus_open() and not g.debug_wave_input.visible and g.view_phase == "ready" and g.dice.all(func(d): return not d.charging and not d.rolling),"Loading exits menus and clears old dice motion")
	var previous_sizes: Array = [84,76,66,56,46,38]
	for wave in range(4,10):
		g._restart(wave)
		check(g._enemy_side() == 84 if wave == 4 else g._enemy_side() > previous_sizes[wave-4] and g._enemy_side() <= previous_sizes[wave-4]*1.2,"Fight four keeps its size; fights five through nine grow modestly")
		for i in range(g.model.enemies.size()): check(g.ARENA.has_point(g._enemy_feet(i)),"Larger enemy feet stay inside the arena")
		if wave in [4,7,9]: await snapshot(g,"wave-"+str(wave),portrait)
	g._handle_click(g.MENU_RECT.get_center())
	g._handle_click(g.DEBUG_RECT.get_center())
	g.debug_wave_input.grab_focus()
	g.debug_wave_input.select_all()
	await process_frame
	for code in [KEY_1,KEY_ENTER]:
		var key := InputEventKey.new()
		key.keycode = code
		key.unicode = 49 if code == KEY_1 else 0
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		await process_frame
	check(g.model.stage == 0 and g.model.hp == 100 and g.view_phase == "ready","Enter submits the chosen wave")
	g.debug_choice = 5
	g._roll()
	g._restart(7)
	await create_timer(0.1).timeout
	check(g.model.stage == 6 and g.model.pending.is_empty() and g.view_phase == "ready","Wave load invalidates the old roll coroutine")
	g.model.stage = 9
	g.model.city_hp = 0
	g.model.perfect_progress = 9
	g._check_over()
	check(g.auto_claim_tier == 3 and not g.model.open_rewards.is_empty(),"Victory reserves the largest chest")
	g._handle_click(g.MENU_RECT.get_center())
	g.auto_claim_remaining = 0
	await process_frame
	await process_frame
	check(g.menu_open and g.view_phase == "over" and not g.chest.visible,"Expired victory notice still waits for an open menu to close")
	g._handle_click(g.MENU_RESUME.get_center())
	await process_frame
	await process_frame
	check(not g._menus_open() and g.view_phase == "reward","Resuming victory starts its pending reward sequence")
	g._restart(5)
	await create_timer(0.05).timeout
	check(g.model.stage == 4 and g.model.open_rewards.is_empty() and not g.chest.visible,"Loading a wave cancels a pending victory chest")
	if "--capture" in OS.get_cmdline_user_args():
		g._restart(10)
		g.model.city_hp = 0
		g.model.perfect_progress = 9
		g._check_over()
		g._process(0.3)
		await snapshot(g,"victory-notice",portrait)
		g._process(g.AUTO_CLAIM_DURATION)
		var deadline: int = Time.get_ticks_msec()+4000
		while not g.chest.visible and Time.get_ticks_msec() < deadline: await process_frame
		check(g.chest.visible,"Victory automatically reveals its chest")
		g.chest.set_process(false)
		g.chest.elapsed = 3
		g.chest.queue_redraw()
		await snapshot(g,"victory-reels",portrait)
		g.chest.elapsed = 11
		g.chest.active = false
		g.chest.queue_redraw()
		await snapshot(g,"victory-pickups",portrait)
		for slot in range(g.chest.rewards.size()): g._handle_click(g.chest.reel_rect(slot).get_center())
		deadline = Time.get_ticks_msec()+4000
		while g.view_phase != "over" and Time.get_ticks_msec() < deadline: await process_frame
		check(g.view_phase == "over" and g.model.reward_history.size() == 5,"Victory returns after every gift is picked up")
	g.queue_free()
	await process_frame

func sound_checks() -> void:
	var g := SoundBattle.new()
	root.add_child(g)
	g._roll(0,false)
	check(g.played.count("soft_sweep") == 1 and "slash" not in g.played and "perfect" not in g.played,"Ordinary throw replaces the scrape with one soft sweep")
	check(g.levels.soft_sweep == -21,"Soft sweep is six dB louder on a low-power throw")
	g._restart()
	g.played.clear()
	g._roll(1,true)
	check(g.played.count("soft_sweep") == 1 and g.played.count("perfect") == 1 and "confirmation_002" in g.played,"Perfect sound layers once with the existing confirmation")
	check(g.levels.soft_sweep == -8,"Soft sweep is six dB louder on a Perfect throw")
	g._restart()
	g.queue_free()
	await process_frame

func run() -> void:
	model_checks()
	await scene_checks(false)
	await scene_checks(true)
	await sound_checks()
	print("Battle menu, wave loading and throw sounds: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
