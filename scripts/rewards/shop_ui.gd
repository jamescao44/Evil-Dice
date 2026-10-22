extends Node2D
## Checkpoint storefront; stock, currency and grants belong to ShopStock.
const Stock = preload("res://scripts/rewards/shop_stock.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const RelicPaint = preload("res://scripts/relics/relic_paint.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const Icons = preload("res://scripts/rewards/reward_icons.gd")
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

## Keep merchandise below pickups, held relics and settings pages.
func _ready() -> void:
	z_index = 80
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Cards.soften(self)
	keeper_sprite = Sprite2D.new()
	keeper_sprite.texture = KEEPER
	var keeper_ink := ShaderMaterial.new()
	keeper_ink.shader = preload("res://scripts/rewards/shop_keeper.gdshader")
	keeper_sprite.material = keeper_ink
	add_child(keeper_sprite)
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
	show()
	queue_redraw()

## Clear presentation when leaving or restarting a run.
func cancel() -> void:
	cancel_drag()
	selected = -1
	replacing = false
	hide()

## Share layout decisions between painting and pointer hit areas.
func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Keep six relics and two face-up cards, with a bottle shelf beneath the keeper.
func offer_rect(slot: int) -> Rect2:
	if portrait():
		if slot == Stock.OFFER_COUNT-1: return Rect2(48,818,178,244)
		if slot < 6: return Rect2(272+(slot%3)*160,310+(slot/3)*250,152,212)
		return Rect2(310+(slot-6)*220,818,178,244)
	if slot == Stock.OFFER_COUNT-1: return Rect2(68,464,200,164)
	if slot < 6: return Rect2(350+(slot%3)*194,134+(slot/3)*164,180,150)
	return Rect2(960+(slot-6)*138,226,126,222)

## Reserve separate artwork, name and price bands on each shelf.
func offer_art_rect(slot: int) -> Rect2:
	var rect: Rect2 = offer_rect(slot)
	var tarot: bool = slot in [6,7]
	if slot == Stock.OFFER_COUNT-1:
		var side: float = 116 if portrait() else 82
		return Rect2(Vector2(rect.get_center().x,rect.position.y+(84 if portrait() else 34))-Vector2.ONE*side/2,Vector2.ONE*side)
	var size: Vector2 = (Vector2(90,140) if portrait() else Vector2(76,118)) if tarot else Vector2.ONE*(92 if portrait() else 60)
	var y: float = (84 if portrait() else 72) if tarot else (68 if portrait() else 30)
	return Rect2(Vector2(rect.get_center().x,rect.position.y+y)-size/2,size)

## Leave enough room for two-line item names without covering the sprite.
func offer_name_rect(slot: int) -> Rect2:
	var rect: Rect2 = offer_rect(slot)
	var top: float = rect.size.y-90 if slot >= 6 else 116 if portrait() else 64
	return Rect2(rect.position+Vector2(8,top),Vector2(rect.size.x-16,64 if portrait() else 48))

## Fit long translated names into two lines, leaving the price unobstructed.
func offer_name_size(slot: int, label: String) -> int:
	var size: int = 22 if portrait() else 18
	while size > 14 and GameText.lines(label,battle.description_font,size,offer_name_rect(slot).size.x).size() > 2: size -= 1
	if GameText.language == "en":
		for word in label.split(" "):
			while size > 14 and battle.description_font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > offer_name_rect(slot).size.x: size -= 1
	return size

## Keep the owned relic rail above the large purchase target.
func inventory_rect() -> Rect2:
	return Rect2(48,1384,708,64) if portrait() else Rect2(260,650,760,42)

## Place readable inspection text between merchandise and the owned rail.
func detail_rect() -> Rect2:
	return Rect2(48,1116,708,232) if portrait() else Rect2(350,474,878,164)

## The large lower purchase area is shared by taps and item drops.
func buy_rect() -> Rect2:
	return Rect2(48,1480,708,108) if portrait() else Rect2(396,710,490,68)

## Refresh stays separate from purchasing and always costs fifty crystals.
func refresh_rect() -> Rect2:
	return Rect2(48,1612,340,76) if portrait() else Rect2(52,715,290,58)

## Leave without requiring purchases or spending crystals.
func leave_rect() -> Rect2:
	return Rect2(414,1612,342,76) if portrait() else Rect2(940,715,288,58)

## Ignore shop mutations while a purchased relic is landing.
func busy() -> bool:
	return battle.relic_ui.pickup.active

## Identify useful pointer targets without including empty shelf space.
func hit(at: Vector2) -> bool:
	return refresh_rect().has_point(at) or leave_rect().has_point(at) or buy_rect().has_point(at) or inventory_rect().has_point(at) or range(battle.model.shop.offers.size()).any(func(i): return offer_rect(i).has_point(at))

## Route purchases and replacements before allowing normal inventory dragging.
func click(at: Vector2) -> bool:
	cancel_drag()
	if not visible or battle._menus_open(): return false
	if busy(): return true
	var stock = battle.model.shop
	if replacing:
		var index: int = battle.relic_ui.at_slot(at)
		if index >= 0: _buy(index)
		elif buy_rect().has_point(at): replacing = false
		return true
	if inventory_rect().grow(6).has_point(at): return false
	if leave_rect().has_point(at):
		stock.close()
		cancel()
		return true
	if refresh_rect().has_point(at):
		if stock.refresh(battle.model):
			selected = -1
			refresh_flash = 0.3
			battle._sound("item/book",1.1,-14)
		return true
	if selected >= 0 and buy_rect().has_point(at):
		_attempt_buy()
		return true
	for i in range(stock.offers.size()):
		if offer_rect(i).has_point(at):
			selected = i
			pressed_offer = i if not stock.offers[i].sold and not stock.offers[i].id.is_empty() else -1
			press_at = at
			pointer = at
			dragging = false
			battle._sound("ui/click_001",1,-20)
			break
	return true

## Share one purchase path for the buy button and drag-to-buy gesture.
func _attempt_buy() -> void:
	if battle.model.shop.needs_replacement(battle.model,selected):
		replacing = true
		battle.inventory_page.open("shop")
	else: _buy()

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
	cancel_drag()
	if should_buy: _attempt_buy()
	return true

## Discard a held listing on refresh, focus loss, inventory opening or exit.
func cancel_drag() -> void:
	pressed_offer = -1
	dragging = false
	if is_instance_valid(held_layer): held_layer.queue_redraw()

## Play the existing inventory landing after a successful model transaction.
func _buy(replace_index: int = -1) -> void:
	var previous: Array = battle.model.relics.items.map(func(item): return item.id)
	var bought: Dictionary = battle.model.shop.buy(battle.model,selected,replace_index)
	if bought.is_empty(): return
	replacing = false
	battle._sound("item/confirmation_002",1,-12)
	if bought.kind == "relic": battle.relic_ui.collect(bought.id,offer_art_rect(selected).get_center(),46 if portrait() else 30,previous)
	elif bought.kind == "soul_bottle":
		battle.fx.floating(offer_art_rect(selected).get_center(),GameText.format("+%d souls",bought.souls),SOUL_COLOR,36 if portrait() else 28)

## Animate only small storefront accents; random stock never changes here.
func _process(delta: float) -> void:
	if not visible: return
	held_layer.visible = dragging and not battle._menus_open()
	held_layer.queue_redraw()
	if battle._menus_open(): return
	age += delta
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
	_text(rect.get_center()+Vector2(0,10),text,28 if portrait() else 22,color)

## Draw a simple wooden shelf whose merchandise has no individual boxes.
func _shelf(at: Vector2, width: float) -> void:
	draw_rect(Rect2(at+Vector2(0,12),Vector2(width,12)),Color("0e1114"))
	draw_rect(Rect2(at,Vector2(width,14)),Color("5e4433"))
	draw_rect(Rect2(at,Vector2(width,3)),Color("99764d"))
	for x in range(12,int(width)-12,48): draw_line(at+Vector2(x,8),at+Vector2(x+25,8),Color("342b27"),2)
	for x in [18,width-30]: draw_colored_polygon(PackedVector2Array([at+Vector2(x,14),at+Vector2(x+12,14),at+Vector2(x,34)]),Color("3a3029"))

## Stage the hooded keeper alongside the two relic shelves and tarot shelf.
func _draw_stall() -> void:
	var at := Vector2(0,514) if portrait() else Vector2(42,190)
	var side: float = 252
	var bob: float = 0 if battle.reduced else sin(age*1.7)*2
	for i in range(7,0,-1): draw_circle(at+Vector2(side/2,side*0.65),side*(0.4+i*0.025),Color(0.34,0.27,0.44,0.025))
	keeper_sprite.position = at+Vector2(side/2,side/2+bob)
	keeper_sprite.scale = Vector2.ONE*side/KEEPER.get_width()
	_shelf(at+Vector2(14,side-12),side-28)
	if portrait():
		for y in [526,776,1066]: _shelf(Vector2(270,y),486)
		_shelf(Vector2(48,1066),178)
	else:
		for y in [288,452]: _shelf(Vector2(346,y),584)
		_shelf(Vector2(954,452),278)
		_shelf(Vector2(68,632),200)

## Show the shelf, a readable description, and one large purchase/drop target.
func _draw() -> void:
	if not visible: return
	var screen: Vector2 = battle.fx.canvas_size
	draw_rect(Rect2(Vector2.ZERO,screen),Color("14191d"))
	for i in range(8):
		draw_line(Vector2(i*screen.x/7,0),Vector2(i*screen.x/7,screen.y),Color("33302a",0.18),2)
	_text(Vector2(screen.x/2,180 if portrait() else 69),"Shop",58 if portrait() else 44)
	_text(Vector2(screen.x/2,234 if portrait() else 108),GameText.format("WAVE %d",battle.model.shop.wave),26 if portrait() else 19,Color("a9a39c"))
	battle.chest.draw_currency(self)
	_draw_stall()
	for i in range(battle.model.shop.offers.size()): _draw_offer(i)
	_draw_detail()
	var valid: bool = selected >= 0 and battle.model.shop.can_buy(battle.model,selected) and not busy()
	var over: bool = dragging and buy_rect().has_point(pointer) and valid
	if over:
		for i in range(4,0,-1): Cards.panel(self,buy_rect().grow(i*5),Color(GOLD,0.04))
	_button(buy_rect(),"CANCEL" if replacing else "DROP TO BUY" if dragging else "BUY",valid or replacing)
	if over: draw_rect(buy_rect().grow(-6),Color(GOLD,0.8),false,3)
	_button(refresh_rect(),GameText.format("REFRESH ALL · %d",Stock.REFRESH_PRICE),battle.model.blood_gems >= Stock.REFRESH_PRICE and not busy() and not replacing)
	_button(leave_rect(),"LEAVE SHOP",not busy() and not replacing)
	if refresh_flash > 0: draw_rect(Rect2(Vector2.ZERO,screen),Color(GOLD,refresh_flash*0.14))

## Keep the dragged item above the entire shop while exposing the drop target.
func _draw_held() -> void:
	if not dragging or pressed_offer < 0: return
	var offer: Dictionary = battle.model.shop.offers[pressed_offer]
	var at: Vector2 = pointer-Vector2(0,36 if portrait() else 22)
	if offer.kind == "relic": RelicPaint.paint(held_layer,offer.id,at,66 if portrait() else 52,true)
	elif offer.kind == "tarot": Cards.card(held_layer,offer.id,at,Vector2(108,168),0,1,0.4,0.86)
	else: Icons.paint(held_layer,battle.chest.art,"soul_bottle",Rect2(at-Vector2.ONE*64,Vector2.ONE*128))

## Keep item labels independent of their catalogue and never reveal sealed contents.
func offer_name(offer: Dictionary) -> String:
	if offer.kind == "relic": return Relics.ITEMS[offer.id].name
	if offer.kind == "tarot": return Cards.Catalog.ITEMS[offer.id].name
	return "Soul Bottle"

## Reveal the exact soul amount only after this bottle has been purchased.
func offer_description(offer: Dictionary) -> String:
	if offer.kind == "relic": return GameText.text(Relics.ITEMS[offer.id].text)
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
			if not (battle.relic_ui.pickup.active and selected == slot): RelicPaint.paint(self,offer.id,artwork.get_center(),artwork.size.x/2,true)
		elif offer.kind == "tarot":
			draw_texture_rect(Cards.texture(offer.id),artwork,false,Color("d9cedd"))
		else:
			Icons.paint(self,battle.chest.art,"soul_bottle",artwork)
	var label := offer_name(offer)
	_wrap(offer_name_rect(slot),label,offer_name_size(slot,label),color,true)
	_price(Vector2(rect.get_center().x,rect.end.y-(10 if portrait() else 14)),offer.price,battle.model.blood_gems >= offer.price)

## Keep inspection on the shop page, with explicit buy or replacement cancellation.
func _draw_detail() -> void:
	var rect: Rect2 = detail_rect()
	draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color("5a5145"),2)
	if selected < 0:
		_wrap(rect.grow(-24),"Tap an item to inspect it. Purchased tarot cards go straight into your collection.",30 if portrait() else 24,Color("c9c0af"),true)
		return
	var offer: Dictionary = battle.model.shop.offers[selected]
	if offer.id.is_empty(): return
	var title := offer_name(offer)
	var description := offer_description(offer)
	var name_color := offer_color(offer)
	_text(Vector2(rect.get_center().x,rect.position.y+38),title,30 if portrait() else 24,name_color)
	var body := Rect2(rect.position+Vector2(20,50),Vector2(rect.size.x-40,rect.size.y-102))
	var size: int = 28 if portrait() else 23
	while size > 18 and GameText.lines(description,battle.description_font,size,body.size.x).size()*size*1.3 > body.size.y: size -= 1
	_wrap(body,description,size,Color("e7dfd1"))
	_price(Vector2(rect.get_center().x,rect.end.y-14),offer.price,battle.model.blood_gems >= offer.price)
