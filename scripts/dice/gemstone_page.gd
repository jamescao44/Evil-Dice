extends RefCounted
## Inventory-only layout and gestures for six sockets, ordered spare gems and merges.
const Gems = preload("res://scripts/dice/gemstone_inventory.gd")
const Paint = preload("res://scripts/dice/gemstone_paint.gd")
const Art = preload("res://scripts/dice/dice_art.gd")
const Panels = preload("res://scripts/tarot/tarot_paint.gd")
const COLUMNS := 5
const ROWS := 4
const PER_PAGE := COLUMNS*ROWS
var page
var selected: Dictionary = {}
var pressed: Dictionary = {}
var dragging := false
var origin := Vector2.ZERO
var pointer := Vector2.ZERO
var bag_page := 0
var page_hover_time := 0.0

func portrait() -> bool:
	return page.portrait()

func model():
	return page.battle.model.gemstones

## Match the battlefield's clockwise die ordering in a smaller hexagon.
func die_center(index: int) -> Vector2:
	return center()+Vector2.from_angle(-PI/2+index*TAU/Gems.SOCKETS)*(156 if portrait() else 106)

func center() -> Vector2:
	return Vector2(402,710) if portrait() else Vector2(336,430)

func socket_rect(index: int) -> Rect2:
	var at: Vector2 = center()+Vector2.from_angle(-PI/2+index*TAU/Gems.SOCKETS)*(256 if portrait() else 184)
	var side: float = 72 if portrait() else 62
	return Rect2(at-Vector2.ONE*side/2,Vector2.ONE*side)

func bag_rect(visible_index: int) -> Rect2:
	return Rect2((Vector2(72,1074) if portrait() else Vector2(646,268))+Vector2(visible_index%COLUMNS,visible_index/COLUMNS)*(Vector2(134,92) if portrait() else Vector2(110,80)),Vector2(124,88) if portrait() else Vector2(100,72))

func previous_rect() -> Rect2:
	return Rect2(72,1008,100,54) if portrait() else Rect2(646,208,80,44)

func next_rect() -> Rect2:
	return Rect2(632,1008,100,54) if portrait() else Rect2(1106,208,80,44)

func remove_rect() -> Rect2:
	return Rect2(72,1588,310,84) if portrait() else Rect2(646,704,260,58)

func merge_rect() -> Rect2:
	return Rect2(422,1588,310,84) if portrait() else Rect2(926,704,260,58)

## Locations use physical socket indices and ordered spare indices, never die pip values.
func gem_at(location: Dictionary) -> Dictionary:
	if location.has("socket"):
		return model().sockets[location.socket] if location.socket >= 0 and location.socket < Gems.SOCKETS else {}
	return model().bag_gem(int(location.get("bag",-1)))

func location_at(at: Vector2, include_empty: bool = false) -> Dictionary:
	for index in range(Gems.SOCKETS):
		if socket_rect(index).has_point(at): return {"socket":index}
	for i in range(PER_PAGE):
		var index: int = bag_page*PER_PAGE+i
		if bag_rect(i).has_point(at) and (index < model().order.size() or include_empty):
			return {"bag":mini(index,model().order.size())}
	return {}

## Selecting a spare then tapping a socket equips it; dragging also supports swaps and merges.
func click(at: Vector2) -> void:
	if previous_rect().has_point(at): bag_page = maxi(0,bag_page-1); return
	if next_rect().has_point(at): bag_page = mini(max_page(),bag_page+1); return
	if remove_rect().has_point(at) and selected.has("socket"):
		if model().unequip(selected.socket): feedback()
		return
	if merge_rect().has_point(at):
		var gem: Dictionary = gem_at(selected)
		if not gem.is_empty() and model().merge(gem,int(selected.get("socket",-1))):
			if selected.has("bag"): selected = {"bag":model().order.find(Gems.key(gem.id,int(gem.level)+1))}
			feedback()
		return
	pressed = location_at(at)
	origin = at
	pointer = at
	dragging = false

func motion(at: Vector2) -> void:
	pointer = at
	if not pressed.is_empty() and not gem_at(pressed).is_empty() and at.distance_to(origin) > (14 if portrait() else 8): dragging = true

## Invalid drops leave equipment intact; different gems move instead of being consumed.
func release(at: Vector2) -> void:
	if pressed.is_empty(): return
	motion(at)
	var target: Dictionary = location_at(at,true)
	if dragging:
		# Merging a preceding spare shifts the destination index left once.
		var shift: bool = pressed.has("bag") and target.has("bag") and pressed.bag < target.bag and gem_at(pressed) == gem_at(target) and Gems.Catalog.can_merge(gem_at(pressed))
		if not target.is_empty() and model().transfer(pressed,target):
			selected = target.duplicate()
			if selected.has("bag"): selected.bag = mini(selected.bag-(1 if shift else 0),model().order.size()-1)
			feedback()
	elif location_at(at) == pressed:
		if selected.has("bag") and pressed.has("socket") and not gem_at(selected).is_empty():
			var gem: Dictionary = gem_at(selected)
			# A tap equips; only an explicit merge/drop consumes two gems.
			if model().equip(pressed.socket,gem.id,gem.level): feedback()
		selected = pressed.duplicate()
	cancel_drag()

func cancel_drag() -> void:
	pressed = {}
	dragging = false
	page_hover_time = 0

## Holding a dragged gem over a page arrow also allows moving between bag pages.
func advance(delta: float) -> void:
	if not dragging: page_hover_time = 0; return
	var direction: int = -1 if previous_rect().has_point(pointer) and bag_page > 0 else 1 if next_rect().has_point(pointer) and bag_page < max_page() else 0
	page_hover_time = page_hover_time+delta if direction != 0 else 0
	if page_hover_time >= 0.55:
		bag_page += direction
		page_hover_time = 0

func reset() -> void:
	selected = {}
	bag_page = 0
	cancel_drag()

func max_page() -> int:
	return maxi(0,(model().order.size()-1)/PER_PAGE)

func feedback() -> void:
	page.battle._sound("item/confirmation_002",1,-16)
	page.battle.dice_selection._refresh_preview()
	page.queue_redraw()

## Draw the selected effect in a fixed panel, leaving every socket and spare accessible.
func draw_details() -> void:
	var gem: Dictionary = gem_at(selected)
	var rect := Rect2(72,1442,660,122) if portrait() else Rect2(646,606,540,88)
	var title: String = GameText.format("%s · LV.%d",[GameText.text(Gems.Catalog.ITEMS[gem.id].name),gem.level]) if not gem.is_empty() else GameText.text("Drag matching gems together to merge.")
	page._text(Vector2(rect.get_center().x,rect.position.y+26),title,28 if portrait() else 23,Gems.Catalog.color(gem.id) if not gem.is_empty() else page.GOLD)
	var description: String = Gems.Catalog.description(gem) if not gem.is_empty() else GameText.text("Tap a gem, then a socket to equip. Drag other gems to rearrange.")
	var body := Rect2(rect.position+Vector2(0,42),rect.size-Vector2(0,42))
	var font_size: int = 24 if portrait() else 20
	while font_size > 14 and GameText.lines(description,page.battle.description_font,font_size,body.size.x).size()*font_size*1.3 > body.size.y: font_size -= 1
	Panels.wrap(page,page.battle.description_font,body,description,font_size,Color("dedbd0"),true)
	if selected.has("socket") and not gem.is_empty(): page._button(remove_rect(),"UNEQUIP")
	if not gem.is_empty() and model().merge_partner(gem,int(selected.get("socket",-1))) != -3: page._button(merge_rect(),"MERGE")
	elif not gem.is_empty() and gem.level == Gems.Catalog.max_level(gem.id): page._text(merge_rect().get_center()+Vector2(0,8),"MAX LEVEL",24 if portrait() else 20,Color("aca486"))

## A familiar hexagon links each die to its outer socket, with spare gems in a paged bag.
func draw() -> void:
	bag_page = mini(bag_page,max_page())
	page._text(Vector2(402,390) if portrait() else Vector2(336,174),"DICE GEMSTONES",34 if portrait() else 30)
	for i in range(Gems.SOCKETS):
		var die_at: Vector2 = die_center(i)
		var rect: Rect2 = socket_rect(i)
		var gem: Dictionary = model().sockets[i]
		var color: Color = Gems.Catalog.color(gem.id) if not gem.is_empty() else Color("58606e")
		page.draw_line(die_at,die_center((i+1)%Gems.SOCKETS),Color("5c5269",0.35),2,true)
		page.draw_line(die_at,rect.get_center(),Color(color,0.65),3,true)
		if not gem.is_empty():
			for j in range(3,0,-1): Panels.panel(page,Rect2(die_at-Vector2.ONE*(43+j*5),Vector2.ONE*(86+j*10)),Color(color,0.08),Color.TRANSPARENT,12)
		Art.paint_face(page,die_at,int(page.battle.model.dice_turn.values[i]),84 if portrait() else 72)
		page._text(die_at+Vector2(0,68 if portrait() else 56),str(i+1),20 if portrait() else 17,Color("a9a39c"))
		_draw_cell(rect,{"socket":i},gem,color)
	page._text(Vector2(402,1046) if portrait() else Vector2(916,238),GameText.format("GEMSTONES · %d",model().order.size()),26 if portrait() else 22)
	if bag_page > 0: page._button(previous_rect(),"‹")
	if bag_page < max_page(): page._button(next_rect(),"›")
	for i in range(PER_PAGE):
		var index: int = bag_page*PER_PAGE+i
		var gem: Dictionary = model().bag_gem(index)
		_draw_cell(bag_rect(i),{"bag":index},gem,Gems.Catalog.color(gem.id) if not gem.is_empty() else Color("414752"))
	draw_details()
	if dragging:
		Paint.paint(page,pointer,gem_at(pressed),42 if portrait() else 34)

## Hover feedback distinguishes a merge from an ordinary move without adding confirmation.
func _draw_cell(rect: Rect2, location: Dictionary, gem: Dictionary, color: Color) -> void:
	var hover: Dictionary = location_at(pointer,true) if dragging else {}
	var active: bool = selected == location or (dragging and hover == location)
	Panels.panel(page,rect,Color(color,0.08 if not active else 0.22),Color(color,0.9 if active else 0.4),12)
	if gem.is_empty():
		page.draw_line(rect.get_center()-Vector2(8,0),rect.get_center()+Vector2(8,0),color,2)
		return
	if not dragging or pressed != location: Paint.paint(page,rect.get_center()-Vector2(0,8 if location.has("bag") else 0),gem,(24 if portrait() else 22) if location.has("bag") else (30 if portrait() else 25))
	if location.has("bag"): page._text(Vector2(rect.get_center().x,rect.end.y-7),"LV.%d" % gem.level,17 if portrait() else 14,color)
	if dragging and hover == location and pressed != location and gem == gem_at(pressed) and Gems.Catalog.can_merge(gem):
		page._text(rect.get_center()+Vector2(0,8),"MERGE",23 if portrait() else 19,Color("fff2c6"))
