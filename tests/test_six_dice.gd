extends SceneTree
## Pool transactions and compatibility checks; fire damage is covered in test_flamelings.
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(20261021)
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000
	m.begin_round()
	return m
func form(m,indices: Array) -> MultiHitSkill:
	for i in indices: check(m.dice_turn.select(i),"Useful straight selection")
	return m.form_selected_skill()
func _initialize() -> void:
	var m = fresh()
	check(not m.dice_turn.select(0) and not m.end_dice_turn(),"Untouched turn cannot select or finish")
	m.roll_pool(false,[1,2,3,4,5,6])
	m.dice_turn.select(0); m.dice_turn.select(1)
	m.dice_turn.values[5] = 2
	check(not m.dice_turn.select(5) and m.dice_turn.selected == [0,1],"Repeated selected faces are rejected")
	m.dice_turn.values[5] = 6
	m.dice_turn.select(2)
	var skill = m.form_selected_skill()
	check(skill.pattern == "straight" and m.dice_turn.locked == [0,1,2],"Formation reserves only selected dice")
	check(not m.dice_turn.can_roll() and not m.dice_turn.select(3) and not m.end_dice_turn(),"Pending skill blocks roll, selection and End Turn")
	check(not m.save_pending_skill() and not m.begin_saved_cast(),"Saved skills remain disabled")
	check(m.cancel_formed_skill() and m.dice_turn.rolls_left == 2 and m.dice_turn.locked.is_empty(),"Cancel returns dice but never refunds rolls")
	form(m,[0,1,2]); m.apply_player(0)
	check(m.dice_turn.committed == [0,1,2] and m.phase == "roll","Cast commits just its three dice")
	check(m.roll_pool(false,[4,4,4]) == [3,4,5],"Only unused dice reroll")
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()
	check(m.dice_turn.values == [1,2,3,4,4,4] and m.dice_turn.rolls_left == 1,"Committed faces and budget survive automatic attacks")
	check(not m.dice_turn.select(3),"An uncompletable straight cannot start")
	m.end_dice_turn(); m.apply_player()
	check(m.phase == "enemy" and m.bonus_turn_count == 0,"Leftovers end the turn without a bonus")
	m = fresh(); m.relics.add("magic_sword"); m.relics.items[-1].charges = 1
	m.roll_pool(false,[1,2,3,4,5,6]); m.hp = 20
	m.end_dice_turn(); m.apply_player()
	check(m.hp == 41 and m.relics.items[-1].charges == 1,"Healing keeps stored critical for an attack skill")
	m = fresh(); m.enemies.append(m.make_enemy(0)); m.enemies[0].hp = 1
	m.roll_pool(false,[1,2,3,4,5,6]); m.tarot_effects.extra_uses = 2
	form(m,[0,1,2]); var other_hp: int = m.enemies[1].hp
	m.apply_player_step(0)
	check(m.player_target() == 0,"Additional Fireball uses stay on the selected corpse")
	m.apply_player(1)
	check(m.enemies[1].hp == other_hp and m.phase == "roll","Fireball cannot overflow to another enemy")
	m = fresh(); m.relics.add("tissue_pack"); m.roll_pool(false,[1,2,3,4,5,6])
	form(m,[0,1,2]); check(m.roll_relic_actions.is_empty(),"Selection never farms formation relics")
	m.cancel_formed_skill(); form(m,[0,1,2]); m.begin_player_cast()
	check(m.roll_relic_actions.size() == 1,"Formation relic fires once at actual cast")
	check("magic_slingshot" in Catalog.DISABLED,"Spare-die relic stays suspended")
	for i in range(100): check(m.relics.draw_one(m.reward_rng) != "magic_slingshot","Suspended relic excluded from offers")
	m = fresh(); m.load_debug_wave(19)
	for enemy in m.enemies: enemy.hp = 0
	check(m.outcome() == "victory" and not m.advance_wave(),"City remains skipped")
	print("Six dice transactions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
