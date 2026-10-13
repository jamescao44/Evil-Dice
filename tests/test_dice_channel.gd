extends SceneTree
const Waves = preload("res://scripts/wave_catalog.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Driver = preload("res://tests/scene_driver.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func tap(game, point: Vector2) -> void:
	game._handle_click(point)
	game._handle_release(point)

func wait_resolved(game) -> void:
	var deadline: int = Time.get_ticks_msec()+6000
	while game.view_phase not in ["ready", "feeding", "over"] and Time.get_ticks_msec()<deadline: await process_frame
	check(Time.get_ticks_msec()<deadline,"Selected action completes")

func prepare(game, values: Array) -> void:
	game._restart()
	game.model.stage = 1
	game.model.power = 1.5
	game.model._load_wave()
	game.model.enemies = [Rules.make_enemy(0),Rules.make_enemy(0),Rules.make_enemy(0)]
	game.visual_stage = 1
	game.monster_side = game.HORROR_SIZES[1]
	game._start_round()
	game.result = game.model.set_test_roll(values)
	game.status_color = game.PURPLE
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = game.skill_bubble.formation
	game.view_phase = "skill"

func test_layout(game) -> void:
	root.add_child(game)
	game.muted = true
	game.speed = 20
	for choice in [0,2,11,12]:
		game._restart()
		game.debug_choice = choice
		var hp: int = game.model.enemies[0].hp
		await game._roll()
		check(game.view_phase == "skill" and game.model.phase == "player", "A revealed roll waits in its skill bubble")
		check(game.model.enemies[0].hp == hp and game.model.statuses[2].count == 0, "Revealing never applies attack or boon")
		check(game.skill_bubble.roll.dice == game.result.dice and game.fx.dice_power.is_empty(), "Dice form a skill instead of channeling to the Horror")
		check(game._skill_center().distance_to(game._skill_rest_point()) <= 7 and game._skill_center().y < game.DICE_CENTER.y,"Skill settles above the dice at its own clickable position")
		check(not game.skill_bubble.caption.name.is_empty() and game.fx.skill.is_empty(),"Skill name belongs to persistent bubble caption, not a timed screen callout")
		check(game._dice_spent() and not game._show_dice_links(),"Held skills grey the dice and hide all combination links")
		check(game.dice.all(func(d): return d.visible and d.self_modulate.r > 0 and d.self_modulate.r < 0.5),"Revealed dice stay visible and dim while the skill is held")
		game.skill_bubble.age += 5
		check(not game.skill_bubble.caption.name.is_empty(),"Caption remains below the skill for as long as it is held")
		var rng: int = game.model.rng.state
		await create_timer(0.08).timeout
		check(game.model.rng.state == rng and game.view_phase == "skill", "Holding a squad skill cannot reroll or advance the enemy turn")
		game._restart()
		await process_frame
		check(game.skill_bubble.roll.is_empty() and game.cinematic_remaining == 0, "Restart clears bubble and cinematic")
		await process_frame # The signal precedes the scene's presentation update.
		check(game.dice.all(func(d): return d.visible and d.self_modulate == Color.WHITE),"Ready dice become fully bright again")
	prepare(game,[1,2,3])
	game.skill_bubble.age = (game.skill_bubble.converge+game.skill_bubble.RISE+0.1)/game.skill_bubble.entrance_speed
	check(game.skill_bubble.radius_scale() >= 1.7,"Skill entrance is substantially larger than the resting seal")
	game.skill_bubble.age = game.skill_bubble.formation
	var original: MultiHitSkill = game.result.duplicate(true)
	tap(game,game._skill_center())
	check(game.view_phase == "targeting" and not game.skill_dragging, "Tap selects single-target skill without casting")
	tap(game,Vector2(30,40))
	check(game.view_phase == "skill" and game.model.pending.same_as(original), "Empty-space tap cancels aim without consuming skill")
	game._handle_click(game._skill_center())
	game._handle_motion(Vector2(40,50))
	game._handle_release(Vector2(40,50))
	check(game.view_phase == "skill" and not game.skill_pressed and game.model.phase == "player", "Invalid drag returns the bubble intact")
	tap(game,game._skill_center())
	var target_point: Vector2 = game._target_rect(2).get_center()
	game._handle_motion(target_point)
	check(game.hover_target == 2 and not game.skill_dragging,"Hover indicates the chosen foe without dragging")
	tap(game,target_point)
	tap(game,target_point)
	await wait_resolved(game)
	check(game.model.enemies[2].hp < 75 and game.model.enemies[0].hp == 75 and game.model.enemies[1].hp == 75,"Single-target damage reaches only the selected foe, once")
	prepare(game,[1,1,1])
	game.model.enemies[1].shield = 10
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = game.get_global_transform_with_canvas()*game._skill_center()
	press.pressed = true
	game._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = game.get_global_transform_with_canvas()*game._enemy_point(1)
	game._input(drag)
	check(game.skill_dragging and game.hover_target == 1,"Touch drag follows finger and highlights a live foe")
	press.position = drag.position
	press.pressed = false
	game._input(press)
	check(game.view_phase == "resolving" and game.active_touch == -1,"Touch release on a foe casts")
	await wait_resolved(game)
	check(game.model.enemies[1].hp == 0 and game.model.enemies[0].hp == 75,"111 executes chosen foe through shield")
	check(game._target_at(game._enemy_point(1)) == -1,"Corpses cannot be selected")
	for face_count in [2,3]:
		prepare(game,[5,5,2] if face_count == 2 else [5,5,5])
		for enemy in game.model.enemies: enemy.hp = 500
		game.model.statuses[3].count = 2
		game.model.perfect_progress = 9
		var count: int = 3 if face_count == 2 else 6
		var damage: int = 36 if face_count == 2 else 30
		var round_number: int = game.model.round_number
		tap(game,game._skill_center())
		check(game.view_phase == "skill" and game.skill_bubble.used == 0,"Tapping a rapid skill does not cast it")
		var expected: Array = [500,500,500]
		var probe := RandomNumberGenerator.new()
		probe.state = game.model.rng.state
		for i in range(count): expected[probe.randi_range(0,2)] -= damage
		Driver.cast_pending(game)
		check(game.view_phase == "resolving" and game.skill_bubble.used == 1,"One field drop starts the whole combo with its first orb")
		check(game.damage_feedback.building and game._world_time_scale() == 1,"Damage buildup leaves the battle running before the impact beat")
		var rng: int = game.model.rng.state
		for repeat in range(4): tap(game,game._skill_center())
		tap(game,game._diamond_center(8))
		check(game.skill_bubble.used == 1 and game.model.rng.state == rng and game.model.open_rewards.is_empty(),"Spam cannot trigger a second chain or claim loot")
		var deadline: int = Time.get_ticks_msec()+5000
		var most_used: int = 1
		var intermediate: bool = false
		var turn_waited: bool = true
		var dice_stayed_dim: bool = true
		while game.view_phase == "resolving" and Time.get_ticks_msec()<deadline:
			dice_stayed_dim = dice_stayed_dim and game.dice.all(func(d): return d.visible and d.self_modulate.r > 0 and d.self_modulate.r < 0.5)
			most_used = maxi(most_used, game.skill_bubble.used)
			if game.model.phase == "executing":
				intermediate = true
				turn_waited = turn_waited and game.model.round_number == round_number and game.model.statuses[3].count == 2 and not game._can_claim_chest()
			await process_frame
		check(Time.get_ticks_msec()<deadline and most_used == count and intermediate,"All orbs pop in sequence without more input")
		check(turn_waited,"Boon clocks, enemy turns and chests wait for the complete combo")
		check(dice_stayed_dim,"Dice remain visible and dim through the entire multi-hit cast and enemy phase")
		for i in range(3): check(game.model.enemies[i].hp == expected[i],"Each automatic hit chooses a fresh random living target")
		check(game.model.round_number == round_number+1 and game.model.statuses[3].count == 1 and game.skill_bubble.roll.is_empty(),"Whole combo spends exactly one action")
		check(game._can_claim_chest() and not game._dice_spent(),"Dice and chests unlock when the turn finishes")
	prepare(game,[5,5,5])
	for enemy in game.model.enemies: enemy.hp = 1
	Driver.cast_pending(game)
	while game.view_phase == "resolving": await process_frame
	check(game.view_phase == "relic_reward" and game.model.living().is_empty() and game.skill_bubble.roll.is_empty(),"Wave clear stops unused hits before offering a relic")
	prepare(game,[2,2,4])
	tap(game,game._skill_center())
	check(game.view_phase == "skill" and game.model.statuses[2].count == 0,"Support tap does not activate the skill")
	Driver.cast_pending(game)
	check(game.view_phase == "resolving" and game._world_time_scale() == 0,"Support field drop starts casting")
	await wait_resolved(game)
	check(game.model.statuses[2].count == 0 and game.model.enemies.all(func(e): return e.hp == e.max_hp),"Freeze does not grant regeneration or damage enemies")
	prepare(game,[4,4,1])
	Driver.cast_pending(game)
	await wait_resolved(game)
	check(game.model.enemies.all(func(e):return e.hp<75),"Area skill hits everyone after one field drop")
	for stage in range(9):
		game._restart()
		game.model.stage = stage
		game.model._load_wave()
		game.visual_stage = stage
		game.monster_side = game.HORROR_SIZES[stage]
		game.model.set_status_counts({2:3,3:3,33:3,6:3})
		for i in range(game.model.enemies.size()):
			var rect: Rect2 = game._target_rect(i)
			check(game.ARENA.encloses(rect),"Enemy target stays inside battlefield")
			var health: Rect2 = game._enemy_health_rect(i).grow(3)
			check(game.ARENA.encloses(health),"Health bar remains inside battlefield")
			for j in range(i):
				check(not health.intersects(game._enemy_health_rect(j).grow(3)),"Health bar borders never overlap in any squad formation")
			for item in game._active_statuses():
				check(not rect.intersects(game._status_rect(item.id)),"Enemy target never overlaps Horror status input")
	check(game.HORROR_SIZES[2] < 288 and game.HORROR_SIZES[6] < 320 and game.HORROR_SIZES[9] == 288,"City Horror is slightly smaller while squad growth stays intact")
	game._restart()
	game.model.perfect_progress = 9
	tap(game,game._diamond_center(2))
	tap(game,game._diamond_center(5))
	check(game.view_phase == "ready" and game.model.perfect_progress == 9,"Lower chest tiers cannot spend a full bank")
	tap(game,game._diamond_center(8))
	check(game.view_phase == "reward" and game.model.open_rewards.size() == 5 and game.model.perfect_progress == 0,"Full bank claims only the epic chest")
	game._restart()
	game.model.perfect_progress = 5
	tap(game,game._diamond_center(5))
	check(game.view_phase == "ready" and game.model.perfect_progress == 5,"Unfilled milestone cannot spend treasure")
	game.model.perfect_progress = 8
	tap(game,game._diamond_center(2))
	check(game.view_phase == "ready" and game.model.perfect_progress == 8,"Common chest is unavailable once rare is earned")
	tap(game,game._diamond_center(5))
	check(game.model.open_rewards.size() == 3 and game.model.perfect_progress == 0,"Sixth diamond chooses rare chest and clears remainder")
	game._restart()
	game.model.stage = Waves.CITY_STAGE
	game.model._load_wave()
	game._start_round()
	game.model.hp = 1000
	game.result = game.model.set_test_roll([1,2,3])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 5
	game.view_phase = "skill"
	var city_clock: float = game.model.volley_clock
	await create_timer(0.12).timeout
	check(game.model.volley_clock < city_clock,"City continues attacking while a skill waits")
	tap(game,game._skill_center())
	check(game.view_phase == "targeting" and game._target_at(game.CITY_POINT) == -2,"Single-target city skill asks to select the city")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.view_phase == "skill" and not game.skill_pressed,"Focus loss cancels aim without losing skill")
	game._begin_cinematic(false)
	check(game._world_time_scale() < 1 and game._cinematic_gloom() == 0,"Triple briefly slows the world")
	var normal_duration: float = game.cinematic_remaining
	game._begin_cinematic(true)
	check(game.cinematic_remaining > normal_duration and game._cinematic_gloom() > 0.5,"666 has longer slowdown and ominous dimming")
	city_clock = game.model.volley_clock
	await create_timer(0.2).timeout
	check(city_clock-game.model.volley_clock < 0.08,"Cinematic slows real city simulation, not only its drawing")
	game.cinematic_remaining = 0
	game.fx.time_factor = 1
	Driver.cast_pending(game)
	await wait_resolved(game)
	check(game.model.city_hp < game.Run.CITY_MAX_HP,"Selected city receives the skill")
	game.model.begin_round()
	game.result = game.model.set_test_roll([5,5,2])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 5
	game.view_phase = "skill"
	game.model.perfect_progress = 9
	game.model.troops = 3
	game.model.spawn_clock = 999
	game.model.volley_clock = 999
	game.model.troop_clock = 999
	var city_hp: int = game.model.city_hp
	Driver.cast_pending(game)
	await wait_resolved(game)
	check(game.model.city_hp == city_hp-54 and game.model.troops == 0,"One city drop automatically deals all three hits and clears three troops")
	check(game.view_phase == "ready" and game._can_claim_chest(),"Whole city combo releases the dice and treasure lock")
	game._restart()
	check(game._world_time_scale() == 1 and game.fx.time_factor == 1,"Restart restores normal time")
	for choice in [0, 2, 7, 11, 12]:
		game._restart()
		game.model.stage = Waves.CITY_STAGE
		game.model._load_wave()
		game._start_round()
		game.model.hp = 1000
		game.model.spawn_clock = 999
		game.model.volley_clock = 999
		game.model.troop_clock = 999
		game.debug_choice = choice
		await game._roll()
		check(game.view_phase == "resolving" and game.casting_source == "current","City rolls start casting automatically after their reveal")
		await wait_resolved(game)
		check(game.view_phase == "ready" and game.model.pending.is_empty(),"City auto-cast finishes without a click or drag and permits the next throw")
		check((game.model.statuses[2].count == 0 and game.model.city_hp == game.Run.CITY_MAX_HP) if choice == 2 else game.model.city_hp < game.Run.CITY_MAX_HP,"City auto-cast applies both support and attack results")
	game._restart()
	# Isolate real-time cast beats, including city simulation and menu suspension.
	game.model.stage = Waves.CITY_STAGE
	game.model._load_wave()
	game._start_round()
	game.model.hp = 1000
	game._begin_cast_cinematic(Rules.Kind.ULTIMATE)
	city_clock = game.model.volley_clock
	await create_timer(0.055).timeout
	check(game._world_time_scale() == 0 and game.model.volley_clock == city_clock,"Cast anticipation freezes city damage clocks")
	await create_timer(game.cinematic_pause).timeout
	check(game._world_time_scale() > 0 and game._world_time_scale() < 0.3 and game._backdrop_dim() > 0.5,"Anticipation releases into ominous slow motion")
	game.guide = true
	var frozen_cinematic: float = game.cinematic_remaining
	city_clock = game.model.volley_clock
	await create_timer(0.05).timeout
	check(game.cinematic_remaining == frozen_cinematic and game.model.volley_clock == city_clock,"Menu pauses both casting cinematic and city clocks")
	game.guide = false
	await create_timer(0.7).timeout
	check(game._world_time_scale() == 1 and game._backdrop_dim() == 0,"Casting slowdown and shade fully recover")
	game._begin_cast_cinematic(Rules.Kind.SPECIAL)
	game._restart()
	check(game.cinematic_pause == 0 and game._world_time_scale() == 1 and game._backdrop_dim() == 0,"Restart cancels a cast pause without leaving darkness or slow time")
	game.queue_free()
	await process_frame

func run() -> void:
	await test_layout(Battle.new())
	await test_layout(Portrait.new())
	print("Skill bubbles: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
