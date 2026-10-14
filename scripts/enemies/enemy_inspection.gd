extends Node2D
## Hold-only move and status inspection, above dice and combat effects.
const Paint = preload("res://scripts/status/status_paint.gd")
const Statuses = preload("res://scripts/status/status_catalog.gd")
var battle

func _ready() -> void:
	z_index = 300

func _process(_delta: float) -> void:
	queue_redraw()

func focus_rect(index: int) -> Rect2:
	var side: float = battle._enemy_side()
	var feet: Vector2 = battle._enemy_feet(index)
	var sprite := Rect2(feet-Vector2(side*0.64,side*1.25),Vector2(side*1.28,side*1.3))
	var health: Rect2 = battle._enemy_health_rect(index)
	if not status_rows(index).is_empty(): health.size.y += 36 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 26
	return sprite.merge(battle._enemy_intent_rect(index)).merge(health).grow(6).intersection(Rect2(Vector2.ZERO,battle.fx.canvas_size))

func status_rows(index: int) -> Array:
	return Statuses.enemy_active(battle.model.enemies[index])

func card_rect(index: int) -> Rect2:
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var width: float = 680 if portrait else 440
	var font_size: int = 30 if portrait else 22
	var inset: float = 24 if portrait else 18
	var data: Dictionary = battle._enemy_intent_data(index)
	var lines := GameText.lines(data.get("description",""),battle.description_font,font_size,width-inset*2)
	var size := Vector2(width,(96 if portrait else 77)+lines.size()*(font_size+8))
	size.y += (56 if portrait else 42)+maxi(1,status_rows(index).size())*(52 if portrait else 38)
	var focus: Rect2 = focus_rect(index)
	var x: float = clampf(focus.get_center().x-size.x/2,20,battle.fx.canvas_size.x-size.x-20)
	var y: float = minf(focus.end.y+20,battle.fx.canvas_size.y-size.y-20)
	if Rect2(Vector2(x,y),size).intersects(focus):
		if focus.position.x-size.x-20 >= 20: x = focus.position.x-size.x-20
		elif focus.end.x+size.x+40 <= battle.fx.canvas_size.x: x = focus.end.x+20
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
	_draw_statuses(index,card,y+10,inset,portrait)

func _draw_statuses(index: int, card: Rect2, top: float, inset: float, portrait: bool) -> void:
	var left: float = card.position.x+inset
	var right: float = card.end.x-inset
	draw_line(Vector2(left,top),Vector2(right,top),Color(battle.CREAM,0.2),2)
	var y: float = top+(34 if portrait else 26)
	draw_string(battle.description_font,Vector2(left,y),GameText.text("BUFFS & STATUS EFFECTS"),HORIZONTAL_ALIGNMENT_LEFT,-1,24 if portrait else 18,battle.MUTED)
	var items: Array = status_rows(index)
	var size: int = 28 if portrait else 20
	var step: float = 52 if portrait else 38
	if items.is_empty():
		draw_string(battle.description_font,Vector2(left,y+step),GameText.text("No active buffs or status effects."),HORIZONTAL_ALIGNMENT_LEFT,-1,size,battle.CREAM)
		return
	for item in items:
		y += step
		Paint.icon(self,Vector2(left+14,y-10),14 if portrait else 11,item.icon,item.color)
		draw_string(battle.description_font,Vector2(left+40,y),GameText.text(item.name),HORIZONTAL_ALIGNMENT_LEFT,-1,size,item.color)
		var counter: String = Statuses.counter_text(item)
		var width: float = battle.description_font.get_string_size(counter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		draw_string(battle.description_font,Vector2(right-width,y),counter,HORIZONTAL_ALIGNMENT_LEFT,-1,size,battle.CREAM)
