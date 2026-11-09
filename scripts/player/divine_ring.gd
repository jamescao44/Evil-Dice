extends RefCounted
## Persistent back ornament, separate from the character's cast and idle timelines.
const SHEET = preload("res://assets/art/player/diablo/divine_ring_FX.png")
const CELL := 48
const FIRST_FRAME := 2
const FRAME_COUNT := 11
const FPS := 16.0*0.7
const CENTER_UV := Vector2(0.18+0.16/3.0,0.27)
const SIZE_UV := Vector2(0.75*0.7,0.75)
const GLOW_SCALE := 0.8
const Particles = preload("res://scripts/effects/baked_particles.gd")
static var halo: GradientTexture2D
static var white_sheet: ImageTexture

## Skip the standalone first cell and loop only the supplied animation frames 2–12.
static func region(age: float) -> Rect2:
	var cell: int = FIRST_FRAME-1+posmod(floori(age*FPS),FRAME_COUNT)
	return Rect2(cell*CELL,0,CELL,CELL)

## Keep native height and 70% width, one head up and two-thirds of a head back.
static func rect_for(actor: Rect2) -> Rect2:
	var size: Vector2 = actor.size*SIZE_UV
	return Rect2(actor.position+actor.size*CENTER_UV-size/2,size)

## Cache a soft annular glow, preserving the ring's open center and crisp sprite.
static func glow_texture() -> GradientTexture2D:
	if halo == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.38,0.60,0.73,0.86,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color(1,1,1,0.18),Color(1,1,1,0.60),Color(1,1,1,0.18),Color(1,1,1,0)])
		halo = GradientTexture2D.new()
		halo.width = 128; halo.height = 128
		halo.gradient = gradient
		halo.fill = GradientTexture2D.FILL_RADIAL
		halo.fill_from = Vector2(0.5,0.5); halo.fill_to = Vector2(1,0.5)
	return halo

## Paint golden light and ring behind the body with the same invisibility/damage tint.
static func paint(canvas: CanvasItem, actor: Rect2, age: float, tint: Color = Color.WHITE, reduced: bool = false, flash: float = 0.0) -> void:
	var rect := rect_for(actor)
	var outer_size: Vector2 = rect.size*1.38*GLOW_SCALE
	var inner_size: Vector2 = rect.size*1.12*GLOW_SCALE
	canvas.draw_texture_rect(glow_texture(),Rect2(rect.get_center()-outer_size/2,outer_size),false,Color(1,0.65,0.08,0.9)*tint)
	canvas.draw_texture_rect(glow_texture(),Rect2(rect.get_center()-inner_size/2,inner_size),false,Color(1,0.85,0.28,0.75)*tint)
	canvas.draw_texture_rect_region(SHEET,rect,region(age),tint,false,true)
	paint_sparks(canvas,rect,age,tint,reduced)
	if flash > 0:
		if white_sheet == null:
			var mask: Image = SHEET.get_image()
			for y in range(mask.get_height()):
				for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
			white_sheet = ImageTexture.create_from_image(mask)
		canvas.draw_texture_rect(glow_texture(),Rect2(rect.get_center()-rect.size*0.65,rect.size*1.3),false,Color(1,1,1,flash*tint.a))
		canvas.draw_texture_rect_region(white_sheet,rect,region(age),Color(1,1,1,flash*tint.a),false,true)

## Four baked layers keep slow varied orbits and seamless outward emission loops.
static func paint_sparks(canvas: CanvasItem, rect: Rect2, age: float, tint: Color, reduced: bool) -> void:
	Particles.ring(canvas,rect,age,tint,reduced)
