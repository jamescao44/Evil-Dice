extends Node2D
const Paint = preload("res://scripts/status_paint.gd")
var battle

func _ready() -> void:
	z_index = 35

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(battle) or not battle.model.is_frozen() or battle._menus_open() or battle.view_phase in ["over","reward"]: return
	var radius: float = battle.DICE_RADIUS+8
	var at: Vector2 = battle.DICE_CENTER
	var cracks: int = 3-battle.model.ice_hits_remaining if battle.model.phase == "frozen" else 0
	Paint.ice(self,battle._ice_rect(),true,cracks)
	Paint.icon(self,at-Vector2(0,radius*0.54),radius*0.18,"ice",Color("d2f6ff"))
	var text: String = GameText.format("TAP ICE - %d LEFT", battle.model.ice_hits_remaining) if battle.model.phase == "frozen" else GameText.text("FROZEN")
	var size: int = 26 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 16
	var width: float = battle.pixel_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var base: Vector2 = at+Vector2(-width/2,radius*0.65)
	draw_string_outline(battle.pixel_font,base,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,5,Color("163246"))
	draw_string(battle.pixel_font,base,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("d2f6ff"))
