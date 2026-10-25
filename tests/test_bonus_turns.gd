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
	var m = Run.new(20261018)
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000
	m.enemies[0].max_hp = 100000
	m.begin_round()
	return m

func form(m, indices: Array) -> void:
	for index in indices: m.dice_turn.select(index)
	check(not m.form_selected_skill().is_empty(),"Valid group forms")

## Automatically generated bonuses finish before another manual combination can be formed.
func cast(m) -> Array:
	var events: Array = m.apply_player(0)
	while m.phase == "player" and m.pending.cast_source != "manual": events.append_array(m.apply_player())
	return events

func _initialize() -> void:
	var m = fresh()
	m.relics.add("magic_sword")
	m.relics.add("crystal_ball")
	m.statuses[m.Status.IMMUNITY].apply(2)
	m.apply_enemy_status(0,m.Status.FROZEN,2)
	var intent: Dictionary = m.enemies[0].intent.duplicate(true)
	var round_before: int = m.round_number
	var previous_id: int = m.dice_turn.turn_id
	for chain in range(3):
		m.roll_pool(false,[1,2,3,4,5,6])
		form(m,[0,1,2]); cast(m)
		form(m,[3,4,5])
		var events: Array = cast(m)
		check(m.phase == "roll" and m.dice_turn.rolls_left == 3 and m.dice_turn.committed.is_empty(),"Bonus restores the full pool")
		check(m.bonus_turn_count == chain+1 and m.dice_turn.turn_id > previous_id,"Each bonus gets a new settlement identity")
		previous_id = m.dice_turn.turn_id
		check(events.filter(func(e): return e.type == "bonus_turn").size() == 1,"One bonus notification per completed pool")
		check(m.reroll_progress == (chain+1)*2,"Each completed pool banks its unused rolls exactly once")
		check(m.round_number == round_before and m.enemies[0].intent == intent,"Bonus preserves the enemy round and queued move")
		check(m.status_count(m.Status.IMMUNITY) == 2 and m.enemy_status_count(0,m.Status.FROZEN) == 2,"Bonus preserves player and enemy round durations")
		check(m.relics.items[0].turns == 0 and not m.relic_turn_closed,"Round relics do not advance during bonuses")
	check(m.shield == 0,"Fire skills no longer create shields")
	check(not m.end_dice_turn(),"Untouched bonus cannot bank free rolls")
	m.roll_pool(false,[1,2,3,4,5,6]); m.end_dice_turn(); m.apply_player()
	check(m.phase == "enemy" and m.bonus_turn_count == 3,"Leftover healing ends the chain even when consuming all dice")
	for i in m.living(): m.enemy_act(i)
	m.end_round()
	check(m.reroll_progress == 8 and m.relics.items[0].turns == 1,"Real round end settles the final pool and advances relics once")
	m.end_round(); m._complete_relic_turn()
	check(m.reroll_progress == 8 and m.relics.items[0].turns == 1,"Repeated settlement cannot duplicate rewards or counters")
	m = fresh(); m.roll_pool(false,[1,2,3,4,5,6])
	form(m,[0,1,2]); cast(m)
	form(m,[3,4,5]); m.cancel_formed_skill()
	check(m.bonus_turn_count == 0 and m.dice_turn.committed.size() == 3,"Cancelling the last straight cannot earn a bonus")
	m.tarot_effects.extra_uses = 2
	form(m,[3,4,5])
	for hit in range(2):
		m.apply_player_step(0)
		check(m.bonus_turn_count == 0 and m.phase == "executing","Bonus waits for the last added hit")
	m.apply_player_step(0)
	check(m.bonus_turn_count == 1 and m.phase == "roll","Final hit awards the bonus")
	m.reset_run()
	check(m.bonus_turn_count == 0 and m.treasure_settled_turn == -1,"Restart clears bonus accounting")
	print("Bonus turns: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
