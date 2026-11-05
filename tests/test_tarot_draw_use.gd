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
		var original: Dictionary = g.model.tarots.add("empress")
		draw_for(g,["empress","sun","magician"],"shop")
		var draw = g.tarot_ui.ceremony
		var rng: int = g.model.rng.state
		var reward_rng: int = g.model.reward_rng.state
		for i in range(12): check(draw.can_use_selected(),"Empress is eligible as an immediate reward")
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
		check(not draw.active() and g.model.tarot_source.is_empty() and g.model.tarots.items.size() == 3,"Keep and Use closes the draw and grants two rewards exactly once")
		check(g.model.tarots.find_instance(original.instance_id) >= 0,"Only the newly drawn copy is consumed")
		await settle(g)
		check(g.view_phase == "shop" and g.model.shop.active and g.model.shop.divination_used,"Draw quick-use returns to the same shop and spends its free draw")
		draw_for(g,["sun","magician","strength"])
		g.model.hp = 40
		check(not draw.can_use_selected() and draw.use_rect() == Rect2(),"Even useful healing has no acquisition use button")
		tap(g,draw.keep_rect().get_center())
		check(draw.state == "collect" and g.model.tarots.items.any(func(c): return c.id == "sun"),"Ordinary Keep still saves an ineligible card")
		draw.advance(1)
		g.model.shop.close(); g.shop_ui.cancel(); g.view_phase = "ready"
		g.model.roll_pool(false,[1,2,3,4,5,6])
		draw_for(g,["strength","sun","death"])
		for id in g.model.Tarot.ITEMS:
			if g.model.Tarot.immediate_reward(id): continue
			g.model.tarot_choices[0] = id; draw.choices[0] = id
			check(not draw.can_use_selected() and draw.use_rect() == Rect2(),"Combat/choice cards must be kept: "+id)
		g.model.tarot_choices[0] = "strength"; draw.choices[0] = "strength"
		g.tarot_ui._collect(0,true)
		check(draw.active() and g.model.tarot_effects.strength == 0,"Calling collection directly cannot bypass eligibility")
		tap(g,draw.keep_rect().get_center()); draw.advance(1)
		var strength: Dictionary = g.model.tarots.items.filter(func(c): return c.id == "strength")[0]
		check(not g.model.tarot_effects.cast(g.model,strength.instance_id).has("error") and g.model.tarot_effects.strength == 1,"Saved Strength can still be deliberately used from inventory")
		g.view_phase = "wave_reward"
		draw_for(g,["strength","star","sun"])
		check(not draw.can_use_selected(),"Noncombat reward screens do not bypass normal tarot availability")
		g._restart(); g.queue_free(); await process_frame
	print("Draw Keep and Use: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
