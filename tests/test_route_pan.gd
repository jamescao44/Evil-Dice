extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Bound real transition waits to catch routes that fail to finish or reset.
func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+6000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.backdrop.refresh()
	await process_frame; RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/route-pan-"+label+".png")

## Drive both route arrows through actual travel while checking fixed HUD and entry geometry.
func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process(false); g.set_process_input(false)
	for arrow in [0,1]:
		g._restart(2)
		for enemy in g.model.enemies: enemy.hp = 0
		g.model.wave_chest_stage = g.model.stage
		g.model.wave_reward_resolved = true
		g.model.route_choices = [g.model.WaveRewards.BLOOD_GEMS,g.model.WaveRewards.SOULS]
		var player_at: Vector2 = g._player_feet()
		var dice_at: Vector2 = g.dice[0].position
		var scroll_before: float = g.background_offset
		g._advance_wave()
		check(await until(func(): return g.wave_chest.phase == "routes"),"Completed reward presents the two route arrows")
		g._handle_click(g.wave_chest.route_rect(arrow).get_center())
		check(g.travel_direction == (Vector2.RIGHT if arrow == 0 else Vector2(1,-0.6)),"Accepted arrow locks its own travel direction")
		g._select_route(1-arrow)
		check(g.travel_direction == (Vector2.RIGHT if arrow == 0 else Vector2(1,-0.6)),"A second route tap cannot change the direction")
		check(await until(func(): return g.view_phase == "transition"),"Route starts a smooth advance transition")
		check(await until(func(): return g.travel_progress >= 0.35),"Travel reaches its intermediate pose")
		var entering: Vector2 = g._enemy_world_feet(0)-g._enemy_layout_feet(0)
		check(entering.x > 0 and (entering.y < 0 if arrow == 1 else is_zero_approx(entering.y)),"Enemies arrive from the selected right or upper-right edge")
		check(g.background_offset > scroll_before and (g.background_vertical_offset < 0 if arrow == 1 else g.background_vertical_offset == 0),"Scenery pans opposite the route direction")
		check(g._player_feet() == player_at and g.dice[0].position == dice_at,"Travel keeps the player footing and dice HUD fixed")
		await capture(g,str(portrait)+"-"+str(arrow)+"-middle")
		check(await until(func(): return g.view_phase == "ready"),"Travel returns to normal combat")
		check(g._arrival_offset() == Vector2.ZERO and g._enemy_world_feet(0).is_equal_approx(g._enemy_layout_feet(0)),"Arrival ends in the exact regular formation")
		check(is_equal_approx(g.background_vertical_offset,-576 if arrow == 1 else 0),"Accumulated vertical scenery offset is retained without a snap")
		await capture(g,str(portrait)+"-"+str(arrow)+"-arrived")
	# The shopkeeper shares the formation offset and scenery invalidates on vertical movement.
	g.view_phase = "transition"; g.travel_direction = Vector2(1,-0.6); g.travel_progress = 0.5
	g.wave_chest.present_keeper(); g.wave_chest._process(0)
	check(g.wave_chest.keeper.position.is_equal_approx(g.wave_chest.chest_rect().get_center()+g._arrival_offset()),"Shopkeeper follows the same diagonal arrival")
	g.backdrop.refresh(); var revision: int = g.backdrop.revision
	g.background_vertical_offset -= 1; g.backdrop.refresh()
	check(g.backdrop.revision == revision+1,"Vertical motion refreshes cached terrain")
	g._restart()
	check(g.travel_direction == Vector2.RIGHT and g.background_vertical_offset == 0,"Restart clears direction and vertical offset")
	g.queue_free(); await process_frame

func run() -> void:
	await layout(false); await layout(true)
	print("Directional route pan: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
