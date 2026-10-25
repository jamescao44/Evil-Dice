extends Node2D
## Battlefield chest and route choices; the run model owns rewards, eligibility and transactions.
const Rewards = preload("res://scripts/progression/wave_rewards.gd")
const Icons = preload("res://scripts/rewards/reward_icons.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
signal chest_pressed
signal route_pressed(index: int)
var battle
var phase := ""
var kind := Rewards.RELIC
var options: Array = []
var age := 0.0
var paid_amount := 0
var keeper: Sprite2D
const LIFT_SECONDS := 0.38
const SHAKE_SECONDS := 0.28

## Keep the reward on top of battlefield actors and beneath inventory/modal pages.
func _ready() -> void:
	z_index = 80
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	keeper = Sprite2D.new()
	keeper.texture = preload("res://assets/art/shop/keeper.png")
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/rewards/shop_keeper.gdshader")
	keeper.material = ink
	add_child(keeper)
	keeper.hide()
	hide()

## Reset all presentation when a run or pending reward is canceled.
func cancel() -> void:
	phase = ""
	options.clear()
	keeper.hide()
	hide()

## Spawn one closed chest on the cleared battlefield.
func present_chest(reward_kind: String) -> void:
	kind = reward_kind
	phase = "closed"
	age = 0
	paid_amount = 0
	show()
	queue_redraw()

## Display two distinct locked route choices without consuming reward randomness.
func present_routes(choices: Array) -> void:
	options = choices.duplicate()
	phase = "routes"
	age = 0
	show()
	queue_redraw()

## Enlarge a relic chest into the existing reel presentation before it opens automatically.
func begin_lift() -> void:
	phase = "lift"
	age = 0

## Show a direct resource payout on the battlefield.
func reveal_amount(amount: int) -> void:
	phase = "paid"
	paid_amount = amount
	age = 0
	queue_redraw()

## Scroll the keeper into the cleared battlefield as a shop destination arrives.
func present_keeper() -> void:
	phase = "keeper"
	age = 0
	show()
	keeper.show()

## Push toward the keeper and fade into the full storefront.
func enter_shop() -> void:
	phase = "shop_enter"
	age = 0

func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

## Keep the chest away from the player's lower-left sprite.
func chest_rect() -> Rect2:
	var side: float = 156 if portrait() else 112
	var at: Vector2 = battle.ARENA.position+battle.ARENA.size*Vector2(0.66,0.57)
	return Rect2(at-Vector2.ONE*side/2,Vector2.ONE*side)

## Route zero points right; route one points upward, both fully inside the arena.
func route_rect(index: int) -> Rect2:
	var side: float = 168 if portrait() else 130
	var ratio := Vector2(0.81,0.59) if index == 0 else Vector2(0.54,0.24)
	return Rect2(battle.ARENA.position+battle.ARENA.size*ratio-Vector2.ONE*side/2,Vector2.ONE*side)

func icon_key(reward_kind: String) -> String:
	return "ruby" if reward_kind == Rewards.BLOOD_GEMS else "soul" if reward_kind == Rewards.SOULS else reward_kind

## Report only active controls to the shared pointer feedback.
func hit(at: Vector2) -> bool:
	if not visible: return false
	if phase == "closed": return chest_rect().grow(16).has_point(at)
	if phase == "routes":
		for i in range(options.size()):
			if route_rect(i).has_point(at): return true
	return false

## Latch input immediately so double taps cannot open or select twice.
func click(at: Vector2) -> bool:
	if not visible: return false
	if phase == "closed" and chest_rect().grow(16).has_point(at):
		phase = "opening"
		age = 0
		chest_pressed.emit()
	elif phase == "routes":
		for i in range(options.size()):
			if route_rect(i).has_point(at):
				phase = "chosen"
				route_pressed.emit(i)
				break
	return true

## Keep presentation responsive to menus and reduced-effects mode.
func _process(delta: float) -> void:
	if not visible or battle._menus_open(): return
	age += delta
	if phase in ["keeper","shop_enter"]:
		var side: float = 240 if portrait() else 180
		var t: float = smoothstep(0,0.45,age) if phase == "shop_enter" else 0.0
		keeper.position = chest_rect().get_center()+battle._arrival_offset()
		keeper.scale = Vector2.ONE*side/keeper.texture.get_width()*(1+t*0.65)
		keeper.modulate.a = 1-t
	queue_redraw()

func _text(at: Vector2, value: String, point_size: int, color: Color) -> void:
	Cards.text(self,battle.description_font,at,value,point_size,color)

## Draw the reward symbol inside an unmistakable directional arrow.
func _draw_route(index: int) -> void:
	var rect := route_rect(index)
	var at := rect.get_center()
	var color: Color = Rewards.COLORS[options[index]]
	var pulse: float = 1.0 if battle.reduced else 1.0+sin(age*3)*0.025
	var points := PackedVector2Array([Vector2(-0.48,-0.32),Vector2(0.10,-0.32),Vector2(0.10,-0.49),Vector2(0.50,0),Vector2(0.10,0.49),Vector2(0.10,0.32),Vector2(-0.48,0.32)])
	for i in range(points.size()):
		if index == 1: points[i] = points[i].rotated(-PI/2)
		points[i] = at+points[i]*rect.size.x*pulse
	draw_colored_polygon(points,Color("181c22"))
	points.append(points[0])
	draw_polyline(points,Color(color,0.85),3)
	var icon_side: float = 60 if portrait() else 44
	var icon_at: Vector2 = at+Vector2(-10,0) if index == 0 else at+Vector2(0,10)
	Icons.paint(self,battle.chest.art,icon_key(options[index]),Rect2(icon_at-Vector2.ONE*icon_side/2,Vector2.ONE*icon_side))
	_text(Vector2(at.x,rect.end.y+24),Rewards.LABELS[options[index]],24 if portrait() else 18,color)

## Show the actual credited amount before its currency icon, with amount-based sizing.
func _draw_amount(rect: Rect2) -> void:
	var size: int = roundi((36 if portrait() else 26)*Rewards.amount_scale(kind,paid_amount,battle.model.stage))
	var label: String = "+%d" % paid_amount
	var font: Font = battle.description_font
	var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var icon_side: float = size*1.12
	var gap: float = size*0.22
	var at: Vector2 = Vector2(rect.get_center().x,rect.position.y-(42 if portrait() else 30))
	if not battle.reduced: at.y -= smoothstep(0,0.5,age)*10
	var left: float = at.x-(width+gap+icon_side)/2
	var baseline := Vector2(left,at.y+size*0.34)
	draw_string_outline(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,4,Color("101418"))
	draw_string(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Rewards.COLORS[kind].lightened(0.4))
	Icons.paint(self,battle.chest.art,icon_key(kind),Rect2(Vector2(left+width+gap,at.y-icon_side/2),Vector2.ONE*icon_side))

## Keep the battlefield visible until the relic chest reaches the full-screen reel position.
func _draw() -> void:
	if not visible: return
	if phase in ["keeper","shop_enter"]:
		if phase == "shop_enter": draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.08,0.1,0.11,smoothstep(0,0.45,age)))
		return
	if phase in ["routes","chosen"]:
		_text(Vector2(battle.ARENA.get_center().x,battle.ARENA.position.y+42),"CHOOSE YOUR PATH",30 if portrait() else 22,Color("eee0b9"))
		for i in range(options.size()): _draw_route(i)
		return
	var rect := chest_rect()
	var color: Color = Rewards.COLORS[kind]
	if phase == "opening" and not battle.reduced:
		var envelope: float = sin(clampf(age/SHAKE_SECONDS,0,1)*PI)
		rect.position += Vector2(sin(age*75)*5,-absf(sin(age*38))*2)*envelope
	if phase == "lift":
		var t := smoothstep(0,LIFT_SECONDS,age)
		draw_rect(Rect2(Vector2.ZERO,battle.fx.canvas_size),Color(0.04,0.07,0.06,0.95*t))
		var destination: Rect2 = battle.chest.closed_rect()
		rect = Rect2(rect.position.lerp(destination.position,t),rect.size.lerp(destination.size,t))
	for i in range(5): draw_circle(rect.get_center(),rect.size.x*(0.48+i*0.08),Color(color,0.035))
	var opening: bool = phase == "paid"
	draw_texture_rect(battle.chest.art.chest_open if opening else battle.chest.art.chest_closed,rect,false)
	if phase == "lift": return
	if opening: _draw_amount(rect)
	elif phase == "closed": _text(Vector2(rect.get_center().x,rect.end.y+30),"TAP TO OPEN",26 if portrait() else 19,color)
