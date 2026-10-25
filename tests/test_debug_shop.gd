extends SceneTree
## Verify free debug purchases, return-to-battle state and the shop's overall rarity curve.
const Run = preload("res://scripts/progression/run_rules.gd")
const Stock = preload("res://scripts/rewards/shop_stock.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Unlimited is a spending mode, not a large balance that can eventually run out.
func economy() -> void:
	var m = Run.new(710)
	m.blood_gems = 7
	m.shop.open_debug(m)
	check(m.shop.active and m.shop.debug_unlimited,"Debug shop opens from an unfinished battle")
	for slot in [0,6,8]:
		check(m.shop.can_buy(m,slot),"Debug accepts relic, tarot and soul-bottle purchases with seven gems")
		check(not m.shop.buy(m,slot).is_empty() and m.blood_gems == 7,"Purchase grants its reward without spending real gems")
	check(m.shop.buy(m,0).is_empty(),"Unlimited money still respects sold stock")
	for i in range(70): check(m.shop.refresh(m) and m.blood_gems == 7,"Repeated debug refreshes never require money")
	check(m.shop.refresh_price == 0x7FFFFFFFFFFFFFFF,"Refresh price remains bounded after many refreshes")
	m.shop.close()
	check(not m.shop.debug_unlimited and not m.shop.can_afford(m,100),"Leaving removes unlimited spending")
	m.shop.open_debug(m); m.reset_run()
	check(not m.shop.debug_unlimited and not m.shop.active,"Restart clears debug spending mode")

## Count complete six-item shelves, including the guaranteed Rare, against the target mix.
func rarity_curve() -> void:
	check(Stock.rarity_weights(1) == Stock.rarity_weights(4),"Early debug shops retain starting odds")
	check(Stock.rarity_weights(4) == [58.0,30.0,10.0,1.0,1.0],"First possible shop uses base rarity odds")
	check(Stock.rarity_weights(1000).all(func(w): return absf(w-20) < 0.001),"All five rarities converge to twenty percent")
	var m = Run.new(910)
	for wave in [4,10,20,30]:
		m.stage = wave-1
		var expected: Array = Stock.rarity_weights(wave)
		var counts := [0,0,0,0,0]
		for sample in range(1200):
			m.reward_rng.seed = sample+9121
			m.shop.open_debug(m)
			check(Stock.Relics.ITEMS[m.shop.offers[m.shop.guaranteed_slot].id].rarity == Stock.Relics.Rarity.RARE,"Every shelf retains its guaranteed Rare")
			for offer in m.shop.offers.slice(0,Stock.RELIC_COUNT): counts[Stock.Relics.ITEMS[offer.id].rarity] += 1
		for rarity in range(5):
			check(absf(counts[rarity]/72.0-expected[rarity]) < 2.0,"Whole-shelf rarity distribution follows the curve")
		print("Shop wave ",wave," target=",expected," observed=",counts.map(func(n): return n/72.0))

## Capture only when explicitly requested; ordinary regression runs need no display.
func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/debug-shop-"+name+".png")

## Exercise the actual debug button and leave control in both supported layouts.
func scene(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	g.muted = true; g.reduced = true
	root.add_child(g); g.set_process_input(false)
	await process_frame
	g.model.blood_gems = 0
	var stage: int = g.model.stage
	var phase: String = g.view_phase
	var old_stock = g.model.shop
	var enemies: Array = g.model.enemies.duplicate(true)
	g._open_debug()
	check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(g.DEBUG_SHOP),"Debug shortcut fits the screen")
	check(not g.DEBUG_SHOP.intersects(g._debug_option_rect(-1)),"Shop shortcut does not cover the random-dice button")
	await capture(g,"menu-"+str(phone))
	g._handle_click(g.DEBUG_SHOP.get_center())
	check(g.view_phase == "shop" and g.shop_ui.visible and g.model.shop.debug_unlimited,"Debug button opens visible unlimited shop")
	check(g.model.shop != old_stock and g.model.stage == stage and g.model.enemies == enemies,"Debug shop preserves the current wave and normal stock")
	await capture(g,"open-"+str(phone))
	var card_count: int = g.model.tarots.items.size()
	g._handle_click(g.shop_ui.offer_rect(6).get_center())
	g._handle_click(g.shop_ui.buy_rect().get_center())
	check(g.model.tarots.items.size() == card_count+1 and g.model.blood_gems == 0,"UI can buy with a zero balance")
	g.tarot_ui.pickup.reset()
	g._handle_click(g.shop_ui.leave_rect().get_center())
	await process_frame
	check(g.view_phase == phase and not g.shop_ui.visible and g.model.shop == old_stock,"Leaving returns to the exact original battle and stock")
	check(not g.model.shop.debug_unlimited,"Normal shopping remains paid after debug closes")
	g._open_debug(); g._handle_click(g.DEBUG_SHOP.get_center()); g._restart(1)
	await process_frame
	check(g.view_phase != "shop" and not g.model.shop.active and not g.model.shop.debug_unlimited,"Restart safely cancels an open debug shop")
	g.queue_free(); await process_frame

func run() -> void:
	economy()
	rarity_curve()
	await scene(false)
	await scene(true)
	print("Debug shop: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _initialize() -> void: call_deferred("run")
