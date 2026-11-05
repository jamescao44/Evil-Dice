extends SceneTree
## Real input paths must preserve underlying scenes and their clocks while menus are open.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
var wait_finished := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func tap(g, point: Vector2) -> void:
	g._handle_click(point); g._handle_release(point)
func open_menu(g) -> void:
	tap(g,g.MENU_RECT.get_center())
	check(g.menu_open and g.menu_canvas.visible,"Menu opens immediately above the current scene")
func resume(g) -> void:
	tap(g,g.MENU_RESUME.get_center())
	check(not g.pause_menu.active(),"Resume closes only the system page")
func timed_wait(g) -> void:
	wait_finished = false
	await g._wait(0.16,g.run_id)
	wait_finished = true

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	for phase in ["ready","rolling","forming","resolving","enemy","frozen","transition","wave_reward","reward","shop","over"]:
		g.view_phase = phase
		var rng: int = g.model.rng.state
		open_menu(g); resume(g)
		check(g.view_phase == phase and g.model.rng.state == rng,"Menu does not mutate "+phase)
	g.view_phase = "ready"
	g._show_events([g.model.event(0,1,"charge","1 / 3")])
	check(g.fx.floats.any(func(f): return f.text == "Charging...") and not g.fx.floats.any(func(f): return f.text == "+ BOON"),"Enemy charge announces Charging instead of a boon")
	GameText.set_language("zh_CN",false)
	check(GameText.text("Charging...") == "蓄力中…","Charge announcement is localized")
	# Closing the system page cannot dismiss the inspection below it.
	g.tarot_feedback.inspection.opened = true
	open_menu(g); resume(g)
	check(g.tarot_feedback.inspection.opened,"Inspection survives menu/resume input")
	g.tarot_feedback.inspection.opened = false
	g.inventory_page.opened = true
	open_menu(g)
	check(g.pause_menu.z_index > g.inventory_page.z_index and g.menu_canvas.z_index > g.pause_menu.z_index,"Shortcut and menu cover inventory and held objects")
	resume(g); check(g.inventory_page.opened,"Inventory remains open after resume")
	check(not g.inventory_page.close_rect().intersects(g.MENU_RECT),"Inventory close stays clear of the menu shortcut")
	g.inventory_page.opened = false
	# The charge timer resumes, rather than silently canceling or jumping ahead.
	var rolls_before: int = g.model.dice_turn.rolls_left
	g._start_charge(); await create_timer(0.05).timeout
	open_menu(g)
	var elapsed: float = g.throw_meter.elapsed
	await create_timer(0.12).timeout
	check(g.view_phase == "charging" and is_equal_approx(g.throw_meter.elapsed,elapsed),"Perfect timer freezes without canceling the throw")
	resume(g); await create_timer(0.05).timeout
	check(g.throw_meter.elapsed > elapsed and g.model.dice_turn.rolls_left == rolls_before,"Perfect timer resumes without spending a roll")
	g._cancel_charge()
	# Dice animation and combat waits use the same pause barrier.
	g.view_phase = "rolling"; g.dice[0].reroll_to(5,1)
	open_menu(g); elapsed = g.dice[0].elapsed
	await create_timer(0.12).timeout
	check(g.dice[0].rolling and g.dice[0].elapsed == elapsed,"Single reroll holds its exact frame")
	resume(g); await create_timer(0.6).timeout
	check(not g.dice[0].rolling and g.dice[0].face == 5,"Reroll finishes once after resuming")
	g.view_phase = "resolving"; timed_wait(g); open_menu(g)
	await create_timer(0.2).timeout
	check(not wait_finished,"Attack delay cannot advance behind menu")
	resume(g); await create_timer(0.22).timeout
	check(wait_finished,"Attack delay resumes normally")
	# Pausing the transition tween must retain it rather than completing the wave.
	g.view_phase = "transition"; g.travel_progress = 0
	g.transition_tween = g.create_tween()
	g.transition_tween.tween_property(g,"travel_progress",1.0,0.18)
	open_menu(g); await create_timer(0.24).timeout
	check(g.transition_tween.is_valid() and not g.transition_tween.is_running() and g.travel_progress == 0,"Route travel stays pending while paused")
	check(g.player_animation.walk_progress == 0,"Paused travel cannot advance the walking cycle")
	resume(g); await create_timer(0.25).timeout
	check(is_equal_approx(g.travel_progress,1) and not g.transition_tween.is_valid(),"Route travel completes after resume")
	check(g.player_animation.walk_progress == 1 and g.player_animation.frame_number() == 22,"Walking finishes its second loop with the movement after resuming")
	# System menus pause even an unskippable Ultra, with its audio and outcomes intact.
	g.view_phase = "reward"
	g.chest.start([0,1,2,3,4],g.fx.canvas_size,g.pixel_font,false,[],3)
	g.chest.open_chest(); g.chest.audio_clock_enabled = false
	open_menu(g); elapsed = g.chest.elapsed
	var prizes: Array = g.chest.rewards.duplicate()
	await create_timer(0.12).timeout
	check(g.chest.elapsed == elapsed and g.chest.audio.payout.stream_paused and g.chest.rewards == prizes,"Ultra timing, music and committed prizes pause together")
	resume(g); await create_timer(0.05).timeout
	check(g.chest.elapsed > elapsed and not g.chest.audio.payout.stream_paused,"Ultra resumes without restarting audio")
	# Tarot draws still leave already-started payout audio playing.
	g.chest.reveal_age = 0.1
	g.tarot_ui.ceremony.start(["magician","sun","world"],g.fx.canvas_size,g.pixel_font,g.DICE_CENTER,true)
	g.pause_menu.sync_pause()
	check(not g.chest.audio.payout.stream_paused,"Drawing tarot still preserves payout music")
	open_menu(g)
	var state: String = g.tarot_ui.ceremony.state
	await create_timer(0.15).timeout
	check(g.tarot_ui.ceremony.state == state and g.chest.audio.payout.stream_paused,"Menu can interrupt tarot preparation without skipping it")
	resume(g); check(g.tarot_ui.ceremony.state == state,"Resume tap does not skip the underlying ceremony")
	g.tarot_ui.ceremony.reset(); g.chest.cancel()
	g.view_phase = "shop"; g.model.shop.open_debug(g.model); g.shop_ui.open()
	check(not g.inventory_page.button_rect().intersects(g.MENU_RECT),"Shop backpack stays clear of the menu shortcut")
	var money: int = g.model.blood_gems
	open_menu(g); tap(g,g.GUIDE_RECT.get_center())
	check(g.guide and g.model.blood_gems == money,"Shop cannot intercept Help controls")
	tap(g,g.GUIDE_CLOSE.get_center()); resume(g)
	check(g.view_phase == "shop" and g.model.shop.active,"Help returns to the same shop")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/universal-menu-shop-"+str(phone)+".png")
	g._restart(); await create_timer(0.1).timeout
	g.queue_free(); await process_frame
	await create_timer(0.1).timeout

func run() -> void:
	for phone in [true,false]: await scene(phone)
	print("Universal menu: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
