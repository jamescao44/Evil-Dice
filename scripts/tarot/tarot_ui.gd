extends Node2D
## Battle adapter plus the upright, depth-sorted consumable carousel.
## Card designs, inventory, reward transactions, and draw animation are separate.
signal use_requested(instance_id: int, point: Vector2, from: Vector2)
const Swipe = preload("res://scripts/tarot/card_swipe.gd")
const DragFeedback = preload("res://scripts/shared/cast_drag_feedback.gd")
var drag_feedback = DragFeedback.new()
var swipe = Swipe.new()
var scroll_audio = preload("res://scripts/tarot/card_scroll_audio.gd").new()
var gesture: String = ""
var external_drag := false
var external_from := Vector2.ZERO
var external_dice_drop := false
var pointer := Vector2.ZERO
var float_levels: Dictionary = {}
var cast_visual: Dictionary = {}
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
const Draw = preload("res://scripts/tarot/tarot_draw.gd")
const Pickup = preload("res://scripts/tarot/tarot_pickup.gd")
var battle
var ceremony = Draw.new()
var pickup = Pickup.new()
var opened: bool = false
var expansion: float = 0.0
var scroll: float = 0.0
var scroll_target: float = 0.0
var held: bool = false
var moved: bool = false
var press_at := Vector2.ZERO
var last_at := Vector2.ZERO
var pressed_card: int = -1
var inspected: int = -1
var clock: float = 0.0
var reward_source: String = ""
var reward_slot: int = -1
var swallow_release: bool = false
var audio_rng := RandomNumberGenerator.new()

## Connect tarot grants, draw selection and card sounds to the battle adapter.
func _ready() -> void:
	swipe.friction = 3.2
	swipe.release_boost = 0.35
	swipe.speed_reference = 4.0
	swipe.max_speed = 10.0
	audio_rng.randomize()
	z_index = BattleLayers.TAROT_INVENTORY
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ceremony)
	pickup.ui = self
	add_child(pickup)
	battle.model.tarot_granted.connect(pickup.enqueue)
	battle.model.tarot_expired.connect(_expire_projections)
	ceremony.picked.connect(_collect)
	ceremony.use_picked.connect(func(index: int): _collect(index,true))
	ceremony.can_use_choice = _can_use_draw_choice
	ceremony.shuffle_preference_changed.connect(_save_shuffle_preference)
	ceremony.card_drawn.connect(func(): battle._sound("item/card_draw",1.0,-5))
	ceremony.card_shuffled.connect(func(): battle._sound("item/deck_flip" if audio_rng.randi_range(0,1) == 0 else "item/deck_flip2",1.0,-13 if ceremony.reduced else -7))

## Choose the phone layout from the battle canvas dimensions.
func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Report whether a menu, help page or debug page covers the tarot UI.
func settings_open() -> bool:
	return battle.menu_open or battle.guide or battle.debug_open

## Keep tarot mode active until its closing animation finishes.
func inventory_visible() -> bool:
	return opened or expansion > 0.001

## Reserve dice-area input for an open inventory or tarot reward ceremony.
func blocks_battle() -> bool:
	return opened or expansion > 0.001 or ceremony.active()

## Return the shared card/dice toggle hit area for this screen layout.
func icon_rect() -> Rect2:
	if battle.view_phase == "shop": return Rect2(86,342,80,72) if portrait() else Rect2(70,130,66,56)
	return Rect2(48,battle.DICE_CENTER.y+190,104,104) if portrait() else Rect2(402,battle.DICE_CENTER.y+102,66,66)

## Check whether a tarot action is allowed in the current battle phase.
func available() -> bool:
	return battle.view_phase in ["ready","skill","frozen"] and battle.inspecting_enemy < 0 and not settings_open() and not battle.relic_ui.pickup.active

## Shrink the dice toward the card icon as the tarot inventory expands.
func dice_transform() -> Transform2D:
	var t: float = smoothstep(0,1,expansion)
	var scale_factor: float = lerpf(1.0,0.12,t)
	var center: Vector2 = battle.DICE_CENTER.lerp(icon_rect().get_center(),t)
	return Transform2D(0,Vector2.ONE*scale_factor,0,center-battle.DICE_CENTER*scale_factor)

## Open a three-card ceremony using the model’s already committed tarot candidates.
func begin_reward(source: String, slot: int = -1, from: Vector2 = Vector2.INF, deck_size: Vector2 = Vector2.ZERO) -> bool:
	if ceremony.active(): return false
	var choices: Array = battle.model.begin_tarot_reward(source,slot)
	if choices.is_empty(): return false
	opened = false
	inspected = -1
	cancel_gesture()
	reward_source = source
	reward_slot = slot
	battle._cancel_enemy_hold()
	battle.relic_ui.cancel_hold()
	var settings := ConfigFile.new()
	settings.load(GameText.settings_path)
	ceremony.skip_shuffle = bool(settings.get_value("interface","skip_tarot_shuffle",false))
	ceremony.start(choices,battle.fx.canvas_size,battle.description_font,icon_rect().get_center(),battle.reduced,from,deck_size)
	return true

## Preserve the animation preference across visits, runs and application restarts.
func _save_shuffle_preference(enabled: bool) -> void:
	var settings := ConfigFile.new()
	settings.load(GameText.settings_path)
	settings.set_value("interface","skip_tarot_shuffle",enabled)
	var error := settings.save(GameText.settings_path)
	if error != OK: push_warning("Could not save tarot animation setting: %s" % error_string(error))

## Only expose immediate use at a safe decision point and for a valid reserved card.
func _can_use_draw_choice(index: int) -> bool:
	return battle.view_phase in ["ready","skill","frozen","shop"] and not settings_open() and not battle.tarot_cast.active() and battle.model.tarot_effects.draw_error(battle.model,index).is_empty()

## Keep exactly one card, then optionally hand that new instance to normal casting.
func _collect(index: int, use_now: bool = false) -> void:
	if use_now and not _can_use_draw_choice(index): return
	var from: Vector2 = ceremony.row_point(index)
	var item: Dictionary = battle.model.choose_tarot(index)
	if item.is_empty(): return
	scroll = battle.model.tarots.items.size()-1
	scroll_target = scroll
	swipe.reset(scroll*card_angle())
	if reward_source == "chest":
		battle.chest.collected.append(reward_slot)
		battle.chest.celebrate(reward_slot)
	battle._sound("item/confirmation_002",1,-12)
	reward_source = ""
	reward_slot = -1
	if use_now:
		ceremony.reset()
		battle.tarot_cast.request_drawn(item.instance_id,from)

## Clear tarot gestures and presentation when starting a new run.
func reset() -> void:
	swipe.reset()
	float_levels.clear()
	cast_visual.clear()
	opened = false
	expansion = 0
	scroll = 0
	scroll_target = 0
	inspected = -1
	ceremony.reset()
	pickup.reset()
	reward_source = ""
	reward_slot = -1
	cancel_gesture()
	if is_instance_valid(battle.dice_group): battle.dice_group.transform = Transform2D.IDENTITY
	queue_redraw()

## Remove expired receipts and release stale card gestures after inventory changes.
func _expire_projections(instances: Array) -> void:
	inspected = -1
	cancel_gesture()
	for instance_id in instances: float_levels.erase(instance_id)
	pickup.pending = pickup.pending.filter(func(item): return item.instance_id not in instances)
	pickup.cards = pickup.cards.filter(func(card): return card.item.instance_id not in instances)
	scroll = minf(scroll,maxi(0,battle.model.tarots.items.size()-1))
	scroll_target = roundf(scroll)
	swipe.reset(scroll*card_angle())
	queue_redraw()

## Release held cards and swipe inertia without consuming a tarot.
func cancel_gesture() -> void:
	external_drag = false
	external_dice_drop = false
	drag_feedback.reset()
	swipe.dragging = false
	swipe.velocity = 0
	gesture = ""
	held = false
	moved = false
	pressed_card = -1
	swallow_release = false
	ceremony.cancel_gesture()

## Space owned cards evenly around the circular inventory.
func card_angle() -> float:
	return TAU/maxi(1,battle.model.tarots.items.size())

## Return the horizontal radius of the tarot inventory ring.
func carousel_radius() -> float:
	return 248.0 if portrait() else 204.0

## Calculate one card’s position, size, depth, inspection lift and idle bob.
func carousel_pose(index: int) -> Dictionary:
	var angle: float = (index-scroll)*card_angle()
	var depth: float = (cos(angle)+1)/2
	var center: Vector2 = battle.DICE_CENTER+Vector2(0,-55 if portrait() else -30)
	var at: Vector2 = center+Vector2(sin(angle)*carousel_radius(),cos(angle)*(105 if portrait() else 56))
	var item: Dictionary = battle.model.tarots.items[index]
	var lift: float = float_levels.get(item.instance_id,0.0)
	at.y -= lift*(62 if portrait() else 38)
	if not battle.reduced: at.y += sin(clock*2.3-index*0.55)*(5 if portrait() else 3)
	var extent: Vector2 = (Vector2(148,229) if portrait() else Vector2(98,152))*lerpf(0.67,1.13,depth)*(1+lift*0.07)
	var t: float = smoothstep(0,1,expansion)
	at = icon_rect().get_center().lerp(at,t)
	extent *= lerpf(0.12,1,t)
	return {"at":at,"size":extent,"depth":depth,"angle":0.0 if battle.reduced else sin(clock*1.8-index*0.55)*0.035}

## Sort cards from back to front using depth alone, preserving overlap order.
func carousel_order() -> Array:
	var order: Array = range(battle.model.tarots.items.size())
	# Sorting needs depth only; avoid rebuilding full card poses for each comparison.
	var depths := PackedFloat64Array()
	var angle_step: float = card_angle()
	for i in order: depths.append((cos((i-scroll)*angle_step)+1)/2)
	order.sort_custom(func(a,b):
		var da: float = depths[a]
		var db: float = depths[b]
		return da < db if not is_equal_approx(da,db) else a < b)
	return order

## Identify the card nearest the player at the current scroll position.
func front_index() -> int:
	var count: int = battle.model.tarots.items.size()
	return posmod(roundi(scroll),count) if count > 0 else -1

## Place the sort control clear of the cards in each screen layout.
func sort_rect() -> Rect2:
	var extent := Vector2(220,52) if portrait() else Vector2(166,40)
	var center: Vector2 = battle.DICE_CENTER+Vector2(0,326) if portrait() else battle.DICE_CENTER+Vector2(272,-142)
	return Rect2(center-extent/2,extent)

## Group cards by their displayed names without changing identities or effects.
func sort_by_name() -> void:
	cancel_gesture()
	inspected = -1
	float_levels.clear()
	var names: Dictionary = {}
	for item in battle.model.tarots.items:
		names[item.id] = GameText.text(Catalog.ITEMS[item.id].name)
	battle.model.tarots.items.sort_custom(func(a,b):
		var comparison: int = str(names[a.id]).naturalnocasecmp_to(str(names[b.id]))
		return a.instance_id < b.instance_id if comparison == 0 else comparison < 0)
	scroll = 0
	scroll_target = 0
	swipe.reset()
	swallow_release = true
	battle._sound("ui/click_001",1,-18)
	queue_redraw()

## Hit-test overlapping cards from front to back.
func card_at(point: Vector2) -> int:
	var order: Array = carousel_order()
	order.reverse()
	for i in order:
		var pose: Dictionary = carousel_pose(i)
		if Rect2(pose.at-pose.size/2,pose.size).has_point(point): return i
	return -1

## Route a tarot press to drawing, inspection, swiping or a neighboring relic.
func click(point: Vector2) -> bool:
	if ceremony.active(): return ceremony.click(point)
	if settings_open(): return false
	# The relic bar remains usable above the carousel. Pass this press through
	# without starting a tarot swipe or leaving its old description on screen.
	if opened and battle.relic_ui.interactable() and battle.relic_ui.at_slot(point) >= 0:
		inspected = -1
		cancel_gesture()
		return false
	if opened and [battle.MENU_RECT,battle.AUDIO_RECT,battle.SPEED_RECT].any(func(rect): return rect.has_point(point)):
		cancel_gesture()
		return false
	if (opened or available()) and icon_rect().grow(6).has_point(point):
		opened = not opened
		inspected = -1
		cancel_gesture()
		swallow_release = true
		battle._cancel_enemy_hold()
		battle._sound("item/book",1.2 if opened else 0.9,-18)
		return true
	# The carousel owns its cards, not the still-visible ice around the player.
	if battle.view_phase == "frozen" and inspected < 0 and battle._player_ice_rect().has_point(point):
		cancel_gesture()
		return false
	if not blocks_battle(): return false
	if expansion < 0.98 or not opened: swallow_release = true; return true
	if sort_rect().has_point(point):
		sort_by_name()
		return true
	held = true
	moved = false
	gesture = ""
	press_at = point
	last_at = point
	pointer = point
	pressed_card = card_at(point)
	swipe.reset(scroll*card_angle())
	swipe.begin()
	scroll_audio.reset(scroll)
	return true

## Quick-access cards share the existing held sprite, targeting and cast transaction.
func begin_quick_drag(instance_id: int, point: Vector2, from: Vector2, dice_drop: bool) -> bool:
	var index: int = battle.model.tarots.find_instance(instance_id)
	if index < 0 or not available(): return false
	cancel_gesture()
	external_drag = true
	external_from = from
	external_dice_drop = dice_drop
	held = true
	moved = true
	gesture = "card"
	pressed_card = index
	pointer = point
	press_at = point
	last_at = point
	return true

## Dice shortcuts also accept a drop into the dice circle; field cards retain targeting.
func accepts_drop(point: Vector2) -> bool:
	return battle.ARENA.has_point(point) or (external_drag and external_dice_drop and battle._in_dice_range(point))

## Update swipe inertia or move a held card toward the battlefield.
func motion(point: Vector2) -> bool:
	if ceremony.active(): return ceremony.motion(point)
	if not blocks_battle() and not held: return false
	pointer = point
	if held:
		var distance: Vector2 = point-press_at
		if distance.length() > (14 if portrait() else 8):
			moved = true
			if gesture.is_empty():
				gesture = "card" if pressed_card >= 0 and distance.y < -absf(distance.x)*0.85 else "swipe"
		if gesture == "swipe" and press_at.y > battle.DICE_CENTER.y-battle.DICE_RADIUS:
			# Inertia runs in radians, so both dragging and coasting ignore deck size.
			swipe.move(-(point.x-last_at.x)/carousel_radius())
			scroll = swipe.position/card_angle()
			scroll_target = scroll
			_scroll_tick(true)
			inspected = -1
		last_at = point
	return true

## Commit an eligible tarot drop or finish the current inspection/swipe gesture.
func release(point: Vector2) -> bool:
	if ceremony.active(): return ceremony.release(point)
	if swallow_release: swallow_release = false; return true
	if not blocks_battle() and not held: return false
	if held:
		motion(point)
		swipe.release()
		if gesture == "card" and pressed_card >= 0 and pressed_card < battle.model.tarots.items.size():
			if accepts_drop(point):
				var item: Dictionary = battle.model.tarots.items[pressed_card]
				use_requested.emit(item.instance_id,point,external_from if external_drag else carousel_pose(pressed_card).at)
		elif not moved and pressed_card >= 0 and pressed_card == card_at(point):
			if pressed_card == front_index(): inspected = -1 if inspected == pressed_card else pressed_card
			else:
				inspected = -1
				var count: int = battle.model.tarots.items.size()
				scroll_target = scroll+wrapf(pressed_card-scroll,-count/2.0,count/2.0)
				swipe.velocity = 0
		else:
			inspected = -1
			scroll_target = roundf(scroll)
	held = false
	gesture = ""
	external_drag = false
	external_dice_drop = false
	drag_feedback.reset()
	return true

## Collapse the tarot carousel and restore the dice-area controls.
func close_inventory() -> void:
	opened = false
	expansion = 0
	inspected = -1
	cancel_gesture()
	battle.dice_group.transform = Transform2D.IDENTITY

## Return a cancelled, unconsumed card to the front instead of losing it in the fan.
func focus_instance(instance_id: int) -> void:
	var index: int = battle.model.tarots.find_instance(instance_id)
	if index < 0: return
	opened = true
	inspected = -1
	cancel_gesture()
	scroll = index
	scroll_target = index
	swipe.reset(scroll*card_angle())
	swallow_release = true
	queue_redraw()

## Start the consumed-card effect and adjust scrolling to the remaining inventory.
func play_cast(id: String, at: Vector2, lane: String = "") -> void:
	cast_visual = {"id":id,"at":at,"age":0.0,"lane":lane}
	inspected = -1
	cancel_gesture()
	scroll = minf(scroll,maxi(0,battle.model.tarots.items.size()-1))
	scroll_target = roundf(scroll)
	swipe.reset(scroll*card_angle())

## Quiet, rate-limited card ticks use index crossings while movement stays in radians.
func _scroll_tick(moving: bool) -> void:
	if scroll_audio.update(scroll,moving and opened): battle._sound("ui/click_001",1,-25)

## Advance tarot expansion, swipe inertia, inspection lift and reward animation.
func _process(delta: float) -> void:
	z_index = battle.HELD_ITEM_Z if gesture == "card" else BattleLayers.TAROT_INVENTORY
	if not settings_open():
		drag_feedback.advance(delta,gesture == "card",accepts_drop(pointer),battle.reduced)
		clock += delta
		expansion = move_toward(expansion,1.0 if opened else 0.0,delta*(8 if battle.reduced else 2.8))
		if not held:
			if absf(swipe.velocity) > 0.1:
				swipe.advance(delta)
				scroll = swipe.position/card_angle()
				scroll_target = roundf(scroll)
			else:
				scroll = lerpf(scroll,scroll_target,1-exp(-delta*14))
				swipe.position = scroll*card_angle()
		_scroll_tick(not held and absf(swipe.velocity) > 0.1)
		# Only inspected cards need lift state; closed inventories do no per-card work.
		var lifted_id: int = battle.model.tarots.items[inspected].instance_id if inspected >= 0 and inspected < battle.model.tarots.items.size() else -1
		if lifted_id >= 0 and not float_levels.has(lifted_id): float_levels[lifted_id] = 0.0
		for instance_id in float_levels.keys():
			var level: float = move_toward(float_levels[instance_id],1.0 if instance_id == lifted_id else 0.0,delta*5)
			if level <= 0: float_levels.erase(instance_id)
			else: float_levels[instance_id] = level
		if not cast_visual.is_empty():
			cast_visual.age += delta
			if cast_visual.age >= (0.6 if not cast_visual.lane.is_empty() else 0.4):
				if not cast_visual.lane.is_empty(): battle.tarot_feedback.finish_arrival(cast_visual.id,cast_visual.lane)
				cast_visual.clear()
		ceremony.reduced = battle.reduced
		ceremony.advance(delta)
	battle.dice_group.transform = dice_transform()
	queue_redraw()

## Render the tarot carousel, toggle, description and frontmost held card.
func _draw() -> void:
	if settings_open() or ceremony.active(): return
	if expansion > 0:
		var center: Vector2 = battle.DICE_CENTER+Vector2(0,-40)
		for i in range(7,0,-1): draw_circle(center,battle.DICE_RADIUS+i*4,Color(0.08,0.07,0.15,expansion*0.07))
		Paint.text(self,battle.description_font,Vector2(center.x,battle.DICE_CENTER.y-(214 if portrait() else 117)),"TAROT COLLECTION",26 if portrait() else 18,Color(Paint.GOLD,expansion))
		for i in carousel_order():
			if gesture == "card" and pressed_card == i: continue
			var pose: Dictionary = carousel_pose(i)
			Paint.card(self,battle.model.tarots.items[i].id,pose.at,pose.size,pose.angle,1,(0.65 if i == front_index() else 0.4)+sin(clock*2.5+i)*0.08,expansion*lerpf(0.55,1,pose.depth))
			if battle.model.tarots.items[i].get("projection",false):
				Paint.text(self,battle.description_font,pose.at+Vector2(0,pose.size.y*0.34),"PROJECTION",20 if portrait() else 14,Color("a5e6ff",expansion))
		var front: int = front_index()
		if front >= 0:
			var id: String = battle.model.tarots.items[front].id
			Paint.text(self,battle.description_font,Vector2(center.x,battle.DICE_CENTER.y+(242 if portrait() else 161)),Catalog.ITEMS[id].name,26 if portrait() else 18,Color(Paint.GOLD,expansion))
			Paint.text(self,battle.description_font,Vector2(center.x,battle.DICE_CENTER.y+(283 if portrait() else 184)),"SWIPE · TAP TO INSPECT · DRAG TO CAST",19 if portrait() else 13,Color(Paint.LILAC,expansion))
		else:
			Paint.text(self,battle.description_font,center,"NO TAROT CARDS YET",27 if portrait() else 19,Paint.GOLD)
			Paint.wrap(self,battle.description_font,Rect2(center+Vector2(-220,28),Vector2(440,140)),"Find cards in wave rewards and treasures.",24 if portrait() else 17,Paint.LILAC,true)
	_draw_icon()
	if inspected >= 0 and inspected < battle.model.tarots.items.size() and gesture != "card": _draw_inspection()
	if opened and expansion >= 0.98 and gesture != "card":
		var rect: Rect2 = sort_rect()
		Paint.panel(self,rect,Color("252431"),Paint.LILAC,10)
		Paint.text(self,battle.description_font,rect.get_center()+Vector2(0,9 if portrait() else 6),"SORT BY NAME",24 if portrait() else 17,Paint.GOLD)
	if gesture == "card" and pressed_card >= 0 and pressed_card < battle.model.tarots.items.size():
		_draw_drag_backdrop()
		var valid: bool = accepts_drop(pointer) and available()
		draw_rect(battle.ARENA,Color(Paint.GOLD,0.65 if valid else 0.2),false,3)
		if external_dice_drop: draw_arc(battle.DICE_CENTER,battle.DICE_RADIUS,0,TAU,64,Color(Paint.LILAC,0.6 if valid else 0.2),3)
		var held_item: Dictionary = battle.model.tarots.items[pressed_card]
		var layout: Dictionary = held_layout(held_item)
		var at: Vector2 = layout.at
		var size: Vector2 = layout.size
		Paint.card(self,battle.model.tarots.items[pressed_card].id,at,size,0,1,1.0,drag_feedback.opacity())
		drag_feedback.paint(self,at,size*0.56,Paint.GOLD,battle.reduced)
		paint_card_details(self,held_item,layout.details)
		if Catalog.ITEMS[battle.model.tarots.items[pressed_card].id].target == "enemy" and not battle.model.is_city():
			var target: int = battle._enemy_inspect_at(pointer)
			for index in battle.model.tarot_effects.targets(battle.model,battle.model.tarots.items[pressed_card].id):
				battle._draw_target_indicator(self,index,index == target,Paint.GOLD)
	if not cast_visual.is_empty():
		if cast_visual.lane.is_empty():
			var t: float = cast_visual.age/0.4
			Paint.card(self,cast_visual.id,cast_visual.at,Vector2(120,186)*(1+t*0.4),sin(t*PI)*0.12,1,2*(1-t),1-t)
		else: _paint_indicator_delivery()

## Compress the card into light, then follow the live badge anchor with a sparkling arc.
func _paint_indicator_delivery() -> void:
	var shrink: float = clampf(cast_visual.age/0.18,0,1)
	var travel: float = clampf((cast_visual.age-0.18)/0.42,0,1)
	var target: Vector2 = battle.tarot_feedback.indicator_center(cast_visual.id,cast_visual.lane)
	var origin: Vector2 = cast_visual.at
	var t: float = travel*travel*(3-2*travel)
	var at: Vector2 = origin.lerp(target,t)+Vector2(0,-sin(t*PI)*55)
	if shrink < 1:
		Paint.card(self,cast_visual.id,origin,Vector2(120,186)*maxf(0.02,1-shrink*shrink),shrink*0.2,1,2,1-shrink)
	for layer in range(5,0,-1):
		draw_circle(at,(5+layer*5)*shrink,Color(Paint.LILAC,0.08*shrink))
	draw_circle(at,7*shrink,Color("faf1ff"))
	if not battle.reduced:
		for i in range(9):
			var tail: float = maxf(0,t-i*0.022)
			var point: Vector2 = origin.lerp(target,tail)+Vector2(sin(i*9.1)*5,-sin(tail*PI)*55)
			draw_circle(point, maxf(1,3-i*0.2),Color(Paint.LILAC,(1-i/9.0)*travel))

## Keep the effect underneath the held card and inside the screen, regardless of source.
func held_layout(item: Dictionary) -> Dictionary:
	var size: Vector2 = (Vector2(170,264) if portrait() else Vector2(110,170))*drag_feedback.scale_factor()
	var width: float = 380 if portrait() else 290
	var height: float = card_details_size(item,width).y
	var at: Vector2 = pointer-Vector2(0,70 if portrait() else 35)
	at.x = clampf(at.x,width/2+8,battle.fx.canvas_size.x-width/2-8)
	at.y = clampf(at.y,size.y/2+8,battle.fx.canvas_size.y-size.y/2-height-20)
	return {"at":at,"size":size,"details":Rect2(Vector2(at.x-width/2,at.y+size.y/2+8),Vector2(width,height))}

## Size localized descriptions once for either a held card or the quick-row preview.
func card_details_size(item: Dictionary, width: float) -> Vector2:
	var font_size: int = 23 if portrait() else 17
	var title_size: int = 28 if portrait() else 21
	var title_lines: int = GameText.lines(GameText.text(Catalog.ITEMS[item.id].name),battle.description_font,title_size,width-24).size()
	var lines: int = GameText.lines(inspection_description(item),battle.description_font,font_size,width-24).size()
	return Vector2(width,24+title_lines*title_size*1.3+lines*font_size*1.3)

## Shared live card details stay readable even when the aiming card is transparent.
func paint_card_details(canvas: CanvasItem, item: Dictionary, rect: Rect2) -> void:
	Paint.panel(canvas,rect,Color("211b2e",0.92),Color(Paint.LILAC,0.3),8)
	var content := Rect2(rect.position+Vector2(12,5),rect.size-Vector2(24,10))
	var title_size: int = 28 if portrait() else 21
	Paint.wrap(canvas,battle.description_font,content,Catalog.ITEMS[item.id].name,title_size,Paint.LILAC,true)
	var title_lines: int = GameText.lines(GameText.text(Catalog.ITEMS[item.id].name),battle.description_font,title_size,content.size.x).size()
	var y: float = content.position.y+title_lines*title_size*1.3+8
	Paint.wrap(canvas,battle.description_font,Rect2(Vector2(content.position.x,y),Vector2(content.size.x,rect.end.y-y-5)),inspection_description(item),23 if portrait() else 17,Color("eee6ed"),true)

## Dim controls around the battlefield while leaving enemies clear for aiming.
func _draw_drag_backdrop() -> void:
	var arena: Rect2 = battle.ARENA
	var screen: Vector2 = battle.fx.canvas_size
	var shade := Color(0.02,0.02,0.04,0.48)
	# Leave enemies clear while aiming; dim the controls surrounding the field.
	for rect in [Rect2(0,0,screen.x,arena.position.y),Rect2(0,arena.end.y,screen.x,screen.y-arena.end.y),Rect2(0,arena.position.y,arena.position.x,arena.size.y),Rect2(arena.end.x,arena.position.y,screen.x-arena.end.x,arena.size.y)]:
		draw_rect(rect,shade)
	# Battlefield shade is drawn below actors by the battle, independent of card position.

## Draw the card/dice toggle, card count and unavailable-state dimming.
func _draw_icon() -> void:
	var rect: Rect2 = icon_rect()
	Paint.panel(self,rect,Color("252431"),Color("8c799d"),14)
	if opened:
		var die := Rect2(rect.get_center()-rect.size*0.27,rect.size*0.54)
		Paint.panel(self,die,Color("eee0d6"),Color("958489"),7)
		for d in [Vector2(-1,-1),Vector2(1,1),Vector2.ZERO]: draw_circle(die.get_center()+d*die.size*0.25,3 if portrait() else 2,Color("282337"))
	else:
		Paint.card(self,"",rect.get_center()+Vector2(-6,0),rect.size*Vector2(0.4,0.64),-0.15)
		Paint.card(self,"",rect.get_center()+Vector2(6,0),rect.size*Vector2(0.4,0.64),0.15)
		var count: int = battle.model.tarots.items.size()
		if count > 0: Paint.text(self,battle.description_font,rect.end-Vector2(10,7),str(count),22 if portrait() else 16,Paint.GOLD)

	if not available() and not opened:
		Paint.panel(self,rect,Color(0.06,0.06,0.07,0.58),Color.TRANSPARENT,14)

## Show the selected floating card and its effect over a dimmed battlefield.
func inspection_description(item: Dictionary) -> String:
	var description: String = GameText.text(Catalog.description(item.id))
	if item.get("projection",false): description = GameText.text("Projection: expires at turn end.")+"\n"+description
	return description

## Fit the projection reminder and effect without clipping longer card descriptions.
func inspection_rect(item: Dictionary) -> Rect2:
	var rect := Rect2(62,battle.DICE_CENTER.y-370,680,236) if portrait() else Rect2(372,battle.DICE_CENTER.y-290,536,180)
	var size: int = 26 if portrait() else 19
	var height: float = (92 if portrait() else 74)+GameText.lines(inspection_description(item),battle.description_font,size,rect.size.x-44).size()*size*1.3
	if height > rect.size.y:
		rect.position.y -= height-rect.size.y
		rect.size.y = height
	return rect

## Show the selected floating card and its effect over a dimmed battlefield.
func _draw_inspection() -> void:
	var item: Dictionary = battle.model.tarots.items[inspected]
	var lift: float = float_levels.get(item.instance_id,0.0)
	draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.025,0.02,0.05,0.62*lift))
	var pose: Dictionary = carousel_pose(inspected)
	Paint.card(self,item.id,pose.at,pose.size,0,1,0.8)
	paint_inspection(self,item)

## Share localized titles, projection reminders and wrapping with quick access.
func paint_inspection(canvas: CanvasItem, item: Dictionary, rect: Rect2 = Rect2()) -> void:
	if not rect.has_area(): rect = inspection_rect(item)
	Paint.panel(canvas,rect,Color("211a38",0.94),Color("75628d"))
	Paint.wrap(canvas,battle.description_font,Rect2(rect.position+Vector2(22,12),Vector2(rect.size.x-44,76)),Catalog.ITEMS[item.id].name,30 if portrait() else 23,Paint.GOLD)
	Paint.wrap(canvas,battle.description_font,Rect2(rect.position+Vector2(22,82 if portrait() else 64),Vector2(rect.size.x-44,rect.size.y-92 if portrait() else rect.size.y-72)),inspection_description(item),26 if portrait() else 19)
