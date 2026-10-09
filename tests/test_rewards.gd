extends SceneTree
const Driver = preload("res://tests/scene_driver.gd")
const Run = preload("res://scripts/run_rules.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func test_model() -> void:
	var model = Run.new(123)
	for perfect in [true,false,true,false]: model.record_perfect(perfect)
	check(model.perfect_progress == 2 and model.chest_tier() == 0, "Perfects accumulate across misses")
	for e in model.enemies: e.hp = 0
	model.advance_wave()
	check(model.perfect_progress == 2, "Perfect progress carries into next wave")
	model.record_perfect(true)
	check(model.perfect_progress == 3 and model.chest_tier() == 1 and model.perfect_total == 3, "Third Perfect banks a chest without opening")
	for progress in range(3,10):
		model.perfect_progress = progress
		var tier: int = model.chest_tier()
		var state: int = model.rng.state
		var results: Array = model.open_chest()
		check(results.size() == [0,1,3,5][tier] and model.open_chest() == results, "Tier locks exact reward count and outcomes")
		check(model.perfect_progress == 0 and model.rng.state == state, "Opening clears the bank and preserves combat RNG")
		var before: int = model.reward_history.size()
		check(not model.close_chest(), "Uncollected gifts prevent closure")
		for slot in range(results.size()-1,-1,-1):
			check(not model.claim_reward(slot).is_empty(), "Every slot can be collected in any order")
			check(model.claim_reward(slot).is_empty(), "Repeated pickup cannot duplicate a reward")
		check(model.rewards_collected() and model.reward_history.size() == before+results.size(), "All results claimed exactly once")
		check(model.close_chest() and model.open_chest().is_empty(), "Chest closes only after pickups")
	model.reset_run()
	for i in range(12): model.record_perfect(true)
	check(model.perfect_progress == 9 and model.chest_tier() == 3 and model.perfect_total == 12, "Nine diamonds cap the bank without auto-opening")
	model.reset_run()
	model.open_rewards = [0,3,4,3,4,6,6]
	for slot in range(model.open_rewards.size()): model.claim_reward(slot)
	check(model.rubies == 100 and model.summon_shards == 2 and model.reward_base_damage == 10 and model.reward_damage_multiplier == 1, "Currency and stat rewards have requested values")
	check(model.regular_attack_power() == 20 and model.damage_multiplier() == 2.5, "Rewards affect base and additive multiplier")
	check(model.attack_base(Rules.classify([1,2,3])) == 16, "Damage reward also increases normal attack")
	model.close_chest()
	model.hp = 20
	model.open_rewards = [1,2,5]
	for slot in range(model.open_rewards.size()): model.claim_reward(slot)
	check(model.hp == 20 and model.rubies == 100 and model.reward_base_damage == 10 and model.buffs.values().all(func(v): return v == 0), "Relic, curse and potion remain placeholders")
	model.close_chest()
	model.stage = 9
	check(model.siege_damage(Rules.classify([6,6,6])) == 800, "Rewards cannot amplify city Annihilation")
	check(model.siege_damage(Rules.classify([1,1,1])) == 500, "City execution uses rewarded base and multiplier")
	model.reset_run()
	check(model.rubies == 0 and model.summon_shards == 0 and model.reward_base_damage == 0 and model.reward_damage_multiplier == 0 and model.perfect_total == 0 and model.reward_history.is_empty() and model.chest_tier() == 0 and model.open_rewards.is_empty(), "New run resets all reward state")
	model.reward_weights = [0,0,0,0,0,0,4]
	model.perfect_progress = 9
	check(model.open_chest() == [6,6,6,6,6], "Reward weights support future modifiers and duplicate prizes")
	for slot in range(5): model.claim_reward(slot)
	model.close_chest()
	model.reset_run()

	var roles: Dictionary = {}
	for stage in range(9):
		model.stage = stage
		model._load_wave()
		check(model.enemies.filter(func(e): return not e.elite).size() == Run.WAVE_COUNTS[stage][0] and model.enemies.filter(func(e): return e.elite).size() == Run.WAVE_COUNTS[stage][1], "Exact normal/elite counts for wave %d" % (stage+1))
		for e in model.enemies: roles[e.role] = true
	check(roles.size() == 3, "Wave generation uses all three roles")
	for elite in [false,true]:
		for role in range(3):
			var enemy: Dictionary = Rules.make_enemy(role,1.0,elite)
			check(enemy.shield == (10 if elite else 0), "Every elite starts with ten shield")
			check(enemy.max_hp == ([150,100,75] if elite else [75,50,35])[role] and enemy.damage == ([10.0,10.0,15.0] if elite else [5.0,7.5,10.0])[role], "Role stats match requested multipliers")
	model.enemies = [Rules.make_enemy(0),Rules.make_enemy(1,1,true),Rules.make_enemy(2,1,true)]
	model.stage = 0
	model.hp = 100
	model.phase = "enemy"
	model.enemies[0].hp = 1
	model.enemies[1].hp = 1
	model.enemies[2].hp = 1
	model.enemies[2].intent = {"type":"heal","target":2,"amount":roundi(model.enemies[2].max_hp*0.3)}
	model.enemy_act(2)
	check(model.enemies[2].hp == 24, "Self heal restores 30% max HP rounded to integer")
	model.enemies[0].hp = 0
	model.enemies[1].intent = {"type":"team_heal","target":1,"amount":0}
	model.enemy_act(1)
	check(model.enemies[0].hp == 0 and model.enemies[1].hp == 21 and model.enemies[2].hp == 39, "Team heal restores 20% to living allies including caster")
	model.enemies[0].hp = 75
	model.enemies[2].acted = false
	model.enemies[2].intent = {"type":"empower","target":0,"amount":0}
	model.enemy_act(2)
	check(model.enemies[0].attack_boost and not model.enemies[1].attack_boost and not model.enemies[2].attack_boost, "Elite mage buffs exactly one other enemy")
	model.enemies[0].intent = {"type":"attack","target":-1,"amount":5.0}
	model.enemy_act(0)
	check(model.hp == 92 and not model.enemies[0].attack_boost, "Ally gets 1.5x next attack then consumes buff")
	check(model.enemy_act(0).is_empty() and model.hp == 92, "An enemy still acts only once each round")
	# Exercise generated support choices, not just injected intent execution.
	for role in [1,2]:
		var seen: Dictionary = {}
		model.enemies[role].hp = 1
		for i in range(200):
			var intent: Dictionary = model.choose_intent(role)
			seen[intent.type] = true
			if intent.type == "heal": check(intent.target == role and intent.amount == 23, "Mage chooses 30% self-heal")
			if intent.type == "empower": check(intent.target != role, "Mage never empowers itself")
		check(seen.has("attack") and seen.has("team_heal" if role == 1 else "heal"), "Support actions remain randomized with attacks")

func test_scene(game) -> void:
	root.add_child(game)
	game.muted = true
	game.speed = 30
	game.chest.playback_speed = 30
	for stage in range(9):
		game.model.stage = stage
		game.model._load_wave()
		game.visual_stage = stage
		for i in range(game.model.enemies.size()):
			check(game.ARENA.has_point(game._enemy_feet(i)), "All enemy positions fit battle area")
	game.model.stage = 9
	game.model._load_wave()
	game.model.begin_round()
	game.model.perfect_progress = 9
	game.view_phase = "ready"
	game._handle_click(game._diamond_center(8 if game.model.chest_tier() == 3 else 5 if game.model.chest_tier() == 2 else 2))
	var city_clock: float = game.model.volley_clock
	game._handle_click(game.DICE_CENTER)
	game._handle_click(game.GUIDE_RECT.get_center())
	if game is Portrait:
		game.model.buffs[2] = 3
		game._handle_click(game._status_rect(2).get_center())
		check(game.selected_status == -1, "Treasure overlay blocks status taps")
	await create_timer(0.1).timeout
	check(game.view_phase == "reward" and not game.guide and game.model.volley_clock == city_clock and game.model.pending.is_empty(), "Chest blocks combat and pauses siege")
	check(not game.chest.visible, "Brief pause precedes treasure reveal")
	await create_timer(0.32).timeout
	check(not game.fx.flashes.is_empty() and not game.chest.visible, "Flash precedes chest")
	await create_timer(0.6).timeout
	check(not game.chest.active and game.view_phase == "reward" and game.model.reward_history.is_empty(), "Landed rewards wait for manual pickup")
	for i in range(5):
		check(Rect2(Vector2.ZERO,game.fx.canvas_size).encloses(game.chest.reel_rect(i)), "All five reward hit areas fit layout")
		game._handle_click(game.chest.reel_rect(i).get_center())
		game._handle_click(game.chest.reel_rect(i).get_center())
		check(game.model.reward_history.size() == i+1, "Reward applies exactly once on tap")
	await create_timer(1.8).timeout
	check(game.view_phase == "ready" and not game.chest.visible and game.model.open_rewards.is_empty(), "Picking up every gift resumes combat")
	game._restart()
	game.model.record_perfect(true)
	game.model.record_perfect(true)
	game.debug_perfect = true
	game.debug_choice = 12
	game._start_charge()
	game._release_charge()
	game._handle_click(game._diamond_center(8 if game.model.chest_tier() == 3 else 5 if game.model.chest_tier() == 2 else 2))
	check(game.throw_perfect and game.throw_power == 1 and not game.debug_perfect and game.view_phase != "reward", "Earning throw cannot be interrupted to claim")
	var deadline: int = Time.get_ticks_msec()+12000
	while (game.model.stage == 0 or game.view_phase != "ready") and Time.get_ticks_msec() < deadline:
		Driver.cast_pending(game)
		await process_frame
	check(game.model.stage == 1 and game.model.perfect_progress == 3 and game.model.reward_history.is_empty(), "Third Perfect finishes skill and advances with unclaimed bank")
	game._handle_click(game._diamond_center(8 if game.model.chest_tier() == 3 else 5 if game.model.chest_tier() == 2 else 2))
	check(game.view_phase == "reward", "Bank is claimable after earning action")
	game._restart()
	await create_timer(0.1).timeout
	check(game.view_phase == "ready" and not game.chest.visible and game.model.reward_history.is_empty(), "Restart cancels pending animation and rewards")
	game.model.perfect_progress = 6
	game.home_enabled = true
	game.model.hp = 0
	game._check_over()
	check(not game._home_rect().intersects(game._chest_milestone_rect(2)) and not game.REPLAY_RECT.intersects(game._chest_milestone_rect(2)), "Ending controls do not cover the claim diamonds")
	game._handle_click(game._diamond_center(8 if game.model.chest_tier() == 3 else 5 if game.model.chest_tier() == 2 else 2))
	check(game.view_phase == "reward" and game.model.open_rewards.size() == 3, "Bank remains claimable on ending screen")
	game._restart()

	game.queue_free()
	await process_frame

func run() -> void:
	test_model()
	await test_scene(Battle.new())
	await test_scene(Portrait.new())
	print("Treasure and elites: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
