extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
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
	m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000
	m.begin_round()
	return m
func form(m, indices: Array) -> void:
	for index in indices: m.dice_turn.select(index)
	check(not m.form_selected_skill().is_empty(),"Pattern forms")
func enemy_phase(m) -> void:
	for i in m.living():
		m.enemies[i].intent = {"type":"attack","amount":0,"target":-1}
		m.enemy_act(i)
	m.end_round()
func _initialize() -> void:
	check(Run.DiceTurn.ROLLS == 5 and Run.Chests.REROLL_COST == 20,"Five throws and twenty-point treasure are the base rules")
	for throws in range(1,Run.DiceTurn.ROLLS+1):
		var m = fresh()
		for i in range(throws): m.roll_pool(i%2 == 0,[1,2,3,4,5,6])
		check(m.reroll_progress == 0,"Throws never immediately add treasure")
		m.end_dice_turn()
		check(m.reroll_progress == Run.DiceTurn.ROLLS-throws,"End Turn banks unused throws before healing or enemy actions")
		m.apply_player(0)
		enemy_phase(m)
		check(m.reroll_progress == Run.DiceTurn.ROLLS-throws,"Bank unused throws once")
		m.end_round(); m._complete_relic_turn()
		check(m.reroll_progress == Run.DiceTurn.ROLLS-throws,"Settlement cannot repeat")
	var m = fresh(); m.reroll_progress = 1; m.roll_pool(false,[1,2,3,4,5,6])
	form(m,[0,1,2]); m.apply_player(0)
	check(m.reroll_progress == 5 and m.chest_tier() == -1 and m.bonus_turn_count == 0 and m.phase == "enemy","Single cast banks throws before the enemy turn")
	m = fresh(); m.reroll_progress = 19
	for i in range(4): m.roll_pool(false,[1,2,3,4,5,6])
	form(m,[0,1,2]); m.apply_player(0)
	check(m.chest_tier() == 0 and m.reroll_progress == 20,"One unused throw completes a Normal chest")
	m = fresh(); m.reroll_progress = 19; m.roll_pool(false,[1,2,3,4,5,6])
	m.end_dice_turn(); m.apply_player(); m.statuses[m.Status.BURNING].apply(2)
	m.enemies[0].acted = true; m.end_round_step()
	check(m.phase == "turn_end" and m.reroll_progress == 20,"Treasure is already banked while Burning resolves")
	m.end_round_step()
	check(m.reroll_progress == 20 and m.chest_tier() == 0,"Treasure caps at twenty and always starts Normal")
	m = fresh(); m.statuses[m.Status.FROZEN].apply(1); m._prepare_player_turn()
	m.break_ice(); m.break_ice(); m.break_ice(); enemy_phase(m)
	check(m.reroll_progress == 0,"Frozen turns never grant free rolls")
	m = fresh(); check(not m.end_dice_turn(),"Unthrown turn cannot be ended")
	m.roll_pool(false,[1,2,3,4,5,6]); m.enemies[0].hp = 1; m.tarot_effects.extra_uses = 2
	form(m,[0,1,2]); m.apply_player_step(0)
	check(m.reroll_progress == 0 and m.outcome().is_empty(),"Winning cast completes all hits before banking")
	m.apply_player(); check(m.reroll_progress == 4,"Early clear banks leftover throws")
	m.begin_wave_reward(); m.begin_wave_reward()
	check(m.reroll_progress == 4,"Reward entry never repeats credit")
	m = fresh(); m.stage = m.LAST_PLAYABLE_STAGE; m.reroll_progress = 16; m.enemies[0].hp = 1
	m.roll_pool(false,[1,2,3,4,5,6]); form(m,range(6)); m.apply_player(0)
	check(m.outcome() == "victory" and m.reroll_progress == 20,"Final victory counts unused throws")
	check(m.auto_claim_victory_chest() == 0 and m.reroll_progress == 0,"Auto-claim sees final earned tier")
	m.reset_run(); check(m.reroll_progress == 0 and m.treasure_settled_turn == -1,"New run resets guard")
	print("Reroll Treasure: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
