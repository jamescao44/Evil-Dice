extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var game
var prefix: String

func _initialize() -> void:
	call_deferred("run")

func snapshot(label: String) -> void:
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + prefix + label + ".png")

func frozen_charge(time: float) -> void:
	game._start_charge()
	game.set_process(false)
	game.throw_meter.elapsed = time
	for die in game.dice: die.charge(game.throw_meter.sample().power)
	game.queue_redraw()

func capture(portrait: bool) -> void:
	game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = not "--audio" in OS.get_cmdline_user_args()
	prefix = "power-portrait-" if portrait else "power-landscape-"
	await process_frame
	frozen_charge(0.15)
	await snapshot("low")
	frozen_charge(0.58)
	await snapshot("high")
	game.throw_meter.elapsed = 0.6
	game.charge_stamp = Time.get_ticks_usec()
	game._release_charge()
	game.set_process(true)
	await snapshot("perfect")
	await create_timer(0.18).timeout
	await snapshot("throw")
	while game.view_phase not in ["ready", "over"]: await process_frame
	game._restart()
	game.model.stage = 9
	game.model.power = 6.75
	game.model.max_hp = 220
	game.model.hp = 220
	game.model._load_wave()
	game.visual_stage = 9
	game.monster_side = 320
	game._start_round()
	frozen_charge(0.6)
	await snapshot("city")
	game.guide = true
	game._process(0)
	await snapshot("guide")
	game.queue_free()
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	await capture(false)
	await capture(true)
	quit()
