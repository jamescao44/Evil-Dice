extends SceneTree
const Waves = preload("res://scripts/wave_catalog.gd")
const Driver = preload("res://tests/scene_driver.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Rules = preload("res://scripts/battle_rules.gd")
var failures := 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while game.view_phase not in ["ready", "over"] and Time.get_ticks_msec() < deadline:
		Driver.cast_pending(game)
		await process_frame
	check(Time.get_ticks_msec() < deadline, "Scene coroutine settles within timeout")

func ultimate_wave() -> void:
	game.debug_choice = 12
	await game._roll()
	await Driver.resolve_held(game)
	await settle()

func observe_shake() -> float:
	var peak := 0.0
	game._roll()
	var deadline := Time.get_ticks_msec() + 10000
	while game.view_phase not in ["ready", "feeding", "over"] and Time.get_ticks_msec() < deadline:
		await process_frame
		peak = maxf(peak, game.shake)
		Driver.cast_pending(game)
	check(Time.get_ticks_msec() < deadline, "Selected attack finishes")
	return peak

func run() -> void:
	game = Portrait.new() if "--portrait" in OS.get_cmdline_user_args() else Battle.new()
	root.add_child(game)
	game.muted = true
	game.speed = 12.0
	await process_frame
	for face in range(1, 7):
		game._restart()
		for enemy in game.model.enemies: enemy.hp = 500
		game.debug_choice = face
		await game._roll()
		var caption: Dictionary = game.skill_bubble.caption.duplicate()
		await Driver.resolve_held(game)
		check(game.view_phase == "ready" and game.model.round_number == 2, "Pair activates on click and ends enemy turn")
		check(game.model.enemies[0].hp < 500 if face in [1,4,5] else game.model.boon_turns(face) >= 0, "Double attack or timed boon resolves")
		check(game.debug_choice == -1, "One-shot debug clears after accepted roll")
		check(caption.name == Rules.PAIR_NAMES[face-1] and not caption.description.is_empty(), "Every boon announces its name and short effect")
		check(game.fx.combo.label == "PAIR" and game.fx.combo.p == game.DICE_CENTER, "Pair burst starts at the center of the dice")
	for face in range(1, 6):
		game._restart()
		game.model.stage = 1
		game.model._load_wave()
		game._start_round()
		for enemy in game.model.enemies: enemy.hp = 500
		game.debug_choice = face + 6
		await game._roll()
		var caption: Dictionary = game.skill_bubble.caption.duplicate()
		await Driver.resolve_held(game)
		check(game.view_phase == "ready" and game.dice.all(func(d): return not d.rolling), "Triple click resolves and completes enemy phase")
		check(caption.name == Rules.SPECIAL_NAMES[face-1], "Every special announces its skill and triple")
	game._restart()
	game.debug_choice = 0
	var normal_shake: float = await observe_shake()
	check(game.fx.skill.is_empty(), "Normal skill caption stays attached to its bubble instead of a timed global callout")
	game._restart()
	game.debug_choice = 7
	var triple_shake: float = await observe_shake()
	check(normal_shake > 0 and triple_shake > normal_shake * 2, "Normal has a small impact shake; triples have a much larger shake")
	game._restart()
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.FX_RECT.get_center())
	if game.menu_open: game._handle_click(game.MENU_RESUME.get_center())
	game.debug_choice = 7
	check(await observe_shake() == 0 and root.canvas_transform == Transform2D.IDENTITY, "Reduced effects disables screen shake")
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.FX_RECT.get_center())
	if game.menu_open: game._handle_click(game.MENU_RESUME.get_center())
	game._restart()
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.DEBUG_RECT.get_center())
	await process_frame
	await process_frame
	check(game.debug_open and game.dice.all(func(d): return d.visible and d.self_modulate.r < 0.4), "Debug dims dice without hiding them")
	game._handle_click(game.DEBUG_REPEAT.get_center())
	game._handle_click(game._debug_option_rect(2).get_center())
	check(not game.debug_open and game.debug_choice == 2 and game.debug_repeat, "Visual card queues repeatable pair")
	game._handle_click(game.DICE_CENTER)
	check(game.view_phase == "charging" and game.model.pending.is_empty(), "First click charges without committing dice")
	game._handle_click(game.DICE_CENTER)
	var pending: MultiHitSkill = game.model.pending.duplicate(true)
	game._handle_click(game.DICE_CENTER)
	check(game.model.pending.same_as(pending), "Extra click cannot create another roll")
	await settle()
	check(game.debug_choice == 2, "Repeat persists after roll")
	game.debug_choice = 0
	for i in range(30):
		check(Rules.classify(game._debug_values()).kind == Rules.Kind.NORMAL, "Random singles are always all different")
	game._restart()
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.GUIDE_RECT.get_center())
	game._handle_click(game.DICE_CENTER)
	check(game.guide and game.view_phase == "ready", "Guide blocks roll")
	game._handle_click(game.GUIDE_CLOSE.get_center())
	if game.menu_open: game._handle_click(game.MENU_RESUME.get_center())
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	game._input(key)
	check(game.model.phase == "roll", "Keyboard never starts combat")
	check(game._in_dice_range(game.DICE_CENTER), "Space between dice is clickable")
	check(not game._in_dice_range(game.DICE_CENTER + Vector2.ONE * game.DICE_RADIUS * 0.8), "Circle excludes bounding-box corner")
	await ultimate_wave()
	check(game.model.stage == 1 and game.model.enemies.size() == 2 and game.monster_side == Waves.player_size(1), "First feeding and pan reach wave two with gradual growth")
	for enemy in game.model.enemies:
		enemy.hp = 1
		enemy.shield = 0
	game.debug_choice = 7
	await game._roll()
	await Driver.resolve_held(game)
	check(game.fallen.size() == 1 and game.corpse_alpha == 1 and game.model.stage == 1, "Randomly killed foe remains on the ground while others live")
	game.debug_choice = 12
	await game._roll()
	await Driver.resolve_held(game)
	check(game.view_phase == "feeding" and game.fallen.size() == 2, "All bodies persist at start of feeding")
	await settle()
	check(game.model.stage == 2 and game.model.enemies.size() == 1 and game.model.enemies[0].elite and game.fallen.is_empty(), "Bodies fade before elite wave")
	await ultimate_wave()
	check(game.model.stage == 3 and game.model.enemies.size() == 4, "Fourth stage contains four adventurers")
	var rows: Dictionary = {}
	for i in range(4): rows[game._enemy_feet(i).y] = true
	check(rows.size() >= 4, "Adventurers have varied depth rather than a straight row")
	game.debug_choice = 2
	var party_round: int = game.model.round_number
	await game._roll()
	await Driver.resolve_held(game)
	check(game.model.phase == "roll" and game.model.round_number == party_round+1, "All four acted and the next round prepared successfully")
	for stage in range(3,Waves.CITY_STAGE): await ultimate_wave()
	check(game.model.is_city() and game.model.stage == Waves.CITY_STAGE and game.monster_side == 288 and game.model.max_hp == 100+30*Waves.CITY_STAGE, "Final transition reaches the full city size without reducing player health")
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.DEBUG_RECT.get_center())
	var city_clock: float = game.model.volley_clock
	await create_timer(0.3).timeout
	check(game.model.volley_clock == city_clock, "Debug picker pauses city clock")
	game._handle_click(game._debug_option_rect(0).get_center())
	game._roll()
	var city_pending: MultiHitSkill = game.model.pending.duplicate(true)
	for i in range(8): game._handle_click(game.DICE_CENTER)
	check(game._roll_speed() == 2.0 and game.model.pending.same_as(city_pending), "City stays at fixed 2x with no rerolls when spammed")
	await settle()
	check(game.model.city_hp < game.model.CITY_MAX_HP and game.view_phase == "ready", "City skill resolves after selection")
	if not game.menu_open: game._handle_click(game.MENU_RECT.get_center())
	game._handle_click(game.GUIDE_RECT.get_center())
	var crowd_clock: float = game.city_life.clock
	var troop_position: Vector2 = game._troop_point(0)
	await create_timer(0.15).timeout
	check(game.city_life.clock == crowd_clock and game._troop_point(0) == troop_position, "Grimoire pauses civilian motion and troop running with city combat")
	game._handle_click(game.GUIDE_CLOSE.get_center())
	if game.menu_open: game._handle_click(game.MENU_RESUME.get_center())
	game.debug_choice = 12
	await game._roll()
	var ultimate_caption: Dictionary = game.skill_bubble.caption.duplicate()
	game.model.city_hp = 1500
	await Driver.resolve_held(game)
	check(game.model.city_hp == 0 and game.view_phase == "over", "City ultimate applies the shared DMG multiplier and reaches victory")
	check(ultimate_caption.name == "Annihilation" and ultimate_caption.description.is_empty(), "666 uses Annihilation without a description")
	check(not game.city_life.people.is_empty(), "Destroyed city houses release a visible fleeing crowd")
	game._handle_click(game.REPLAY_RECT.get_center())
	check(game.model.stage == 0 and game.city_corpses.is_empty() and game.city_life.people.is_empty() and game.city_life.destroyed.is_empty() and game.model.hp == 100, "Mouse restart clears run and city inhabitants")
	game.debug_choice = 9
	game._roll()
	game._restart()
	await create_timer(0.5).timeout
	check(game.model.phase == "roll" and game.view_phase == "ready" and game.model.round_number == 1, "Restart cancels pending roll coroutine")
	game.debug_choice = 12
	await game._roll()
	await Driver.resolve_held(game)
	game._restart()
	await create_timer(0.5).timeout
	check(game.model.stage == 0 and game.view_phase == "ready", "Restart cancels feeding coroutine")
	print("Scene smoke: manual targets, shake, every buff/special, debug, growth, city ultimate, pause, spam, restart; %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
