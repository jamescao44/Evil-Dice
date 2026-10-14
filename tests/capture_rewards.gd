extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var game
var prefix: String

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	game.queue_redraw()
	game.chest.queue_redraw()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/treasure-" + prefix + "-" + label + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var portrait: bool = "--portrait" in OS.get_cmdline_user_args()
	prefix = "portrait" if portrait else "landscape"
	game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = true
	game.reduced = false
	game.chest.cosmetic.seed = 826
	game.model.stage = 2
	game.model._load_wave()
	game.model.enemies = [game.model.make_enemy(0,1,true)]
	game.visual_stage = 2
	game.monster_side = 288
	game._start_round()
	await capture("elite")
	game.model.stage = 8
	game.model._load_wave()
	game.visual_stage = 8
	game.model.perfect_progress = 2
	game.model.rubies = 300
	game.model.summon_shards = 4
	game.model.perfect_progress = 7
	game.monster_side = 320
	game._start_round()
	await capture("wave-nine")
	for id in [2,3,33,6]: game.model.statuses[id].count = 3
	await capture("statuses")
	game.model.statuses[3].count = 0
	game.model.statuses[6].count = 0
	await capture("statuses-expired")
	game.debug_open = true
	game.debug_perfect = true
	await capture("debug-perfect")
	game.debug_open = false
	game.view_phase = "reward"
	game.chest.start([3],game.fx.canvas_size,game.pixel_font)
	game.chest.open_chest()
	game.chest.audio_clock_enabled = false
	game.chest.playback_speed = 0
	game.chest.elapsed = 1.0
	await capture("emerging")
	game.chest.elapsed = 3.0
	await capture("single-spin")
	game.chest.start([0,6,4,1,2],game.fx.canvas_size,game.pixel_font)
	game.chest.open_chest()
	game.chest.elapsed = 3.0
	await capture("triple-spin")
	game.chest.elapsed = 10.0
	game.chest.active = false
	await capture("triple-landed")
	game.chest.active = false
	game.fx.z_index = 90
	game.fx.reveal_skill("Sharpened Hunger", "+5 base damage", game.GOLD)
	await capture("reward-name")
	for reward in [0,1,2,3,4]:
		game.chest.start([reward],game.fx.canvas_size,game.pixel_font)
		game.chest.open_chest()
		game.chest.active = false
		game.chest.elapsed = 9.0
		game.chest.collected.append(0)
		game.chest.celebrate(0)
		game.chest.elapsed += 1.2
		var item: Dictionary = game.Rewards.ITEMS[reward]
		game.fx.reveal_skill(item.name,item.text,item.color)
		await capture("effect-"+item.id)
	game.chest.cancel()
	game.queue_free()
	await process_frame
	quit()
