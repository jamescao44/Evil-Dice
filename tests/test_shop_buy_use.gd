extends SceneTree
## Shop quick-use preserves purchases, runs real tarot choices, and cannot leak into battle.
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func offer(g, id: String) -> void:
	g.model.shop.offers[6] = {"kind":"tarot","id":id,"price":100,"sold":false}
	g.shop_ui.selected = 6
func tap(g, at: Vector2) -> void:
	g._handle_click(at); g._handle_release(at)
func settle(g) -> void:
	for frame in range(300):
		if not g.tarot_cast.active() and not g.relic_ui.pickup.active: break
		await process_frame
func run() -> void:
	for phone in [true,false]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.speed = 20; g.set_process_input(false)
		g.model.shop.open_debug(g.model); g.model.shop.debug_unlimited = false
		g.model.blood_gems = 2000; g.view_phase = "shop"; g.shop_ui.open()
		var ui = g.shop_ui
		for slot in [-1,0,8]:
			ui.selected = slot
			check(not ui.shows_buy_and_use() and ui.buy_use_rect() == Rect2(),"Only tarot merchandise shows quick use")
			check(ui.buy_rect() == ui.purchase_rect(),"Other merchandise gets the full-width Buy button")
		offer(g,"empress")
		for rect in [ui.buy_rect(),ui.buy_use_rect()]:
			check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(rect),"Purchase buttons fit screen")
			check(not rect.intersects(ui.inventory_rect()) and not rect.intersects(ui.refresh_rect()) and not rect.intersects(ui.leave_rect()),"Taller purchase buttons clear other controls")
			check(rect.size.y == (162 if phone else 102),"Both purchase buttons are 1.5 times taller")
		check(not ui.buy_rect().intersects(ui.buy_use_rect()),"Purchase buttons have separate tap and drop targets")
		for id in ui.Stock.Tarot.ITEMS:
			offer(g,id)
			var quick: bool = ui.Stock.Tarot.immediate_reward(id)
			check(ui.shows_buy_and_use() == quick and ui.can_buy_and_use() == quick,"Only reward cards offer immediate use: "+id)
			if not quick:
				check(ui.buy_use_rect() == Rect2() and ui.buy_rect() == ui.purchase_rect(),"Combat cards retain full-width Buy")
				check(g.model.shop.buy(g.model,6,-1,true).is_empty() and not g.model.shop.offers[6].sold,"Direct quick-use cannot bypass reward restriction")
		offer(g,"sun"); g.model.hp = 40
		check(not ui.can_buy_and_use(),"Low health still saves newly bought Sun for tactical use")
		offer(g,"empress")
		var original: Dictionary = g.model.tarots.add("empress")
		var rng: int = g.model.rng.state
		var rewards_rng: int = g.model.reward_rng.state
		for i in range(10): ui.can_buy_and_use()
		check(g.model.rng.state == rng and g.model.reward_rng.state == rewards_rng,"Eligibility never rerolls rewards or combat")
		g.model.blood_gems = 99
		check(not ui.can_buy_and_use(),"Unaffordable tarot stays dim")
		tap(g,ui.buy_use_rect().get_center())
		check(not g.model.shop.offers[6].sold and g.model.blood_gems == 99,"Disabled button cannot buy")
		g.model.blood_gems = 2000
		tap(g,ui.buy_use_rect().get_center())
		check(g.model.tarots.items.size() == 3 and g.model.shop.offers[6].sold and g.model.blood_gems == 1900,"Buy and Use charges once and grants two tarot rewards")
		check(g.model.tarots.find_instance(original.instance_id) >= 0,"Uses the newly bought copy instead of an already owned tarot")
		tap(g,ui.buy_use_rect().get_center())
		await settle(g)
		check(g.view_phase == "shop" and g.model.blood_gems == 1900 and g.model.shop.active,"Double click cannot repeat payment or exit the shop")
		g.tarot_ui.pickup.reset()
		offer(g,"empress")
		var count: int = g.model.tarots.items.size()
		var from: Vector2 = ui.offer_rect(6).get_center()
		g._handle_click(from); g._handle_motion(ui.buy_use_rect().get_center()); g._handle_release(ui.buy_use_rect().get_center())
		check(g.model.tarots.items.size() == count+2,"Dropping a reward tarot onto Buy and Use activates it")
		await settle(g)
		g.tarot_ui.pickup.reset()
		offer(g,"strength"); tap(g,ui.buy_rect().get_center())
		check(g.model.tarot_effects.strength == 0 and g.model.tarots.items.any(func(c): return c.id == "strength"),"Ordinary Buy saves Strength without applying a buff")
		g.tarot_ui.pickup.reset()
		offer(g,"sun"); tap(g,ui.buy_rect().get_center())
		check(g.model.hp == 40 and g.model.tarots.items.any(func(c): return c.id == "sun"),"Ordinary Buy still stores the card without using it")
		g.tarot_ui.pickup.reset()
		g.model.acquire_relic("ancient_prophecy")
		count = g.model.tarots.items.size()
		offer(g,"empress"); tap(g,ui.buy_use_rect().get_center()); await settle(g)
		check(g.model.tarots.items.size() == count+4 and g.view_phase == "shop","Ancient Prophecy repeats purchased rewards and returns to the shop")
		g.tarot_ui.pickup.reset()
		# Full-inventory reward choices still consume Emperor and return safely on discard.
		g.model.relics.items.clear()
		for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","bloodstone","contract","worn_dagger"]: g.model.acquire_relic(id)
		var owned_emperors: int = g.model.tarots.items.filter(func(c): return c.id == "emperor").size()
		offer(g,"emperor"); tap(g,ui.buy_use_rect().get_center())
		check(g.inventory_page.opened and g.tarot_cast.choice_type == "replace","Emperor opens the existing inventory replacement page")
		check(g.model.tarots.items.filter(func(c): return c.id == "emperor").size() == owned_emperors,"New Emperor is consumed while existing copies remain")
		g.inventory_page.close()
		await settle(g)
		check(g.view_phase == "shop" and not g.tarot_cast.active(),"Declining Emperor's relic resumes shopping without another payment")
		# Wheel may open a real reward chest; closing it must restore the same shop.
		var wheel_rng := RandomNumberGenerator.new()
		var seed_value := 0
		while true:
			wheel_rng.seed = seed_value
			if wheel_rng.randi_range(1,4) == 1: break
			seed_value += 1
		g.model.reward_rng.seed = seed_value
		offer(g,"wheel"); tap(g,ui.buy_use_rect().get_center())
		for frame in range(300):
			if g.chest.active: break
			await process_frame
		check(g.chest.active and not ui.visible,"Wheel presents its bonus chest over the shop")
		g.model.discard_unclaimed_rewards(); g.chest.cancel(); g.crystal_pickup.reset()
		for frame in range(300):
			if ui.visible: break
			await process_frame
		check(g.view_phase == "shop" and ui.visible and g.model.shop.active,"Finishing the chest returns to the same active shop")
		for locale in ["en","zh_CN"]:
			GameText.set_language(locale,false); offer(g,"empress")
			await process_frame; await process_frame
			if DisplayServer.get_name() != "headless":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("res://test-output/shop-buy-use-"+("phone" if phone else "desktop")+"-"+locale+".png")
		g._restart(); g.queue_free(); await process_frame
	print("Shop Buy and Use: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
