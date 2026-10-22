extends Node2D
## A shared ten-slot inventory and item details page, above battle and rewards.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Panels = preload("res://scripts/tarot/tarot_paint.gd")
const GOLD := Color("dfc78d")
var battle
var opened: bool = false
var selected: int = -1
var replacement: String = ""

## Cover held items while remaining below settings and help.
func _ready() -> void:
	z_index = 450
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Use the same five-column grid at both supported screen sizes.
func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Place the inventory shortcut in free header space on every supported page.
func button_rect() -> Rect2:
	if battle.view_phase in ["shop","reward","over"]:
		return Rect2(620,124,136,76) if portrait() else Rect2(1090,26,148,48)
	return Rect2(338,124,108,88) if portrait() else Rect2(974,24,96,34)

## Permit browsing during battle, shop decisions and chest collection.
func available(source: String = "") -> bool:
	var tarot_choice: bool = source == "tarot" and battle.tarot_cast.choice_type == "replace" and not battle.tarot_cast.busy
	return not battle.menu_open and not battle.guide and not battle.debug_open and not battle.tarot_ui.ceremony.active() and (not battle.tarot_cast.active() or tarot_choice) and not battle.relic_ui.pickup.active and (tarot_choice or battle.view_phase in ["ready","skill","targeting","frozen","shop","reward","wave_reward","over"])

## Open safely without carrying a held skill or item into the modal page.
func open(source: String = "") -> void:
	if not available(source): return
	opened = true
	selected = -1
	replacement = source
	if replacement.is_empty() and battle.view_phase == "shop" and battle.shop_ui.replacing: replacement = "shop"
	if replacement.is_empty() and battle.view_phase == "reward" and battle.relic_ui.chest_slot >= 0: replacement = "chest"
	battle._cancel_targeting()
	battle._cancel_enemy_hold()
	battle.relic_ui.cancel_hold()
	battle.tarot_ui.cancel_gesture()
	battle.shop_ui.cancel_drag()
	battle._sound("ui/book",1,-17)
	queue_redraw()

## Close inspection; cancellation keeps chest prizes and uncommitted tarot cards intact.
func close(cancel_pending: bool = true) -> void:
	var source: String = replacement
	opened = false
	selected = -1
	replacement = ""
	battle.tarot_ui.swallow_release = true
	if cancel_pending:
		if source == "chest": battle.relic_ui.chest_slot = -1
		elif source == "tarot": battle.tarot_cast.cancel_choice()
	queue_redraw()

## Return all ten stable cells, including uncollected inventory spaces.
func slot_rect(index: int) -> Rect2:
	var step := Vector2(144,192) if portrait() else Vector2(190,180)
	var size := Vector2(132,164) if portrait() else Vector2(168,154)
	var start := Vector2(48,520) if portrait() else Vector2(176,244)
	return Rect2(start+Vector2(index%5,index/5)*step,size)

## Keep close and back controls separate from item or replacement taps.
func close_rect() -> Rect2:
	return Rect2(610,128,146,80) if portrait() else Rect2(1070,56,150,56)

func back_rect() -> Rect2:
	return Rect2(48,1510,300,90) if portrait() else Rect2(170,686,300,64)

func replace_rect() -> Rect2:
	return Rect2(376,1510,380,90) if portrait() else Rect2(682,686,428,64)

## Put declining the new reward inside its description card, away from owned items.
func discard_rect() -> Rect2:
	return Rect2(80,1240,140,68) if portrait() else Rect2(212,738,138,34)

## Discard only the incoming reward; closing the page remains a reversible cancel.
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
	if selected < 0 and not incoming_relic().is_empty() and discard_rect().has_point(at):
		_discard_incoming()
		return true
	if selected >= 0:
		if back_rect().has_point(at): selected = -1
		elif not replacement.is_empty() and replace_rect().has_point(at): _replace()
	else:
		for i in range(battle.model.relics.items.size()):
			if slot_rect(i).has_point(at): selected = i; break
	return true

## Confirm replacement only from the inspected item's explicit action button.
func _replace() -> void:
	if selected < 0 or selected >= battle.model.relics.items.size(): return
	if replacement == "shop":
		battle.shop_ui._buy(selected)
		if not battle.shop_ui.replacing: close()
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
	return ""

## Refresh live item counters and the shortcut's enabled state.
func _process(_delta: float) -> void:
	queue_redraw()

## Render crisp translated text without relying on tiny sprite lettering.
func _text(at: Vector2, value: String, size: int, color: Color = GOLD) -> void:
	Panels.text(self,battle.description_font,at,value,size,color)

func _button(rect: Rect2, label: String) -> void:
	Panels.panel(self,rect,Color("28272a"),GOLD,10)
	_text(rect.get_center()+Vector2(0,10),label,28 if portrait() else 22)

## Paint a compact shortcut or the opaque inventory page above every game layer.
func _draw() -> void:
	if not opened:
		if available(): _button(button_rect(),"ITEMS")
		return
	draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color("15191e"))
	_button(close_rect(),"CANCEL" if replacement in ["chest","tarot"] else "CLOSE")
	if selected >= battle.model.relics.items.size(): selected = -1
	if selected >= 0: _draw_item(); return
	_text(Vector2(battle.fx.canvas_size.x/2,320 if portrait() else 156),"RELIC INVENTORY",44 if portrait() else 36)
	_text(Vector2(battle.fx.canvas_size.x/2,388 if portrait() else 202),GameText.format("%d / 10 ITEMS",battle.model.relics.items.size()),27 if portrait() else 21,Color("a9a39c"))
	for i in range(Catalog.MAX_SLOTS): _draw_slot(i)
	var message: String = "Choose an owned item to inspect before replacing it." if not replacement.is_empty() else "Tap an item to view its details."
	Panels.wrap(self,battle.description_font,Rect2(48 if portrait() else 176,956 if portrait() else 604,708 if portrait() else 928,80),message,28 if portrait() else 22,Color("c4bba8"),true)
	_draw_incoming(false)

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
	var text_rect := Rect2(rect.position+Vector2(162,16),rect.size-Vector2(180,32))
	var description: String = label+"\n"+GameText.text(Catalog.ITEMS[id].text)
	var size: int = 28 if portrait() else 22
	while size > 18 and GameText.lines(description,battle.description_font,size,text_rect.size.x).size()*size*1.3 > text_rect.size.y: size -= 1
	Panels.wrap(self,battle.description_font,text_rect,description,size,Color("eee4d2"),false)
	_button(discard_rect(),"DISCARD")

## Keep empty cells visible and tint collected cells by their item's rarity.
func _draw_slot(index: int) -> void:
	var rect: Rect2 = slot_rect(index)
	var occupied: bool = index < battle.model.relics.items.size()
	var item: Dictionary = battle.model.relics.items[index] if occupied else {}
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
	if not replacement.is_empty(): _button(replace_rect(),"REPLACE THIS ITEM")
