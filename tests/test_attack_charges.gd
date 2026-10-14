extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Catalog = preload("res://scripts/status/status_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(city: bool = false):
	var m = Run.new(201)
	if city: m.load_debug_wave(Waves.COUNT)
	else:
		m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
		for e in m.enemies: e.hp = 10000; e.max_hp = 10000
	m.begin_round()
	m.statuses[Status.MIGHT].apply(2)
	m.statuses[Status.ASCENSION].apply(1)
	return m

func finish(m) -> void:
	if m.phase == "enemy":
		for i in m.living():
			m.enemies[i].intent = {"type":"attack","target":-1,"amount":0}
			m.enemy_act(i)
	m.end_round()
	m.begin_round()

func counts(m, might: int, ascension: int, label: String) -> void:
	check(m.status_count(Status.MIGHT) == might and m.status_count(Status.ASCENSION) == ascension,label)

func _initialize() -> void:
	for city in [false,true]:
		var m = fresh(city)
		for values in [[2,2,4],[2,2,2],[6,6,4]]:
			m.set_test_roll(values)
			m.apply_player()
			finish(m)
			counts(m,2,1,"Non-attacks and completed enemy phases keep both attack charges")
		m.set_test_roll([5,5,5])
		m.set_skill_use_multiplier("test",2)
		for hit in range(12):
			var events: Array = m.apply_player_step()
			check(events[0].display_amount == 52,"Both boons cover all twelve impacts, including the last")
			counts(m,2 if hit < 11 else 1,1 if hit < 11 else 0,"One charge per cast, never per impact")
		finish(m)
		counts(m,1,0,"No second decrement after enemies act")
		check(m.attack_multiplier() == 1.5,"The weaker buff retains its final charge")
		m.set_skill_use_multiplier("test",1)
		m.set_test_roll([1,2,3])
		check(m.save_pending_skill(),"Banking an attack is allowed")
		counts(m,1,0,"Banking does not cast the attack or spend a charge")
		finish(m)
		m.set_test_roll([2,2,4])
		var waiting = m.pending.duplicate()
		check(m.begin_saved_cast(),"Saved attack begins")
		m.apply_player()
		counts(m,0,0,"Saved attack consumes exactly one charge")
		check(m.phase == "player" and m.pending.same_as(waiting),"Saved attack restores the waiting support skill")
		m = fresh(city)
		m.tarot_effects.extra_rolls = 1
		m.set_test_roll([1,2,3])
		m.apply_player()
		counts(m,1,0,"An extra throw still spends a charge for its completed attack")
		check(m.phase == "roll","Extra throw does not advance the enemy turn")
		m = fresh(city)
		m.saved_skill = Rules.classify([3,3,3])
		m.set_test_roll([1,2,3])
		m.begin_saved_cast()
		m.apply_player()
		counts(m,2,3,"Saved attack-boon reapply refreshes itself without spending either boon")
		m.apply_player()
		counts(m,1,2,"Waiting attack spends one charge of each active boon")
	var m = fresh()
	m.apply_affliction(Status.FROZEN,1)
	m._prepare_player_turn()
	m.skip_frozen_turn()
	finish(m)
	counts(m,2,1,"Losing a turn to freeze spends no attack charges")
	m = fresh()
	for enemy in m.enemies: enemy.hp = 1
	m.set_test_roll([6,6,6])
	m.apply_player()
	counts(m,1,0,"A wave-ending attack spends one charge")
	check(m.advance_wave(),"Cleared wave advances")
	counts(m,1,0,"Wave transition retains unspent charges")
	GameText.set_language("en",false)
	var row: Dictionary = Catalog.active(m.statuses).filter(func(item): return item.id == Status.MIGHT)[0]
	check(Catalog.counter_text(row) == "1 attack" and GameText.remaining(2,"attack") == "2 attacks remaining.","Attack counters use attacks, not turns")
	GameText.set_language("zh_CN",false)
	check(Catalog.counter_text(row) == "1次攻击","Chinese status counter uses attack charges")
	print("Attack charges: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
