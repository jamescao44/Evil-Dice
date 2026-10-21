extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

## Report projection, input, and wave-entry regressions by their behavior.
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Capture optional native frames for camera, taunt and scroll-in inspection.
func capture(label: String, g) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.arena_actors.queue_redraw(); g.backdrop.refresh()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/focus-"+label+".png")

## Verify actual scene geometry and hit tests at intermediate camera positions.
func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false)
	g.set_process_input(false)
	var label: String = "portrait" if portrait else "landscape"
	for wave in range(1,20):
		g._restart(wave)
		g._update_battlefield_view(0)
		g.model.statuses[g.Status.DARKNESS].count = 3
		var status_at: Vector2 = g._status_center(g.Status.DARKNESS)
		var indicator_width: float = g._enemy_intent_rect(0).size.x
		var formation := Rect2()
		for index in g.model.living():
			var feet: Vector2 = g._enemy_layout_feet(index)
			var side: float = g._enemy_side()
			var rect := Rect2(feet-Vector2(side*0.55,side),Vector2(side*1.1,side))
			formation = rect if not formation.has_area() else formation.merge(rect)
		var player: Rect2 = g._player_sprite_rect()
		var dice_at: Vector2 = g.dice[0].global_position
		g.result = g.Rules.Patterns.classify([6,6])
		g.skill_bubble.begin(g.result)
		g.skill_bubble.age = 2
		g.view_phase = "targeting"
		g.skill_source = "current"
		g._update_battlefield_view(0.04)
		var initial: float = g.battlefield_view.zoom
		g._update_battlefield_view(0.10)
		check(g.battlefield_view.zoom >= initial and g.battlefield_view.zoom >= 1,"Camera smoothly enlarges "+label+str(wave))
		for target in g._skill_targets():
			check(g._target_at(g._enemy_point(target)) == target,"A moving target's projected center stays clickable")
		g._update_battlefield_view(0.02)
		check((g.battlefield_view.transform*formation.get_center()).distance_to(g.ARENA.get_center()) < 0.01,"Formation reaches the battlefield center after 0.16 seconds")
		g.skill_bubble._process(0.3)
		check(g.skill_bubble.center_at().y-g.skill_bubble.display_radius() > g.ARENA.end.y,"Resting aimed skill leaves enemy click areas clear")
		check(g.battlefield_view.focused and (g.battlefield_view.zoom > 1 if g._enemy_side() < 100 else g.battlefield_view.zoom >= 1),"Dense formations still enlarge")
		check(is_equal_approx(g._enemy_intent_rect(0).size.x,indicator_width*g.battlefield_view.zoom),"Enemy intent icons scale with the world")
		if wave == 1:
			check(g.battlefield_view.zoom <= 1.11,"Large enemies get only a gentle zoom")

		check(g._player_sprite_rect().is_equal_approx(g.battlefield_view.transform*player),"Player shares the same world transform")
		check(g.backdrop.transform.is_equal_approx(g.arena_actors.transform),"Scenery shares actor scale and pan")
		check(g.dice[0].global_position == dice_at,"Dice and inventory remain outside the camera")
		check(g._status_center(g.Status.DARKNESS) == status_at,"Player status controls stay fixed with the HUD")
		for target in g.model.living():
			check(g.ARENA.encloses(g._enemy_sprite_rect(target)),"Focused enemy fits the arena")
			check(g.ARENA.encloses(g._enemy_health_rect(target)),"Focused health bar fits the arena")
			check(g.ARENA.encloses(g._enemy_intent_rect(target).grow_individual(0,32*g.battlefield_view.zoom if target in g.model.taunting_enemies() else 0,0,0)),"Intent and taunt labels remain inside arena "+label+str(wave))
			for other in g.model.living():
				if target != other: check(not g._enemy_health_rect(target).grow(2).intersects(g._enemy_health_rect(other).grow(2)),"Projected health bars do not overlap")
		if wave in [1,4,10,14,18,19]: await capture(label+"-wave"+str(wave),g)
		var held: Transform2D = g.battlefield_view.transform
		var target: int = g._skill_targets()[0]
		g.fx.cast(0,g._player_point(),[g._enemy_point(target)],0.7,true,true)
		g.view_phase = "resolving"
		g._update_battlefield_view(0.1)
		check(not g.battlefield_view.focused,"Target commitment immediately starts returning, during the skill")
		var projectile: Dictionary = g.fx.projected_spell(g.fx.spell)
		check(projectile.targets[0].distance_to(g._enemy_point(target)) < 0.01,"Projectile destination follows the enemy during camera return")
		check(projectile.from.distance_to(g._player_point()) < 0.01,"Projectile origin follows the Horror during camera return")
		check(g.battlefield_view.zoom < held.get_scale().x and g.battlefield_view.zoom > 1 if held.get_scale().x > 1.001 else is_equal_approx(g.battlefield_view.zoom,1),"The casting camera eases back out immediately")
		g._update_battlefield_view(0.09)
		check(g.battlefield_view.transform.is_equal_approx(Transform2D.IDENTITY),"Camera returns exactly to normal")
	g._restart(14)
	g.result = g.Rules.Patterns.classify([4,4])
	g.view_phase = "targeting"
	g._update_battlefield_view(0.05)
	var quick_release: Transform2D = g.battlefield_view.transform
	g.view_phase = "resolving"
	g._update_battlefield_view(0.1)
	check(not g.battlefield_view.focused and g.battlefield_view.zoom < quick_release.get_scale().x,"A quick target selection also immediately reverses the zoom")
	var paladin: int = g.model.taunting_enemies()[0]
	check(g._skill_targets() == [paladin],"Taunt still restricts skill targeting after projection")
	g.model.enemies[paladin].hp = 0
	check(g.model.taunting_enemies().is_empty(),"Killed taunters immediately lose their indicator")
	g._restart(14)
	g._update_battlefield_view(1)
	g.view_phase = "transition"
	g.travel_progress = 0
	for i in g.model.living(): check(not g.ARENA.intersects(g._enemy_sprite_rect(i)),"New wave starts beyond the battlefield edge")
	g.travel_progress = 0.7
	g._update_battlefield_view(0)
	await capture(label+"-arriving",g)
	var previous: Vector2 = g._enemy_feet(0)
	g.travel_progress = 0.9
	check(g._enemy_feet(0).x < previous.x,"Advancing enemies scroll left rather than popping in")
	g.travel_progress = 1
	var arriving: Vector2 = g._enemy_feet(0)
	g.view_phase = "ready"
	check(arriving.is_equal_approx(g._enemy_feet(0)),"Wave entry joins the ready pose without a jump")
	g.result = g.Rules.Patterns.classify([1,2,3])
	g.view_phase = "targeting"
	g._update_battlefield_view(1)
	check(not g.battlefield_view.focused,"Shield and support skills do not pull focus to enemies")
	g.model.tarots.add("death")
	g.tarot_ui.gesture = "card"; g.tarot_ui.pressed_card = 0
	g.view_phase = "ready"
	g._update_battlefield_view(1)
	check(g.battlefield_view.focused,"Enemy-targeted tarot shares targeting zoom")
	g.tarot_ui.drag_feedback.amount = 0
	var outside_dim: float = g._backdrop_dim()
	g.tarot_ui.drag_feedback.amount = 1
	check(outside_dim > 0 and is_equal_approx(g._backdrop_dim(),outside_dim),"Tarot battlefield shade stays constant inside and outside the usage area")
	check(g.arena_shade.get_index() < g.arena_actors.get_index(),"Tarot shade stays below actors so targets remain bright")
	g.tarot_ui.opened = true; g.tarot_ui.expansion = 1
	g.tarot_ui.pointer = g.DICE_CENTER
	g.tarot_ui.drag_feedback.amount = 0
	await capture(label+"-tarot-outside",g)
	g.tarot_ui.pointer = g._enemy_point(0)
	g.tarot_ui.drag_feedback.amount = 1
	await capture(label+"-tarot-inside",g)
	g._restart(17)
	g.model.acquire_relic("ancient_prophecy")
	g.speed = 10
	var death: Dictionary = g.model.tarots.add("death")
	g.tarot_ui.opened = true; g.tarot_ui.expansion = 1
	g.tarot_ui.gesture = "card"; g.tarot_ui.pressed_card = 0
	g._update_battlefield_view(0.5)
	var guarded: int = g.model.taunting_enemies()[0]
	var untouched: int = g.model.living().filter(func(i): return i not in g.model.taunting_enemies())[0]
	g.tarot_cast.request(death.instance_id,g._enemy_point(untouched),g.DICE_CENTER)
	check(g.model.tarots.find_instance(death.instance_id) >= 0,"A protected tarot target cannot consume Death")
	g.tarot_cast.request(death.instance_id,g._enemy_point(guarded),g.DICE_CENTER)
	g.kill_slow_remaining = 0
	var deadline: int = Time.get_ticks_msec()+3000
	while g.tarot_cast.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not g.model.is_enemy_alive(guarded) and g.tarot_cast.choice_type == "repeat_target","Projected Death target executes and offers the Prophecy repeat")
	g._update_battlefield_view(0.5)
	var next: int = g.model.taunting_enemies()[0]
	g.tarot_cast.click(g._enemy_point(next))
	g.kill_slow_remaining = 0
	deadline = Time.get_ticks_msec()+3000
	while g.tarot_cast.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(g.model.living() == [untouched] and g.view_phase == "ready","Repeated targeting uses the same projected geometry and returns control")
	g._restart()
	check(g.battlefield_view.transform == Transform2D.IDENTITY,"Debug reload resets the camera")
	g._update_battlefield_view(0)
	await capture(label+"-normal",g)
	g.queue_free(); await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	await layout(false)
	await layout(true)
	print("Battlefield view: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
