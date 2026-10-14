extends Node2D
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Pickup = preload("res://scripts/relics/relic_pickup.gd")
var pickup = Pickup.new()
var battle
var pressed: int = -1
var dragging: bool = false
var pointer := Vector2.ZERO
var press_origin := Vector2.ZERO
var chest_slot: int = -1
var bar_style: StyleBoxFlat
var drop_style: StyleBoxFlat
const ACTIVATION_TIME := 0.65
const ICON_RADIUS_SCALE := 0.49
const HELD_RADIUS_SCALE := 0.59
var activations: Dictionary = {}
var ready_clock: float = 0.0

func _ready() -> void:
	z_index = 110
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color("10160f",0.56)
	bar_style.set_corner_radius_all(12)
	bar_style.corner_detail = 6
	bar_style.anti_aliasing = true
	drop_style = StyleBoxFlat.new()
	drop_style.bg_color = Color("a8adb0",0.36)
	drop_style.border_color = Color("c8cbce",0.75)
	drop_style.set_border_width_all(2)
	drop_style.set_corner_radius_all(8)
	drop_style.corner_detail = 6
	drop_style.anti_aliasing = true

func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

func inventory_rect() -> Rect2:
	if chest_slot >= 0 or (battle.view_phase == "reward" and pickup.active): return Rect2(48,1376,708,64) if portrait() else Rect2(260,602,760,56)
	return Rect2(48,982,708,54) if portrait() else Rect2(36,474,480,38)

func slot_rect(index: int) -> Rect2:
	var row: Rect2 = inventory_rect()
	var step: float = row.size.x / Catalog.MAX_SLOTS
	return Rect2(row.position + Vector2(index*step,0),Vector2(step-4,row.size.y))

func skip_rect() -> Rect2:
	return Rect2(142,1490,520,96) if portrait() else Rect2(422,686,436,58)

func interactable() -> bool:
	return not pickup.active and not battle._menus_open() and battle.inspecting_enemy < 0 and (battle.view_phase in ["ready","skill"] or (battle.view_phase == "reward" and chest_slot >= 0))

func at_slot(at: Vector2) -> int:
	for i in range(battle.model.relics.items.size()):
		if slot_rect(i).has_point(at): return i
	return -1

func drop_index(at: Vector2) -> int:
	var row: Rect2 = inventory_rect()
	var count: int = battle.model.relics.items.size()
	# A captured drag follows one horizontal rail, even if the finger drifts vertically.
	var margin: float = 12 if portrait() else 8
	if count == 0 or at.x < row.position.x-margin or at.x > row.end.x+margin: return -1
	return clampi(floori((at.x-row.position.x)/(row.size.x/Catalog.MAX_SLOTS)),0,count-1)

func held_position() -> Vector2:
	var rect: Rect2 = slot_rect(pressed)
	if not dragging: return rect.get_center()
	var row: Rect2 = inventory_rect()
	return Vector2(clampf(rect.get_center().x+pointer.x-press_origin.x,row.position.x+rect.size.y/2,row.end.x-rect.size.y/2),row.get_center().y)

func click(at: Vector2) -> bool:
	if pickup.active and not battle._menus_open(): return true
	if not interactable(): return false
	pointer = at
	var index: int = at_slot(at)
	if chest_slot >= 0:
		if index >= 0:
			if battle._claim_chest_reward(chest_slot,index) and not pickup.active: reset()
		elif skip_rect().has_point(at):
			battle._claim_chest_reward(chest_slot,-1,true)
			reset()
		return true
	if index >= 0:
		pressed = index
		press_origin = at
		dragging = false
		return true
	return false

func collect(id: String, from: Vector2, radius: float, previous_ids: Array) -> void:
	var slot: int = battle.model.relics.index_of(id)
	# Fusion may replace the selected relic with a new inventory entry.
	if slot < 0: slot = battle.model.relics.items.find_custom(func(item): return item.id not in previous_ids)
	if slot < 0: return
	cancel_hold()
	pickup.start(id,slot,from,radius)
	queue_redraw()

func motion(at: Vector2) -> bool:
	if pressed < 0: return false
	pointer = at
	if absf(at.x-press_origin.x) > (12 if portrait() else 7): dragging = true
	return true

func release(at: Vector2) -> bool:
	if pressed < 0: return false
	if dragging and interactable():
		var index: int = drop_index(at)
		if index >= 0: battle.model.move_relic(pressed,index)
	pressed = -1
	dragging = false
	return true

func cancel_hold() -> void:
	pressed = -1
	dragging = false

func reset() -> void:
	cancel_hold()
	chest_slot = -1
	activations.clear()
	ready_clock = 0.0
	pickup.clear()

func activate(id: String, animation_speed: float = 0.0) -> void:
	var slot: int = battle.model.relics.index_of(id)
	if animation_speed <= 0: animation_speed = battle.model.relic_activation_speed
	if slot >= 0: activations[id] = {"age":0.0,"slot":slot,"speed":animation_speed}

func activation_tilt(id: String) -> float:
	if battle.reduced or not activations.has(id): return 0.0
	var t: float = activations[id].age/ACTIVATION_TIME
	return sin(t*TAU*1.5)*0.13*(1-t)

func _process(delta: float) -> void:
	if not battle._menus_open():
		ready_clock += delta
		for id in activations.keys():
			activations[id].age += delta*clampf(battle._roll_speed(),1,2)*activations[id].get("speed",1.0)
			if activations[id].age >= ACTIVATION_TIME: activations.erase(id)
		if pickup.active:
			if pickup.advance(delta*clampf(battle.speed,1,2)): battle._sound("item/drop_001",0.8,-12)
			if not pickup.active:
				chest_slot = -1
	self_modulate = Color(0.25,0.25,0.25) if battle.inspecting_enemy >= 0 else Color.WHITE
	if not interactable(): pressed = -1; dragging = false
	z_index = battle.HELD_ITEM_Z if pressed >= 0 else 140 if chest_slot >= 0 else 110
	queue_redraw()

func _text(at: Vector2, value: String, size: int, color: Color) -> void:
	value = GameText.text(value)
	draw_string(battle.pixel_font,at.round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(at: Vector2, value: String, size: int, color: Color) -> void:
	value = GameText.text(value)
	var width: float = battle.pixel_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_text(at-Vector2(width/2,0),value,size,color)

func _wrap(at: Vector2, value: String, width: float, size: int, color: Color) -> void:
	var y: float = at.y
	for line in GameText.lines(value, battle.description_font, size, width):
		draw_string(battle.description_font,Vector2(at.x,y).round(),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		y += size+8

func _frame(rect: Rect2, color: Color, rarity: bool = false) -> void:
	draw_rect(rect,Color("20271f"))
	draw_rect(rect,color if rarity else color.darkened(0.35),false,3 if rarity else 2)
	draw_rect(rect.grow(-5),Color(color,0.15),false,1)

func _draw() -> void:
	if not is_instance_valid(battle) or battle._menus_open() or battle.view_phase in ["over","wave_reward"] or (battle.view_phase == "reward" and chest_slot < 0 and not pickup.active): return
	if chest_slot >= 0: _draw_chest_replacement()
	draw_style_box(bar_style,inventory_rect())
	var order: Array = range(battle.model.relics.items.size())
	var destination: int = drop_index(pointer) if dragging else -1
	if dragging and pressed >= 0 and pressed < order.size():
		order.erase(pressed)
		order.insert(destination if destination >= 0 else pressed,-1)
	for i in range(order.size()):
		if order[i] < 0 or order[i] == pressed: continue
		if pickup.active and not pickup.landed and i == pickup.slot: continue
		var rect: Rect2 = slot_rect(i)
		var item: Dictionary = battle.model.relics.items[order[i]]
		_paint_inventory_item(item,rect,false,pickup.inventory_scale(i,battle.reduced))
	# A consumed Last Contract gets its brief activation before disappearing.
	for id in activations:
		if not battle.model.relics.has(id): _paint_inventory_item({"id":id},slot_rect(activations[id].slot))
	if destination >= 0: _draw_drop_indicator(destination)
	if pressed >= 0 and pressed < battle.model.relics.items.size():
		var held_size: Vector2 = slot_rect(pressed).size
		_paint_inventory_item(battle.model.relics.items[pressed],Rect2(held_position()-held_size/2,held_size),true)
	if interactable(): _draw_tooltip()
	if pickup.active:
		var target: Rect2 = slot_rect(pickup.slot)
		pickup.paint(self,target.get_center(),target.size.y*ICON_RADIUS_SCALE,battle.reduced)

func ready_glow(item: Dictionary) -> float:
	if not Catalog.charged(item): return 0.0
	return 0.9 if battle.reduced else 0.85+sin(ready_clock*4.5)*0.15

func _paint_inventory_item(item: Dictionary, rect: Rect2, held: bool = false, landing_scale: Vector2 = Vector2.ONE) -> void:
	var id: String = item.id
	var strength: float = 0.0
	if activations.has(id): strength = sin(clampf(activations[id].age/ACTIVATION_TIME,0,1)*PI)
	var at: Vector2 = rect.get_center()
	var radius: float = rect.size.y*(HELD_RADIUS_SCALE if held else ICON_RADIUS_SCALE)
	var pulse: float = ready_glow(item)
	if pulse > 0:
		var gold := Color("dfb866")
		for i in range(5,0,-1):
			draw_circle(at,radius+i*2.5,Color(gold,pulse*0.16))
		Pixel.circle(self,at,radius+4+pulse*3,Color(gold.lightened(0.5),pulse*0.85),2)
		for i in range(4):
			var glint: Vector2 = at+Vector2.from_angle(PI/4+i*PI/2)*(radius+5)
			Pixel.line(self,glint-Vector2(2,0),glint+Vector2(2,0),Color("fff2c8",pulse),2)
			Pixel.line(self,glint-Vector2(0,2),glint+Vector2(0,2),Color("fff2c8",pulse),2)
	if strength > 0:
		var color: Color = Catalog.color(id).lightened(0.3)
		for i in range(4): draw_circle(at,radius*(1.15+i*0.22),Color(color,strength*(0.16-i*0.03)))
		draw_arc(at,radius*1.18,0,TAU,32,Color(color,strength*0.85),2)
	var scale_factor: float = 1.0 if battle.reduced else 1.0+strength*0.08
	draw_set_transform(at,activation_tilt(id),landing_scale*scale_factor)
	Paint.paint(self,id,Vector2.ZERO,radius,held)
	draw_set_transform(Vector2.ZERO)
	_draw_counter(item,at,radius)

func _draw_counter(item: Dictionary, at: Vector2, radius: float) -> void:
	var count: int = Catalog.counter_value(item)
	if count <= 0: return
	var text: String = str(count)
	var size: int = 20 if portrait() else 14
	var font: Font = battle.description_font
	while size > (14 if portrait() else 10) and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > radius*1.8: size -= 1
	var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var baseline: Vector2 = (at+Vector2(radius+2-width,radius+2)).round()
	draw_string_outline(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color("10150f"))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("fff2cc"))

func _draw_drop_indicator(index: int) -> void:
	var rect: Rect2 = slot_rect(index)
	var side: float = rect.size.y+8
	draw_style_box(drop_style,Rect2(rect.get_center()-Vector2.ONE*side/2,Vector2.ONE*side))

func _draw_chest_replacement() -> void:
	var item: Dictionary = battle.model.reward_item(chest_slot)
	if not item.has("relic_id"): return
	draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color("131811",0.98))
	var mid: float = battle.fx.canvas_size.x/2
	_center(Vector2(mid,320 if portrait() else 118),"INVENTORY FULL",32,Color("dfb866"))
	if not pickup.active: Paint.paint(self,item.relic_id,Vector2(mid,620 if portrait() else 280),80)
	_center(Vector2(mid,790 if portrait() else 418),item.name,26,item.color)
	_wrap(Vector2(64 if portrait() else 310,880 if portrait() else 464),item.text,676 if portrait() else 660,28 if portrait() else 22,Color("eee0b9"))
	_center(Vector2(mid,1290 if portrait() else 565),"CHOOSE A RELIC TO REPLACE",24 if portrait() else 18,Color("dfb866"))
	_frame(skip_rect(),Color("dd7e6b"))
	_center(skip_rect().get_center()+Vector2(0,10),"LEAVE RELIC",28 if portrait() else 22,Color("e998a4"))
	battle.chest.draw_skip_button(self)

func _draw_tooltip() -> void:
	var index: int = pressed
	if index < 0 or index >= battle.model.relics.items.size(): return
	var item: Dictionary = battle.model.relics.items[index]
	var rect: Rect2 = tooltip_rect(index)
	_frame(rect,Catalog.rarity_color(item.id),true)
	_text(rect.position+Vector2(20,36),Catalog.ITEMS[item.id].name,26 if portrait() else 20,Catalog.rarity_color(item.id))
	_wrap(rect.position+Vector2(20,78),Catalog.description(item,GameText.text),rect.size.x-40,30 if portrait() else 24,Color("fff1ca"))

func tooltip_rect(index: int) -> Rect2:
	var width: float = 728 if portrait() else 540
	var size: int = 30 if portrait() else 24
	var lines := GameText.lines(Catalog.description(battle.model.relics.items[index],GameText.text),battle.description_font,size,width-40)
	var height: float = 94+(size+8)*lines.size()
	return Rect2(38,inventory_rect().position.y-height-18,width,height)
