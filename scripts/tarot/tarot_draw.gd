extends Node2D
## Presentation-only reward ceremony. Fan positions never determine the locked outcomes.
signal picked(index: int)
signal card_drawn
signal card_shuffled
signal finished
const SHUFFLE_LEAD := 0.16
const SHUFFLE_STEP := 0.027
const SHUFFLE_TRAVEL := 0.18
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
const Swipe = preload("res://scripts/tarot/card_swipe.gd")
var swipe = Swipe.new()
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
var canvas_size := Vector2(804,1748)
var font: Font
var reduced: bool = false
var choices: Array = []
var state: String = ""
var age: float = 0.0
var sky_age: float = 0.0
var offset: float = 0.0
var selected: int = -1
var draws: Array = []
var removed: Array = []
var pressed: bool = false
var moved: bool = false
var press_at := Vector2.ZERO
var last_at := Vector2.ZERO
var pressed_card: int = -1
var collection_target := Vector2.ZERO
var shuffled_cards: int = 0

func _ready() -> void:
	z_index = 160
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func active() -> bool:
	return not state.is_empty()

func portrait() -> bool:
	return canvas_size.y > canvas_size.x

func start(ids: Array, size: Vector2, text_font: Font, target: Vector2, reduce: bool) -> void:
	reset()
	if ids.size() != 3: return
	choices = ids.duplicate()
	canvas_size = size
	font = text_font
	collection_target = target
	reduced = reduce
	state = "shuffle"
	queue_redraw()

func reset() -> void:
	state = ""
	choices.clear()
	draws.clear()
	removed.clear()
	shuffled_cards = 0
	age = 0
	sky_age = 0
	offset = 0
	swipe.reset()
	selected = -1
	cancel_gesture()
	queue_redraw()

func cancel_gesture() -> void:
	pressed = false
	moved = false
	pressed_card = -1
	swipe.dragging = false

func card_size() -> Vector2:
	return Vector2(204,316) if portrait() else Vector2(154,238)

func row_point(index: int) -> Vector2:
	var bob: float = 0.0
	if not reduced and index >= 0 and index < draws.size():
		var settle: float = smoothstep(0.45,0.85,draws[index].age)
		if state == "collect": settle *= 1.0-smoothstep(0,0.12,age)
		bob = sin(sky_age*2.2-index*0.8)*(8 if portrait() else 5)*settle
	return Vector2(canvas_size.x/2+(index-1)*(242 if portrait() else 266),670 if portrait() else 298)+Vector2(0,bob)

func row_rect(index: int) -> Rect2:
	return Rect2(row_point(index)-card_size()/2,card_size())

func fan_size() -> Vector2:
	return Vector2(168,260) if portrait() else Vector2(122,189)

func fan_pose(index: int) -> Dictionary:
	var step: float = fposmod(index+offset+11,22)-11
	var angle: float = step*(0.077 if portrait() else 0.070)
	var radius: float = 800 if portrait() else 1080
	var pivot := Vector2(canvas_size.x/2,2130 if portrait() else 1670)
	var at: Vector2 = pivot+Vector2(sin(angle)*radius,-cos(angle)*radius)
	var spread: float = 1.0 if state != "fan" or reduced else smoothstep(0,0.55,age)
	return {"at":Vector2(canvas_size.x/2,1330 if portrait() else 590).lerp(at,spread),"angle":angle*spread,"step":step}

func fan_order() -> Array:
	var order: Array = range(22)
	order.sort_custom(func(a,b): return fan_pose(a).step < fan_pose(b).step)
	return order

func fan_at(point: Vector2) -> int:
	var order: Array = fan_order()
	order.reverse()
	for i in order:
		if i in removed: continue
		var pose: Dictionary = fan_pose(i)
		var local: Vector2 = (point-pose.at).rotated(-pose.angle)
		if Rect2(-fan_size()/2,fan_size()).has_point(local): return i
	return -1

func keep_rect() -> Rect2:
	return Rect2(152,1458,500,92) if portrait() else Rect2(420,670,440,62)

func click(point: Vector2) -> bool:
	if not active(): return false
	cancel_gesture()
	# Consume the skip tap; its release must not also draw or select a card.
	if skip_preparation(): return true
	pressed = true
	swipe.reset(offset)
	swipe.begin()
	press_at = point
	last_at = point
	if state == "fan" and age >= 0.55: pressed_card = fan_at(point)
	return true

func motion(point: Vector2) -> bool:
	if not active(): return false
	if pressed:
		if point.distance_to(press_at) > (14 if portrait() else 8): moved = true
		if moved and state == "fan" and age >= 0.55 and press_at.y > canvas_size.y*0.55:
			swipe.move((point.x-last_at.x)/(55 if portrait() else 65))
			offset = swipe.position
		last_at = point
	return true

func release(point: Vector2) -> bool:
	if not active(): return false
	if not pressed: return true
	motion(point)
	swipe.release()
	if not moved:
		if state == "fan" and pressed_card >= 0 and pressed_card == fan_at(point):
			var pose: Dictionary = fan_pose(pressed_card)
			draws.append({"from":pose.at,"angle":pose.angle,"age":0.0})
			removed.append(pressed_card)
			card_drawn.emit()
			if draws.size() == 3: state = "drawing"; age = 0
		elif state == "choose":
			for i in range(3):
				if row_rect(i).grow(12).has_point(point): selected = i
			if selected >= 0 and keep_rect().has_point(point) and keep_rect().has_point(press_at):
				state = "collect"
				age = 0
				picked.emit(selected)
	cancel_gesture()
	return true

func skip_preparation() -> bool:
	if state in ["shuffle","drop"] or (state == "fan" and age < 0.55):
		shuffled_cards = 22
		state = "fan"
		age = 0.55
	elif state in ["drawing","reveal"]:
		for d in draws: d.age = maxf(d.age,0.85)
		state = "choose"
		age = 0
	else: return false
	queue_redraw()
	return true

func advance(delta: float) -> void:
	if not active(): return
	age += delta
	sky_age += delta
	if state == "shuffle":
		# Share the visual departure times so each card sounds once, independent of FPS.
		while shuffled_cards < 22 and age >= shuffle_duration()*(SHUFFLE_LEAD+shuffled_cards*SHUFFLE_STEP):
			shuffled_cards += 1
			card_shuffled.emit()
	if state == "fan":
		swipe.advance(delta)
		offset = swipe.position
	for d in draws: d.age += delta*(3 if reduced else 1)
	if state == "shuffle" and age >= shuffle_duration(): state = "drop"; age = 0
	elif state == "drop" and age >= (0.18 if reduced else 0.48): state = "fan"; age = 0
	elif state == "drawing" and draws[-1].age >= 0.55: state = "reveal"; age = 0
	elif state == "reveal" and age >= (0.25 if reduced else 1.05): state = "choose"; age = 0
	elif state == "collect" and age >= (0.35 if reduced else 0.85):
		reset()
		finished.emit()
	queue_redraw()

func _draw() -> void:
	if not active() or font == null: return
	Paint.sky(self,canvas_size,sky_age,reduced)
	var mid: float = canvas_size.x/2
	Paint.text(self,font,Vector2(mid,230 if portrait() else 90),"TAROT",44 if portrait() else 32)
	var caption: String = "SHUFFLING THE STARS" if state in ["shuffle","drop"] else "CHOOSE ONE TO KEEP" if state in ["choose","reveal"] else "CARD COLLECTED" if state == "collect" else "DRAW THREE CARDS"
	Paint.text(self,font,Vector2(mid,308 if portrait() else 140),caption,28 if portrait() else 22,Paint.LILAC)
	if state == "shuffle": _draw_shuffle()
	if state == "drop":
		var t: float = smoothstep(0,0.18 if reduced else 0.48,age)
		var at: Vector2 = _deck_left().lerp(Vector2(mid,1330 if portrait() else 590),t)
		for i in range(22): Paint.card(self,"",at+Vector2(0,-i*1.5*(1-t)),fan_size(),0 if reduced else sin(t*PI)*0.07)
	if state in ["fan","drawing"]:
		for i in fan_order():
			if i in removed: continue
			var pose: Dictionary = fan_pose(i)
			Paint.card(self,"",pose.at,fan_size(),pose.angle,1,0,1-smoothstep(0,0.55,age) if state == "drawing" else 1)
		Paint.text(self,font,Vector2(mid,1080 if portrait() else 475),GameText.format("DRAWN %d / 3",draws.size()),26 if portrait() else 20)
		Paint.text(self,font,Vector2(mid,1630 if portrait() else 755),"SWIPE TO EXPLORE THE FAN",24 if portrait() else 18,Paint.LILAC)
	for i in range(draws.size()):
		if state == "collect" and i == selected: continue
		var d: Dictionary = draws[i]
		var t: float = clampf(d.age/0.5,0,1)
		var eased: float = 1-pow(1-t,3)
		var at: Vector2 = d.from.lerp(row_point(i),eased)-Vector2(0,sin(t*PI)*70)
		var extent: Vector2 = fan_size().lerp(card_size(),eased)
		var flip: float = 1.0
		var face: bool = state in ["choose","collect"]
		if state == "reveal":
			var progress: float = clampf((age-i*0.13)/(0.55 if not reduced else 0.1),0,1)
			flip = cos(progress*PI)
			face = progress >= 0.5
		Paint.card(self,choices[i] if face else "",at,extent,lerpf(d.angle,0,eased),flip,1.0 if selected == i else 0.0,0.3 if state == "collect" else 1.0)
		if face and state != "collect":
			Paint.wrap(self,font,Rect2(row_point(i)+Vector2(-115,card_size().y/2+22),Vector2(230,104)),Catalog.ITEMS[choices[i]].name,27 if portrait() else 20,Paint.GOLD,true)
	if state == "choose" and selected >= 0:
		var rect := Rect2(66,1000,672,360) if portrait() else Rect2(264,484,752,172)
		Paint.panel(self,rect,Color("211a38"),Color("534265"))
		Paint.text(self,font,rect.position+Vector2(24,42 if portrait() else 30),"Effect",24 if portrait() else 18,Paint.GOLD,false)
		Paint.wrap(self,font,Rect2(rect.position+Vector2(24,60 if portrait() else 42),rect.size-Vector2(48,110 if portrait() else 86)),Catalog.ITEMS[choices[selected]].design,30 if portrait() else 20)
		Paint.text(self,font,Vector2(mid,rect.end.y-24),"Single use",22 if portrait() else 17,Paint.LILAC)
		Paint.panel(self,keep_rect(),Color("3c3056"),Paint.GOLD)
		Paint.text(self,font,keep_rect().get_center()+Vector2(0,10),"KEEP THIS CARD",28 if portrait() else 22)
	if state == "collect":
		var t: float = smoothstep(0.12,0.78,age)
		var at: Vector2 = row_point(selected).lerp(collection_target,t)-Vector2(0,sin(t*PI)*110)
		Paint.card(self,choices[selected],at,card_size().lerp(Vector2(36,56),t),0,1,sin(t*PI)*2)
		for i in range(12):
			var p: Vector2 = at+Vector2.from_angle(i*TAU/12+age)*sin(t*PI)*110
			draw_circle(p,2+(i%3),Color(Paint.GOLD,sin(t*PI)))
	Paint.text(self,font,Vector2(mid,canvas_size.y-38),"Art by Jose Angel Canabal",18 if portrait() else 14,Color("94869f"))

func _deck_left() -> Vector2:
	return Vector2(canvas_size.x*0.28,870 if portrait() else 370)

func shuffle_duration() -> float:
	return 0.35 if reduced else 1.00

func shuffle_pose(index: int) -> Dictionary:
	var progress: float = age/shuffle_duration()
	var t: float = clampf((progress-SHUFFLE_LEAD-index*SHUFFLE_STEP)/SHUFFLE_TRAVEL,0,1)
	var right := Vector2(canvas_size.x*0.72,_deck_left().y)-Vector2(0,(21-index)*1.5)
	var left: Vector2 = _deck_left()-Vector2(0,index*1.5)
	return {"at":right.lerp(left,smoothstep(0,1,t)),"t":t}

func _draw_shuffle() -> void:
	# The top card leaves the right deck, crosses quickly, then lands on the left.
	for i in range(21,-1,-1):
		var pose: Dictionary = shuffle_pose(i)
		if pose.t == 0: Paint.card(self,"",pose.at,fan_size())
	for i in range(22):
		var pose: Dictionary = shuffle_pose(i)
		if pose.t == 1: Paint.card(self,"",pose.at,fan_size())
	for i in range(22):
		var pose: Dictionary = shuffle_pose(i)
		if pose.t > 0 and pose.t < 1: Paint.card(self,"",pose.at,fan_size(),0 if reduced else -sin(pose.t*PI)*0.06)
