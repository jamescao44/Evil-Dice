extends SceneTree
## Real HP waits for XP receipts and completed celebrations; CLI has no visual delay.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const DebugLevel = preload("res://scripts/player/character_debug.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Reset only isolated fixtures, never a campaign or the user's checkpoint.
func fresh(game, level: int = 1) -> void:
	game._restart(1)
	game.model.character_level = level
	game.evolution.reset()
	game.soul_pickup.reset()
	game.model.hp = 250

func scene(phone: bool) -> void:
	var game = Portrait.new() if phone else Battle.new()
	root.add_child(game); game.muted = true; game.set_process(false); game.set_process_input(false)
	game.evolution.set_process(false); game.soul_pickup.set_process(false)
	fresh(game)
	var model = game.model
	var effect = game.evolution
	model.gain_souls(10); game.soul_pickup.enqueue(game._player_point(),10)
	check(model.character_level == 2 and model.hp == 250,"XP updates the level without healing before its pickup")
	effect._process(5)
	check(effect.displayed_level == 1 and model.hp == 250,"Neither the level display nor HP jumps ahead of soul receipts")
	game.soul_pickup.advance(5); effect._process(0.1)
	check(effect.displayed_level == 2 and model.hp == 250,"The level-up effect appears before healing")
	game.menu_open = true; effect._process(5)
	check(model.hp == 250,"Pausing the celebration also pauses its heal")
	game.menu_open = false; effect._process(effect.duration()-effect.age-0.01)
	check(model.hp == 250,"HP stays unchanged until the final part of the celebration")
	effect._process(0.02)
	check(model.hp == model.max_hp and not effect.active() and model.pending_level_heals.is_empty(),"Animation completion heals fully and consumes its pending grant")
	check(game.health_trails.value(-1,model.hp) == model.hp,"Health trail refreshes with the heal instead of showing old damage")
	model.hp = 400; effect._process(5)
	check(model.hp == 400,"Idle frames cannot apply the completed heal again")
	# Both evolution clips include the entire entrance and its light fading away.
	for previous_level in [4,9]:
		fresh(game,previous_level); model.gain_souls(model.level_cost())
		effect._process(effect.REVEAL+0.01)
		check(effect.entrance.active() and model.hp == 250,"Evolution reveal does not heal while the entrance is still playing")
		effect._process(effect.duration()-effect.age-0.01)
		check(model.hp == 250,"Transformation holds the heal until its visual finishes")
		effect._process(0.02)
		check(model.hp == model.max_hp and not effect.active(),"Each evolved form heals after its complete transformation")
	fresh(game); model.gain_souls(30)
	for expected in [2,3]:
		model.hp = 300
		effect._process(0.1)
		check(effect.displayed_level == expected and model.hp == 300,"Each queued level owns a separate celebration")
		effect._process(effect.duration())
		check(model.hp == model.max_hp,"Every queued celebration heals exactly when it finishes")
	fresh(game); game.debug_open = true
	check(DebugLevel.set_level(model,10),"Debug level is accepted")
	effect.queue_debug_level(10); effect._process(10)
	check(model.hp == 250 and effect.displayed_level == 1,"Debug healing waits with the transformation while its menu is open")
	game.debug_open = false; effect._process(0.9); effect._process(effect.duration())
	check(model.hp == model.max_hp and effect.displayed_level == 10,"Closing debug lets the transformation complete before healing")
	fresh(game); model.gain_souls(10); model.hp = 0; effect._process(2)
	check(model.hp == 0 and model.pending_level_heals.is_empty(),"A pending level heal never resurrects a defeated player")
	fresh(game); model.gain_souls(10); game._restart(1); model.hp = 150
	effect._process(5)
	check(model.hp == 150 and model.pending_level_heals.is_empty(),"Restart discards heals from the previous run")
	game.queue_free(); await process_frame

func run() -> void:
	var model = Run.new(97)
	model.hp = 100; model.gain_souls(10)
	check(model.hp == model.max_hp and model.pending_level_heals.is_empty(),"CLI resolves the same level heal immediately without a renderer")
	for phone in [false,true]: await scene(phone)
	print("Level-up healing timing: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
