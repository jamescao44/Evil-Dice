extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_classification()
	_test_caps()
	_test_independent_rolls()
	_test_buffs()
	_test_human_phase()
	_test_rounds_and_rng()
	print("Battle checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh():
	var game = Rules.new(12)
	game.begin_round()
	return game

func _test_classification() -> void:
	var counts := [0, 0, 0, 0]
	for a in range(1, 7):
		for b in range(1, 7):
			for c in range(1, 7):
				var result: Dictionary = Rules.classify([a, b, c])
				counts[result.kind] += 1
				check(result.sum == a + b + c, "Sum is exact")
				var permutation: Dictionary = Rules.classify([c, a, b])
				check(result.kind == permutation.kind and result.face == permutation.face, "Order independent")
	check(counts == [120, 90, 5, 1], "All 216 outcomes partition correctly")
	check(Rules.classify([6, 6, 6]).kind == Rules.Kind.ULTIMATE, "666 is ultimate")
	check(Rules.classify([1, 1, 1]).kind == Rules.Kind.SPECIAL, "111 is not a pair")
	for invalid in [[], [1, 2], [0, 1, 2], [1, 2, 7], [1.5, 2, 3], [1, 2, 3, 4]]:
		check(Rules.classify(invalid).is_empty(), "Reject invalid dice")

func _test_caps() -> void:
	var game = fresh()
	game.set_test_roll([4, 5, 6])
	check(game.preview(game.pending, 0)[0].damage == 22, "Normal uses dice power below the one-third cap")
	game.apply_player(0)
	check(game.enemies[0].hp == 53, "Normal hit reduces health")
	for values in [[1,1,6], [4,4,6], [5,5,6], [4,4,4], [5,5,5]]:
		game = fresh()
		game.set_test_roll(values)
		check(game.preview(game.pending, 0)[0].damage > 10, "New skills bypass normal caps")
	game = fresh()
	game.enemies[0].hp = 999
	game.enemies[0].max_hp = 999
	game.enemies[0].shield = 20
	game.set_test_roll([1,1,1])
	game.apply_player(0)
	check(game.enemies[0].hp == 0 and game.enemies[1].hp == 50, "111 executes only one foe through shields")
	game = fresh()
	for enemy in game.enemies:
		enemy.hp = 999
		enemy.max_hp = 999
		enemy.shield = 20
	game.set_test_roll([6,6,6])
	game.apply_player()
	check(game.outcome() == "victory", "Annihilation clears every foe through shields")

func _test_buffs() -> void:
	for spare in range(1, 7):
		for face in [2,3,6]:
			if spare == face: continue
			var game = fresh()
			game.set_test_roll([face, spare, face])
			game.apply_player()
			check(game.buffs[face] == spare and game.enemies[0].hp == 75, "Spare die sets boon duration, with no attack")
	var game = fresh()
	game.hp = 40
	game.set_test_roll([2,2,3])
	game.apply_player()
	check(game.hp == 40, "Regen does not heal on granting turn")
	for expected in [45,50,55,55]:
		game.phase = "round_end"
		game.begin_round()
		check(game.hp == expected, "Regen heals 5 for exactly three starts")
	game.phase = "roll"
	game.set_test_roll([2,2,2])
	game.apply_player()
	check(game.hp == game.max_hp, "222 restores full health without attacking")
	game = fresh()
	game.set_test_roll([3,3,2])
	game.apply_player()
	check(game.buffs[3] == 2 and game.attack_multiplier() == 1.5, "Pair attack boon starts with all turns available")
	game.phase = "roll"
	game.set_test_roll([3,3,3])
	game.apply_player()
	check(game.buffs[33] == 3 and game.attack_multiplier() == 3.0, "Triple boost overrides weaker boon without multiplying it")
	for remaining in [2,1,0]:
		game.phase = "roll"
		game.set_test_roll([2,2,2])
		game.apply_player()
		check(game.buffs[33] == remaining, "Boost durations count turns, including support turns")
	check(game.attack_multiplier() == 1.0, "Power returns to normal after expiration")

func _test_human_phase() -> void:
	var game = fresh()
	game.set_test_roll([6,6,2])
	game.apply_player()
	for turn in range(3):
		for i in range(3):
			game.enemies[i].intent = {"type":"attack", "target":-1, "amount":3}
			game.enemy_act(i)
		check(game.hp == (100 if turn < 2 else 91), "Invincibility protects exactly two complete enemy phases")
		game.enemy_act(0)
		check(game.hp == (100 if turn < 2 else 91), "Enemy cannot act twice")
		game.end_round()
		game.begin_round()
		game.set_test_roll([3,3,1])
		game.apply_player()
	game = fresh()
	game.enemies[0].hp = 1
	game.enemies[2].intent = {"type":"heal", "target":0, "amount":6}
	game.set_test_roll([1,2,3])
	game.apply_player(0)
	game.enemy_act(2)
	check(game.enemies[0].hp == 0 and game.enemies[2].heals == 0, "Dead heal target is not resurrected")
	var before: int = game.enemies[1].hp
	check(game.apply_player().is_empty() and game.enemies[1].hp == before, "Duplicate action cannot damage twice")
	check(game.roll().is_empty(), "No rolling during enemy phase")

func _test_rounds_and_rng() -> void:
	var a = fresh()
	var b = fresh()
	check(a.roll() == b.roll(), "Seeded dice are deterministic")
	var victories: int = 0
	var total_rounds: int = 0
	for seed_value in range(200):
		var game = Rules.new(seed_value)
		for turn in range(150):
			game.begin_round()
			game.roll()
			var living: Array = game.living()
			var target: int = 2 if 2 in living else living[0]
			game.apply_player(target)
			if not game.outcome().is_empty():
				break
			for i in range(3):
				game.enemy_act(i)
			game.end_round()
			if not game.outcome().is_empty():
				break
		check(not game.outcome().is_empty(), "Battle finishes without getting stuck")
		victories += 1 if game.outcome() == "victory" else 0
		total_rounds += game.round_number
		game.reset()
		check(game.hp == Rules.MAX_HP and game.round_number == 0 and game.shield == 0 and game.living().size() == 3, "Restart resets battle")
	print("Balance sample (200 fixed seeds, mage first): %d wins; %.1f mean rounds" % [victories, total_rounds / 200.0])

func _test_independent_rolls() -> void:
	var longest_match_drought: int = 0
	var longest_triple_drought: int = 0
	for seed_value in range(80):
		var game = Rules.new(seed_value)
		var match_drought: int = 0
		var triple_drought: int = 0
		for turn in range(100):
			game.phase = "roll"
			var fresh_history = Rules.new(seed_value)
			fresh_history.rng.state = game.rng.state
			fresh_history.phase = "roll"
			var expected: Array = fresh_history.roll().dice
			var result: Dictionary = game.roll()
			check(result.dice == expected, "Weighted odds do not depend on previous roll history")
			match_drought = match_drought + 1 if result.kind == Rules.Kind.NORMAL else 0
			triple_drought = triple_drought + 1 if result.kind < Rules.Kind.SPECIAL else 0
			longest_match_drought = maxi(longest_match_drought, match_drought)
			longest_triple_drought = maxi(longest_triple_drought, triple_drought)
			var state: int = game.rng.state
			check(game.roll().is_empty() and game.rng.state == state, "Rejected input cannot draw another outcome")
	check(longest_match_drought >= 3 and longest_triple_drought >= 6, "Neither former pity guarantee remains")
