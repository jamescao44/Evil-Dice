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
	m.enemies[0].hp = 100000
	m.enemies[0].max_hp = 100000
	m.begin_round()
	return m

func form(m, indices: Array) -> void:
	for index in indices: m.dice_turn.select(index)
	check(not m.form_selected_skill().is_empty(), "Selected trio forms")

func enemy_phase(m) -> void:
	for index in m.living():
		m.enemies[index].intent = {"type":"attack","amount":0,"target":-1}
		m.enemy_act(index)
	m.end_round()

func play_supports(m) -> void:
	form(m,[0,1,2]); m.apply_player()
	form(m,[3,4,5]); m.apply_player()

func _initialize() -> void:
	for throws in range(1,4):
		var m = fresh()
		for n in range(throws): m.roll_pool(n % 2 == 0,[3,3,1,6,6,1])
		check(m.reroll_progress == 0, "Accepted throws do not credit treasure immediately")
		play_supports(m)
		check(m.phase == "enemy" and m.reroll_progress == 0, "Both skills finish before treasure is banked")
		enemy_phase(m)
		check(m.reroll_progress == 3-throws, "%d throws banks %d unused rolls" % [throws,3-throws])
		m.end_round(); m._complete_relic_turn()
		check(m.reroll_progress == 3-throws, "Repeated settlement cannot double-credit treasure")
		m.begin_round()
		check(m.reroll_progress == 3-throws and m.dice_turn.rolls_left == 3, "Fresh dice preserve the bank")
		m.roll_pool(false,[3,3,1,6,6,1]); play_supports(m); enemy_phase(m)
		check(m.reroll_progress == 5-throws, "A later non-Perfect turn adds to the existing bank")
	var m = fresh()
	m.reroll_progress = 7
	m.roll_pool(true,[3,3,1,6,6,1]); m.roll_pool(false,[3,3,1,6,6,1])
	check(m.reroll_progress == 7 and m.perfect_combo == 0, "Missing Perfect resets combo but preserves partial treasure progress")
	form(m,[0,1,2]); m.cancel_formed_skill()
	check(m.reroll_progress == 7, "Cancelling a formed skill does not bank rolls")
	form(m,[0,1,2]); m.save_pending_skill(); m.begin_saved_cast(); m.apply_player()
	check(m.reroll_progress == 7, "Saving and bonus casts do not settle a live turn")
	form(m,[3,4,5]); m.apply_player(); enemy_phase(m)
	check(m.reroll_progress == 8 and m.chest_tier() == 2, "One unused roll unlocks Greed at eight")
	m.open_chest(); m.discard_unclaimed_rewards(); m.close_chest()
	m.end_round(); m._complete_relic_turn()
	check(m.reroll_progress == 0, "Claim clears the bank without reopening its completed turn")
	m = fresh()
	m.reroll_progress = 14
	m.roll_pool(false,[3,3,1,6,6,1]); play_supports(m)
	m.statuses[m.Status.BURNING].apply(2)
	m.enemies[0].acted = true
	m.end_round_step()
	check(m.phase == "turn_end" and m.reroll_progress == 14, "Treasure waits for all turn-end status ticks")
	m.end_round_step()
	check(m.reroll_progress == 15 and m.chest_tier() == 3, "Treasure caps at Ultra after the last tick")
	m = fresh()
	m.statuses[m.Status.FROZEN].apply(1); m._prepare_player_turn()
	m.break_ice(); m.break_ice(); m.break_ice(); enemy_phase(m)
	check(m.reroll_progress == 0, "Frozen turns do not earn three free rolls")
	m = fresh()
	check(not m.end_dice_turn() and m.reroll_progress == 0, "Untouched turns cannot claim rolls")
	m.roll_pool(false,[3,3,1,6,6,1]); m.end_dice_turn(); enemy_phase(m)
	check(m.reroll_progress == 2, "An explicitly ended played turn banks its remaining rolls")
	m = fresh()
	m.enemies[0].hp = 1
	m.roll_pool(false,[5,5,5,2,2,1]); form(m,[0,1,2])
	m.apply_player_step(0)
	check(m.reroll_progress == 0 and m.outcome().is_empty(), "A clearing multi-hit skill must finish its remaining hits")
	m.apply_player()
	check(m.reroll_progress == 2 and m.outcome() == "wave_clear", "Early clear banks rolls even when three dice remain")
	m.begin_wave_reward(); m.begin_wave_reward()
	check(m.reroll_progress == 2, "Wave reward entry does not credit the same turn twice")
	m.open_wave_chest(); m.discard_unclaimed_rewards(); m.close_chest(); m.finish_wave_reward(); m.advance_wave(); m.begin_round()
	check(m.reroll_progress == 2, "Treasure carries across wave transitions")
	m = fresh()
	m.roll_pool(false,[3,3,1,6,6,1]); m.enemies[0].hp = 0
	m.begin_wave_reward()
	check(m.reroll_progress == 2, "Immediate clear outside a skill also settles a played turn")
	m = fresh()
	m.enemies[0].hp = 0; m.begin_wave_reward()
	check(m.reroll_progress == 0, "Immediate clear before any throw earns no progress")
	m = fresh()
	m.stage = m.LAST_PLAYABLE_STAGE; m.reroll_progress = 1
	m.roll_pool(false,[1,1,1,2,2,1]); form(m,[0,1,2]); m.apply_player(0)
	check(m.outcome() == "victory" and m.reroll_progress == 3, "Final winning action counts its unused rolls before auto-claim")
	check(m.auto_claim_victory_chest() == 1 and m.reroll_progress == 0, "Victory claims the newly earned tier once")
	m.reset_run()
	check(m.reroll_progress == 0 and m.treasure_settled_turn == -1, "Restart clears the bank and settlement guard")
	m.begin_round(); m.roll_pool(false,[3,3,1,6,6,1]); m.end_dice_turn(); enemy_phase(m)
	check(m.reroll_progress == 2, "Restart permits the new first turn to settle")
	print("Reroll Treasure: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
