extends SceneTree
## Throw reactions fire once; corrections still honor tarot faces, budgets and combo preservation.
const Run = preload("res://scripts/progression/run_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(881)
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	m.begin_round()
	return m
func settle(m) -> void:
	for step in range(100):
		if m.perfect_relic_ready: m.resolve_roll_relic_step()
		elif m.phase == "roll_attacks": m.resolve_roll_attack_step()
		elif m.start_roll_chip_casts(): pass
		elif m.phase == "player" and m.pending.cast_source != "manual": m.apply_player()
		else: return
	check(false,"Automatic relic queues must terminate")
func _initialize() -> void:
	for id in ["worn_bow","magic_slingshot","enchanted_missile","pet_ghost","pet_dragon","black_chip","blue_chip"]:
		var m = fresh(); m.acquire_relic(id)
		m.roll_pool(true,[1,2,3,4,5,6])
		check(not m.roll_relic_actions.is_empty() or not m.roll_chip_casts.is_empty(),"Initial throw queues "+id)
		settle(m)
		var hp: Array = m.enemies.map(func(e): return e.hp)
		var combo: int = m.perfect_combo
		var activations: Array = []
		m.relic_activated.connect(func(item): activations.append(item))
		m.reroll_die(0,[2]); settle(m)
		check(m.enemies.map(func(e): return e.hp) == hp and activations.is_empty(),"Single-die correction cannot retrigger "+id)
		m.reroll_dice([0,1,2],[4,4,4]); settle(m)
		check(m.enemies.map(func(e): return e.hp) == hp and activations.is_empty(),"Batch correction cannot retrigger "+id)
		m.roll_pool(false,[1,2,3,4,5,6],true); settle(m)
		check(m.enemies.map(func(e): return e.hp) == hp and activations.is_empty() and m.perfect_combo == combo,"Free full-pool reroll cannot retrigger "+id)
		m.end_dice_turn(); m.apply_player()
		for e in m.enemies: e.acted = true
		m.end_round(); m.begin_round(); settle(m); m.roll_pool(false,[1,2,3,4,5,6])
		check(not m.roll_relic_actions.is_empty() or not m.roll_chip_casts.is_empty(),"Next turn re-enables "+id)
	var m = fresh(); m.acquire_relic("lucky_die"); m.relics.items[0].throws = 9
	m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
	check(m.relics.items[0].throws == 10,"Initial throw advances the lucky counter")
	m.reroll_die(0,[6]); m.roll_pool(false,[1,1,1,1,1,1],true)
	check(m.relics.items[0].throws == 10 and m.dice_turn.values == [1,1,1,1,1,1],"Rerolls neither advance nor consume a ready guarantee")
	m = fresh(); m.acquire_relic("red_chip"); m.roll_pool(false,[1,1,3,3,5,5]); settle(m)
	check(m.relics.items[0].no_straight,"Initial throw can activate Red Chip")
	m.reroll_die(0,[1]); check(not m.relics.items[0].no_straight,"Reroll expires but cannot reactivate Red Chip")
	m = fresh(); m.acquire_relic("cursed_die"); m.roll_pool(false,[6,6,1,2,3,4]); settle(m)
	m.reroll_die(2,[6]); check(m.dice_turn.values == [6,6,6,2,3,4],"Correction does not activate Cursed Die transformation")
	print("Opening throw relics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
