extends SceneTree
## Debug awakenings reuse real powers and wait through Debug, pause and Help pages.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Sins = preload("res://scripts/sins/sin_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

## Repeated/unknown requests grant nothing extra; actual Food is consumed once with its real bonus.
func rules() -> void:
	var m = Run.new(96)
	m.acquire_relic("hamburger"); m.acquire_relic("worn_bow")
	var awakened: Array = []
	m.sins.awakened.connect(func(id): awakened.append(id))
	var old_max: int = m.max_hp
	check(m.sins.awaken(m,["missing"]) == 0 and awakened.is_empty(),"Unknown sins cannot unlock")
	check(m.sins.awaken(m,Sins.ORDER) == 7 and awakened == Sins.ORDER,"All sins activate once in catalog order")
	m.refresh_relic_health(old_max)
	check(m.sins.food_consumed == 1 and m.relics.items.size() == 1 and m.relics.items[0].id == "worn_bow","Gluttony consumes real Food and preserves other inventory")
	check(m.hp <= m.max_hp and m.relics.consume_food,"Removing Food keeps health valid and enables future consumption")
	check(m.sins.awaken(m,Sins.ORDER) == 0 and awakened.size() == 7 and m.sins.food_consumed == 1,"Repeating the shortcut cannot duplicate bonuses or notifications")
	var restored = Run.new(97)
	restored.sins.restore(m.sins.save())
	check(restored.sins.unlocked == Sins.ORDER,"Debug awakenings save like normal chapter powers")
	restored.reset_run()
	check(restored.sins.unlocked.is_empty(),"A fresh run resets debug awakenings")

func capture(g, name: String, phone: bool) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.menu_canvas.queue_redraw(); g.sin_view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/debug-sins-%s-%s.png" % [name,"portrait" if phone else "desktop"])

## Use actual tab/button hit areas, including closing Debug back into the ordinary pause menu.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = root.content_scale_size
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.view_phase = "ready"; g.player_animation.reset()
	g.model.chest_pity.save_path = ""
	g._open_debug()
	var ui = g.debug_page
	g._handle_menu_page_click(ui.tab_rect(ui.Page.SINS).get_center())
	check(ui.page == ui.Page.SINS and not g.debug_wave_input.visible and not ui.level_input.visible and not ui.character_input.visible,"Sin tab hides all native fields")
	check(ui.buttons().size() == 8,"One shortcut per sin plus all seven")
	var rects: Array = ui.buttons().map(func(row): return row[0])
	for tab in range(ui.TABS.size()): rects.append(ui.tab_rect(tab))
	for i in range(rects.size()):
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(rects[i]),"New controls remain on screen")
		for j in range(i): check(not rects[i].intersects(rects[j]),"Tabs and shortcuts do not overlap")
	await capture(g,"options",phone)
	var items: Array = g.model.relics.items.duplicate(true)
	var rng_state: int = g.model.rng.state
	g._handle_menu_page_click(ui.reward_rect(Sins.ORDER.find("wrath")).get_center())
	check(g.model.sins.has("wrath") and g.sin_view.queue == ["wrath"],"Button immediately activates and queues selected sin")
	check(not paused and not g.sin_view.active() and g._menus_open(),"Queued awakening leaves options interactive while combat stays blocked")
	g.sin_view._process(1)
	check(not g.sin_view.active() and not paused,"Awakening cannot open behind Debug")
	g._handle_menu_page_click(ui.reward_rect(Sins.ORDER.find("wrath")).get_center())
	check(g.sin_view.queue == ["wrath"] and not ui.buttons()[Sins.ORDER.find("wrath")][3],"Already satisfied button disables without a duplicate page")
	g._handle_menu_page_click(ui.reward_rect(Sins.ORDER.size()).get_center())
	check(g.model.sins.unlocked.size() == 7 and g.sin_view.queue.size() == 7,"All shortcut queues remaining sins without duplicating the first")
	check(g.model.relics.items == items and g.model.rng.state == rng_state,"Awakening does not fill inventory or consume combat RNG")
	g._handle_menu_page_click(g.DEBUG_CLOSE.get_center())
	g.sin_view._process(1)
	check(g.menu_open and not g.debug_open and not g.sin_view.active() and not paused,"Returning from Debug to pause menu still defers presentation")
	g._handle_menu_page_click(g.GUIDE_RECT.get_center())
	g.sin_view._process(1)
	check(g.guide and not g.sin_view.active(),"Help also keeps pending awakenings deferred")
	g._handle_menu_page_click(g.GUIDE_CLOSE.get_center())
	g._handle_menu_page_click(g.MENU_RESUME.get_center())
	check(g._menus_open() and not g.sin_view.active(),"Pending queue blocks the frame before awakening opens")
	g.sin_view._process(0.1)
	check(paused and g.sin_view.active() and g.sin_view.current == "wrath" and g.sin_view.opening,"Closing options starts the queued awakening and pauses the scene")
	g.sin_view.age = 1; g.sin_view.mode = "hold"
	await capture(g,"awakening",phone)
	var shown: Array = []
	while g.sin_view.active():
		shown.append(g.sin_view.current)
		g.sin_view.mode = "leave"; g.sin_view.age = 0; g.sin_view._process(0.5)
		if g.sin_view.active(): check(paused,"Queued pages never resume combat between awakenings")
	shown.sort(); var expected: Array = Sins.ORDER.duplicate(); expected.sort()
	check(shown == expected and not paused and not g._menus_open(),"Each awakening plays once, then gameplay resumes")
	g._open_debug(); ui.apply_sin("all")
	check(g.sin_view.queue.is_empty(),"Reopening Debug cannot replay already-awakened sins")
	g.model.sins.restore({}); ui.apply_sin("envy")
	check(g.sin_view.queue == ["envy"],"New pending awakening can be tested after a reset")
	g._restart(1)
	g.sin_view._process(1)
	check(not g.sin_view.active() and g.sin_view.queue.is_empty() and not paused and g.model.sins.unlocked.is_empty(),"A debug wave jump clears obsolete queued pages")
	g.queue_free(); await process_frame

func run() -> void:
	rules()
	var args := OS.get_cmdline_user_args()
	if "--portrait-only" not in args: await scene(false)
	if "--desktop-only" not in args: await scene(true)
	print("Debug sins: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _initialize() -> void: call_deferred("run")
