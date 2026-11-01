extends Node2D
## Fixed combat row, cyclic dice tools, and an expandable upcoming-roll hand.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
const Swipe = preload("res://scripts/tarot/card_swipe.gd")
const Layout = preload("res://scripts/tarot/tarot_quick_layout.gd")
const ScrollAudio = preload("res://scripts/tarot/card_scroll_audio.gd")
var layout = Layout.new()
var scroll_audio = ScrollAudio.new()
var clock := 0.0
var next_open := false
var next_expansion := 0.0
var expanded_canvas: Node2D
const LANES := ["field","now","next"]
const PURPLE := Color("ce9bff")
var battle
var lanes: Dictionary = {}
var signature: Array = []
var held := false
var gesture := ""
var lane := ""
var pressed := -1
var inspected := -1
var field_focus := -1
var field_lifts: Dictionary = {}
var press_at := Vector2.ZERO
var last_at := Vector2.ZERO
var source := Vector2.ZERO
var swallow_release := false
var preview_canvas: Node2D
var inspection_canvas: Node2D

func _ready() -> void:
	layout.ui = self
	z_index = BattleLayers.TAROT_QUICK
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in LANES:
		var clip := Control.new()
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		add_child(clip)
		var canvas := Node2D.new()
		clip.add_child(canvas)
		canvas.draw.connect(_paint_lane.bind(canvas,id))
		lanes[id] = {"cards":[],"display":[],"visibility":0.0,"swipe":Swipe.new(),"clip":clip,"canvas":canvas}
		lanes[id].swipe.friction = 3.2
		lanes[id].swipe.release_boost = 0.35
		lanes[id].swipe.max_speed = 18.0
	expanded_canvas = Node2D.new()
	expanded_canvas.z_as_relative = false
	expanded_canvas.z_index = BattleLayers.TAROT_QUICK_NAME
	expanded_canvas.draw.connect(_paint_expanded)
	add_child(expanded_canvas)
	preview_canvas = Node2D.new()
	preview_canvas.z_as_relative = false
	preview_canvas.z_index = BattleLayers.TAROT_QUICK_NAME
	preview_canvas.draw.connect(_paint_preview)
	add_child(preview_canvas)
	inspection_canvas = Node2D.new()
	inspection_canvas.z_as_relative = false
	inspection_canvas.z_index = BattleLayers.EFFECT_INSPECTION
	inspection_canvas.draw.connect(_paint_inspection.bind(inspection_canvas))
	add_child(inspection_canvas)
	sync_inventory()

func portrait() -> bool: return battle.tarot_ui.portrait()

## Reuse casting validation without choosing a target or changing gameplay state.
func eligible(id: String) -> bool:
	var choice: Dictionary = {}
	if id == "death":
		var targets: Array = battle.model.tarot_effects.targets(battle.model,id)
		if targets.is_empty(): return false
		choice.target = targets[0]
	return battle.model.tarot_effects.error(battle.model,id,choice).is_empty()

## Projection first, then oldest instance: inventory reordering cannot swap the representative.
func preferred_copy(candidate: Dictionary, current: Dictionary) -> bool:
	if candidate.get("projection",false) != current.get("projection",false): return candidate.get("projection",false)
	return candidate.instance_id < current.instance_id

## One usable copy per name; spend expiring projections before permanent cards.
func sync_inventory() -> void:
	var copies: Dictionary = {}
	for item in battle.model.tarots.items:
		if Catalog.quick_lane(item.id).is_empty(): continue
		if not copies.has(item.id) or preferred_copy(item,copies[item.id]):
			copies[item.id] = item
	# Keep existing shortcuts on screen through a tarot transaction; input remains locked.
	var retained: Array = []
	for id in LANES:
		for item in lanes[id].cards: retained.append(item.id)
	var cards: Array = copies.values().filter(func(item): return item.id in retained if battle.tarot_cast.active() else eligible(item.id))
	var names: Dictionary = {}
	for item in cards: names[item.id] = GameText.text(Catalog.ITEMS[item.id].name)
	cards.sort_custom(func(a,b):
		var comparison: int = str(names[a.id]).naturalnocasecmp_to(str(names[b.id]))
		return a.id < b.id if comparison == 0 else comparison < 0)
	var ids: Array = cards.map(func(item): return [item.instance_id,item.id,item.get("projection",false),names[item.id]])
	if signature == ids: return
	signature = ids
	for id in LANES:
		var state: Dictionary = lanes[id]
		var old: Array = state.cards
		var anchor: String = "" if old.is_empty() else old[posmod(roundi(state.swipe.position),old.size())].id
		state.cards = cards.filter(func(item): return Catalog.quick_lane(item.id) == id)
		if not state.cards.is_empty(): state.display = state.cards.duplicate()
		var slot: int = state.cards.find_custom(func(item): return item.id == anchor)
		if not state.cards.is_empty(): state.swipe.reset(slot if slot >= 0 else (state.cards.size()-1)*0.5)
	scroll_audio.reset(lanes.now.swipe.position)
	if lanes.next.cards.is_empty(): next_open = false
	var visible_ids: Array = cards.map(func(item): return item.instance_id)
	if pressed >= 0 and pressed not in visible_ids: cancel_gesture()
	if inspected >= 0 and inspected not in visible_ids: inspected = -1
	if field_focus >= 0 and field_focus not in visible_ids: field_focus = -1

## Cancellation from Magician returns to its shortcut without opening the full carousel.
func focus_instance(instance_id: int) -> void:
	sync_inventory()
	for id in LANES:
		var index: int = lanes[id].cards.find_custom(func(item): return item.instance_id == instance_id)
		if index < 0: continue
		lanes[id].swipe.reset(index)
		swallow_release = true
		return

func reset() -> void:
	cancel_gesture()
	inspected = -1
	next_open = false; next_expansion = 0
	field_focus = -1; field_lifts.clear()
	signature.clear()
	for id in LANES:
		lanes[id].cards.clear(); lanes[id].display.clear(); lanes[id].swipe.reset(); lanes[id].visibility = 0.0
	sync_inventory()

func cancel_gesture() -> void:
	held = false; gesture = ""; pressed = -1; swallow_release = false
	field_focus = -1
	for id in LANES:
		lanes[id].swipe.dragging = false
		lanes[id].swipe.velocity = 0

## Keep shortcuts in battle, but let full-screen pages and the full carousel own their space.
func shown() -> bool:
	return not battle.menu_open and not battle.guide and not battle.debug_open and not battle.inventory_page.opened and not battle.tarot_ui.ceremony.active() and not battle.tarot_ui.inventory_visible() and battle.view_phase not in ["shop","reward","over"]

func lane_shown(id: String) -> bool:
	if not shown() or battle._power_meter_visible() or lanes[id].cards.is_empty(): return false
	# Only a valid skill preview needs the top row's space; partial selections keep it.
	var connected: bool = not battle.model.dice_turn.selected.is_empty() and not battle.dice_selection.preview.is_empty()
	return id != "field" or (not connected and not battle.model.dice_turn.has_pending_group())

func available() -> bool:
	return shown() and not battle.tarot_cast.active() and battle.tarot_ui.available() and not battle._menus_open() and not battle.dice_selection.dragging and not battle.skill_pressed

func card_size(id: String) -> Vector2: return layout.card_size(id)
func arc_radius() -> float: return layout.radius()
func arc_step() -> float: return layout.step()
func lane_rect(id: String) -> Rect2: return layout.lane_rect(id)
func pose(id: String, index: int) -> Dictionary: return layout.pose(id,index)
func visible_indices(id: String) -> Array: return range(lanes[id].display.size())

func card_at(point: Vector2) -> Dictionary:
	var picked: Dictionary = {}
	var nearest: float = INF
	for id in LANES:
		if not lane_shown(id) or lanes[id].visibility < 0.85: continue
		if next_open and id != "next": continue
		for index in visible_indices(id):
			var p := pose(id,index)
			if p.alpha < 0.2: continue
			var local: Vector2 = (point-p.at).rotated(-p.angle)
			if not Rect2(-p.size/2,p.size).grow(3).has_point(local): continue
			# Neighboring arc cards overlap: the closest visible center owns the tap.
			var distance: float = local.length_squared()
			if distance < nearest:
				nearest = distance
				picked = {"lane":id,"index":index,"item":lanes[id].cards[index],"pose":p}
	return picked

func hit(point: Vector2) -> bool:
	return next_open or inspected >= 0 or (available() and not card_at(point).is_empty())

## The top row previews on touch; side controls retain their separate gestures.
func click(point: Vector2) -> bool:
	if not shown(): return false
	sync_inventory()
	var picked := card_at(point)
	if field_focus >= 0:
		if picked.is_empty():
			field_focus = -1; swallow_release = true
			return true
		if picked.lane != "field": field_focus = -1
	if next_open and picked.is_empty():
		next_open = false; inspected = -1; swallow_release = true
		return true
	if inspected >= 0 and (picked.is_empty() or picked.item.instance_id != inspected):
		inspected = -1; swallow_release = true
		return true
	if not available() and inspected < 0: return false
	if picked.is_empty(): return false
	if picked.lane == "next" and not next_open:
		next_open = true; inspected = -1; swallow_release = true
		battle._sound("ui/click_001",1,-24)
		return true
	held = true; gesture = ""; lane = picked.lane; pressed = picked.item.instance_id
	press_at = point; last_at = point; source = picked.pose.at
	lanes[lane].swipe.begin()
	if lane == "field": _focus_field(picked.index)
	return true

func motion(point: Vector2) -> bool:
	if not held: return inspected >= 0 or (next_open and not battle.tarot_ui.external_drag)
	if not shown(): cancel_gesture(); return false
	var delta := point-press_at
	if lane == "field" and layout.field_zone().has_point(point):
		gesture = "browse"
		var closest := -1
		var distance := INF
		for i in range(lanes.field.cards.size()):
			var d: float = absf(point.x-pose("field",i).at.x)
			if d < distance: distance = d; closest = i
		if closest >= 0: _focus_field(closest)
		last_at = point
		return true
	if lane == "field" and delta.length() > (14 if portrait() else 8): gesture = "card"
	if gesture.is_empty() and delta.length() > (14 if portrait() else 8):
		var cast_drag: bool = lane != "now" or absf(delta.x) > absf(delta.y)*0.85
		gesture = "card" if cast_drag else "swipe"
		inspected = -1
	if gesture == "card":
		var instance: int = pressed
		var start: Vector2 = source
		var dice_drop: bool = lane != "field"
		next_open = false
		cancel_gesture()
		return battle.tarot_ui.begin_quick_drag(instance,point,start,dice_drop)
	if gesture == "swipe":
		lanes[lane].swipe.move(-(point.y-last_at.y)/(arc_radius()*arc_step()))
		_tick_scroll(true)
	last_at = point
	return true

func release(point: Vector2) -> bool:
	if swallow_release: swallow_release = false; return true
	if not held: return inspected >= 0 or (next_open and not battle.tarot_ui.external_drag)
	motion(point)
	if not held: return battle.tarot_ui.release(point)
	lanes[lane].swipe.release()
	if gesture.is_empty() or gesture == "browse":
		if lane == "now": inspected = -1 if inspected == pressed else pressed
	held = false; gesture = ""; pressed = -1
	return true

## Scrubbing changes only the previewed instance and never selects a gameplay target.
func _focus_field(index: int) -> void:
	var item: Dictionary = lanes.field.cards[index]
	field_focus = item.instance_id
	pressed = item.instance_id
	source = pose("field",index).at
	inspected = -1

## Compact description above the enlarged top card, without dimming or pausing battle.
func field_preview_rect(item: Dictionary, card_pose: Dictionary) -> Rect2:
	var extent: Vector2 = battle.tarot_ui.card_details_size(item,420 if portrait() else 320)
	var x: float = clampf(card_pose.at.x-extent.x/2,8,battle.fx.canvas_size.x-extent.x-8)
	return Rect2(Vector2(x,maxf(8,card_pose.at.y-card_pose.size.y/2-extent.y-16)),extent)

## Scroll ticks follow both the finger and the coast, with overlap-safe audio throttling.
func _tick_scroll(moving: bool) -> void:
	if scroll_audio.update(lanes.now.swipe.position,moving): battle._sound("ui/click_001",1,-25)

func _process(delta: float) -> void:
	sync_inventory()
	clock += delta
	if battle.tarot_cast.active():
		field_focus = -1; inspected = -1; next_open = false
	if not lane_shown("field"): field_focus = -1
	if field_focus >= 0 and not field_lifts.has(field_focus): field_lifts[field_focus] = 0.0
	for instance in field_lifts.keys():
		field_lifts[instance] = move_toward(field_lifts[instance],1.0 if instance == field_focus else 0.0,delta*9)
		if field_lifts[instance] <= 0: field_lifts.erase(instance)
	if not shown(): inspected = -1; next_open = false; cancel_gesture()
	if not lane_shown("next"): next_open = false
	next_expansion = move_toward(next_expansion,1.0 if next_open else 0.0,delta*5.5)
	var moving: bool = shown() and absf(lanes.now.swipe.velocity) > 0.15
	if shown() and not battle._menus_open() and not held and not next_open:
		lanes.now.swipe.advance(delta,true)
		_tick_scroll(moving)
	for id in LANES:
		var state: Dictionary = lanes[id]
		state.visibility = move_toward(state.visibility,1.0 if lane_shown(id) else 0.0,delta*5)
		state.clip.position = layout.clip_rect(id).position
		state.clip.size = layout.clip_rect(id).size
		state.canvas.position = -state.clip.position
		state.clip.visible = state.visibility > 0
		state.canvas.queue_redraw()
	expanded_canvas.queue_redraw()
	inspection_canvas.queue_redraw()
	preview_canvas.visible = shown() and inspected < 0 and battle.tarot_ui.gesture != "card"
	preview_canvas.queue_redraw()
	expanded_canvas.z_index = BattleLayers.TAROT_QUICK_NAME if next_open and lane_shown("next") else BattleLayers.TAROT_QUICK

## Shared card paint keeps all three layouts softly glowing and projection-aware.
func _paint_cards(canvas: CanvasItem, id: String) -> void:
	var order: Array = visible_indices(id)
	if id == "field": order.sort_custom(func(a,b): return field_lifts.get(lanes[id].display[a].instance_id,0.0) < field_lifts.get(lanes[id].display[b].instance_id,0.0))
	for index in order:
		var item: Dictionary = lanes[id].display[index]
		if battle.tarot_ui.external_drag and battle.tarot_ui.pressed_card >= 0 and battle.model.tarots.find_instance(item.instance_id) == battle.tarot_ui.pressed_card: continue
		var p := pose(id,index)
		if p.alpha <= 0: continue
		Paint.card(canvas,item.id,p.at,p.size,p.angle,1,p.glow,p.alpha,p.brightness)
		if item.get("projection",false):
			Paint.text(canvas,battle.pixel_font,p.at+Vector2(0,p.size.y*0.3),"*",18 if portrait() else 14,Color("abeaff",p.alpha))

func _paint_lane(canvas: CanvasItem, id: String) -> void:
	if lanes[id].visibility <= 0 or (id == "next" and next_expansion > 0): return
	_paint_cards(canvas,id)

## Expand upcoming-roll cards over a quiet backdrop; dragging clears the backdrop immediately.
func _paint_expanded() -> void:
	if next_expansion <= 0: return
	if not battle.tarot_ui.external_drag:
		expanded_canvas.draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.025,0.02,0.05,next_expansion*0.42))
	_paint_cards(expanded_canvas,"next")

func _paint_preview() -> void:
	if field_focus >= 0 and lane_shown("field"):
		var index: int = lanes.field.cards.find_custom(func(card): return card.instance_id == field_focus)
		if index >= 0:
			var item: Dictionary = lanes.field.cards[index]
			battle.tarot_ui.paint_card_details(preview_canvas,item,field_preview_rect(item,pose("field",index)))
		return

func _paint_inspection(canvas: CanvasItem) -> void:
	if inspected < 0 or not shown(): return
	var index: int = battle.model.tarots.find_instance(inspected)
	if index < 0: return
	var item: Dictionary = battle.model.tarots.items[index]
	canvas.draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.025,0.02,0.05,0.7))
	var details: Rect2 = battle.tarot_ui.inspection_rect(item)
	details.position.y = minf(details.position.y,lane_rect("field").position.y-details.size.y-22)
	battle.tarot_ui.paint_inspection(canvas,item,details)
	var id: String = Catalog.quick_lane(item.id)
	var slot: int = lanes[id].cards.find_custom(func(card): return card.instance_id == inspected)
	if slot >= 0:
		var p := pose(id,slot)
		Paint.card(canvas,item.id,p.at-Vector2(0,12),p.size*1.15,p.angle,1,0.8)
