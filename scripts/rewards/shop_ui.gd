extends Node2D
## Checkpoint storefront; stock, currency and grants belong to ShopStock.
const Stock = preload("res://scripts/rewards/shop_stock.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const RarityDisplay = preload("res://scripts/relics/relic_rarity_display.gd")
const TypeTags = preload("res://scripts/relics/relic_type_tags.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const Icons = preload("res://scripts/rewards/reward_icons.gd")
const Resonance = preload("res://scripts/rewards/shop_set_resonance.gd")
const KEEPER = preload("res://assets/art/shop/keeper.png")
const GOLD := Color("dfc78d")
const SOUL_COLOR := Color("a5e4ef")
var battle
var selected: int = -1
var replacing: bool = false
var age: float = 0
var refresh_flash: float = 0
var pressed_offer: int = -1
var dragging: bool = false
var press_at := Vector2.ZERO
var pointer := Vector2.ZERO
var held_layer: Node2D
var keeper_sprite: Sprite2D
var keeper_overlay: Node2D
var reveal_layer: Node2D
var reveals: Array[Dictionary] = []
var reveal_clock: float = 0.0
var dialogue_time: float = 0.0
var resonance = Resonance.new()

## Keep merchandise below pickups, held relics and settings pages.
func _ready() -> void:
	z_index = BattleLayers.REWARD_PAGE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Cards.soften(self)
	keeper_sprite = Sprite2D.new()
	keeper_sprite.texture = KEEPER
	var keeper_ink := ShaderMaterial.new()
	keeper_ink.shader = preload("res://scripts/rewards/shop_keeper.gdshader")
	keeper_sprite.material = keeper_ink
	add_child(keeper_sprite)
	keeper_overlay = Node2D.new()
	keeper_overlay.z_index = 1
	keeper_overlay.draw.connect(_draw_divination)
	add_child(keeper_overlay)
	reveal_layer = Node2D.new()
	reveal_layer.z_index = 2
	reveal_layer.draw.connect(_draw_reveals)
	add_child(reveal_layer)
	held_layer = Node2D.new()
	held_layer.z_as_relative = false
	held_layer.z_index = battle.HELD_ITEM_Z
	Cards.soften(held_layer)
	held_layer.draw.connect(_draw_held)
	add_child(held_layer)
	hide()

## Present already-rolled stock without blocking the announcement banner.
func open() -> void:
	selected = -1
	replacing = false
	age = 0
	dialogue_time = 0
	_queue_reveals(true)
	show()
	queue_redraw()

## Clear presentation when leaving or restarting a run.
func cancel() -> void:
	cancel_purchase()
	reveals.clear()
	resonance.reset()
	hide()

## Introduce new Legendary stock one at a time using the chest's spin, slam and rebound.
func _queue_reveals(include_gift: bool = false) -> void:
	reveals.clear()
	resonance.reset()
	reveal_clock = 0
	if battle.reduced: return
	var slots: Array = range(battle.model.shop.offers.size())
	if include_gift and not battle.model.shop.divination_used: slots.append(Stock.GIFT_SLOT)
	for slot in slots:
		var offer: Dictionary = battle.model.shop.offer_at(slot)
		if offer.get("kind","") != "relic" or offer.get("sold",false): continue
		if not Relics.ITEMS.has(offer.id) or Relics.ITEMS[offer.id].rarity != Relics.Rarity.LEGENDARY: continue
		reveals.append({"slot":slot,"offer":offer,"start":reveals.size()*RarityDisplay.REVEAL_DURATION})

## Reject sold or replaced listings so refreshes and purchases cannot leave a ghost item.
func _reveal_age(slot: int) -> float:
	if battle.reduced: return -1.0
	var offer: Dictionary = battle.model.shop.offer_at(slot)
	if offer.is_empty() or offer.get("sold",false): return -1.0
	if slot == Stock.GIFT_SLOT and battle.model.shop.divination_used: return -1.0
	for entry in reveals:
		if entry.slot != slot or not is_same(entry.offer,offer): continue
		var elapsed: float = reveal_clock-entry.start
		if RarityDisplay.featured_reveal(Relics.Rarity.LEGENDARY,elapsed): return elapsed
	return -1.0

## Enlarged merchandise clears adjacent shelf icons while staying below pickups and menus.
func _draw_reveals() -> void:
	if not visible: return
	for entry in reveals:
		var elapsed := _reveal_age(entry.slot)
		if elapsed < 0: continue
		var gift: bool = entry.slot == Stock.GIFT_SLOT
		var at: Vector2 = divination_deck_position() if gift else offer_art_rect(entry.slot).get_center()
		var radius: float = (46 if portrait() else 36) if gift else offer_art_rect(entry.slot).size.x/2
		RarityDisplay.paint(reveal_layer,entry.offer.id,at,radius,age,battle.reduced,1.0 if selected == entry.slot else 0.0,elapsed)

## Abandon a pending purchase completely without changing stock, funds or owned items.
func cancel_purchase() -> void:
	cancel_drag()
	selected = -1
	replacing = false
	queue_redraw()

## Share layout decisions between painting and pointer hit areas.
func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Use the whole keeper illustration as a generous touch target.
func keeper_rect() -> Rect2:
	return Rect2(Vector2(0,514) if portrait() else Vector2(42,190),Vector2.ONE*252)

## Keep the floating deck in front of the keeper's hands, clear of the bottle shelf.
func divination_deck_position() -> Vector2:
	var bob: float = 0 if battle.reduced else sin(age*TAU/2.4)*5
	return keeper_rect().get_center()+Vector2(0,52+bob)

func divination_deck_size() -> Vector2:
	return (Vector2(80,124) if portrait() else Vector2(66,102))*0.8

## Place the speech bubble above the keeper without covering merchandise or the tarot shortcut.
func dialogue_rect() -> Rect2:
	return Rect2(24,424,224,84) if portrait() else Rect2(148,98,180,86)

## The invitation persists; the completed reading answers only when tapped again.
func dialogue_text() -> String:
	if not battle.model.shop.divination_used and not battle.model.shop.gift.is_empty(): return "Looking for this?"
	if not battle.model.shop.divination_used: return "Would you like a divination?"
	return "Fate has spoken." if dialogue_time > 0 else ""

## Lock the free draw before animating, so repeated taps cannot create extra readings.
func _divine() -> void:
	if battle.model.shop.divination_used:
		dialogue_time = 3.0
		battle._sound("ui/book",0.9,-20)
	else:
		selected = -1
		cancel_drag()
		if not battle.model.shop.gift.is_empty():
			selected = Stock.GIFT_SLOT
			battle._sound("ui/book",1,-17)
		else:
			battle.tarot_ui.begin_reward("shop",-1,divination_deck_position(),divination_deck_size())
	queue_redraw()
	keeper_overlay.queue_redraw()

## Treat the keeper's free gift as an inspectable offer without adding a shelf slot.
func selected_offer() -> Dictionary:
	return battle.model.shop.offer_at(selected)

func selected_gift() -> bool:
	return selected == Stock.GIFT_SLOT and not selected_offer().is_empty()

## Keep six relics and two face-up cards, with a bottle shelf beneath the keeper.
func offer_rect(slot: int) -> Rect2:
	if portrait():
		if slot == Stock.OFFER_COUNT-1: return Rect2(48,818,178,244)
		if slot < 6: return Rect2(272+(slot%3)*160,310+(slot/3)*250,152,230)
		return Rect2(310+(slot-6)*220,818,178,244)
	if slot == Stock.OFFER_COUNT-1: return Rect2(68,464,200,164)
	if slot < 6: return Rect2(350+(slot%3)*194,134+(slot/3)*172,180,162)
	return Rect2(960+(slot-6)*138,226,126,222)

## Reserve separate artwork, name and price bands on each shelf.
func offer_art_rect(slot: int) -> Rect2:
	var rect: Rect2 = offer_rect(slot)
	var tarot: bool = slot in [6,7]
	if slot == Stock.OFFER_COUNT-1:
		var side: float = 116 if portrait() else 82
		return Rect2(Vector2(rect.get_center().x,rect.position.y+(84 if portrait() else 34))-Vector2.ONE*side/2,Vector2.ONE*side)
	var size: Vector2 = (Vector2(90,140) if portrait() else Vector2(76,118)) if tarot else Vector2.ONE*(92 if portrait() else 60)
	var y: float = (84 if portrait() else 72) if tarot else (48 if portrait() else 26)
	return Rect2(Vector2(rect.get_center().x,rect.position.y+y)-size/2,size)

## Leave enough room for two-line item names without covering the sprite.
func offer_name_rect(slot: int) -> Rect2:
	var rect: Rect2 = offer_rect(slot)
	var top: float = rect.size.y-90 if slot >= 6 else 104 if portrait() else 58
	return Rect2(rect.position+Vector2(8,top),Vector2(rect.size.x-16,64 if portrait() else 48))

## Fit long translated names into two lines, leaving the price unobstructed.
func offer_name_size(slot: int, label: String) -> int:
	var size: int = 22 if portrait() else 18
	while size > 14 and GameText.lines(label,battle.description_font,size,offer_name_rect(slot).size.x).size() > 2: size -= 1
	if GameText.language == "en":
		for word in label.split(" "):
			while size > 14 and battle.description_font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > offer_name_rect(slot).size.x: size -= 1
	if slot < Stock.RELIC_COUNT:
		var offer: Dictionary = battle.model.shop.offer_at(slot)
		var badge_height: float = TypeTags.height({"id":offer.id},battle.description_font,offer_name_rect(slot).size.x,offer_tag_size(slot)) if not offer.get("id","").is_empty() else 0.0
		var available: float = offer_rect(slot).end.y-(35 if portrait() else 32)-offer_name_rect(slot).position.y-badge_height-6
		while size > 12 and size*(1+(GameText.lines(GameText.text(label),battle.description_font,size,offer_name_rect(slot).size.x).size()-1)*1.3) > available: size -= 1
	return size

## Rare multi-type merchandise keeps its tags on one row above the price.
func offer_tag_size(slot: int) -> int:
	var size: int = 16 if portrait() else 14
	var offer: Dictionary = battle.model.shop.offer_at(slot)
	if offer.get("kind","") != "relic" or offer.get("id","").is_empty(): return size
	var item := {"id":offer.id}
	while size > 10 and TypeTags.height(item,battle.description_font,offer_name_rect(slot).size.x,size) > battle.description_font.get_height(size)+8.01: size -= 1
	return size

## Place shelf badges after the actual name lines instead of using a fixed two-line gap.
func offer_tags_top(slot: int, label: String, point_size: int) -> Vector2:
	var rect := offer_name_rect(slot)
	var lines: int = GameText.lines(GameText.text(label),battle.description_font,point_size,rect.size.x).size()
	return rect.position+Vector2(0,point_size*(1+maxi(0,lines-1)*1.3)+6)

## Keep the owned relic rail above the large purchase target.
func inventory_rect() -> Rect2:
	return Rect2(48,1384,708,64) if portrait() else Rect2(260,642,760,42)

## Place readable inspection text between merchandise and the owned rail.
func detail_rect() -> Rect2:
	return Rect2(48,1116,708,232) if portrait() else Rect2(350,474,878,164)

## Reserve the taller purchase target; only tarot offers need a second action.
func purchase_rect() -> Rect2:
	return Rect2(48,1464,708,162) if portrait() else Rect2(396,692,490,102)

## Combat cards use the full-width Buy action; only reward cards offer immediate use.
func shows_buy_and_use() -> bool:
	return selected_offer().get("kind","") == "tarot" and Stock.Tarot.immediate_reward(selected_offer().get("id",""))

func buy_rect() -> Rect2:
	var rect := purchase_rect()
	if shows_buy_and_use(): rect.size.x = rect.size.x*2.0/3.0-5
	return rect

func buy_use_rect() -> Rect2:
	if not shows_buy_and_use(): return Rect2()
	var rect := purchase_rect()
	rect.position.x += rect.size.x*2.0/3.0+5
	rect.size.x = rect.size.x/3.0-5
	return rect

func can_buy_and_use() -> bool:
	return not replacing and not busy() and battle.model.shop.can_buy_and_use(battle.model,selected)

## Keep refresh separate from purchasing; the stock owns its escalating fee.
func refresh_rect() -> Rect2:
	return Rect2(48,1644,340,76) if portrait() else Rect2(52,715,290,58)

## Leave without requiring purchases or spending crystals.
func leave_rect() -> Rect2:
	return Rect2(414,1644,342,76) if portrait() else Rect2(940,715,288,58)

## Ignore shop mutations while a purchased relic is landing.
func busy() -> bool:
	return battle.relic_ui.pickup.active or battle.tarot_cast.active()

## Identify useful pointer targets without including empty shelf space.
func hit(at: Vector2) -> bool:
	return keeper_rect().has_point(at) or refresh_rect().has_point(at) or leave_rect().has_point(at) or buy_rect().has_point(at) or buy_use_rect().has_point(at) or inventory_rect().has_point(at) or range(battle.model.shop.offers.size()).any(func(i): return offer_rect(i).has_point(at))

## Route purchases and replacements before allowing normal inventory dragging.
func click(at: Vector2) -> bool:
	cancel_drag()
	if not visible or battle._menus_open(): return false
	if busy(): return true
	var stock = battle.model.shop
	if replacing:
		var index: int = battle.relic_ui.at_slot(at)
		if index >= 0: _buy(index)
		elif buy_rect().has_point(at): cancel_purchase()
		return true
	if keeper_rect().has_point(at):
		_divine()
		if selected_gift() and stock.can_buy(battle.model,selected): _begin_drag(selected,at)
		return true
	if inventory_rect().grow(6).has_point(at): return false
	if leave_rect().has_point(at):
		stock.close()
		cancel()
		return true
	if refresh_rect().has_point(at):
		if stock.refresh(battle.model):
			selected = -1
			_queue_reveals()
			refresh_flash = 0.3
			battle._sound("item/book",1.1,-14)
		return true
	if buy_use_rect().has_point(at):
		_attempt_buy_and_use()
		return true
	if selected >= 0 and buy_rect().has_point(at):
		_attempt_buy()
		return true
	for i in range(stock.offers.size()):
		if offer_rect(i).has_point(at):
			selected = i
			if not stock.offers[i].sold and not stock.offers[i].id.is_empty(): _begin_drag(i,at)
			battle._sound("ui/click_001",1,-20)
			break
	return true

## Share the same drag gesture for shelf merchandise and the keeper's free gift.
func _begin_drag(slot: int, at: Vector2) -> void:
	# Inspection or dragging takes over immediately without a second floating copy.
	reveals = reveals.filter(func(entry): return entry.slot != slot)
	pressed_offer = slot
	press_at = at
	pointer = at
	dragging = false

## Share one purchase path for the buy button and drag-to-buy gesture.
func _attempt_buy() -> void:
	if battle.model.shop.needs_replacement(battle.model,selected):
		replacing = true
		battle.inventory_page.open("shop")
	else: _buy()

## Purchase the exact card silently, then immediately enter its existing use flow.
func _attempt_buy_and_use() -> void:
	if not can_buy_and_use(): return
	var origin: Vector2 = offer_art_rect(selected).get_center()
	var bought: Dictionary = battle.model.shop.buy(battle.model,selected,-1,true)
	if bought.is_empty(): return
	battle._sound("item/confirmation_002",1,-12)
	battle.tarot_cast.request_shop(bought.tarot_instance,origin)

## Capture only a merchandise press; no hover can accidentally begin a purchase.
func motion(at: Vector2) -> bool:
	if pressed_offer < 0: return false
	pointer = at
	if at.distance_to(press_at) > (14 if portrait() else 8): dragging = true
	return true

## Release elsewhere cancels the drag; dropping on BUY uses its displayed item.
func release(at: Vector2) -> bool:
	if pressed_offer < 0: return false
	var should_buy: bool = dragging and buy_rect().has_point(at) and not battle._menus_open()
	var should_use: bool = dragging and buy_use_rect().has_point(at) and not battle._menus_open()
	cancel_drag()
	if should_use: _attempt_buy_and_use()
	elif should_buy: _attempt_buy()
	return true

## Discard a held listing on refresh, focus loss, inventory opening or exit.
func cancel_drag() -> void:
	pressed_offer = -1
	dragging = false
	if is_instance_valid(held_layer): held_layer.queue_redraw()

## Play the existing inventory landing after a successful model transaction.
func _buy(replace_index: int = -1) -> void:
	if replace_index >= 0 and not replacing: return
	var from_keeper: bool = selected_gift()
	var origin: Vector2 = divination_deck_position() if from_keeper else offer_art_rect(selected).get_center()
	var previous: Array = battle.model.relics.items.map(func(item): return item.id)
	var bought: Dictionary = battle.model.shop.buy(battle.model,selected,replace_index)
	if bought.is_empty(): return
	replacing = false
	battle._sound("item/confirmation_002",1,-12)
	if bought.kind == "relic": battle.relic_ui.collect(bought.id,origin,46 if portrait() else 30,previous)
	elif bought.kind == "soul_bottle":
		battle.fx.floating(offer_art_rect(selected).get_center(),GameText.format("+%d souls",bought.souls),SOUL_COLOR,36 if portrait() else 28,true)
	if from_keeper: selected = -1

## Explicitly forfeit the keeper's gift, preserving ordinary shop cancellation behavior.
func discard_gift() -> void:
	if not selected_gift(): return
	var amount: int = battle.model.shop.discard_gift(battle.model)
	if amount <= 0: return
	battle.fx.floating(divination_deck_position(),GameText.format("+%d blood gems",amount),Color("fa6086"),30,true)
	battle._sound("item/confirmation_002",1,-12)
	cancel_purchase()

## Hint only while both merchandise and the owned-item rail are visible.
func _resonance_available() -> bool:
	if not visible or battle.view_phase != "shop" or not battle.model.shop.active or modulate.a < 0.99: return false
	if busy() or battle.pause_menu.active() or battle.tarot_ui.ceremony.active(): return false
	if pressed_offer >= 0 or battle.relic_ui.pressed >= 0 or battle.tarot_quick.inspected >= 0 or battle.tarot_feedback.inspection.opened: return false
	if battle.inventory_page.opened: return false
	return not replacing and not reveals.any(func(entry): return _reveal_age(entry.slot) >= 0)

## Shared queries keep shelf, keeper gift and the visible owned-item rail synchronized.
func set_hint_for_offer(slot: int) -> Vector3:
	return resonance.offer_pose(slot) if _resonance_available() else Vector3.ZERO

func set_hint_for_owned(index: int) -> Vector3:
	return resonance.owned_pose(index) if _resonance_available() else Vector3.ZERO

## Pause reveal timing behind menus and wait until the shop has finished fading in.
func _process(delta: float) -> void:
	if not visible: return
	resonance.advance(delta,battle.model.shop,battle.model.relics.items,_resonance_available(),battle.reduced)
	held_layer.visible = dragging and not battle._menus_open()
	held_layer.queue_redraw()
	keeper_overlay.queue_redraw()
	reveal_layer.queue_redraw()
	if battle._menus_open(): return
	age += delta
	if modulate.a >= 0.99: reveal_clock += delta
	dialogue_time = maxf(0,dialogue_time-delta)
	refresh_flash = maxf(0,refresh_flash-delta)
	queue_redraw()

## Draw localized labels using the high-resolution description font.
func _text(at: Vector2, value: String, size: int, color: Color = GOLD) -> void:
	Cards.text(self,battle.description_font,at,value,size,color)

## Wrap descriptions and names inside their reserved panels.
func _wrap(rect: Rect2, value: String, size: int, color: Color, centered: bool = false) -> void:
	Cards.wrap(self,battle.description_font,rect,value,size,color,centered)

## Pair every price with the soul crystal icon rather than an ambiguous number.
func _price(at: Vector2, amount: int, enabled: bool = true) -> void:
	var size: int = 30 if portrait() else 23
	var label: String = str(amount)
	var width: float = battle.description_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var side: float = size+2
	var left: float = at.x-(width+side+10)/2
	Icons.paint(self,battle.chest.art,"ruby",Rect2(Vector2(left,at.y-side*0.7),Vector2.ONE*side),Rect2(),Color.WHITE if enabled else Color("777777"))
	_text(Vector2(left+side+10+width/2,at.y),label,size,Color("ffd0de") if enabled else Color("8e8187"))

## Give action buttons a strong border and clear disabled coloring.
func _button(rect: Rect2, text: String, enabled: bool = true) -> void:
	var color: Color = GOLD if enabled else Color("777575")
	Cards.panel(self,rect,Color("292526"),color,12)
	var size: int = 28 if portrait() else 22
	var label: String = GameText.text(text)
	while size > 14 and battle.description_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x-20: size -= 1
	_text(rect.get_center()+Vector2(0,10),text,size,color)

## Draw a simple wooden shelf whose merchandise has no individual boxes.
func _shelf(at: Vector2, width: float) -> void:
	draw_rect(Rect2(at+Vector2(0,12),Vector2(width,12)),Color("0e1114"))
	draw_rect(Rect2(at,Vector2(width,14)),Color("5e4433"))
	draw_rect(Rect2(at,Vector2(width,3)),Color("99764d"))
	for x in range(12,int(width)-12,48): draw_line(at+Vector2(x,8),at+Vector2(x+25,8),Color("342b27"),2)
	for x in [18,width-30]: draw_colored_polygon(PackedVector2Array([at+Vector2(x,14),at+Vector2(x+12,14),at+Vector2(x,34)]),Color("3a3029"))

## Stage the hooded keeper alongside the two relic shelves and tarot shelf.
func _draw_stall() -> void:
	var at: Vector2 = keeper_rect().position
	var side: float = keeper_rect().size.x
	var bob: float = 0 if battle.reduced else sin(age*1.7)*2
	for i in range(7,0,-1): draw_circle(at+Vector2(side/2,side*0.65),side*(0.4+i*0.025),Color(0.34,0.27,0.44,0.025))
	keeper_sprite.position = at+Vector2(side/2,side/2+bob)
	keeper_sprite.scale = Vector2.ONE*side/KEEPER.get_width()
	_shelf(at+Vector2(14,side-12),side-28)
	if portrait():
		for y in [544,794,1066]: _shelf(Vector2(270,y),486)
		_shelf(Vector2(48,1066),178)
	else:
		for y in [300,472]: _shelf(Vector2(346,y),584)
		_shelf(Vector2(954,452),278)
		_shelf(Vector2(68,632),200)

## Draw the deck and speech above the keeper sprite, below every modal ceremony.
func _draw_divination() -> void:
	if not visible or battle.tarot_ui.ceremony.active(): return
	if not battle.model.shop.divination_used:
		if not battle.model.shop.gift.is_empty():
			if not (dragging and pressed_offer == Stock.GIFT_SLOT):
				var radius: float = 46 if portrait() else 36
				if _reveal_age(Stock.GIFT_SLOT) < 0:
					RarityDisplay.paint(keeper_overlay,battle.model.shop.gift.id,divination_deck_position(),radius,age,battle.reduced,1.0 if selected_gift() else 0.0,-1.0,{},set_hint_for_offer(Stock.GIFT_SLOT))
				Cards.text(keeper_overlay,battle.description_font,divination_deck_position()+Vector2(0,radius+30),"FREE",22 if portrait() else 18,GOLD)
		else:
			for i in range(3,-1,-1):
				Cards.card(keeper_overlay,"",divination_deck_position()+Vector2(i*3,-i*2),divination_deck_size(),0,1,0.35 if i == 0 else 0)
	var message: String = dialogue_text()
	if message.is_empty(): return
	var rect: Rect2 = dialogue_rect()
	var color := Color("ede0be")
	Cards.panel(keeper_overlay,rect,Color("2c2930"),color,12)
	var tip: Vector2 = Vector2(keeper_rect().get_center().x,rect.end.y+14)
	var base: Vector2 = Vector2(clampf(tip.x,rect.position.x+20,rect.end.x-20),rect.end.y-2)
	keeper_overlay.draw_colored_polygon(PackedVector2Array([base-Vector2(9,0),base+Vector2(9,0),tip]),Color("2c2930"))
	keeper_overlay.draw_polyline(PackedVector2Array([base-Vector2(9,0),tip,base+Vector2(9,0)]),color,2)
	var size: int = 24 if portrait() else 20
	var label: String = GameText.text(message)
	while size > 16 and GameText.lines(label,battle.description_font,size,rect.size.x-20).size()*size*1.3 > rect.size.y-12: size -= 1
	var lines: PackedStringArray = GameText.lines(label,battle.description_font,size,rect.size.x-20)
	var height: float = lines.size()*size*1.3
	Cards.wrap(keeper_overlay,battle.description_font,Rect2(rect.position+Vector2(10,maxf(2,(rect.size.y-height)/2)),rect.size-Vector2(20,4)),label,size,color,true)

## Show the shelf, a readable description, and one large purchase/drop target.
func _draw() -> void:
	if not visible: return
	var screen: Vector2 = battle.fx.canvas_size
	draw_rect(Rect2(Vector2.ZERO,screen),Color("14191d"))
	for i in range(8):
		draw_line(Vector2(i*screen.x/7,0),Vector2(i*screen.x/7,screen.y),Color("33302a",0.18),2)
	_text(Vector2(screen.x/2,180 if portrait() else 69),"Shop",58 if portrait() else 44)
	_text(Vector2(screen.x/2,234 if portrait() else 108),"调试 · 无限血宝石" if battle.model.shop.debug_unlimited else GameText.format("After wave %d-%d",[battle.model.level_number(),battle.model.level_wave()]),26 if portrait() else 19,Color("a9a39c"))
	battle.chest.draw_currency(self)
	_draw_stall()
	for i in range(battle.model.shop.offers.size()): _draw_offer(i)
	_draw_detail()
	var valid: bool = selected >= 0 and battle.model.shop.can_buy(battle.model,selected) and not busy()
	var over: bool = dragging and buy_rect().has_point(pointer) and valid
	if over:
		for i in range(4,0,-1): Cards.panel(self,buy_rect().grow(i*5),Color(GOLD,0.04))
	_button(buy_rect(),"CANCEL" if replacing else "TAKE RELIC" if selected_gift() else "DROP TO BUY" if dragging else "BUY",valid or replacing)
	if over: draw_rect(buy_rect().grow(-6),Color(GOLD,0.8),false,3)
	var use_enabled: bool = can_buy_and_use()
	var over_use: bool = dragging and buy_use_rect().has_point(pointer) and use_enabled
	if over_use:
		for i in range(4,0,-1): Cards.panel(self,buy_use_rect().grow(i*5),Color(GOLD,0.04))
	if shows_buy_and_use(): _button(buy_use_rect(),"BUY AND USE",use_enabled)
	if over_use: draw_rect(buy_use_rect().grow(-6),Color(GOLD,0.8),false,3)
	var refresh_price: int = battle.model.shop.refresh_price
	_button(refresh_rect(),"刷新全部" if battle.model.shop.debug_unlimited else GameText.format("REFRESH ALL · %d",refresh_price),battle.model.shop.can_afford(battle.model,refresh_price) and not busy() and not replacing)
	_button(leave_rect(),"LEAVE SHOP",not busy() and not replacing)
	if refresh_flash > 0: draw_rect(Rect2(Vector2.ZERO,screen),Color(GOLD,refresh_flash*0.14))

## Keep the dragged item above the entire shop while exposing the drop target.
func _draw_held() -> void:
	if not dragging or pressed_offer < 0: return
	var offer: Dictionary = battle.model.shop.offer_at(pressed_offer)
	if offer.is_empty(): return
	var at: Vector2 = pointer-Vector2(0,36 if portrait() else 22)
	if offer.kind == "relic": RarityDisplay.paint(held_layer,offer.id,at,66 if portrait() else 52,age,battle.reduced,1.0)
	elif offer.kind == "tarot": Cards.card(held_layer,offer.id,at,Vector2(108,168),0,1,0.4,0.86)
	else: Icons.paint(held_layer,battle.chest.art,"soul_bottle",Rect2(at-Vector2.ONE*64,Vector2.ONE*128))

## Keep item labels independent of their catalogue and never reveal sealed contents.
func offer_name(offer: Dictionary) -> String:
	if offer.kind == "relic": return Relics.ITEMS[offer.id].name
	if offer.kind == "tarot": return Cards.Catalog.ITEMS[offer.id].name
	return "Soul Bottle"

## Reveal the exact soul amount only after this bottle has been purchased.
func offer_description(offer: Dictionary) -> String:
	if offer.kind == "relic": return Relics.short_description(offer.id,GameText.text,battle.model.relics.items)
	if offer.kind == "tarot": return Cards.Catalog.description(offer.id)
	if offer.sold: return GameText.format("Opened: +%d souls.",offer.souls)
	return GameText.text("A sealed bottle of souls. Opens on purchase. Its contents are a mystery.")

## Use pale blue for souls without assigning them a relic rarity.
func offer_color(offer: Dictionary) -> Color:
	if offer.kind == "relic" and not offer.id.is_empty(): return Relics.rarity_color(offer.id)
	return SOUL_COLOR if offer.kind == "soul_bottle" else Color("cbb1f5")

## Paint each item's rarity, identity, fixed price and sold state.
func _draw_offer(slot: int) -> void:
	var offer: Dictionary = battle.model.shop.offers[slot]
	var rect: Rect2 = offer_rect(slot)
	var color := offer_color(offer)
	if selected == slot: draw_line(Vector2(rect.position.x+16,rect.end.y+1),Vector2(rect.end.x-16,rect.end.y+1),color,3)
	if offer.id.is_empty() or offer.sold:
		var label: String = GameText.format("+%d souls",offer.souls) if offer.kind == "soul_bottle" and offer.sold else "SOLD" if offer.sold else "SOLD OUT"
		_text(rect.get_center(),label,24,color if offer.kind == "soul_bottle" else Color("92888c"))
		return
	var artwork: Rect2 = offer_art_rect(slot)
	# Hide the shelf artwork for every item type while its held copy is drawn.
	if not (dragging and pressed_offer == slot):
		if offer.kind == "relic":
			if _reveal_age(slot) < 0 and not (battle.relic_ui.pickup.active and selected == slot):
				RarityDisplay.paint(self,offer.id,artwork.get_center(),artwork.size.x/2,age,battle.reduced,1.0 if selected == slot else 0.0,-1.0,{},set_hint_for_offer(slot))
		elif offer.kind == "tarot":
			draw_texture_rect(Cards.texture(offer.id),artwork,false,Color("d9cedd"))
		else:
			Icons.paint(self,battle.chest.art,"soul_bottle",artwork)
	var label := offer_name(offer)
	var name_size: int = offer_name_size(slot,label)
	_wrap(offer_name_rect(slot),label,name_size,color,true)
	if offer.kind == "relic": TypeTags.paint(self,{"id":offer.id},battle.description_font,offer_tags_top(slot,label,name_size),offer_name_rect(slot).size.x,offer_tag_size(slot))
	_price(Vector2(rect.get_center().x,rect.end.y-(10 if portrait() else 14)),offer.price,battle.model.shop.can_afford(battle.model,offer.price))

## Keep inspection on the shop page, with explicit buy or replacement cancellation.
func _draw_detail() -> void:
	var rect: Rect2 = detail_rect()
	draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("5a5145"),2)
	if selected < 0:
		_wrap(rect.grow(-24),"Tap an item to inspect it. Purchased tarot cards go straight into your collection.",30 if portrait() else 24,Color("c9c0af"),true)
		return
	var offer: Dictionary = selected_offer()
	if offer.is_empty() or offer.id.is_empty(): return
	var title := offer_name(offer)
	var description := offer_description(offer)
	var name_color := offer_color(offer)
	_text(Vector2(rect.get_center().x,rect.position.y+(38 if portrait() else 26)),title,30 if portrait() else 24,name_color)
	var top: float = 50 if portrait() else 34
	var body := Rect2(rect.position+Vector2(20,top),Vector2(rect.size.x-40,rect.size.y-top-34))
	if offer.kind == "relic":
		var bottom: float = TypeTags.paint(self,{"id":offer.id},battle.description_font,body.position,body.size.x,22 if portrait() else 18)+10
		body.size.y -= bottom-body.position.y
		body.position.y = bottom
	var size: int = 28 if portrait() else 23
	while size > 18 and GameText.lines(description,battle.description_font,size,body.size.x).size()*size*1.3 > body.size.y: size -= 1
	_wrap(body,description,size,Color("e7dfd1"))
	if selected_gift(): _text(Vector2(rect.get_center().x,rect.end.y-14),"FREE",28 if portrait() else 23)
	else: _price(Vector2(rect.get_center().x,rect.end.y-14),offer.price,battle.model.shop.can_afford(battle.model,offer.price))
