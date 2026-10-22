extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	var m = Run.new(843)
	m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	m.begin_round()
	m.roll_pool(false,[1,2,3,4,5,6])
	m.dice_turn.selected = [0,1,2]
	m.form_selected_skill()
	m.cancel_formed_skill()
	check(m.character_passive.charge == 0,"Cancelling never charges")
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	check(m.begin_player_cast(0),"First Fireball begins")
	check(m.character_passive.charge == 1 and m.pending.use_count() == 1,"First cast fills one circle")
	m.apply_player_step(0)
	m.dice_turn.selected = [3,4,5]; m.form_selected_skill()
	check(m.begin_player_cast(0),"Second Fireball begins")
	check(m.character_passive.displayed_charge(m.pending) == 2 and m.pending.use_count() == 1,"Second cast fills two circles without triggering")
	m.apply_player_step(0)
	m.roll_pool(false,[1,2,3,4,5,6])
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	check(m.begin_player_cast(0),"Third Fireball begins")
	check(m.character_passive.displayed_charge(m.pending) == 3 and m.pending.use_count() == 3,"Third cast fills three and queues two echoes")
	var rolled: Array = m.dice_turn.values.duplicate()
	var trigger_events: Array = m.apply_player_step(0)
	check(trigger_events.filter(func(e): return e.type == "bonus_skill").size() == 1,"Counter consumption emits one feedback event")
	check(m.pending.random_target_per_use() and m.character_passive.displayed_charge(m.pending) == 0,"Echoes randomly target after the original impact and empty the meter")
	var targets: Array = []
	for i in range(2):
		var target: int = m.player_target()
		check(target in m.attack_targets(),"Echo chooses a legal living target")
		var events: Array = m.apply_player_step(target)
		check(events.any(func(e): return e.type == "damage"),"Each echo hits")
		check(not events.any(func(e): return e.type == "bonus_skill"),"Echoes do not repeat the consumption flash")
		targets.append(target)
	check(m.character_passive.charge == 0 and m.phase != "executing","Echoes cannot recursively fill the counter")
	check(m.dice_turn.values == rolled or m.bonus_turn_count == 1,"Echoes never reroll dice")
	var passive = m.FlamelingsPassive.new()
	var slash = Patterns.classify([1,2,3,4]); slash.begin_cast(); passive.on_cast(slash)
	check(passive.charge == 0 and slash.use_count() == 1,"Other straights do not charge")
	for i in range(3):
		var fire = Patterns.classify([1,2,3]); fire.begin_cast({"test":3}); passive.on_cast(fire)
		check(fire.use_count() == (3 if i < 2 else 5),"Multi-hit cast charges once and gains only two echoes")
	m.character_passive.charge = 1
	m.reset_run()
	check(m.character_passive.charge == 0,"New runs clear the passive")
	print("Fireball passive: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
