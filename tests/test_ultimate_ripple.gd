extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func prepare(values: Array) -> void:
	game._restart()
	game.result = game.model.set_test_roll(values)
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = game.skill_bubble.formation
	game.view_phase = "skill"

func wait_for_impact() -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while game.screen_ripple.age >= game.screen_ripple.DURATION and Time.get_ticks_msec() < deadline:
		await process_frame
	check(Time.get_ticks_msec() < deadline, "666 reaches its screen impact")

func visual_check() -> void:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.screen_ripple.age = 0.44
	game.screen_ripple._update_surface()
	await process_frame
	await RenderingServer.frame_post_draw
	var distorted: Image = root.get_texture().get_image()
	game.screen_ripple.surface.hide()
	game.screen_ripple.capture.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	var clean: Image = root.get_texture().get_image()
	var changed := 0
	var top_changed := 0
	var viewport_size: Vector2 = root.get_visible_rect().size
	for y in range(0, clean.get_height(), 2):
		for x in range(0, clean.get_width(), 2):
			if clean.get_pixel(x, y) != distorted.get_pixel(x, y):
				changed += 1
				if y < game.ARENA.position.y / viewport_size.y * clean.get_height(): top_changed += 1
	check(changed > 200, "GPU ripple distorts the rendered scene")
	check(top_changed > 10, "Ripple also reaches the HUD above the battlefield")
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var layout: String = "portrait" if game is Portrait else "landscape"
	distorted.save_png("res://test-output/ripple-%s.png" % layout)
	clean.save_png("res://test-output/ripple-%s-clean.png" % layout)
	game.process_mode = Node.PROCESS_MODE_INHERIT

func run() -> void:
	game = Portrait.new() if "--portrait" in OS.get_cmdline_user_args() else Battle.new()
	root.add_child(game)
	game.muted = true
	game.speed = 20
	prepare([6,6,6])
	game._begin_cinematic(true)
	check(not game.screen_ripple.surface.visible, "Revealing 666 does not slam before activation")
	var point: Vector2 = game.ARENA.get_center()
	var rng: int = game.model.rng.state
	game._activate_skill(-1, point)
	await create_timer(0.1).timeout
	check(game.skill_bubble.display_center().y < point.y and game.skill_bubble.slam_scale() > 1, "666 rises and enlarges before slamming")
	check(not game.screen_ripple.surface.visible, "Wave waits until the impact")
	check(is_equal_approx(game.skill_bubble.self_modulate.a, game.skill_bubble.CAST_OPACITY), "Slam preserves the transparent casting skill")
	await wait_for_impact()
	check(game.screen_ripple.origin == point, "Wave originates from the actual drop position")
	check(game.model.rng.state == rng, "Presentation does not consume combat randomness")
	check(game.screen_ripple.layer > 0 and game.screen_ripple.surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Fullscreen pass covers the HUD without intercepting input")
	if "--visual" in OS.get_cmdline_user_args(): await visual_check()
	game.menu_open = true
	await process_frame
	var age: float = game.screen_ripple.age
	await create_timer(0.1).timeout
	check(game.screen_ripple.age == age and not game.screen_ripple.surface.visible, "Menu pauses and hides distortion")
	game.menu_open = false
	game.reduced = true
	await process_frame
	await process_frame
	check(game.screen_ripple.ripple_material.get_shader_parameter("strength") == 0.0, "Reduced effects removes screen displacement")
	game._restart()
	check(not game.screen_ripple.surface.visible and game.screen_ripple.capture.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "Restart clears the wave and disables screen copying")
	prepare([6,6,6])
	game._activate_skill(-1, point)
	await create_timer(0.08).timeout
	check(game.skill_bubble.slam_scale() == 1.0 and game.skill_bubble.display_center() == point, "Reduced effects keeps the casting skill motionless")
	game._restart()
	await create_timer(0.35).timeout
	check(not game.screen_ripple.surface.visible, "Canceled slam cannot leave a delayed ripple")
	game.reduced = false
	prepare([1,2,3])
	game._activate_skill(0, point)
	await create_timer(0.35).timeout
	check(not game.screen_ripple.surface.visible, "Ordinary skills do not ripple")
	prepare([2,3,4])
	game.model.saved_skill = game.Rules.classify([6,6,6])
	game._sync_saved_bubble()
	game.skill_source = "saved"
	game._activate_skill(-1, point)
	await wait_for_impact()
	check(game.casting_source == "saved" and game.screen_ripple.origin == point, "Stored 666 uses the same slam")
	game._restart(Waves.COUNT)
	game.debug_choice = 12
	game._roll()
	await wait_for_impact()
	check(game.model.is_city() and game.view_phase == "resolving", "City auto-cast also triggers the slam")
	await create_timer(1.3).timeout
	check(not game.screen_ripple.surface.visible and game.screen_ripple.capture.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "Finished ripple removes its fullscreen pass")
	game._restart()
	game.queue_free()
	await process_frame
	print("Ultimate ripple: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
