extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func capture(g, label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	g.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/tower-%s-%s.png" % ["portrait" if g is Portrait else "landscape",label])
func start_tower(g) -> void:
	var card: Dictionary = g.model.tarots.add("tower")
	g.tarot_ui.opened = true
	g.tarot_ui.expansion = 1
	g.tarot_cast.request(card.instance_id,g.ARENA.get_center(),g.DICE_CENTER)
func finish_cast(g) -> void:
	var deadline: int = Time.get_ticks_msec()+4000
	while g.tarot_cast.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not g.tarot_cast.busy,"Tower burst finishes without leaving input locked")
func scene_checks(g) -> void:
	if not g is Portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	root.add_child(g)
	await process_frame
	g.muted = true
	g.model.acquire_relic("heart")
	g.model.set_test_roll([4,4,2])
	g.result = g.model.pending.duplicate()
	g.skill_bubble.begin(g.result)
	g.skill_bubble.age = 3
	g.view_phase = "skill"
	g.model.saved_skill = g.model.classify([5,5,3])
	g._sync_saved_bubble()
	g._handle_click(g._skill_center())
	g._handle_motion(g.relic_ui.inventory_rect().get_center())
	await process_frame
	check(g.skill_dragging and g.skill_bubble.z_index > g.relic_ui.z_index and g.skill_bubble.z_index > g.saved_bubble.z_index,"Dragged current skill draws above inventory and saved skill")
	await capture(g,"skill-over-bar")
	g._handle_motion(g._saved_slot_center())
	await capture(g,"skill-over-saved")
	g._cancel_targeting()
	await process_frame
	check(g.skill_bubble.z_index == 40,"Cancel restores the current skill's regular layer")
	g._handle_click(g._saved_slot_center())
	g._handle_motion(g.relic_ui.inventory_rect().get_center())
	await process_frame
	check(g.skill_dragging and g.saved_bubble.z_index > g.relic_ui.z_index and g.saved_bubble.z_index > g.skill_bubble.z_index,"Dragged saved skill also draws on top")
	g._cancel_targeting()
	g._handle_click(g.relic_ui.slot_rect(0).get_center())
	await process_frame
	check(g.relic_ui.z_index == g.HELD_ITEM_Z,"Held relic uses the same foreground layer")
	g._handle_release(g.relic_ui.slot_rect(0).get_center())
	await process_frame
	check(g.relic_ui.z_index == 110,"Released relic restores inventory layering")
	g._restart()
	g.model.tarots.add("tower")
	g.tarot_ui.opened = true
	g.tarot_ui.expansion = 1
	var origin: Vector2 = g.tarot_ui.carousel_pose(0).at
	g._handle_click(origin)
	g._handle_motion(origin-Vector2(0,100))
	await process_frame
	check(g.tarot_ui.gesture == "card" and g.tarot_ui.z_index == g.HELD_ITEM_Z,"Dragged tarot uses the same foreground layer")
	g._handle_release(origin)
	await process_frame
	check(g.tarot_ui.z_index == 120,"Released tarot restores its regular layer")
	g._restart()
	g.speed = 20
	var started: int = Time.get_ticks_msec()
	start_tower(g)
	check(g.tarot_cast.busy and g.model.tarot_effects.pending_steps.size() == 10,"Casting Tower reserves ten pending applications")
	var previous: int = 10
	var changes: int = 0
	var deadline: int = Time.get_ticks_msec()+4000
	while g.tarot_cast.busy and Time.get_ticks_msec() < deadline:
		await process_frame
		var remaining: int = g.model.tarot_effects.pending_steps.size()
		if remaining != previous:
			check(remaining == previous-1,"Tower applies only one status per animation beat")
			changes += 1
			previous = remaining
			if remaining == 8: await capture(g,"burst")
	check(changes == 10 and not g.tarot_cast.busy,"All ten applications finish in order")
	check(Time.get_ticks_msec()-started >= 1000,"Fast-forward does not collapse Tower into an unreadable burst")
	check(g.view_phase in ["ready","frozen"],"The burst restores the correct player interaction")
	g._restart()
	start_tower(g)
	await create_timer(0.15).timeout
	g._restart()
	await create_timer(0.2).timeout
	check(g.model.tarot_effects.pending_steps.is_empty() and g.model.statuses.values().all(func(effect): return effect.count == 0) and g.view_phase == "ready","Restart invalidates the old burst coroutine")
	g._restart(Waves.COUNT)
	start_tower(g)
	g.model.hp = 1
	g.model.volley_clock = 0.01
	await finish_cast(g)
	check(g.view_phase == "over" and g.model.tarot_effects.pending_steps.is_empty(),"City defeat interrupts and clears the unfinished burst")
	g.queue_free()
	await process_frame
func run() -> void:
	await scene_checks(Battle.new())
	await scene_checks(Portrait.new())
	print("Held layers and Tower: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
