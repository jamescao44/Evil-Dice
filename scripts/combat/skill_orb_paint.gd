extends RefCounted
## Shared cream shell and colored core for skill uses and multiplier energy.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")

static func paint(canvas: CanvasItem, at: Vector2, radius: float, color: Color, shiny: bool = false) -> void:
	for glow in range(3,0,-1):
		Pixel.disc(canvas,at,radius+glow*(5 if shiny else 3),Color(color,0.10 if shiny else 0.06),2)
	Pixel.disc(canvas,at,radius,Color("fff2c8") if shiny else Color("eee0b9"),2)
	Pixel.disc(canvas,at,radius*0.5,color,2)
	if shiny:
		Pixel.disc(canvas,at-Vector2.ONE*radius*0.28,radius*0.22,Color("fffff1"),2)
		var glint := at+Vector2(radius*0.62,-radius*0.65)
		Pixel.line(canvas,glint-Vector2(radius*0.35,0),glint+Vector2(radius*0.35,0),Color.WHITE,2)
		Pixel.line(canvas,glint-Vector2(0,radius*0.35),glint+Vector2(0,radius*0.35),Color.WHITE,2)
