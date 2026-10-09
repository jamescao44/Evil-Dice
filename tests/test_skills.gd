extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/run_rules.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func fresh():
	var game = Rules.new(42)
	game.begin_round()
	for e in game.enemies:
		e.hp = 500
		e.max_hp = 500
	return game

func _initialize() -> void:
	for face in [1,4,5]:
		for spare in range(1,7):
			if spare == face: continue
			var game = fresh()
			game.set_test_roll([face,spare,face])
			var expected: int = floori(({1:15.0,4:20.0/3.0,5:10.0}[face] + spare) * 1.5)
			var events: Array = game.apply_player(0)
			var damage: Array = events.filter(func(e): return e.type == "damage")
			check(damage.size() == (1 if face == 1 else 3), "Double produces correct target/hit count")
			for hit in damage: check(hit.amount == expected, "Only the spare die adds to double attack base")
			if face == 4: check(game.enemies.all(func(e): return e.hp == 500 - expected), "Double four hits every foe once")
	for face in [4,5]:
		var game = fresh()
		game.set_test_roll([face,face,face])
		var hits: Array = game.apply_player(0).filter(func(e): return e.type == "damage")
		check(hits.size() == (3 if face == 4 else 6), "Triple produces correct hit count")
		for hit in hits: check(hit.amount == (30 if face == 4 else 15), "Triple attack uses fixed regular power, not dice sum")
	var game = fresh()
	game.buffs[3] = 2
	game.buffs[33] = 1
	game.set_test_roll([5,5,5])
	for remaining in range(5,-1,-1):
		var hits: Array = game.apply_player_step()
		check(hits[0].amount == 45, "All six hits keep the same 3x boost")
		check(game.buffs[33] == (1 if remaining > 0 else 0), "Boost expires after the full combo, not the first hit")
	check(game.attack_multiplier() == 1.5 and game.buffs[3] == 1, "Weaker boon resumes with remaining turn")
	check(game.apply_player_step().is_empty(), "Seventh hit is rejected")
	game = fresh()
	for enemy in game.enemies: enemy.hp = 1
	game.set_test_roll([5,5,5])
	var killed: Dictionary = {}
	for i in range(3):
		var target: int = game.player_target()
		var state: int = game.rng.state
		check(game.player_target() == target and game.rng.state == state, "Target locks once for each strike")
		check(not killed.has(target), "Consecutive hits never retarget a corpse")
		killed[target] = true
		game.apply_player_step(target)
	check(game.outcome() == "victory" and game.pending.is_empty(), "Combo ends early when all foes die")
	game = fresh()
	game.enemies[0].shield = 20
	game.set_test_roll([5,5,5])
	check(game.preview(game.pending,0)[0].hp_loss == 0, "Preview honors shield break protection")
	var before_hp: int = game.enemies[0].hp
	game.apply_player_step(0)
	check(game.enemies[0].hp == before_hp and game.enemies[0].shield == 5, "Shield absorbs first hit")
	game.apply_player_step(0)
	check(game.enemies[0].hp == before_hp and game.enemies[0].shield == 0, "Breaking hit cannot spill into HP")
	game.apply_player_step(0)
	check(game.enemies[0].hp == before_hp-15, "Next consecutive hit damages health after shield break")
	game = fresh()
	game.buffs[6] = 1
	game.set_test_roll([6,6,4])
	game.apply_player()
	check(game.buffs[6] == 4, "Invincibility refreshes duration rather than stacking")
	var city = Run.new(42)
	city.stage = 9
	city.power = 6.75
	city.max_hp = 220
	city.hp = 100
	city._load_wave()
	city.begin_round()
	city.troops = 6
	city.set_test_roll([1,1,1])
	city.apply_player()
	check(city.city_hp == 1388, "City 111 deals floor(10 x 5 x 1.5 x 6.75 x 2)")
	check(city.troops == 6, "City 111 is a city strike, not an all-troop sweep")
	city.begin_round()
	city.set_test_roll([4,4,1])
	city.apply_player()
	check(city.troops == 0, "Double AoE clears every troop as well as striking city")
	city.begin_round()
	city.troops = 6
	city.set_test_roll([5,5,1])
	var before: int = city.city_hp
	city.apply_player()
	check(city.city_hp == before - 666 and city.troops == 3, "City double five delivers three distinct 222-damage hits")
	city.begin_round()
	city.set_test_roll([2,2,2])
	city.apply_player()
	check(city.hp == 220, "Triple heal uses grown maximum health")
	city.begin_round()
	city.set_test_roll([5,5,5])
	city.apply_player_step()
	city.reset_run()
	check(city.pending.is_empty() and city.apply_player_step().is_empty(), "Restart discards an unfinished combo")
	check(city.buffs.values().all(func(v): return v == 0), "Restart clears every new boon")
	print("Skill rework: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
