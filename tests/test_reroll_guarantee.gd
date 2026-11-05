extends SceneTree
## Accumulation spans physical dice, turns and levels, before any face-changing modifiers.
const Run = preload("res://scripts/progression/run_rules.gd")
const Rules = preload("res://scripts/dice/reroll_rules.gd")
const Campaign = preload("res://scripts/progression/campaign_progress.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(818)
	m.begin_round(); m.roll_pool(true,[1,2,3,4,5,6])
	return m

func _initialize() -> void:
	var m = fresh(); var combo: int = m.perfect_combo
	m.reroll_die(0,[1])
	check(m.same_pip_rerolls == 1 and m.dice_turn.values[0] == 1,"First unchanged reroll is retained")
	m.reroll_die(1,[3])
	check(m.same_pip_rerolls == 1,"A successful correction does not reset accumulated unchanged rolls")
	m.reroll_die(5,[6])
	check(m.same_pip_rerolls == 2 and m.dice_turn.values[5] != 6,"Second unchanged reroll changes face even on a different die")
	m.reroll_die(4,[5])
	check(m.same_pip_rerolls == 3 and m.dice_turn.values[4] == 5,"Third unchanged reroll starts the next pair")
	check(m.perfect_combo == combo and m.roll_attacks.is_empty() and m.dice_turn.rolls_left == 0,"Guarantee costs no extra roll and cannot change combo or trigger attacks")
	var rng_state: int = m.rng.state
	check(m.reroll_die(3).is_empty() and m.same_pip_rerolls == 3 and m.rng.state == rng_state,"Exhausted reroll never touches pity or RNG")
	m.dice_turn.reset(); m.phase = "roll"
	m.roll_pool(false,[1,2,3,4,5,6])
	check(m.same_pip_rerolls == 3,"Initial throws and new turns preserve the accumulator")
	m.reroll_die(2,[3])
	check(m.same_pip_rerolls == 4 and m.dice_turn.values[2] != 3,"Fourth unchanged result is corrected across turns")
	m.roll_pool(false,m.dice_turn.values.duplicate(),true)
	check(m.same_pip_rerolls == 4,"Full-pool tarot throws do not count as single-die corrections")
	rng_state = m.rng.state
	check(m.reroll_die(0,[0]).is_empty() and m.same_pip_rerolls == 4 and m.rng.state == rng_state,"Invalid forced faces cannot spend the guarantee")

	m = fresh(); m.same_pip_rerolls = 1; m.tarot_effects.dice_boost = 5
	m.reroll_die(5,[6])
	check(m.same_pip_rerolls == 2 and m.dice_turn.values[5] == 6,"High Priestess applies after the corrected raw face, even if it returns to six")
	m.reroll_die(5,[1])
	check(m.same_pip_rerolls == 2 and m.dice_turn.values[5] == 6,"Only raw same-pip outcomes count, not repeats created by modifiers")
	m.stage = 7
	var checkpoint: Dictionary = Campaign.capture(m)
	var restored = Run.new(819)
	check(Campaign.restore(restored,checkpoint) and restored.same_pip_rerolls == 2,"Level checkpoints preserve accumulated reroll matches")
	checkpoint.run.erase("same_pip_rerolls")
	check(Campaign.restore(restored,checkpoint) and restored.same_pip_rerolls == 0,"Older checkpoints safely start without accumulated matches")
	m.reset_run(); check(m.same_pip_rerolls == 0,"A new run resets the shared accumulator")

	var rng := RandomNumberGenerator.new(); rng.seed = 154
	for previous in range(1,7):
		var seen: Dictionary = {}
		for i in range(200):
			var face: int = Rules.corrected_face(rng,previous,previous,1)
			check(face in range(1,7) and face != previous,"Guaranteed raw rerolls always choose another valid face")
			seen[face] = true
		check(seen.size() == 5,"All other five faces remain possible")
		var weights := [0.0,0.0,0.0,0.0,0.0,0.0]
		for outcome in Rules.outcomes(previous,1): weights[outcome.face-1] += outcome.weight
		for face in range(1,7): check(is_equal_approx(weights[face-1],0.0 if face == previous else 0.2),"CLI forecast uses the exact protected distribution")
	print("Single-die reroll guarantee: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
