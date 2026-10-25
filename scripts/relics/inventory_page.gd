extends Node2D
## A shared ten-slot inventory and item details page, above battle and rewards.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Panels = preload("res://scripts/tarot/tarot_paint.gd")
const GOLD := Color("dfc78d")
const BACKPACK_PIXELS := [
	"000000kkkkkk000000", "00000kk0000kk00000", "00000kl0000lk00000",
	"000kkkkkkkkkkkk000", "00kllbbbbbbbbllk00", "0klbbbbbbbbbbbblk0",
	"0klbbbbbbbbbbbblk0", "0kllllllllllllllk0", "0kllffffffffffllk0",
	"0klllfffffffflllk0", "0klbllllggllllblk0", "0klbbbbkggkbbbblk0",
	"0klbbbbkkkkbbbblk0", "0klbbbbbbbbbbbblk0", "0klbkkkkkkkkbblk00",
	"0klbklpppplkbblk00", "0klbkllllllkbblk00", "0klbkkkkkkkkbblk00",
	"00kbbbbbbbbbbbk000", "000kkkkkkkkkkk0000"]
const BACKPACK_PALETTE := {"k":Color("171b1a"),"b":Color("8c6749"),"l":Color("b79762"),"f":Color("c6ab72"),"g":GOLD,"p":Color("72543d")}
var battle
var opened: bool = false
var selected: int = -1
var replacement: String = ""
var pressed: int = -1
var dragging: bool = false
var press_origin := Vector2.ZERO
var pointer := Vector2.ZERO
var sale_receipt: int = 0
var sale_receipt_time: float = 0

## Cover held items while remaining below settings and help.
func _ready() -> void:
	z_index = 450
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Use the same five-column grid at both supported screen sizes.
func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Keep the backpack beside the dice during battle and rewards; the shop has its own rail.
func button_rect() -> Rect2:
	if battle.view_phase == "shop":
		return Rect2(652,124,104,104) if portrait() else Rect2(1168,26,66,66)
	var tarot: Rect2 = battle.tarot_ui.icon_rect()
	return Rect2(Vector2(2*battle.DICE_CENTER.x-tarot.end.x,tarot.position.y),tarot.size)

## Permit browsing during battle, shop decisions and chest collection.
func available(source: String = "") -> bool:
	var tarot_choice: bool = source == "tarot" and battle.tarot_cast.choice_type == "replace" and not battle.tarot_cast.busy
	return not battle.menu_open and not battle.guide and not battle.debug_open and not battle.tarot_ui.ceremony.active() and (not battle.tarot_cast.active() or tarot_choice) and not battle.relic_ui.pickup.active and (tarot_choice or battle.view_phase in ["ready","skill","targeting","frozen","shop","reward","wave_reward","over"])

## Open safely without carrying a held skill or item into the modal page.
func open(source: String = "") -> void:
	if not available(source): return
	opened = true
	selected = -1
	cancel_drag()
	replacement = source
	if replacement.is_empty() and battle.view_phase == "shop" and battle.shop_ui.replacing: replacement = "shop"
	if replacement.is_empty() and battle.view_phase == "reward" and battle.relic_ui.chest_slot >= 0: replacement = "chest"
	battle._cancel_targeting()
	battle._cancel_enemy_hold()
	battle.relic_ui.cancel_hold()
	battle.tarot_ui.cancel_gesture()
	battle.tarot_ui.inspected = -1
	battle.shop_ui.cancel_drag()
	battle._sound("ui/book",1,-17)
	queue_redraw()

## Close inspection; cancellation keeps chest prizes and uncommitted tarot cards intact.
func close(cancel_pending: bool = true) -> void:
	var source: String = replacement
	opened = false
	selected = -1
	cancel_drag()
	replacement = ""
	battle.tarot_ui.swallow_release = true
	if cancel_pending:
		if source == "chest": battle.relic_ui.chest_slot = -1
		elif source == "tarot": battle.tarot_cast.cancel_choice()
		elif source == "shop": battle.shop_ui.cancel_purchase()
	queue_redraw()

## Return all ten stable cells, including uncollected inventory spaces.
func slot_rect(index: int) -> Rect2:
	var step := Vector2(144,192) if portrait() else Vector2(190,180)
	var size := Vector2(132,164) if portrait() else Vector2(168,154)
	var start := Vector2(48,520) if portrait() else Vector2(176,244)
	return Rect2(start+Vector2(index%5,index/5)*step,size)

## Number the first row from above and the second row from below.
func number_position(index: int) -> Vector2:
	var rect: Rect2 = slot_rect(index)
	return Vector2(rect.get_center().x,rect.position.y-14 if index < 5 else rect.end.y+(32 if portrait() else 28))

## Empty cells accept an append, preserving continuous left-to-right activation order.
func drop_index(at: Vector2) -> int:
	var count: int = battle.model.relics.items.size()
	if count == 0: return -1
	for i in range(Catalog.MAX_SLOTS):
		if slot_rect(i).grow(6).has_point(at): return mini(i,count-1)
	return -1

## Capture a two-dimensional drag only after a small mouse or finger movement.
func motion(at: Vector2) -> bool:
	if not opened: return false
	if pressed >= 0:
		pointer = at
		if at.distance_to(press_origin) > (14 if portrait() else 8): dragging = true
	return true

## A tap opens details; a drop reorders exactly once and never selects a reward.
func release(at: Vector2) -> bool:
	if not opened: return false
	if pressed >= 0:
		motion(at)
		if dragging:
			var destination: int = drop_index(at)
			if destination >= 0: battle.model.move_relic(pressed,destination)
		elif slot_rect(pressed).has_point(at): selected = pressed
	cancel_drag()
	return true

## Cancel gestures on close or focus loss without changing inventory priority.
func cancel_drag() -> void:
	pressed = -1
	dragging = false

## Keep close and back controls separate from item or replacement taps.
func close_rect() -> Rect2:
	return Rect2(610,128,146,80) if portrait() else Rect2(1070,56,150,56)

func back_rect() -> Rect2:
	return Rect2(48,1510,300,90) if portrait() else Rect2(170,686,300,64)

func replace_rect() -> Rect2:
	return Rect2(376,1510,380,90) if portrait() else Rect2(682,686,428,64)

## Put declining the new reward inside its description card, away from owned items.
func discard_rect() -> Rect2:
	return Rect2(80,1240,140,68) if portrait() else Rect2(904,670,154,42)

## Keep sales accessible while comparing a reward against an owned item.
func sell_rect() -> Rect2:
	if replacement.is_empty(): return replace_rect()
	return Rect2(48,128,250,80) if portrait() else Rect2(60,56,220,56)

func take_rect() -> Rect2:
	return Rect2(440,1240,250,68) if portrait() else Rect2(904,746,154,32)

## A newly freed slot accepts the pending reward only on an explicit tap.
func can_take_incoming() -> bool:
	var id: String = incoming_relic()
	return not id.is_empty() and battle.model.relics.can_add(id) and (not battle.model.relics.needs_slot(id) or battle.model.relics.items.size() < Catalog.MAX_SLOTS)

func _take_incoming() -> void:
	if not can_take_incoming(): return
	if replacement == "chest":
		if battle._claim_chest_reward(battle.relic_ui.chest_slot): close(false)
	elif replacement == "tarot":
		battle.tarot_cast._cast({})
		if battle.tarot_cast.busy: close(false)
	elif replacement == "shop":
		battle.shop_ui._buy()
		if not battle.shop_ui.replacing: close(false)

## Discard only the incoming reward; closing a chest picker preserves its prize.
func _discard_incoming() -> void:
	if incoming_relic().is_empty(): return
	if replacement == "chest":
		if battle._claim_chest_reward(battle.relic_ui.chest_slot,-1,true):
			battle.relic_ui.chest_slot = -1
			close(false)
	elif replacement == "tarot":
		battle.tarot_cast._cast({"discard":true})
		if battle.tarot_cast.busy: close(false)

## Swallow modal input; the shortcut opens before chest or shop hit handlers.
func click(at: Vector2) -> bool:
	if not opened:
		if available() and button_rect().has_point(at): open(); return true
		return false
	if close_rect().has_point(at): close(); return true
	if selected < 0 and replacement in ["chest","tarot"] and not incoming_relic().is_empty() and discard_rect().has_point(at):
		_discard_incoming()
		return true
	if selected < 0 and can_take_incoming() and take_rect().has_point(at):
		_take_incoming()
		return true
	if selected >= 0:
		if sell_rect().has_point(at):
			sale_receipt = battle.model.sell_relic(selected)
			sale_receipt_time = 2.0
			selected = -1
			battle._sound("item/confirmation_002",1,-12)
		elif back_rect().has_point(at): selected = -1
		elif not replacement.is_empty() and replace_rect().has_point(at): _replace()
	else:
		for i in range(battle.model.relics.items.size()):
			if slot_rect(i).has_point(at):
				pressed = i
				press_origin = at
				pointer = at
				dragging = false
				break
	return true

## Confirm replacement only from the inspected item's explicit action button.
func _replace() -> void:
	if selected < 0 or selected >= battle.model.relics.items.size(): return
	if replacement == "shop":
		battle.shop_ui._buy(selected)
		if not battle.shop_ui.replacing: close(false)
	elif replacement == "chest":
		if battle._claim_chest_reward(battle.relic_ui.chest_slot,selected): close(false)
	elif replacement == "tarot":
		battle.tarot_cast._cast({"replace":selected})
		if battle.tarot_cast.busy: close(false)

## Show the locked incoming item beside the inventory decision, without another draw.
func incoming_relic() -> String:
	match replacement:
		"chest": return battle.model.reward_item(battle.relic_ui.chest_slot).get("relic_id","")
		"tarot": return battle.tarot_cast.prepared.get("relic","")
		"shop":
			if battle.shop_ui.selected >= 0: return battle.model.shop.offers[battle.shop_ui.selected].id
	return ""

## Refresh live item counters and the shortcut's enabled state.
func _process(delta: float) -> void:
	sale_receipt_time = maxf(0,sale_receipt_time-delta)
	queue_redraw()

## Render crisp translated text without relying on tiny sprite lettering.
func _text(at: Vector2, value: String, size: int, color: Color = GOLD) -> void:
	Panels.text(self,battle.description_font,at,value,size,color)

func _button(rect: Rect2, label: String) -> void:
	Panels.panel(self,rect,Color("28272a"),GOLD,10)
	_text(rect.get_center()+Vector2(0,10),label,28 if portrait() else 22)

## Preview sale or forfeit proceeds directly below its committing button.
func _gem_quote(rect: Rect2, amount: int) -> void:
	battle.chest.font = battle.description_font
	battle.chest.draw_gem_quote(self,Vector2(rect.get_center().x,rect.end.y+(26 if portrait() else 17)),amount,26 if portrait() else 19)

## Paint a compact shortcut or the opaque inventory page above every game layer.
func _draw() -> void:
	if not opened:
		if not battle.menu_open and not battle.guide and not battle.debug_open and not battle.tarot_ui.ceremony.active() and not battle.tarot_cast.active(): _draw_shortcut()
		return
	draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color("15191e"))
	_button(close_rect(),"CANCEL" if not replacement.is_empty() else "CLOSE")
	if selected >= battle.model.relics.items.size(): selected = -1
	if selected >= 0: _draw_item(); return
	_text(Vector2(battle.fx.canvas_size.x/2,320 if portrait() else 156),"RELIC INVENTORY",44 if portrait() else 36)
	_text(Vector2(battle.fx.canvas_size.x/2,388 if portrait() else 202),GameText.format("+%d blood gems",sale_receipt) if sale_receipt_time > 0 else GameText.format("%d / 10 ITEMS",battle.model.relics.items.size()),27 if portrait() else 21,Color("a9a39c"))
	var order: Array = range(battle.model.relics.items.size())
	var destination: int = drop_index(pointer) if dragging else -1
	if dragging:
		order.erase(pressed)
		order.insert(destination if destination >= 0 else pressed,-1)
	for i in range(Catalog.MAX_SLOTS):
		_draw_slot(i,order[i] if i < order.size() else -1)
		_text(number_position(i),str(i+1),28 if portrait() else 22,Color("a9a39c"))
	var message: String = "Tap to compare · Drag to reorder" if not replacement.is_empty() else "Tap to inspect · Drag to reorder"
	Panels.wrap(self,battle.description_font,Rect2(48 if portrait() else 176,956 if portrait() else 620,708 if portrait() else 928,64),message,28 if portrait() else 22,Color("c4bba8"),true)
	_draw_incoming(false)
	if dragging and pressed >= 0 and pressed < battle.model.relics.items.size():
		if destination >= 0:
			var rect: Rect2 = slot_rect(destination)
			Panels.panel(self,rect.grow(-4),Color("a8adb0",0.22),Color("c8cbce",0.9),12)
		var item: Dictionary = battle.model.relics.items[pressed]
		var at: Vector2 = slot_rect(pressed).get_center()-Vector2(0,16)+pointer-press_origin
		Paint.paint(self,item.id,at,58 if portrait() else 55,true,item)

## A hand-drawn pixel backpack stays visible as the destination for incoming relics.
func _draw_shortcut() -> void:
	var rect: Rect2 = button_rect()
	var scale_factor: Vector2 = battle.relic_ui.pickup.inventory_scale(battle.relic_ui.pickup.slot,battle.reduced)
	draw_set_transform(rect.get_center(),0,scale_factor)
	Panels.panel(self,Rect2(-rect.size/2,rect.size),Color("292821"),Color("9b8863"),14)
	var unit: float = rect.size.x/28.0
	var origin := Vector2(-9,-10)*unit
	for y in range(BACKPACK_PIXELS.size()):
		for x in range(BACKPACK_PIXELS[y].length()):
			var key: String = BACKPACK_PIXELS[y][x]
			if BACKPACK_PALETTE.has(key): draw_rect(Rect2(origin+Vector2(x,y)*unit,Vector2.ONE*unit),BACKPACK_PALETTE[key])
	var count: int = battle.model.relics.items.size()
	if count > 0: _text(rect.size/2-Vector2(17,8),str(count),22 if portrait() else 16)
	if not available(): Panels.panel(self,Rect2(-rect.size/2,rect.size),Color(0.06,0.06,0.07,0.45),Color.TRANSPARENT,14)
	draw_set_transform(Vector2.ZERO)

## Keep the new relic visible while players compare it with an owned item's details.
func _draw_incoming(compact: bool) -> void:
	var id: String = incoming_relic()
	if id.is_empty(): return
	var color: Color = Catalog.rarity_color(id)
	var label: String = GameText.format("Incoming relic: %s",GameText.text(Catalog.ITEMS[id].name))
	if compact:
		Panels.wrap(self,battle.description_font,Rect2(66,238,672,128) if portrait() else Rect2(230,110,820,54),label,28 if portrait() else 21,color,true)
		return
	var rect := Rect2(66,1060,672,350) if portrait() else Rect2(200,658,880,120)
	Panels.panel(self,rect,Color(color,0.06),Color(color,0.45),12)
	var center := rect.position+Vector2(82,88 if portrait() else 58)
	Paint.paint(self,id,center,54 if portrait() else 42,true)
	var text_rect := Rect2(rect.position+Vector2(162,16),rect.size-Vector2(180 if portrait() else 376,32))
	var description: String = label+"\n"+GameText.text(Catalog.ITEMS[id].text)
	var size: int = 28 if portrait() else 22
	while size > 18 and GameText.lines(description,battle.description_font,size,text_rect.size.x).size()*size*1.3 > text_rect.size.y: size -= 1
	Panels.wrap(self,battle.description_font,text_rect,description,size,Color("eee4d2"),false)
	if replacement in ["chest","tarot"]:
		_button(discard_rect(),"DISCARD")
		_gem_quote(discard_rect(),battle.model.relic_forfeit_preview(id))
	if can_take_incoming(): _button(take_rect(),"BUY" if replacement == "shop" else "TAKE RELIC")

## Keep empty cells visible and tint collected cells by their item's rarity.
func _draw_slot(index: int, item_index: int) -> void:
	var rect: Rect2 = slot_rect(index)
	var occupied: bool = item_index >= 0
	var item: Dictionary = battle.model.relics.items[item_index] if occupied else {}
	var color: Color = Catalog.rarity_color(item.id) if occupied else Color("42474b")
	Panels.panel(self,rect,Color(color,0.09 if occupied else 0.03),Color(color,0.75 if occupied else 0.55),12)
	if not occupied:
		draw_line(rect.get_center()-Vector2(12,0),rect.get_center()+Vector2(12,0),Color("42474b"),2)
		return
	Paint.paint(self,item.id,rect.get_center()-Vector2(0,16),48 if portrait() else 46,true,item)
	var label: String = GameText.text(Catalog.RARITY_NAMES[Catalog.ITEMS[item.id].rarity])
	_text(Vector2(rect.get_center().x,rect.end.y-14),label,19 if portrait() else 16,color)
	var count: int = Catalog.counter_value(item)
	if count > 0: _text(rect.position+Vector2(rect.size.x-20,28),str(count),22,color)

## Give each relic a dedicated large illustration, rarity and complete description.
func _draw_item() -> void:
	_draw_incoming(true)
	var item: Dictionary = battle.model.relics.items[selected]
	var color: Color = Catalog.rarity_color(item.id)
	var mid: float = battle.fx.canvas_size.x/2
	Paint.paint(self,item.id,Vector2(mid,550 if portrait() else 256),126 if portrait() else 90,true,item)
	_text(Vector2(mid,775 if portrait() else 398),Catalog.ITEMS[item.id].name,40 if portrait() else 32,color)
	_text(Vector2(mid,835 if portrait() else 442),Catalog.RARITY_NAMES[Catalog.ITEMS[item.id].rarity],26 if portrait() else 21,color)
	var rect := Rect2(66,916,672,500) if portrait() else Rect2(228,476,824,186)
	var description: String = Catalog.description(item,GameText.text)
	var size: int = 34 if portrait() else 26
	while size > 20 and GameText.lines(description,battle.description_font,size,rect.size.x).size()*size*1.3 > rect.size.y: size -= 1
	Panels.wrap(self,battle.description_font,rect,description,size,Color("eee4d2"),true)
	_button(back_rect(),"BACK TO INVENTORY")
	_button(sell_rect(),"SELL")
	_gem_quote(sell_rect(),battle.model.relic_sale_preview(selected))
	if not replacement.is_empty():
		_button(replace_rect(),"REPLACE THIS ITEM")
		_gem_quote(replace_rect(),battle.model.replacement_gem_preview(incoming_relic(),selected))
