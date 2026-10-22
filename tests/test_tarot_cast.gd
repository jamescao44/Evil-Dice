extends SceneTree
## Exercise real tap/drag routes, modal cancellation and animated tarot turn flow.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func tap(game, at: Vector2) -> void:
	game._handle_click(at); game._handle_release(at)
func give_front(game,id: String) -> Dictionary:
	var card: Dictionary = game.model.tarots.add(id)
	game.tarot_ui.focus_instance(card.instance_id)
	game.tarot_ui.expansion = 1
	game.tarot_ui.swallow_release = false
	return card
func drag(game, target: Vector2) -> void:
	var at: Vector2 = game.tarot_ui.carousel_pose(game.tarot_ui.front_index()).at
	game._handle_click(at); game._handle_motion(at-Vector2(0,70)); game._handle_motion(target); game._handle_release(target)
func settle(game) -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while game.tarot_cast.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not game.tarot_cast.busy,"Cast animation completes")
func capture(game,label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/tarot-cast-%s-%s.png" % ["portrait" if game is Portrait else "landscape",label])
func prepare_roll(game, values: Array = [1,2,3,4,5,6]) -> void:
	game.model.roll_pool(false,values)
	while not game.model.roll_attacks.is_empty(): game.model.resolve_roll_attack_step()
	for i in range(6): game.dice[i].face = game.model.dice_turn.values[i]; game.dice[i].final_face = game.dice[i].face
	game.view_phase = "ready"
func tough_enemies(game) -> void:
	for e in game.model.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
func scene_checks(game) -> void:
	root.content_scale_size = Vector2i(804,1748) if game is Portrait else Vector2i(1280,800)
	root.size = root.content_scale_size
	root.add_child(game); game.muted = true; game.speed = 5; tough_enemies(game)
	var ui = game.tarot_ui
	var cast_ui = game.tarot_cast
	var drop: Vector2 = game.ARENA.get_center()
	give_front(game,"strength"); tap(game,ui.carousel_pose(ui.front_index()).at)
	check(ui.inspected == ui.front_index(),"Card inspects inline")
	drag(game,drop); await settle(game)
	check(game.model.tarot_effects.strength == 1,"Dragging inspected card casts")
	prepare_roll(game)
	var magician: Dictionary = give_front(game,"magician")
	drag(game,drop)
	check(cast_ui.choice_type == "magician" and not ui.inventory_visible(),"Magician exposes dice and waits without consuming")
	cast_ui._process(0.2)
	check(game.dice.all(func(d): return d.magician_hint),"All eligible dice pulse")
	check(not game.dice_selection.available(),"Regular selection cannot compete with Magician")
	await capture(game,"magician-pulse")
	tap(game,game.DICE_CENTER)
	check(cast_ui.choice_type.is_empty() and game.model.tarots.find_instance(magician.instance_id) >= 0 and ui.opened,"Cancel returns the same unconsumed card")
	while ui.expansion < 0.98: await process_frame
	drag(game,drop)
	check(cast_ui.choice_type == "magician","Reopen Magician after cancellation")
	for index in range(6):
		tap(game,game.DICE_POSITIONS[index])
		check(cast_ui.magician_choice.selected == index,"Every unused die opens its face ring")
		for face in range(1,7):
			var at: Vector2 = cast_ui.magician_choice.face_center(game,face)
			check(Rect2(Vector2.ZERO,game.fx.canvas_size).grow(-28).has_point(at),"All six face options stay on screen")
		tap(game,cast_ui.magician_choice.face_center(game,game.model.dice_turn.values[index]))
		check(cast_ui.choice_type == "magician" and cast_ui.magician_choice.selected == index,"Current face is dimmed and not selectable")
		tap(game,cast_ui.magician_choice.selected_center(game))
		check(cast_ui.magician_choice.selected == -1,"Tap chosen die again deselects only the die")
	tap(game,game.DICE_POSITIONS[0]); await capture(game,"magician-ring")
	tap(game,cast_ui.magician_choice.face_center(game,6)); await settle(game)
	check(game.model.dice_turn.values[0] == 6 and game.dice[0].face == 6 and game.model.tarots.find_instance(magician.instance_id) == -1,"Face choice commits and updates visible die")
	check(game.model.roll_attacks.is_empty() and game.view_phase == "ready","Magician returns controls without auto attacks")
	give_front(game,"high_priestess"); drag(game,drop); await settle(game)
	check(game.dice[1].face == 3 and game.dice[5].face == 6,"Priestess synchronizes visible faces")
	give_front(game,"hanged_man"); drag(game,drop)
	var ban: String = cast_ui.options()[0]
	var columns: int = 4 if ui.portrait() else 6
	tap(game,cast_ui.cell_rect(0,columns,ceili(cast_ui.options().size()/float(columns))).get_center()); await settle(game)
	check(ban in game.model.tarot_effects.banned,"Ban chooser remains usable")
	game._restart(); tough_enemies(game); prepare_roll(game); game.model.hp = 20
	give_front(game,"temperance"); drag(game,drop)
	var deadline: int = Time.get_ticks_msec()+10000
	while (cast_ui.busy or game.model.round_number < 2 or game.view_phase != "ready") and Time.get_ticks_msec() < deadline: await process_frame
	check(game.view_phase == "ready" and game.model.dice_turn.rolls_left == 5,"Temperance completes healing/enemies and resumes with five throws")
	check(game.model.reroll_progress == 0,"Transferred throws do not reward the old turn")
	game._restart(); tough_enemies(game); prepare_roll(game)
	game.model.acquire_relic("ancient_prophecy")
	give_front(game,"magician"); drag(game,drop)
	tap(game,game.DICE_POSITIONS[0]); tap(game,cast_ui.magician_choice.face_center(game,2)); await settle(game)
	check(cast_ui.choice_type == "magician" and cast_ui.instance_id < 0,"Prophecy asks for a second die edit")
	tap(game,game.DICE_POSITIONS[1]); tap(game,cast_ui.magician_choice.face_center(game,6)); await settle(game)
	check(game.model.dice_turn.values == [2,6,3,4,5,6] and game.view_phase == "ready","Second edit finishes independently")
	give_front(game,"justice"); drag(game,drop); await settle(game)
	check(game.model.dice_turn.rolls_made == 3 and game.model.dice_turn.rolls_left == 2 and game.view_phase == "ready","Repeated Justice animates two complete free rolls")
	game._restart(); tough_enemies(game)
	game.model.apply_affliction(game.Status.FROZEN,1); game.model._prepare_player_turn(); game.view_phase = "frozen"
	give_front(game,"hierophant"); drag(game,drop); await settle(game)
	check(game.view_phase == "ready" and game.model.phase == "roll" and not game.model.is_frozen(),"Hierophant can be dragged while frozen and restores controls")
	game._restart()
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]: game.model.acquire_relic(id)
	var emperor: Dictionary = give_front(game,"emperor"); drag(game,drop)
	check(cast_ui.choice_type == "replace" and game.inventory_page.opened,"Full inventory opens replacement backpack")
	tap(game,game.inventory_page.close_rect().get_center())
	check(game.model.tarots.find_instance(emperor.instance_id) >= 0,"Cancel first Emperor retains card")
	while ui.expansion < 0.98: await process_frame
	drag(game,drop); var offered: String = cast_ui.prepared.relic
	tap(game,game.inventory_page.slot_rect(4).get_center()); tap(game,game.inventory_page.replace_rect().get_center()); await settle(game)
	check(game.model.relics.items[4].id == offered,"Replacement consumes the card and inserts selected relic")
	game._restart(); game.view_phase = "rolling"; tap(game,ui.icon_rect().get_center())
	check(not ui.opened,"Disabled tarot icon cannot interrupt a roll")
	game.queue_free(); await process_frame
func run() -> void:
	GameText.set_language("en" if "--english" in OS.get_cmdline_user_args() else "zh_CN",false)
	await scene_checks(Battle.new())
	await scene_checks(Portrait.new())
	print("Tarot cast UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
