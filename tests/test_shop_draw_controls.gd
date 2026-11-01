extends SceneTree
## Exercise free-gift gestures and the saved shuffle preference through real battle input.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var checks := 0
var failures := 0
var shuffle_sounds := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)

func capture(g, label: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args(): return
	g.shop_ui._process(0)
	g.tarot_ui.ceremony.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/shop-draw-"+label+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
	g.model.shop.open_debug(g.model); g.view_phase = "shop"; g.shop_ui.open(); g._process(0)
	var ui = g.shop_ui
	var shop = g.model.shop
	shop.gift = {"kind":"relic","id":"fries","price":0,"sold":false}
	var currency: int = g.model.blood_gems
	g._handle_click(ui.divination_deck_position()); g._handle_motion(ui.buy_rect().get_center())
	check(ui.dragging and ui.selected_gift(),"Keeper gift follows the normal shop drag gesture")
	await capture(g,"gift-held-"+("phone" if phone else "desktop"))
	g._handle_release(Vector2(12,12))
	check(not ui.dragging and not shop.divination_used and not g.model.relics.has("fries"),"Dropping elsewhere leaves the free gift available")
	g._handle_click(ui.divination_deck_position()); g._handle_motion(ui.buy_rect().get_center()); g._handle_release(ui.buy_rect().get_center())
	check(shop.divination_used and g.model.relics.has("fries") and g.relic_ui.pickup.active,"Dropping on Claim grants once with the existing pickup animation")
	g._handle_release(ui.buy_rect().get_center())
	check(g.model.relics.items.size() == 1 and g.model.blood_gems == currency,"Repeated releases cannot duplicate the gift or charge currency")
	g.relic_ui.pickup.clear()
	shop.gift = {}; shop.divination_used = false
	g.tarot_ui._save_shuffle_preference(false)
	var draw = g.tarot_ui.ceremony
	shuffle_sounds = 0
	draw.card_shuffled.connect(func(): shuffle_sounds += 1)
	tap(g,ui.keeper_rect().get_center())
	check(draw.state == "arrive" and not draw.skip_shuffle,"Default shop draw retains the deck arrival and shuffle")
	var choices: Array = draw.choices.duplicate()
	var rng: int = g.model.reward_rng.state
	draw.advance(0.2)
	var at: Vector2 = draw.arrival_pose().at
	tap(g,draw.shuffle_checkbox_rect().get_center())
	check(draw.skip_shuffle and draw.state == "arrive" and draw.arrival_pose().at.is_equal_approx(at),"Checking midway redirects the deck without jumping or instantly drawing")
	check(draw.draws.is_empty() and draw.choices == choices and g.model.reward_rng.state == rng,"Checkbox press and release preserve reserved outcomes")
	draw.advance(0.56)
	check(draw.state == "fan" and draw.age == 0 and shuffle_sounds == 0,"Skipped deck arrives at fan without shuffle sounds or left-deck drop")
	check(draw.fan_pose(0).at == draw.fan_center(),"Fan opens from the flight's exact destination")
	draw.advance(0.56)
	for locale in ["en","zh_CN"]:
		GameText.set_language(locale,false)
		var rect: Rect2 = draw.shuffle_checkbox_rect()
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(rect),"Checkbox fits both orientations")
		check(not rect.intersects(g.MENU_RECT) and not rect.intersects(g.inventory_page.button_rect()),"Checkbox stays clear of the menu and backpack")
		check(g.description_font.get_string_size(GameText.text("Skip shuffle animation"),HORIZONTAL_ALIGNMENT_LEFT,-1,24 if phone else 18).x < rect.size.x-64,"Both translations fit the checkbox")
		await capture(g,"fan-"+("phone" if phone else "desktop")+"-"+locale)
	for i in range(3):
		var backs: Array = draw.fan_order().filter(func(index): return index not in draw.removed)
		backs.sort_custom(func(a,b): return absf(draw.fan_pose(a).step) < absf(draw.fan_pose(b).step))
		tap(g,draw.fan_pose(backs[0]).at)
	check(draw.draws.size() == 3,"Skipping shuffle still permits exactly three independent draws")
	draw.advance(0.6); draw.advance(1.1)
	tap(g,draw.shuffle_checkbox_rect().get_center())
	check(draw.state == "choose" and draw.selected == -1 and not draw.skip_shuffle,"Preference toggle does not select a revealed card")
	tap(g,draw.shuffle_checkbox_rect().get_center())
	tap(g,draw.row_point(1)); tap(g,draw.keep_rect().get_center()); draw.advance(0.9)
	check(g.model.tarots.items.size() == 1 and g.model.tarots.items[0].id == choices[1],"Collection grants only the chosen reserved card")
	check(g.tarot_ui.begin_reward("debug") and draw.state == "fan" and draw.skip_shuffle,"Next ceremony reloads the saved preference and bypasses shuffle")
	var settings := ConfigFile.new(); settings.load(GameText.settings_path)
	check(settings.get_value("interface","skip_tarot_shuffle",false) and settings.get_value("interface","language","") == "en","Saved preference preserves unrelated interface settings")
	draw.reset()
	# Test the default route independently, including the existing manual preparation skip.
	draw.skip_shuffle = false
	draw.start(choices,g.fx.canvas_size,g.description_font,Vector2.ZERO,false,Vector2(100,200),Vector2(64,96))
	draw.advance(0.56); check(draw.state == "shuffle","Unchecked setting restores normal shuffle")
	draw.advance(1.01); check(draw.state == "drop" and shuffle_sounds == 22,"Normal shuffle still sounds each card exactly once")
	tap(g,Vector2(10,10)); check(draw.state == "fan" and draw.draws.is_empty(),"Manual skip still consumes its release")
	draw.skip_shuffle = true
	draw.start(choices,g.fx.canvas_size,g.description_font,Vector2.ZERO,true,Vector2(100,200),Vector2(64,96))
	draw.advance(0.19); check(draw.state == "fan","Reduced effects also supports direct fan arrival")
	g.queue_free(); await process_frame

func run() -> void:
	var previous_path: String = GameText.settings_path
	GameText.settings_path = "user://test-shop-draw-settings.cfg"
	var settings := ConfigFile.new(); settings.set_value("interface","language","en"); settings.save(GameText.settings_path)
	await scene(true); await scene(false)
	DirAccess.remove_absolute(GameText.settings_path)
	GameText.settings_path = previous_path
	print("Shop draw controls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
