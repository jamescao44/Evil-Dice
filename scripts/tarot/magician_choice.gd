extends RefCounted
## In-place die editing: cancellation and face changes are committed by TarotCast.
const Art = preload("res://scripts/dice/dice_art.gd")
const Paint = preload("res://scripts/tarot/tarot_paint.gd")
var selected: int = -1
var age: float = 0
var origin := Vector2.ZERO

func start(from: Vector2) -> void:
	selected = -1
	age = 0
	origin = from

## Lift edge dice just enough to keep the entire face ring inside the screen.
func selected_center(battle) -> Vector2:
	var margin: float = 166 if battle.tarot_ui.portrait() else 128
	return battle.DICE_POSITIONS[selected].clamp(Vector2.ONE*margin,battle.fx.canvas_size-Vector2.ONE*margin)

func face_center(battle, face: int) -> Vector2:
	var radius: float = 122 if battle.tarot_ui.portrait() else 92
	return selected_center(battle)+Vector2.from_angle(-PI/2+(face-1)*TAU/6)*radius

## Return an uncommitted selection; tapping the same die closes only its ring.
func click(battle, point: Vector2) -> Dictionary:
	if selected >= 0:
		if point.distance_to(selected_center(battle)) < (66 if battle.tarot_ui.portrait() else 49):
			selected = -1
			return {}
		for face in range(1,7):
			if point.distance_to(face_center(battle,face)) < (36 if battle.tarot_ui.portrait() else 26):
				return {"die":selected,"face":face} if face != battle.model.dice_turn.values[selected] else {}
		return {} # Deselect the enlarged die before interacting with the dimmed controls.
	if battle.dice_selection.center_hit(point): return {"cancel":true}
	if selected < 0:
		for index in battle.model.dice_turn.unused():
			if battle.dice_selection.die_rect(index).has_point(point):
				selected = index
				break
	return {}

## Enlarge and pulse eligible dice without changing their selection hitboxes.
func advance(battle, delta: float, active: bool) -> void:
	age += delta
	for index in range(battle.dice.size()):
		battle.dice[index].magician_hint = active and index in battle.model.dice_turn.unused() and selected < 0

## Keep the selected die and its six face choices above the dimmed battlefield.
func paint(canvas: CanvasItem, battle) -> void:
	var portrait: bool = battle.tarot_ui.portrait()
	var screen: Vector2 = battle.fx.canvas_size
	Paint.text(canvas,battle.description_font,battle.DICE_CENTER+Vector2(0,12),"Cancel",42 if portrait else 30,Color("df9696"))
	if selected >= 0:
		canvas.draw_rect(Rect2(Vector2.ZERO,screen),Color(0.015,0.015,0.025,0.76))
		var at: Vector2 = selected_center(battle)
		canvas.draw_arc(at,79 if portrait else 60,0,TAU,64,Paint.GOLD,3,true)
		Art.paint_face(canvas,at,battle.model.dice_turn.values[selected],122 if portrait else 92)
		for face in range(1,7):
			var current: bool = face == battle.model.dice_turn.values[selected]
			Art.paint_face(canvas,face_center(battle,face),face,58 if portrait else 44,Color(0.35,0.35,0.35) if current else Color.WHITE)
	var destination := Vector2(screen.x*0.5,screen.y*0.25)
	var t: float = smoothstep(0,0.28,age)
	var card_at: Vector2 = origin.lerp(destination,t)
	Paint.card(canvas,"magician",card_at,Vector2(108,168)*(1 if portrait else 0.8),0,1,0.35,1)
	var prompt: String = "Choose a face. Tap the die to go back." if selected >= 0 else "Choose a die to change"
	Paint.text(canvas,battle.description_font,card_at+Vector2(0,116 if portrait else 92),prompt,26 if portrait else 20,Paint.GOLD)
