extends SceneTree
## Exercise real dice commitment, generated casts and automatic turn settlement.
const Run = preload("res://scripts/progression/run_rules.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(830)
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000; m.enemies[0].shield = 0
	m.begin_round()
	return m

func form(m, indices: Array = [0,1,2]) -> void:
	m.dice_turn.selected = indices.duplicate()
	check(not m.form_selected_skill().is_empty(),"A valid manual straight can form")

func finish(m) -> Array:
	var events: Array = []
	for guard in range(30):
		if m.phase not in ["player","executing"]: break
		events.append_array(m.apply_player(0))
	return events

func next_turn(m) -> void:
	for e in m.enemies: e.acted = true
	m.end_round(); m.begin_round()

func _initialize() -> void:
	var m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); form(m)
	check(m.cancel_formed_skill() and m.dice_turn.manual_casts == 0,"Cancelling formation preserves the one skill")
	form(m); finish(m)
	check(m.phase == "enemy" and m.dice_turn.manual_casts == 1 and not m.dice_turn.active,"Manual cast automatically passes to enemies")
	check(m.reroll_progress == 4 and m.relic_recovery.leftover_sum == 15,"Remaining rolls and leftover pips settle immediately")
	check(not m.dice_turn.select(3) and not m.dice_turn.can_roll(true),"Neither selection nor a free reroll can bypass the cap")
	m.dice_turn.selected = [3,4,5]
	check(m.form_selected_skill().is_empty() and not m.end_dice_turn(),"A second manual cast or duplicate end cannot occur")
	next_turn(m)
	check(m.dice_turn.manual_casts == 0 and m.dice_turn.rolls_left == 5 and m.reroll_progress == 4,"Only the next real turn restores the skill allowance")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); form(m,[0,1,2,3,4,5]); finish(m)
	check(m.phase == "enemy" and m.bonus_turn_count == 0,"A six-straight has no unlimited extra-turn loop")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.set_skill_use_multiplier("test",3); form(m)
	for hit in range(2):
		m.apply_player_step(0)
		check(m.phase == "executing" and m.dice_turn.manual_casts == 1 and m.reroll_progress == 0,"Extra uses finish before automatic turn end")
	m.apply_player_step(0)
	check(m.phase == "enemy" and m.reroll_progress == 4,"Last extra use ends exactly one manual skill")
	m = fresh(); m.character_passive.charge = 2; m.roll_pool(false,[1,2,3,4,5,6]); form(m)
	var events: Array = finish(m)
	check(events.filter(func(e): return e.type == "damage" and e.target == 0).size() == 3,"Counter Fireballs remain two additional independent attacks")
	check(m.phase == "enemy" and m.dice_turn.manual_casts == 1 and m.character_passive.charge == 0,"Generated bonuses do not spend another allowance")
	m = fresh(); m.acquire_relic("echo_bell"); m.relics.items[0].casts = 2
	m.roll_pool(false,[1,2,3,4,5,6]); form(m); events = finish(m)
	check(events.filter(func(e): return e.type == "damage" and e.target == 0).size() == 2 and m.phase == "enemy","Echo resolves before the automatic enemy phase")
	m = fresh(); m.acquire_relic("enchanted_missile"); m.phase = "round_end"; m.begin_round(); finish(m)
	check(m.phase == "roll" and m.dice_turn.manual_casts == 0,"Turn-start relic skills leave the manual allowance untouched")
	m.roll_pool(false,[1,2,3,4,5,6]); form(m); finish(m)
	check(m.phase == "enemy" and m.dice_turn.manual_casts == 1,"Manual skill still ends a turn that began with a relic cast")
	m = fresh(); m.acquire_relic("frozen_tilapia"); m.roll_pool(false,[1,2,3,4,5,6]); form(m); events = finish(m)
	check(m.relic_recovery.finished and m.relic_recovery.leftover_sum == 15,"Leftover relic hooks execute on automatic turn end")
	check(m.relic_recovery.finish_player_turn(m).is_empty(),"Leftover item effects cannot pay twice")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); form(m)
	var card: Dictionary = m.grant_tarot("justice")
	check(not m.tarot_effects.cast(m,card.instance_id).has("error") and m.dice_turn.manual_casts == 0,"Justice can cancel an uncommitted skill without spending it")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.enemies[0].hp = 1; form(m); finish(m)
	check(m.outcome() == "wave_clear" and m.reroll_progress == 4,"A wave-ending skill still banks unused rolls")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6]); m.end_dice_turn(); finish(m)
	check(m.phase == "enemy" and m.dice_turn.manual_casts == 0 and m.reroll_progress == 4,"Players may still pass without casting")
	check("hermit" not in Tarot.eligible(),"Hermit leaves reward, shop and draw pools")
	m = fresh(); card = m.grant_tarot("hermit")
	check(m.tarot_effects.cast(m,card.instance_id).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"An already-owned Hermit is disabled without consuming it")
	for i in range(100): check("hermit" not in Tarot.draw_choices(m.reward_rng),"Draw choices exclude disabled cards")
	print("One skill per turn: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
