extends Node2D
## Already-granted enemy cards scatter and wait for a readable face-up pickup receipt.
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
const DROP_TIME := 0.42
const PICKUP_START := 0.85
var ui
var cards: Array = []
var cosmetic := RandomNumberGenerator.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cosmetic.randomize()

## Capture the body position at death; presentation never grants another card.
func enqueue(item: Dictionary) -> void:
	var b = ui.battle
	var index: int = item.enemy_index
	var feet: Vector2 = b._enemy_feet(index) if index >= 0 else b._troop_point(-3-index)
	var origin: Vector2 = feet-Vector2(0,b._enemy_side()*0.4)
	var ground: Vector2 = (feet+Vector2(cosmetic.randf_range(-48,48),cosmetic.randf_range(-12,16))).clamp(b.ARENA.position+Vector2(28,38),b.ARENA.end-Vector2(28,38))
	cards.append({"item":item.duplicate(),"origin":origin,"ground":ground,"age":0.0,"spin":cosmetic.randf_range(3.8,5.4)*(-1 if cosmetic.randf()<0.5 else 1),"seed":cosmetic.randf()*TAU})
	queue_redraw()

func reset() -> void:
	cards.clear()
	queue_redraw()

## Share the receipt controller's pause/transition rules, including simultaneous deaths.
func advance(delta: float) -> void:
	for card in cards: card.age += delta
	queue_redraw()

## Transfer only cards that can be shown now; queued drops stay visible on the ground.
func take_ready(limit: int) -> Array:
	var ready: Array = []
	for card in cards:
		if ready.size() >= limit: break
		if card.age < PICKUP_START: continue
		var p: Dictionary = pose(card)
		ready.append({"item":card.item,"from":p.at,"from_size":p.size,"from_angle":p.angle})
	for receipt in ready:
		var index: int = cards.find_custom(func(card): return card.item.instance_id == receipt.item.instance_id)
		cards.remove_at(index)
	queue_redraw()
	return ready

## Toss outward with gravity and a small bounce, retaining the settled pose until pickup.
func pose(card: Dictionary) -> Dictionary:
	var age: float = minf(card.age,PICKUP_START)
	var at: Vector2 = card.ground
	if age < DROP_TIME:
		var t: float = age/DROP_TIME
		at = card.origin.lerp(card.ground,t)
		if not ui.battle.reduced: at.y -= sin(t*PI)*58
	elif not ui.battle.reduced:
		var t: float = (age-DROP_TIME)/(PICKUP_START-DROP_TIME)
		at.y -= absf(sin(t*TAU))*12*(1-t)
	var size := Vector2(34,52) if ui.portrait() else Vector2(26,40)
	return {"at":at,"size":size,"angle":0.0 if ui.battle.reduced else age*card.spin,"alpha":1.0}

## White card halos and staggered pixel stars distinguish tarot from blood gems.
func _draw() -> void:
	for card in cards:
		var p: Dictionary = pose(card)
		draw_set_transform(p.at,p.angle)
		var rect := Rect2(-p.size*0.5,p.size)
		for layer in range(4,0,-1): Paint.panel(self,rect.grow(layer*3),Color(1,1,1,0.045*p.alpha))
		Paint.panel(self,rect.grow(2),Color.WHITE*Color(1,1,1,p.alpha))
		draw_set_transform(Vector2.ZERO)
		Paint.card(self,card.item.id,p.at,p.size,p.angle,1,0,p.alpha)
		for i in range(3 if ui.battle.reduced else 7):
			var t: float = fposmod(card.age*1.4+i/7.0,1)
			var d := Vector2.from_angle(card.seed+i*2.4)
			var at: Vector2 = p.at+d*(18+t*24)-Vector2(0,t*14)
			var strength: float = sin(t*PI)*p.alpha
			var side: float = 2+strength*3
			draw_line(at-Vector2(side,0),at+Vector2(side,0),Color(1,1,1,strength),2)
			draw_line(at-Vector2(0,side),at+Vector2(0,side),Color(1,1,1,strength),2)
