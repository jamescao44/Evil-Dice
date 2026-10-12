extends SceneTree
const Portrait = preload("res://scripts/battle_portrait.gd")
const Battle = preload("res://scripts/battle.gd")
const Catalog = preload("res://scripts/tarot_catalog.gd")
var failures: int = 0
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func tap(game, at: Vector2) -> void:
	game._handle_click(at)
	game._handle_release(at)
func give_front(game,id: String) -> Dictionary:
	var item: Dictionary = game.model.tarots.add(id)
	game.tarot_ui.scroll = game.model.tarots.items.size()-1
	game.tarot_ui.scroll_target = game.tarot_ui.scroll
	game.tarot_ui.swipe.reset(game.tarot_ui.scroll)
	game.tarot_ui.opened = true
	game.tarot_ui.expansion = 1
	return item
func drag(game, target: Vector2) -> void:
	var origin: Vector2 = game.tarot_ui.carousel_pose(game.tarot_ui.front_index()).at
	game._handle_click(origin)
	game._handle_motion(origin-Vector2(0,70))
	game._handle_motion(target)
	game._handle_release(target)
func settle(game) -> void:
	var deadline: int = Time.get_ticks_msec()+3500
	while game.tarot_cast.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not game.tarot_cast.busy,"Cast animation completes")
func capture(game,label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	game.queue_redraw(); game.tarot_ui.queue_redraw(); game.tarot_cast.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/tarot-cast-%s-%s.png" % ["portrait" if game is Portrait else "landscape",label])
func scene_checks(game) -> void:
	if not game is Portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	root.add_child(game)
	game.muted = true
	game.speed = 5
	for e in game.model.enemies: e.hp = 10000; e.max_hp = 10000
	var ui = game.tarot_ui
	var cast_ui = game.tarot_cast
	for id in Catalog.ITEMS: game.model.tarots.add(id)
	give_front(game,"strength")
	await capture(game,"collection")
	var front: Vector2 = ui.carousel_pose(ui.front_index()).at
	tap(game,front)
	check(ui.inspected == ui.front_index(),"Tap raises and inspects the selected card inline")
	ui._process(0.2)
	await capture(game,"floating")
	var drop: Vector2 = game.ARENA.get_center()
	drag(game,drop)
	check(game.model.tarot_effects.strength == 1,"Dragging a floating card casts it")
	await settle(game)
	give_front(game,"strength")
	drag(game,drop)
	await settle(game)
	check(game.model.tarot_effects.strength == 2,"Dragging an uninspected card also casts")
	var magician: Dictionary = give_front(game,"magician")
	drag(game,drop)
	check(cast_ui.choice_type == "magician" and game.model.tarots.find_instance(magician.instance_id) >= 0,"Magician asks for dice before consumption")
	await capture(game,"magician")
	tap(game,cast_ui.cancel_rect().get_center())
	check(cast_ui.choice_type.is_empty() and game.model.tarots.find_instance(magician.instance_id) >= 0,"Cancel keeps the same card")
	ui.scroll = game.model.tarots.find_instance(magician.instance_id); ui.scroll_target = ui.scroll; ui.swipe.reset(ui.scroll)
	drag(game,drop)
	for cell in [1,7,15]: tap(game,cast_ui.cell_rect(cell,6,4).get_center())
	tap(game,cast_ui.cell_rect(3,1,4).get_center())
	await settle(game)
	check(game.model.tarot_effects.magician == [2,2,4],"Dice picker stores the exact selected faces")
	give_front(game,"hanged_man"); drag(game,drop)
	await capture(game,"ban")
	var ban: String = cast_ui.options()[0]
	var columns: int = 4 if ui.portrait() else 6
	tap(game,cast_ui.cell_rect(0,columns,ceili(cast_ui.options().size()/float(columns))).get_center())
	await settle(game)
	check(ban in game.model.tarot_effects.banned,"Ban selector casts the chosen exclusion")
	give_front(game,"lovers"); drag(game,drop)
	await capture(game,"parity")
	tap(game,cast_ui.cell_rect(1,2,1).get_center())
	await settle(game)
	check(game.model.tarot_effects.parity == 0,"Parity selector applies even faces")
	var death: Dictionary = give_front(game,"death")
	drag(game,game.ARENA.position+Vector2(5,5))
	check(game.model.tarots.find_instance(death.instance_id) >= 0 and not cast_ui.busy,"Dropping targeted tarot away from an enemy keeps it")
	game.model.set_test_roll([2,3,4]); game.result = game.model.pending.duplicate(); game.skill_bubble.roll = game.result.duplicate(); game.view_phase = "skill"
	give_front(game,"hermit"); drag(game,drop)
	await settle(game)
	check(game.model.phase == "player" and not game.model.pending.is_empty() and game.view_phase == "skill","Free tarot cast after rolling preserves the skill and its view phase")
	await capture(game,"hidden")
	give_front(game,"temperance"); drag(game,drop)
	var deadline: int = Time.get_ticks_msec()+4000
	while game.view_phase != "ready" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.view_phase == "ready" and game.model.tarot_effects.extra_rolls == 1,"Temperance animates through the enemy turn and starts the extra-throw turn")
	game.model.tarot_effects.bonus_chests.append(1)
	game.model.reward_weights = [1,0,0,0,0,0,0]
	game.model.set_test_roll([1,2,3]); game.result = game.model.pending.duplicate(); game.skill_bubble.roll = game.result.duplicate(); game.view_phase = "skill"
	give_front(game,"star"); drag(game,drop)
	deadline = Time.get_ticks_msec()+4000
	game.chest.playback_speed = 100
	while (not game.chest.visible or game.chest.active) and Time.get_ticks_msec() < deadline: await process_frame
	check(game.view_phase == "reward" and game.chest.visible,"A bonus chest opens the rolling reward presentation after a tarot cast")
	tap(game,game.chest.skip_rect().get_center())
	deadline = Time.get_ticks_msec()+3000
	while game.view_phase == "reward" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.view_phase == "skill" and game.model.phase == "player" and not game.model.pending.is_empty(),"Bonus chest returns to the already rolled skill")
	game._restart()
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]: game.model.acquire_relic(id)
	give_front(game,"world"); drag(game,game.ARENA.get_center())
	check(cast_ui.choice_type == "replace","Full inventory opens a replacement picker")
	await capture(game,"replacement")
	tap(game,cast_ui.cell_rect(4,2,5).get_center())
	await settle(game)
	check(game.model.relics.items[4].id == "mithril_blade","Replacement selection puts the new relic into that exact slot")
	game._restart(10)
	give_front(game,"magician"); drag(game,game.ARENA.get_center())
	game.model.hp = 1; game.model.volley_clock = 0.01
	game._process(0.05)
	await process_frame
	check(game.view_phase == "over" and not ui.opened and cast_ui.choice_type.is_empty(),"City continues during choice UI and defeat dismisses the picker")
	game._restart()
	game.view_phase = "rolling"
	await capture(game,"dimmed-icon")
	check(not ui.available(),"Unavailable icon cannot open tarot")
	tap(game,ui.icon_rect().get_center())
	check(not ui.opened,"Dimmed card icon cannot steal input during a throw")
	game.queue_free()
	await process_frame
func run() -> void:
	GameText.set_language("en" if "--english" in OS.get_cmdline_user_args() else "zh_CN",false)
	await scene_checks(Battle.new())
	await scene_checks(Portrait.new())
	print("Tarot cast UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
