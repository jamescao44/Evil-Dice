extends SceneTree
## Shop reveals stay cosmetic, interruptible and above shelves in either screen layout.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Display = preload("res://scripts/relics/relic_rarity_display.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Use fixed merchandise without changing save files or rolling rewards during capture.
func stock(g) -> void:
	g.model.shop.open_debug(g.model)
	for i in range(6):
		g.model.shop.offers[i] = {"kind":"relic","id":["pet_dragon","black_chip","bracelet","magic_sword","armor","reaper_scythe"][i],"price":400,"sold":false}
	g.model.shop.gift = {"kind":"relic","id":"hellfire","price":0,"sold":false}
	g.shop_ui.open()

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	g.shop_ui.queue_redraw(); g.shop_ui.reveal_layer.queue_redraw(); g.shop_ui.keeper_overlay.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/shop-reveal-"+label+".png")

func run() -> void:
	GameText.set_language("zh_CN",false)
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
		g.reduced = false
		stock(g)
		var ui = g.shop_ui
		check(ui.reveals.size() == 3,"Only legendary shelf items and the free legendary gift enter the reveal queue")
		check(ui.reveal_layer.z_index > ui.keeper_overlay.z_index and ui.z_index+ui.reveal_layer.z_index < BattleLayers.INVENTORY_PAGE,"Reveal clears shelf layers but stays below inventory")
		var rng: int = g.model.reward_rng.state
		var snapshot: Array = g.model.shop.offers.duplicate(true)
		ui.modulate.a = 0.5; ui._process(0.3)
		check(ui.reveal_clock == 0,"Shop fade-in does not spend the reveal")
		ui.modulate.a = 1; ui._process(Display.REVEAL_SPIN)
		check(ui._reveal_age(0) == Display.REVEAL_SPIN and ui._reveal_age(1) < 0,"Legendary stock reveals one item at a time")
		check(g.model.reward_rng.state == rng and snapshot == g.model.shop.offers,"Reveal never changes rewards or reward RNG")
		await capture(g,"phone" if phone else "wide")
		g.menu_open = true; ui._process(1); g.menu_open = false
		check(ui.reveal_clock == Display.REVEAL_SPIN,"Menu pauses the reveal clock")
		ui.click(ui.offer_art_rect(0).get_center())
		check(ui.selected == 0 and ui._reveal_age(0) < 0,"Tap immediately selects and settles the featured item")
		ui.motion(ui.offer_art_rect(0).get_center()+Vector2(40,40))
		check(ui.dragging and ui._reveal_age(0) < 0,"Dragging cannot leave an enlarged copy behind")
		ui.cancel_drag()
		ui.reveal_clock = Display.REVEAL_DURATION+Display.REVEAL_SPIN
		check(ui._reveal_age(1) >= 0,"Next legendary gets its own reveal")
		g.model.shop.offers[1].sold = true
		check(ui._reveal_age(1) < 0,"Purchased listing immediately loses its reveal")
		g.model.shop.offers[1].sold = false
		g.model.shop.offers[1] = g.model.shop.offers[1].duplicate()
		check(ui._reveal_age(1) < 0,"Replacement listing does not inherit the previous reveal even with the same ID")
		ui.reveal_clock = Display.REVEAL_DURATION*2+Display.REVEAL_SPIN
		check(ui._reveal_age(ui.Stock.GIFT_SLOT) >= 0,"Keeper gift uses the same reveal")
		await capture(g,"gift-phone" if phone else "gift-wide")
		ui.click(ui.refresh_rect().get_center())
		check(ui.reveal_clock == 0 and ui._reveal_age(ui.Stock.GIFT_SLOT) < 0,"Refresh schedules fresh stock without replaying the old gift")
		ui.reveal_clock = Display.REVEAL_DURATION*10
		check(ui.reveals.all(func(entry): return ui._reveal_age(entry.slot) < 0),"Reveals finish and never loop")
		g.reduced = true; ui._queue_reveals(true)
		check(ui.reveals.is_empty(),"Reduced effects omit spinning and enlargement")
		ui.cancel()
		check(ui.reveals.is_empty() and not ui.visible,"Exit clears presentation")
		g.queue_free(); await process_frame
	print("Shop relic reveal: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
