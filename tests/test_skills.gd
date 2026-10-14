extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
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
	_test_normalized_base_damage()
	_test_damage_captions()
	_test_turn_end_buffs()
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
	game.statuses[3].count = 2
	game.statuses[33].count = 1
	game.set_test_roll([5,5,5])
	for remaining in range(5,-1,-1):
		var hits: Array = game.apply_player_step()
		check(hits[0].amount == 52, "All six hits add both active attack bonuses")
		check(game.statuses[33].count == (1 if remaining > 0 else 0), "Boost covers every hit and spends one charge after the final impact")
	for i in game.living(): game.enemy_act(i)
	game.end_round()
	check(game.attack_multiplier() == 1.5 and game.statuses[3].count == 1, "Weaker boon resumes with remaining turn")
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
	check(game.outcome().is_empty() and game.pending.uses_left() == 3, "Combo retains its remaining uses after all foes die")
	var follow_through: Array = game.apply_player().filter(func(e): return e.type == "damage")
	check(follow_through.size() == 3 and follow_through.all(func(e): return e.corpse_hit and e.amount == 0), "Remaining strikes hit corpses without extra HP loss")
	check(game.outcome() == "victory" and game.pending.is_empty(), "Victory follows the final hit")
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
	game.statuses[6].count = 1
	game.set_test_roll([6,6,4])
	game.apply_player()
	check(game.statuses[6].count == 5, "Invincibility adds the new duration to the remaining protection")
	var city = Run.new(42)
	city.stage = Waves.CITY_STAGE
	city.power = 6.75
	city.max_hp = 220
	city.hp = 100
	city._load_wave()
	city.begin_round()
	city.troops = 6
	city.set_test_roll([1,1,1])
	city.apply_player()
	check(city.city_hp == Run.CITY_MAX_HP-506, "City 111 deals floor(15 x 5 x 6.75)")
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
	check(city.city_hp == before - 333 and city.troops == 3, "City double five delivers three distinct 111-damage hits")
	city.begin_round()
	city.set_test_roll([2,2,2])
	city.apply_player()
	check(city.hp == 220, "Triple heal uses grown maximum health")
	city.begin_round()
	city.set_test_roll([5,5,5])
	city.apply_player_step()
	city.reset_run()
	check(city.pending.is_empty() and city.apply_player_step().is_empty(), "Restart discards an unfinished combo")
	check(city.status_counts().values().all(func(v): return v == 0), "Restart clears every new boon")
	print("Skill rework: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_normalized_base_damage() -> void:
	var game = fresh()
	check(game.damage_multiplier() == 1.0, "A fresh battle starts at DMG x 1.0")
	for a in range(1,7):
		for b in range(a+1,7):
			for c in range(b+1,7):
				var normal = Rules.classify([a,b,c])
				check(game.attack_damage(normal,0) == floori((a+b+c)*1.5), "Normal x1 preserves the previous unbuffed hit across all distinct rolls")
	game.reward_damage_multiplier = 1.0
	for spare in range(2,7):
		var heavy = Rules.classify([1,1,spare])
		check(game.attack_damage(heavy,0) == 45+3*spare, "Heavy x2 multiplies the fractional base before rounding, yielding 51 through 63")

func _test_damage_captions() -> void:
	var game = Rules.new(42)
	for example in [
		[[1,1,6], "31 + 0 (x1)"], [[4,4,1], "11 + 0 (x1)"],
		[[5,5,1], "16 + 0 (x3)"], [[5,5,5], "15 + 0 (x6)"],
		[[4,4,4], "30 + 0 (x1)"], [[1,2,3], "9 + 0 (x1)"]]:
		check(game.damage_caption(Rules.classify(example[0]),0) == example[1], "Caption gives integer base plus modifier and actual hit count")
	var normal: MultiHitSkill = Rules.classify([4,5,6])
	check(game.damage_caption(normal,2) == "22 + (-11) (x1)", "Normal target cap can reduce the displayed damage below its base")
	check(game.damage_caption(normal) == "22 + (-11 to 0) (x1)", "Unchosen targets show the truthful cap range")
	for values in [[1,1,1],[6,6,6],[2,2,3],[3,3,4],[6,6,4],[2,2,2],[3,3,3]]:
		check(game.damage_caption(Rules.classify(values)).is_empty(), "Instant kills and support never show a damage number")
	for stats in [[1.0,0,0,0],[5.625,5,0.5,3],[12.375,10,1.0,33]]:
		for values in [[1,2,3],[4,5,6],[1,1,2],[4,4,5],[5,5,4],[4,4,4],[5,5,5]]:
			game = fresh()
			game.power = stats[0]
			game.reward_base_damage = stats[1]
			game.reward_damage_multiplier = stats[2]
			if stats[3] > 0: game.statuses[stats[3]].count = 2
			game.set_test_roll(values)
			var rng: int = game.rng.state
			var pending: MultiHitSkill = game.pending.duplicate(true)
			var buffs: Dictionary = game.status_counts([2,3,33,6])
			var caption: String = game.damage_caption(game.pending,0)
			var terms: PackedStringArray = caption.split(" ")
			var predicted: int = int(terms[0])+int(terms[2].trim_prefix("(").trim_suffix(")"))
			check(game.rng.state == rng and game.pending.same_as(pending) and game.status_counts([2,3,33,6]) == buffs, "Preview leaves RNG, pending skill and buffs untouched")
			var events: Array = game.apply_player_step(0)
			check(events[0].amount == mini(500,predicted), "Displayed per-hit sum matches actual damage after rewards, growth, buffs and caps")
	var city := Run.new(42)
	city.stage = Waves.CITY_STAGE
	city.power = 12.375
	city._load_wave()
	check(city.damage_caption(Rules.classify([1,1,1])) == "75 + 853 (x1)", "City 111 has scaled numeric damage instead of instant-kill omission")
	check(city.damage_caption(Rules.classify([6,6,6])) == "2000 + 22750 (x1)", "City Annihilation displays the full multiplied hit")
	city.reward_base_damage = 5
	city.reward_damage_multiplier = 0.5
	city.statuses[33].count = 3
	check(city.damage_caption(Rules.classify([5,5,5])) == "22 + 312 (x6)", "City preview includes all current bonuses and six hits")
	city.city_hp = 100
	check(city.damage_caption(Rules.classify([6,6,6])) == "2000 + 27750 (x1)", "Low city health never shrinks the damage preview")

func _test_turn_end_buffs() -> void:
	var game = fresh()
	game.hp = 50
	game.set_status_counts({2:1,3:2,33:1,6:1})
	game.phase = "round_end"
	game.begin_round()
	check(game.hp == 55 and game.statuses[2].count == 1, "Regeneration heals at start without decrementing its badge")
	game.set_test_roll([1,2,3])
	game.apply_player(0)
	check(game.status_counts([2,3,33,6]) == {2:1,3:1,33:0,6:1}, "Only attack charges decrease after the player attack")
	for i in game.living():
		game.enemies[i].intent = {"type":"attack","target":-1,"amount":5}
		game.enemy_act(i)
		check(game.hp == 55 and game.statuses[6].count == 1, "Last immunity turn protects every enemy impact")
		if i < 2:
			game.end_round()
			check(game.status_counts([2,3,33,6]) == {2:1,3:1,33:0,6:1}, "An incomplete enemy phase cannot tick timed buffs")
	game.end_round()
	check(game.status_counts([2,3,33,6]) == {2:0,3:1,33:0,6:0}, "All used durations decrease together after the final enemy")
	game.end_round()
	check(game.statuses[3].count == 1, "Duplicate turn completion cannot decrement twice")
	game.begin_round()
	check(game.hp == 55 and game.attack_multiplier() == 1.5, "Expired regeneration stops and weaker attack boon resumes")
	game.set_test_roll([2,2,1])
	game.apply_player()
	for i in game.living(): game.enemy_act(i)
	game.end_round()
	check(game.statuses[2].count == 0 and game.statuses[3].count == 1, "Freeze grants no regeneration and preserves attack charges")
	game.begin_round()
	var healed_hp: int = game.hp
	game.set_test_roll([2,2,3])
	game.apply_player()
	for i in game.living(): game.enemy_act(i)
	game.end_round()
	check(game.statuses[2].count == 0 and game.statuses[3].count == 1, "Repeated freeze does not spend attack charges")
	check(game.hp <= healed_hp, "Refresh itself does not heal twice")
	var run := Run.new(5)
	run.begin_round()
	run.statuses[3].count = 2
	run.set_test_roll([1,1,1])
	run.apply_player(0)
	check(run.statuses[3].count == 1, "A normal wave-ending action closes the turn when there are no enemies left")
	run.advance_wave()
	check(run.statuses[3].count == 1 and run.buff_ticks.is_empty(), "Wave transition cannot repeat a completed countdown")
