extends SceneTree
## Draw quick-use shares real card choices and never consumes another owned copy.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

## Skip only presentation in fixtures; card acquisition still uses the real transaction.
func draw_for(g, cards: Array, source: String = "debug") -> void:
	check(g.tarot_ui.begin_reward(source),"Open an independent draw")
	g.model.tarot_choices = cards.duplicate()
	var draw = g.tarot_ui.ceremony
	draw.choices = cards.duplicate()
	draw.state = "choose"; draw.selected = 0
	for i in range(3): draw.draws.append({"from":draw.row_point(i),"angle":0.0,"age":1.0})

func settle(g) -> void:
	for frame in range(400):
		if not g.tarot_cast.active() and not g.relic_ui.pickup.active: break
		await process_frame
	check(not g.tarot_cast.active(),"Casting settles back to a decision point")

func run() -> void:
	for phone in [true,false]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 20; g.set_process_input(false)
		g.model.shop.open_debug(g.model); g.view_phase = "shop"; g.shop_ui.open()
		var original: Dictionary = g.model.tarots.add("strength")
		draw_for(g,["strength","sun","magician"],"shop")
		var draw = g.tarot_ui.ceremony
		var rng: int = g.model.rng.state
		var reward_rng: int = g.model.reward_rng.state
		for i in range(12): check(draw.can_use_selected(),"Strength is eligible after keeping it")
		check(g.model.tarots.items.size() == 1 and g.model.tarot_effects.strength == 0 and g.model.rng.state == rng and g.model.reward_rng.state == reward_rng,"Eligibility never grants, consumes, changes effects or rolls rewards")
		for locale in ["en","zh_CN"]:
			GameText.set_language(locale,false)
			for rect in [draw.keep_rect(),draw.use_rect()]:
				check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(rect),"Draw actions fit the screen")
			check(not draw.keep_rect().intersects(draw.use_rect()),"Draw actions have separate hit areas")
			for label in ["KEEP THIS CARD","KEEP AND USE"]:
				check(g.description_font.get_string_size(GameText.text(label),HORIZONTAL_ALIGNMENT_LEFT,-1,28 if phone else 22).x < draw.keep_rect().size.x-20,"Localized action text fits its button")
			await process_frame; await process_frame
			if DisplayServer.get_name() != "headless":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://test-output/draw-use-"+("phone" if phone else "desktop")+"-"+locale+".png")
		var at: Vector2 = draw.use_rect().get_center()
		tap(g,at); tap(g,at)
		check(not draw.active() and g.model.tarot_source.is_empty() and g.model.tarot_effects.strength == 1,"Keep and Use closes the draw and activates exactly once")
		check(g.model.tarots.items.size() == 1 and g.model.tarots.find_instance(original.instance_id) >= 0,"Only the newly drawn copy is consumed")
		await settle(g)
		check(g.view_phase == "shop" and g.model.shop.active and g.model.shop.divination_used,"Draw quick-use returns to the same shop and spends its free draw")
		draw_for(g,["sun","magician","strength"])
		check(not draw.can_use_selected() and draw.use_rect() == Rect2(),"Ineligible Sun at full health has no use button")
		tap(g,draw.keep_rect().get_center())
		check(draw.state == "collect" and g.model.tarots.items.any(func(c): return c.id == "sun"),"Ordinary Keep still saves an ineligible card")
		draw.advance(1)
		draw_for(g,["hanged_man","strength","star"])
		tap(g,draw.use_rect().get_center())
		check(g.tarot_cast.choice_type == "hanged_man","Drawn choice cards open their normal picker")
		tap(g,g.tarot_cast.cancel_rect().get_center())
		check(g.view_phase == "shop" and g.model.tarots.items.any(func(c): return c.id == "hanged_man"),"Cancelling keeps the unused chosen card")
		g.model.shop.close(); g.shop_ui.cancel(); g.view_phase = "ready"
		g.model.roll_pool(false,[1,2,3,4,5,6])
		draw_for(g,["magician","strength","star"])
		tap(g,draw.use_rect().get_center())
		check(g.tarot_cast.choice_type == "magician","Drawn Magician opens the die picker after a roll")
		g.tarot_cast.cancel_choice(); g.tarot_ui.close_inventory()
		check(g.model.tarots.items.any(func(c): return c.id == "magician"),"Cancelling Magician retains it")
		draw_for(g,["death","strength","star"])
		check(draw.can_use_selected(),"Death is eligible when a legal enemy is present")
		tap(g,draw.use_rect().get_center())
		check(g.tarot_cast.choice_type == "target" and g.model.living().size() > 0,"Drawn Death waits for explicit target selection")
		g.tarot_cast.cancel_choice(); g.tarot_ui.close_inventory()
		check(g.model.tarots.items.any(func(c): return c.id == "death"),"Cancel target selection keeps Death")
		g.view_phase = "wave_reward"
		draw_for(g,["strength","star","sun"])
		check(not draw.can_use_selected(),"Noncombat reward screens do not bypass normal tarot availability")
		g._restart(); g.queue_free(); await process_frame
	print("Draw Keep and Use: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
