extends SceneTree
const Chest = preload("res://scripts/rewards/reward_chest.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
class Context extends Node:
	var model
	var muted := true

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var chest = Chest.new()
	root.add_child(chest)
	chest.set_process(false)
	chest.audio_clock_enabled = false
	var battle = Context.new()
	battle.model = Run.new(91)
	chest.battle = battle
	battle.model.relics.add("codex_page")
	var reward_state: int = battle.model.reward_rng.state
	for seed_value in range(100):
		chest.cosmetic.seed = seed_value
		chest.start([0,0,0,0,0],Vector2(1280,800),null,false,[],3)
		check(chest.relic_symbols.codex_page not in chest.scroll_symbols,"Owned stackable relic excluded")
		for sequence in chest.sequences:
			check(sequence[0] != sequence[chest.reel_steps-1],"Loop seam is distinct")
			for i in range(1,sequence.size()):
				check(sequence[i] != sequence[i-1],"Adjacent cosmetic symbols differ")
				check(sequence[i] != chest.relic_symbols.codex_page,"Owned relic absent from strip")
		# Force a winner equal to existing filler to exercise landing-neighbor repair.
		for i in range(5): chest.rewards[i] = chest.sequences[i][chest.reel_steps-1]
		var locked: Array = chest.rewards.duplicate()
		chest.tier = seed_value % 4
		chest.roll_scroll = seed_value * 2.37
		chest.roll_phase = "spinning"
		chest._begin_settle(0)
		for i in range(5):
			var sequence: Array = chest.sequences[i]
			check(sequence[chest.reel_steps] == locked[i],"Committed prize preserved")
			for j in range(1,sequence.size()): check(sequence[j] != sequence[j-1],"Settling strip has no neighbors duplicated")
	check(battle.model.reward_rng.state == reward_state,"Cosmetic strips do not consume reward RNG")
	battle.model.relics.clear()
	chest.start([0],Vector2(1280,800),null)
	check(chest.relic_symbols.codex_page in chest.scroll_symbols,"Pool refreshes after inventory changes")
	chest.cancel()
	chest.free()
	battle.free()
	print("Chest strips: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
