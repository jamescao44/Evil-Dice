extends SceneTree
## Capture real shop/chest layouts with every rarity, without touching player saves.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Display = preload("res://scripts/relics/relic_rarity_display.gd")
const IDS := ["bracelet","magic_shield","magic_sword","mithril_blade","ancient_tentacle"]
var failures := 0

func _initialize() -> void: call_deferred("run")

## Sample rendered frames only; frozen scene processing prevents unrelated animations.
func capture(g, label: String) -> void:
	g.queue_redraw(); g.shop_ui.queue_redraw(); g.shop_ui.keeper_overlay.queue_redraw(); g.shop_ui.held_layer.queue_redraw(); g.chest.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/relic-rarity-"+label+".png")

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)

## Preview both orientations, drag feedback and each of the five stopped prize styles.
func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(603,1311) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
	g.model.shop.open_debug(g.model); g.view_phase = "shop"; g.shop_ui.open(); g._process(0)
	for i in range(6): g.model.shop.offers[i] = {"kind":"relic","id":IDS[i%5],"price":200+i*50,"sold":false}
	g.model.shop.gift = {"kind":"relic","id":"second_hand","price":0,"sold":false}
	g.shop_ui.selected = 3; g.shop_ui.age = 1.6; g.shop_ui._process(0)
	var suffix := "phone" if phone else "desktop"
	var stock: Array = g.model.shop.offers.duplicate(true)
	var rng_state: int = g.model.reward_rng.state
	await capture(g,"shop-"+suffix)
	g.shop_ui._process(0.5)
	await capture(g,"shop-motion-"+suffix)
	check(g.model.shop.offers == stock and g.model.reward_rng.state == rng_state,"Rarity animation preserves stock and reward RNG")
	g._handle_click(g.shop_ui.offer_rect(3).get_center())
	g._handle_motion(g.shop_ui.buy_rect().get_center())
	g.shop_ui._process(0)
	check(g.shop_ui.dragging,"Decorated shelf item still drags to purchase")
	await capture(g,"shop-held-"+suffix)
	g.shop_ui.cancel()
	g.view_phase = "reward"
	var values: Array = g.model._roll_chest(3)
	var prizes: Array = IDS.map(func(id): return {"relic_id":id})
	g.chest.start(values,g.fx.canvas_size,g.description_font,false,prizes,3)
	g.chest.audio_clock_enabled = false
	g.chest.open_chest(); g.chest._process(6)
	g.chest._process(1.3)
	g.chest.confetti.clear(); g.chest.landing_bursts.clear()
	await capture(g,"chest-"+suffix)
	for i in range(5):
		check(g.chest.symbols[g.chest.rewards[i]].relic_id == IDS[i],"Stopped decoration retains actual prize identity")
		check(g.chest.pickup_at(g.chest.reel_rect(i).get_center()) == i,"Decoration leaves prize collection hitboxes unchanged")
	g.chest._process(0.7)
	await capture(g,"chest-motion-"+suffix)
	g.chest.reduced = true
	await capture(g,"chest-reduced-"+suffix)
	g.chest.cancel(); g.queue_free(); await process_frame

## A close-up strip makes the family silhouettes and low-cost animation easy to inspect.
func strip() -> void:
	root.content_scale_size = Vector2i(1280,400); root.size = Vector2i(1280,400)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var clock := [0.0]
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0,0,1280,400),Color("14191d"))
		for i in range(5):
			Display.paint(canvas,IDS[i],Vector2(128+i*256,190),66,clock[0])
			canvas.draw_string(ThemeDB.fallback_font,Vector2(75+i*256,340),Display.Catalog.RARITY_NAMES[i],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Display.Catalog.rarity_color(IDS[i])))
	for frame in range(4):
		clock[0] = frame*0.4
		canvas.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/relic-rarity-strip-%d.png" % frame)
	canvas.queue_free(); await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Use a rendering window for rarity previews"); quit(1); return
	GameText.set_language("zh_CN",false)
	for phone in [true,false]: await scene(phone)
	await strip()
	print("Rarity presentation: %d failures; previews saved in test-output" % failures)
	quit(1 if failures else 0)
