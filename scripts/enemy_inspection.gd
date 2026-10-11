extends Node2D
## Hold-only move inspection, above dice, skill bubbles and combat effects.
const Paint = preload("res://scripts/status_paint.gd")
var battle

func _ready() -> void:
	z_index = 90

func _process(_delta: float) -> void:
	queue_redraw()

func focus_rect(index: int) -> Rect2:
	var side: float = battle._enemy_side()
	var feet: Vector2 = battle._enemy_feet(index)
	var sprite := Rect2(feet-Vector2(side*0.64,side*1.25),Vector2(side*1.28,side*1.3))
	return sprite.merge(battle._enemy_intent_rect(index)).merge(battle._enemy_health_rect(index)).grow(6).intersection(Rect2(Vector2.ZERO,battle.fx.canvas_size))

func card_rect(index: int) -> Rect2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var width: float = 680 if portrait else 440
	var font_size: int = 30 if portrait else 22
	var inset: float = 24 if portrait else 18
	var data: Dictionary = battle._enemy_intent_data(index)
	var lines := GameText.lines(data.get("description",""),battle.description_font,font_size,width-inset*2)
	var size := Vector2(width,(96 if portrait else 77)+lines.size()*(font_size+8))
	var focus: Rect2 = focus_rect(index)
	var x: float = clampf(focus.get_center().x-size.x/2,20,battle.fx.canvas_size.x-size.x-20)
	var y: float = minf(focus.end.y+20,battle.fx.canvas_size.y-size.y-20)
	return Rect2(Vector2(x,y),size)

func _draw() -> void:
	if not is_instance_valid(battle) or battle.inspecting_enemy < 0 or not battle._can_inspect_enemy(): return
	var index: int = battle.inspecting_enemy
	var data: Dictionary = battle._enemy_intent_data(index)
	if data.is_empty(): return
	var focus: Rect2 = focus_rect(index)
	var canvas: Vector2 = battle.fx.canvas_size
	var shade := Color(0.025,0.035,0.045,0.78)
	# Leave the inspected enemy bright while shading every other UI layer.
	draw_rect(Rect2(0,0,canvas.x,focus.position.y),shade)
	draw_rect(Rect2(0,focus.end.y,canvas.x,canvas.y-focus.end.y),shade)
	draw_rect(Rect2(0,focus.position.y,focus.position.x,focus.size.y),shade)
	draw_rect(Rect2(focus.end.x,focus.position.y,canvas.x-focus.end.x,focus.size.y),shade)
	draw_rect(focus,Color(data.color,0.65),false,2)
	var card: Rect2 = card_rect(index)
	var portrait: bool = canvas.y > canvas.x
	draw_rect(card,Color("202723"))
	draw_rect(card,data.color,false,2)
	var inset: float = 24 if portrait else 18
	var title_y: float = 44 if portrait else 34
	Paint.intent_icon(self,card.position+Vector2(inset+12,title_y-10),12,data.icon,data.color)
	draw_string(battle.pixel_font,card.position+Vector2(inset+40,title_y),GameText.text(data.name),HORIZONTAL_ALIGNMENT_LEFT,-1,28 if portrait else 20,data.color)
	var font_size: int = 30 if portrait else 22
	var y: float = card.position.y+(86 if portrait else 67)
	for line in GameText.lines(data.description,battle.description_font,font_size,card.size.x-inset*2):
		draw_string(battle.description_font,Vector2(card.position.x+inset,y),line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,battle.CREAM)
		y += font_size+8
