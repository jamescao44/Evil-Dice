extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var game
var prefix: String

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + prefix + label + ".png")

func run() -> void:
	for portrait in [false,true]:
		game = Portrait.new() if portrait else Battle.new()
		root.add_child(game)
		game.muted = true
		prefix = "skills-portrait-" if portrait else "skills-landscape-"
		await shot("layout")
		game.model.statuses[2].count = 4
		game.model.statuses[3].count = 5
		game.model.statuses[6].count = 2
		game.model.statuses[33].count = 1
		await shot("active-boons")
		game.guide = true
		await shot("active-boon-guide")
		game.guide = false
		if portrait:
			for item in game._active_statuses():
				game.selected_status = item.id
				game.status_until = game.clock_time + 5
				await shot("boon-description-" + str(item.id))
			game.selected_status = -1
		game._restart()
		for sample in [{"values": [2,4,6], "face": 0, "name": "normal"}, {"values": [5,2,5], "face": 5, "name": "double"}, {"values": [4,4,4], "face": 4, "name": "triple"}]:
			for i in range(3): game.dice[i].face = sample.values[i]
			game.fx.channel_dice(sample.values, game.DICE_POSITIONS, game.DICE_CENTER, game._player_point(), sample.face, game.GOLD, 1.0)
			game.fx.set_process(false)
			for moment in [{"age": 0.04, "name": "extract"}, {"age": 0.4, "name": "gather"}, {"age": 0.66, "name": "fly"}]:
				game.fx.dice_power.age = moment.age
				game.fx.queue_redraw()
				await shot(sample.name + "-" + moment.name)
			game.fx.clear()
			game.fx.set_process(true)
		game.model.stage = 1
		game.model._load_wave()
		game._start_round()
		for enemy in game.model.enemies:
			enemy.hp = 500
			enemy.max_hp = 500
		game.debug_choice = 11
		game._roll()
		while game.model.phase != "executing": await process_frame
		await shot("multi-hit")
		while game.view_phase not in ["ready","over"]: await process_frame
		game.guide = true
		if portrait: game.guide_page = 0
		await shot("pairs")
		if portrait: game.guide_page = 1
		await shot("triples")
		game.model.stage = 9
		game.model._load_wave()
		await shot("city-guide")
		game.queue_free()
		await process_frame
	quit()
