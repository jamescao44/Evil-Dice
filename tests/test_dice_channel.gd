extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for portrait in [false, true]:
		var game = Portrait.new() if portrait else Battle.new()
		root.add_child(game)
		game.muted = true
		game.speed = 2
		for choice in [0, 2, 11, 12]:
			game._restart()
			game.debug_choice = choice
			var before: int = game.model.enemies[0].hp
			game._roll()
			var deadline: int = Time.get_ticks_msec() + 5000
			while game.fx.dice_power.is_empty() and Time.get_ticks_msec() < deadline:
				await process_frame
			check(not game.fx.dice_power.is_empty(), "Roll starts a number-transfer animation in either layout")
			if game.fx.dice_power.is_empty(): continue
			var flow: Dictionary = game.fx.dice_power
			check(flow.sources.size() == (2 if choice == 2 else 3), "Only matching dice are extracted for combinations")
			check(flow.merge == (choice == 0), "Only regular attacks combine into one total")
			check(flow.sum == game.result.sum, "Transferred total matches the committed dice")
			check(flow.target == game._player_point(), "Transfer lands on the Horror in the active layout")
			check(game.model.phase == "player" and game.model.enemies[0].hp == before, "Combat waits for dice energy to arrive")
			check(game.fx.skill.is_empty(), "Skill title follows the transfer instead of overlapping it")
			var state: int = game.model.rng.state
			await create_timer(0.06).timeout
			check(game.model.rng.state == state, "Number animation never consumes combat randomness")
			game._restart()
			await create_timer(0.55).timeout
			check(game.fx.dice_power.is_empty() and game.fx.skill.is_empty() and game.model.phase == "roll", "Restart cancels transfer and prevents the old action from executing")
		game.queue_free()
		await process_frame
	print("Dice channel: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
