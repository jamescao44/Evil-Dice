extends SceneTree
## Tarot dice changes reuse matching attacks without spending a turn or rerunning throw relics.
const Run = preload("res://scripts/progression/run_rules.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(11010)
	m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	m.begin_round()
	return m

func settle(m) -> Array:
	var events: Array = []
	for step in range(100):
		if m.phase == "roll_attacks": events.append_array(m.resolve_roll_attack_step())
		elif m.perfect_relic_ready: events.append_array(m.resolve_roll_relic_step())
		else: return events
	check(false,"Tarot matching attacks terminate")
	return events

func cast(m, id: String, choice: Dictionary = {}) -> Dictionary:
	var card: Dictionary = m.tarots.add(id)
	var result: Dictionary = m.tarot_effects.cast(m,card.instance_id,choice)
	check(not result.has("error") and m.tarots.find_instance(card.instance_id) < 0,"Consume exactly one "+id)
	return result

func rules() -> void:
	for count in range(2,7):
		var m = fresh()
		var values: Array = []
		for i in range(count-1): values.append(6)
		values.append(5)
		for i in range(6-count): values.append(i+1)
		m.roll_pool(true,values); settle(m)
		var budget: int = m.dice_turn.rolls_left
		var combo: int = m.perfect_combo
		m.tarot_effects.strength = 2
		cast(m,"magician",{"die":count-1,"face":6})
		check(m.phase == "roll_attacks" and m.roll_attacks.size() == 1 and m.roll_attacks[0].indices.size() == count,"Magician forms the correct matching tier")
		var events: Array = settle(m).filter(func(e): return e.type == "damage")
		var expected: int = 2 if count == 2 else 1 if count == 3 else 3 if count == 4 else 5 if count == 5 else 18
		check(events.size() == expected,"Tarot matches retain single/random/area attack behavior")
		check(m.phase == "roll" and m.dice_turn.rolls_left == budget and m.perfect_combo == combo,"Matching attacks return control without spending rerolls or combo")
		check(m.dice_turn.locked.is_empty() and m.dice_turn.manual_casts == 0 and m.tarot_effects.strength == 2,"Matching attacks neither spend dice nor consume next-skill effects")
	var m = fresh()
	cast(m,"high_priestess")
	check(m.roll_attacks.is_empty() and not m.dice_turn.has_rolled(),"Priestess before the opening throw grants only its queued boost")
	m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
	cast(m,"high_priestess")
	check(m.dice_turn.values == [3,4,5,6,6,6] and m.roll_attacks[0].indices == [3,4,5],"Priestess activates matches after incrementing and capping faces")
	settle(m)
	m.dice_turn.values.fill(6)
	cast(m,"high_priestess")
	check(m.roll_attacks[0].indices.size() == 6,"Priestess activates existing matches even at the pip cap")
	settle(m)
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
	m.dice_turn.locked = [4,5]; m.dice_turn.committed = [4,5]
	cast(m,"magician",{"die":0,"face":6})
	check(m.roll_attacks.is_empty(),"Spent dice never participate in a tarot-triggered match")
	m = fresh(); m.acquire_relic("worn_bow"); m.acquire_relic("lucky_die")
	m.roll_pool(true,[1,2,3,4,5,6]); settle(m)
	var throws: int = m.relics.items[1].throws
	for id in ["high_priestess","magician","justice"]:
		var activations: Array = []
		var listener := func(relic): activations.append(relic)
		m.relic_activated.connect(listener)
		m.dice_turn.values = [1,2,3,4,5,6]
		var budget: int = m.dice_turn.rolls_left
		var result := cast(m,id,{"die":0,"face":6} if id == "magician" else {})
		if result.reroll: m.roll_pool(false,[6,6,6,6,6,6],true,[],true)
		check(not m.roll_attacks.is_empty(),id+" queues matching attacks")
		settle(m)
		check("worn_bow" not in activations and m.relics.items[1].throws == throws,"Tarot attacks never retrigger initial-throw relics")
		check(m.dice_turn.rolls_left == budget and m.perfect_combo == 1,"All dice tarots retain roll budget and Perfect combo")
		m.relic_activated.disconnect(listener)
	m.reroll_die(0,[6]); check(m.roll_attacks.is_empty(),"Ordinary corrections still do not attack")
	for rolled in [false,true]:
		m = fresh()
		if rolled: m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
		var budget: int = m.dice_turn.rolls_left
		cast(m,"judgement"); cast(m,"judgement")
		check(m.dice_turn.rolls_left == budget+6 and m.dice_turn.has_rolled() == rolled,"Judgement grants three immediately, regardless of throw or straight")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill(); m.dice_turn.rolls_left = 0
	cast(m,"judgement")
	check(m.dice_turn.rolls_left == 3 and not m.pending.is_empty(),"Judgement also works with zero rerolls and a formed skill")
	m = fresh(); m.acquire_relic("ancient_prophecy")
	cast(m,"judgement")
	var repeat: int = m.tarot_effects.pending_repeat.instance_id
	check(not m.tarot_effects.cast(m,repeat).has("error") and m.dice_turn.rolls_left == Run.DiceTurn.ROLLS+6,"Prophecy repeats Judgement's three rerolls")
	for id in ["magician","high_priestess"]:
		m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); settle(m)
		for enemy in m.enemies: enemy.hp = 1
		m.dice_turn.values = [5,6,6,6,6,6]
		cast(m,id,{"die":0,"face":6} if id == "magician" else {})
		settle(m)
		check(m.phase == "finished" and m.outcome() == "wave_clear" and m.roll_attacks.is_empty(),"A tarot match can clear the wave without stranding the turn")

func cli() -> void:
	for id in ["magician","high_priestess","justice","judgement"]:
		var session = Session.new(11010)
		for enemy in session.model.enemies: enemy.hp = 100000; enemy.max_hp = 100000
		session.model.roll_pool(false,[1,2,3,4,5,6]); session._settle()
		var card: Dictionary = session.model.tarots.add(id)
		var hp: int = session.model.enemies.reduce(func(total,e): return total+e.hp,0)
		var error: String = session._cast_tarot(card.instance_id,{"die":0,"face":6} if id == "magician" else {})
		if id != "judgement": check(session.model.phase == "roll_attacks","CLI queues tarot matches")
		session._settle()
		check(error.is_empty() and session.model.phase == "roll","CLI returns to dice controls after "+id)
		if id != "judgement": check(session.model.enemies.reduce(func(total,e): return total+e.hp,0) < hp,"CLI applies tarot match damage")
		else: check(session.model.dice_turn.rolls_left == 7,"CLI Judgement grants three rerolls")
		session.close()

func _initialize() -> void:
	rules(); cli()
	print("Tarot dice matches: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
