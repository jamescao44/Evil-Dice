extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func snapshot(label: String) -> void:
	await create_timer(0.07).timeout
	await RenderingServer.frame_post_draw
	var prefix: String = "portrait-" if "--portrait" in OS.get_cmdline_user_args() else ""
	root.get_texture().get_image().save_png("res://test-output/" + prefix + label + ".png")
func settle() -> void:
	while game.view_phase not in ["ready", "over"]: await process_frame
func clear_wave() -> void:
	game.debug_choice = 12
	await game._roll()
	await settle()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	game = Portrait.new() if "--portrait" in OS.get_cmdline_user_args() else Battle.new()
	root.add_child(game)
	game.muted = not "--audio" in OS.get_cmdline_user_args()
	await create_timer(0.2).timeout
	await snapshot("growth-1v1")
	game.debug_open = true
	await snapshot("debug-picker")
	game.debug_open = false
	game.guide = true
	await snapshot("growth-guide")
	game.guide = false
	game.debug_choice = 2
	game._roll()
	while game.fx.combo.is_empty(): await process_frame
	await create_timer(0.06).timeout
	await snapshot("pair-pop")
	await settle()
	game._restart()
	game.debug_choice = 0
	game._roll()
	while game.fx.skill.is_empty(): await process_frame
	await snapshot("normal-skill")
	await settle()
	game._restart()
	game.debug_choice = 8
	game._roll()
	while game.fx.combo.is_empty(): await process_frame
	await create_timer(0.06).timeout
	await snapshot("triple-pop")
	await settle()
	game._restart()
	game.speed = 4
	await clear_wave()
	await create_timer(0.7).timeout
	await snapshot("growth-1v3")
	game.speed = 1
	for enemy in game.model.enemies:
		enemy.hp = 1
		enemy.shield = 0
	game.debug_choice = 7
	game._roll()
	while game.view_phase == "rolling": await process_frame
	await create_timer(0.45).timeout
	await snapshot("slash-impact")
	await settle()
	await snapshot("persistent-corpse")
	game.debug_choice = 12
	await game._roll()
	await create_timer(0.8).timeout
	await snapshot("feeding")
	while game.view_phase != "transition": await process_frame
	await create_timer(0.65).timeout
	await snapshot("advancing")
	await settle()
	await snapshot("growth-1v5")
	game.speed = 4
	await clear_wave()
	await create_timer(0.7).timeout
	await snapshot("growth-1v8")
	await clear_wave()
	await create_timer(2.9).timeout
	await snapshot("city-fever")
	game.guide = true
	await snapshot("city-guide")
	game.guide = false
	game.debug_choice = 12
	game._roll()
	for i in range(4): game._handle_click(game.DICE_CENTER)
	while game.view_phase == "rolling": await process_frame
	await create_timer(0.45).timeout
	await snapshot("city-ultimate")
	await settle()
	await snapshot("city-damaged")
	await create_timer(1.6).timeout
	await snapshot("city-panic")
	await create_timer(0.15).timeout
	await snapshot("city-panic-running")
	for i in range(2):
		game.debug_choice = 12
		await game._roll()
	await snapshot("city-victory")
	var audio_deadline := Time.get_ticks_msec()+4000
	while game.get_children().any(func(child): return child is AudioStreamPlayer) and Time.get_ticks_msec()<audio_deadline:
		await process_frame
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
