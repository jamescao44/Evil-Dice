extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Pool = preload("res://scripts/dice/dice_turn.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh():
	var m = Run.new(20261016)
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000
	m.enemies[0].max_hp = 100000
	m.begin_round()
	return m

func form(m,indices: Array) -> MultiHitSkill:
	for i in indices: check(m.dice_turn.select(i),"Useful selection: %s" % str(indices))
	return m.form_selected_skill()

func _initialize() -> void:
	for count in range(2,7):
		for face in range(1,7):
			var values: Array = []
			values.resize(count); values.fill(face)
			var skill = Patterns.classify(values)
			var m = fresh()
			check(skill.is_attack() and not skill.is_freeze(),"Every matching face is an attack")
			check(m.is_instant_kill(skill) == (count == 6),"Only six alike annihilates, including 111")
			check(skill.hits_all() == (count == 6),"Only annihilation hits everyone")
			check(skill.use_count() == (1 if count == 6 else face),"Pips set hits independently of group size")
			check(skill.duplicate().same_as(skill),"Copy retains pattern")
			if count < 6: check(m.attack_base(skill) == [15,30,50,75][count-2],"Matching tier damage")
	for length in range(3,7):
		for first in range(1,8-length):
			var values: Array = range(first,first+length)
			var expected: int = 0
			for value in values: expected += value
			values.reverse()
			var skill = Patterns.classify(values)
			check(skill.pattern == "straight" and not skill.is_attack(),"Unordered consecutive faces shield")
			check(Patterns.shield_points(skill) == expected*(length-2),"Straight pip sum and length scale")
	for invalid in [[],[1],[1,1,2],[1,2,4],[2,2,2,3],[0,0],[7,7]]:
		check(Patterns.classify(invalid).is_empty(),"Reject invalid pattern "+str(invalid))
	check(Patterns.can_extend([1,3],[1,2,3,6,6,6]),"Out-of-order straight can complete")
	check(not Patterns.can_extend([1,3],[1,3,5,6,6,6]),"Missing bridge is rejected")
	check(not Patterns.can_extend([2,2,3],[2,2,3,4,5,6]),"Mixed pair cannot complete")
	var m = fresh()
	check(not m.dice_turn.select(0) and not m.end_dice_turn(),"Untouched turn cannot select or finish")
	m.roll_pool(false,[2,2,3,3,4,4])
	m.dice_turn.select(0); m.dice_turn.select(1)
	check(not m.dice_turn.select(2) and m.dice_turn.selected == [0,1],"Invalid addition leaves selection intact")
	var skill = m.form_selected_skill()
	check(skill.pattern == "match" and m.dice_turn.locked == [0,1],"Pair reserves only two dice")
	check(not m.dice_turn.can_roll() and not m.dice_turn.select(2) and not m.end_dice_turn(),"Pending skill blocks roll, selection and End Turn")
	check(not m.save_pending_skill() and not m.begin_saved_cast(),"Saved skills disabled")
	check(m.cancel_formed_skill() and m.dice_turn.rolls_left == 2 and m.dice_turn.locked.is_empty(),"Cancel returns dice without refunding throws")
	for indices in [[0,1],[2,3],[4,5]]:
		form(m,indices); m.apply_player(0)
	check(m.phase == "enemy" and m.dice_turn.locked.size() == 6,"Three pairs share one enemy phase")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.shield = 90
	form(m,range(6)); m.apply_player()
	check(m.shield == 174 and m.phase == "enemy","Six-straight adds 84 with no shield cap")
	m._load_wave(); check(m.shield == 0,"Next wave clears shield")
	m = fresh(); m.roll_pool(false,[1,2,3,6,6,5])
	form(m,[0,1,2]); m.apply_player()
	check(m.shield == 6 and m.phase == "roll","Straight leaves other dice usable")
	check(m.roll_pool(false,[4,4,4]) == [3,4,5],"Only unused dice reroll")
	check(m.dice_turn.values == [1,2,3,4,4,4],"Spent straight keeps faces")
	form(m,[3,4,5]); m.apply_player(0)
	check(m.phase == "enemy","Mixed lengths finish exactly once")
	for left in [1,2,3,4,6]:
		m = fresh(); m.roll_pool(false,[1,2,3,4,5,6])
		if left < 6:
			m.dice_turn.locked = range(6-left); m.dice_turn.committed = m.dice_turn.locked.duplicate()
		var volley = m.leftover_skill()
		var expected: int = floori(1.25*volley.sum)
		var before: int = m.enemies[0].hp
		check(m.end_dice_turn() and not m.end_dice_turn(),"End Turn queues exactly one volley")
		var hits: int = 0
		while m.phase in ["player","executing"]:
			m.apply_player_step(0); hits += 1
		check(hits == volley.sum and before-m.enemies[0].hp == expected,"Each leftover pip hits once while fractional damage preserves the total")
		check(m.phase == "enemy","Enemy waits for all leftover hits")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.statuses[m.Status.MIGHT].apply(3)
	m.tarot_effects.strength = 2; m.tarot_effects.extra_uses = 3
	m.end_dice_turn(); m.apply_player(0)
	check(m.status_count(m.Status.MIGHT) == 2 and m.tarot_effects.strength == 0 and m.tarot_effects.extra_uses == 0,"Cleanup consumes each next-cast bonus once")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.relics.add("magic_sword")
	m.relics.items[-1].charges = 1
	var expected_total: int = m.leftover_total_damage()
	var before_hp: int = m.enemies[0].hp
	m.end_dice_turn(); m.apply_player(0)
	check(expected_total == before_hp-m.enemies[0].hp and expected_total == 78,"End Turn preview includes stored critical and fractional rounding")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.tarot_effects.strength = 2; m.tarot_effects.extra_uses = 3
	m.statuses[m.Status.MIGHT].apply(2)
	form(m,range(6)); m.apply_player()
	check(m.shield == 252 and m.tarot_effects.extra_uses == 3 and m.status_count(m.Status.MIGHT) == 2,"Strength boosts shield potency while attack-only bonuses remain")
	m = fresh(); m.roll_pool(false,[1,1,1,1,1,1]); m.hp = 20
	form(m,range(6)); m.apply_player(0)
	check(m.enemies[0].hp == 0 and m.hp == 32 and m.outcome() == "wave_clear","Six ones annihilates and retains healing")
	m = fresh(); m.roll_pool(false,[6,6,1,2,3,4]); m.enemies[0].hp = 1
	form(m,[0,1]); var events: Array = m.apply_player(0)
	check(events.filter(func(e): return e.type == "damage").size() == 6,"Match finishes all hits on corpses")
	# A living alternative must never steal the selected target's remaining hits.
	m = fresh(); m.enemies.append(m.make_enemy(0)); m.enemies[0].hp = 1
	m.roll_pool(false,[6,6,1,2,3,4]); form(m,[0,1])
	var other_hp: int = m.enemies[1].hp
	m.apply_player_step(0)
	check(m.player_target() == 0 and m.player_attack_targets() == [0],"Selected corpse stays targetable while another foe lives")
	var follow: Array = m.apply_player_step(1)
	check(follow.any(func(e): return e.type == "damage" and e.target == 0 and e.get("corpse_hit",false)),"An explicit later target cannot redirect the cast")
	m.apply_player()
	check(m.enemies[1].hp == other_hp and m.phase == "roll","All remaining matching hits stay on the selected foe")
	m = fresh(); m.enemies.append(m.make_enemy(0)); m.roll_pool(false,[4,4,1,2,3,5]); form(m,[0,1])
	m.begin_player_cast(1); m.hit_enemy(1,9999,true)
	check(m.player_target() == 1 and m.apply_player_step().any(func(e): return e.get("corpse_hit",false)),"Cast binds its target before formation relic effects can kill it")
	# Leftovers preserve die order and random retargeting, with fractional carry.
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.end_dice_turn()
	var amounts: Array = []
	while m.phase in ["player","executing"]:
		var step: Array = m.apply_player_step(0)
		for e in step:
			if e.type == "damage": amounts.append(e.display_amount)
	check(amounts == [1,1,1,2,1,1,1,2,1,1,1,2,1,1,1,2,1,1,1,2,1],"Every pip produces its own hit and fractional carry preserves the total")
	m = fresh(); m.enemies.append(m.make_enemy(0)); m.enemies[0].hp = 1
	m.roll_pool(false,[6,1,2,3,4,5]); m.end_dice_turn(); m.apply_player_step(0)
	check(m.player_target() == 1,"Leftover dice still choose living enemies after a kill")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.tarot_effects.extra_uses = 3
	var bonus_expected: int = m.leftover_total_damage()
	var bonus_before: int = m.enemies[0].hp
	m.end_dice_turn(); var bonus_hits: Array = m.apply_player(0).filter(func(e): return e.type == "damage")
	check(bonus_hits.size() == 24 and bonus_before-m.enemies[0].hp == bonus_expected and bonus_expected == 30,"Extra cleanup orbs match the End Turn damage preview")
	m = fresh(); m.relics.add("twin_scythes")
	check(m.skill_use_count(Patterns.classify([4,4])) == 8,"Existing hit relics modify new matching attacks")
	check(m.skill_use_count(Patterns.cleanup([4,4])) == 8,"Cleanup does not double-dip into matching-only relics")
	check("magic_slingshot" in Catalog.DISABLED,"Incompatible spare-die relic is suspended")
	for i in range(100): check(m.relics.draw_one(m.reward_rng) != "magic_slingshot","Suspended relic excluded from offers")
	m = fresh(); m.relics.add("tissue_pack"); m.roll_pool(false,[1,2,3,4,5,6])
	form(m,[0,1,2]); check(m.roll_relic_actions.is_empty(),"Selection never farms formation relics")
	m.begin_player_cast(); check(m.roll_relic_actions.size() == 1,"Straight fires all-different relic once when cast")
	m = fresh(); m.load_debug_wave(19)
	for enemy in m.enemies: enemy.hp = 0
	check(m.outcome() == "victory" and not m.advance_wave(),"City remains skipped")
	print("Dice pattern checks: %d passed, %d failed" % [checks-failures,failures])
	quit(1 if failures else 0)
