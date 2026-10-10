extends SceneTree
const Run = preload("res://scripts/run_rules.gd")
const Rules = preload("res://scripts/battle_rules.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func clear_wave(game) -> void:
	game.begin_round()
	game.set_test_roll([6, 6, 6])
	game.apply_player(0)
	check(game.advance_wave(), "Cleared wave can advance")

func city():
	var game = Run.new(13)
	for i in range(Run.WAVE_COUNTS.size()): clear_wave(game)
	return game

func tick(game, seconds: float, step: float = 0.05) -> void:
	for i in range(roundi(seconds / step)): game.tick_city(step)

func force(game, values: Array) -> void:
	game.begin_round()
	game.set_test_roll(values)
	game.apply_player(0)

func _initialize() -> void:
	var game = Run.new(13)
	check(game.enemies.size() == 1 and game.max_hp == 100, "Run starts 1v1")
	check(not game.advance_wave(), "Living enemies prevent growth")
	for wave in range(9):
		check(game.enemies.size() == [1, 3, 1, 5, 3, 5, 7, 4, 10][wave], "Wave size progression")
		game.begin_round()
		game.statuses[2].count = 1
		game.statuses[33].count = 3
		for kind in [Rules.Kind.NORMAL]:
			var result: MultiHitSkill = Rules.classify([4, 5, 6] if kind == Rules.Kind.NORMAL else [1, 1, 1])
			for index in game.living():
				check(game.preview(result, index)[0].damage <= game.damage_cap(kind, index), "Growth and buffs respect individual caps")
		game.hp = 40
		game.shield = 7
		for e in game.enemies: e.hp = 0
		game.statuses[3].count = 2
		check(game.advance_wave(), "Growth once per clear")
		check(game.hp == 95 and game.max_hp == 130 + wave * 30, "Feeding increases capacity and heals 55")
		check(game.power == [1.5,3.0,5.625,6.75,7.875,9.0,10.125,11.25,12.375][wave], "Later growth includes cumulative 1.5x boosts")
		check(game.statuses[3].count == 2 and game.shield == 7, "Buffs and shield carry between areas")
		check(not game.advance_wave(), "Repeated advance cannot grow again")
	check(game.is_city() and game.enemies.is_empty(), "Final battle uses city rather than squad")
	var boosted = Run.new(13)
	for wave in range(9):
		var normal: MultiHitSkill = Rules.classify([4,5,6])
		check(boosted.preview(normal,0)[0].damage == mini(floori(22.5 * boosted.power), boosted.damage_cap(Rules.Kind.NORMAL,0)), "Existing normal stage caps remain")
		var special: MultiHitSkill = Rules.classify([4,4,4])
		check(boosted.preview(special,0)[0].damage == floori(30.0 * boosted.power), "Skills now ignore former stage caps")
		clear_wave(boosted)
	check(boosted.siege_damage(Rules.classify([1,2,3])) == floori(6 * 1.5 * boosted.power * 2), "Normal city damage follows extended growth")
	for values in [[1,1,1],[4,4,4],[5,5,5]]:
		var base: float = 50 if values[0] == 1 else 20 if values[0] == 4 else 10
		check(boosted.siege_damage(Rules.classify(values)) == floori(base * 1.5 * boosted.power * 2), "City skill damage uses fixed regular power")
	game = city()
	game.hp = 100
	force(game, [2,2,4])
	game.begin_round()
	check(game.hp == 105 and game.statuses[2].count == 4, "City regen heals on next roll start and retains its count until the roll ends")
	game.begin_round()
	check(game.hp == 105, "Duplicate start cannot repeat regen")
	game.set_test_roll([6,6,2])
	game.apply_player()
	tick(game, 2)
	check(game.hp == 105 and game.statuses[6].count == 1 and is_equal_approx(game.city_immunity_seconds(),2), "City immunity loses one stack after two seconds")
	force(game, [3,3,1])
	check(game.hp == 110 and game.statuses[6].count == 1, "Extra throws do not shorten timed immunity")
	tick(game, 1.95)
	check(game.hp == 110 and game.statuses[6].count == 1,"Immunity protects until its final fraction of a second")
	var before_hp: int = game.hp
	tick(game, 0.1)
	check(game.hp < before_hp and game.statuses[6].count == 0, "City immunity expires at four seconds even without another roll")
	game = city()
	game.hp = 1
	game.troops = 6
	force(game, [2,2,2])
	check(game.hp == game.max_hp and game.troops == 6 and game.city_hp == Run.CITY_MAX_HP, "Full heal does not attack city or troops")
	game = city()
	var other = city()
	tick(game, 8.0, 0.05)
	tick(other, 8.0, 0.1)
	check(game.hp == other.hp and game.troops == other.troops, "City attack cadence is frame-rate independent")
	check(game.hp < game.max_hp and game.troops == 6, "City troops and ranged volleys keep attacking without player input")
	game.statuses[2].count = 1
	game.statuses[33].count = 3
	force(game, [6, 6, 6])
	check(game.city_hp == 9200 and game.outcome().is_empty() and game.troops == 0, "Ultimate clears troops and keeps its 800 base damage against the 10000 HP city")
	force(game, [6, 6, 6])
	check(game.city_hp == 8400 and game.outcome().is_empty(), "Second ultimate still deals 800")
	for i in range(11): force(game, [6, 6, 6])
	check(game.city_hp == 0 and game.outcome() == "victory", "Thirteen unboosted ultimates destroy the larger city")
	var final_hp: int = game.hp
	tick(game, 5.0)
	check(game.hp == final_hp, "City damage stops after victory")
	game.reset_run()
	check(game.stage == 0 and game.hp == 100 and game.power == 1 and game.troops == 0 and game.city_hp == Run.CITY_MAX_HP, "Restart clears all progression")
	game = city()
	game.city_hp = 217
	force(game, [6, 6, 6])
	check(game.city_hp == 0, "City ultimate clamps damage to remaining HP without going negative")
	game = Run.new(19)
	clear_wave(game)
	clear_wave(game)
	clear_wave(game)
	game.enemies[1].hp = 0
	game.enemies[3].hp = 0
	var selected: Dictionary = {}
	for i in range(100):
		game.phase = "roll"
		game.set_test_roll([1,2,3])
		var target: int = game.player_target()
		check(target in [0,2,4], "Automatic target never chooses dead foes")
		selected[target] = true
		var rng_state: int = game.rng.state
		check(game.player_target() == target and game.rng.state == rng_state, "Target stays locked without another random sample")
	check(selected.size() == 3, "Random selection can reach every living foe")
	var hp_before: Array = game.enemies.map(func(e): return e.hp)
	var locked: int = game.player_target()
	game.apply_player()
	for i in [0,2,4]:
		check((game.enemies[i].hp < hp_before[i]) == (i == locked), "Automatic normal damages exactly the locked living target")
	game.phase = "roll"
	game.set_test_roll([2,2,1])
	var pair_rng: int = game.rng.state
	check(game.player_target() == -1 and game.rng.state == pair_rng, "Pairs do not choose a foe or consume target RNG")
	var wins := 0
	var total_rolls := 0
	var defeats := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for seed_value in range(100):
		game = Run.new(seed_value)
		for turn in range(200):
			game.begin_round()
			if game.phase == "frozen":
				for hit in range(3): game.break_ice()
			else:
				game.roll()
				game.apply_player()
			if game.outcome() == "wave_clear":
				game.advance_wave()
			elif game.is_city():
				game.end_round()
				tick(game, 1.5)
			else:
				for i in range(game.enemies.size()): game.enemy_act(i)
				game.end_round()
			if game.outcome() in ["victory", "defeat"]: break
		check(game.outcome() in ["victory", "defeat"], "Seeded full run completes")
		wins += int(game.outcome() == "victory")
		if game.outcome() == "defeat": defeats[game.stage] += 1
		total_rolls += game.round_number
	print("Run balance: %d/100 wins; %.1f mean rolls (automatic random targets; 1.5 seconds per city roll)" % [wins, total_rolls / 100.0])
	print("Defeats by stage: ", defeats)
	print("Run tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
