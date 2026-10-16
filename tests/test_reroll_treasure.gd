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
	for throws in [1,2,3]:
		var m = fresh()
		for i in range(throws): m.roll_pool(i%2 == 0,[1,2,3,4,5,6])
		check(m.reroll_progress == 0,"Throws never immediately add treasure")
		m.end_dice_turn(); m.apply_player(0)
		check(m.reroll_progress == 0,"Leftover volley waits for enemy phase")
		enemy_phase(m)
		check(m.reroll_progress == 3-throws,"Bank unused throws once")
		m.end_round(); m._complete_relic_turn()
		check(m.reroll_progress == 3-throws,"Settlement cannot repeat")
	var m = fresh(); m.reroll_progress = 1; m.roll_pool(false,[1,2,3,4,5,6])
	form(m,range(6)); m.apply_player(); enemy_phase(m)
	check(m.reroll_progress == 3 and m.chest_tier() == 1,"Using all dice automatically earns Perfect chest")
	m = fresh(); m.reroll_progress = 7
	m.roll_pool(false,[1,2,3,4,5,6]); m.roll_pool(false,[1,2,3,4,5,6])
	form(m,range(6)); m.apply_player(); enemy_phase(m)
	check(m.chest_tier() == 2 and m.reroll_progress == 8,"One unused throw unlocks Greed")
	m = fresh(); m.reroll_progress = 14; m.roll_pool(false,[1,2,3,4,5,6])
	form(m,range(6)); m.apply_player(); m.statuses[m.Status.BURNING].apply(2)
	m.enemies[0].acted = true; m.end_round_step()
	check(m.phase == "turn_end" and m.reroll_progress == 14,"Burning resolves before treasure")
	m.end_round_step()
	check(m.reroll_progress == 15 and m.chest_tier() == 3,"Ultra caps progress at fifteen")
	m = fresh(); m.statuses[m.Status.FROZEN].apply(1); m._prepare_player_turn()
	m.break_ice(); m.break_ice(); m.break_ice(); enemy_phase(m)
	check(m.reroll_progress == 0,"Frozen turns never grant free rolls")
	m = fresh(); check(not m.end_dice_turn(),"Unthrown turn cannot be ended")
	m.roll_pool(false,[6,6,1,2,3,4]); m.enemies[0].hp = 1
	form(m,[0,1]); m.apply_player_step(0)
	check(m.reroll_progress == 0 and m.outcome().is_empty(),"Winning cast completes all hits before banking")
	m.apply_player(); check(m.reroll_progress == 2,"Early clear banks leftover throws")
	m.begin_wave_reward(); m.begin_wave_reward()
	check(m.reroll_progress == 2,"Reward entry never repeats credit")
	m = fresh(); m.stage = m.LAST_PLAYABLE_STAGE; m.reroll_progress = 1
	m.roll_pool(false,[1,1,1,1,1,1]); form(m,range(6)); m.apply_player(0)
	check(m.outcome() == "victory" and m.reroll_progress == 3,"Final victory counts unused throws")
	check(m.auto_claim_victory_chest() == 1 and m.reroll_progress == 0,"Auto-claim sees final earned tier")
	m.reset_run(); check(m.reroll_progress == 0 and m.treasure_settled_turn == -1,"New run resets guard")
	print("Reroll Treasure: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
