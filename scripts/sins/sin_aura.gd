extends RefCounted
## Cached sprite contours expand in sin-colored echoes, without individual particles.
const Sprite = preload("res://scripts/player/player_sprite.gd")
const PERIOD := 3.0
const STAGGER := 0.3
const DURATION := 1.1
const EXPANSION := 0.45
const NEIGHBORS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
static var sheets: Dictionary = {}
static var outlines: Dictionary = {}

## Every sin repeats on the same three-second clock, with its own delayed start.
static func pulse_age(time: float, index: int) -> float:
	return fposmod(time-index*STAGGER,PERIOD)

## Cache only the alpha boundary of an authored frame; colors never fill the silhouette.
static func outline(form: int, frame: int) -> Texture2D:
	var key := Vector2i(form,frame)
	if outlines.has(key): return outlines[key]
	if not sheets.has(form): sheets[form] = Sprite.sheet(form).get_image()
	var source: Image = sheets[form].get_region(Rect2i(Sprite.region(frame,form)))
	var mask := Image.create(Sprite.CELL,Sprite.CELL,false,Image.FORMAT_RGBA8)
	for y in range(Sprite.CELL):
		for x in range(Sprite.CELL):
			if source.get_pixel(x,y).a < 0.1: continue
			var edge := false
			for offset in NEIGHBORS:
				var next: Vector2i = Vector2i(x,y)+offset
				if next.x < 0 or next.y < 0 or next.x >= Sprite.CELL or next.y >= Sprite.CELL or source.get_pixelv(next).a < 0.1:
					edge = true
					break
			if edge: mask.set_pixel(x,y,Color.WHITE)
	outlines[key] = ImageTexture.create_from_image(mask)
	return outlines[key]

## Scale around the feet, cropping transparent atlas padding and any pixels below the ground.
static func paint(canvas: CanvasItem, rect: Rect2, form: int, frame: int, colors: Array, time: float) -> void:
	if colors.is_empty(): return
	var texture: Texture2D = outline(form,frame)
	var ground: Vector2 = Sprite.ground_anchor(rect,form)
	var source := Rect2(0,0,Sprite.CELL,Sprite.CELL*Sprite.rest_bounds(form).end.y)
	# Older, wider echoes go behind the more recent contours.
	for index in range(colors.size()):
		var age: float = pulse_age(time,index)
		if age >= DURATION: continue
		var progress: float = age/DURATION
		var growth: float = 1.0+EXPANSION*(1-pow(1-progress,2))
		var alpha: float = smoothstep(0,0.10,age)*(1-smoothstep(0.15,DURATION,age))*0.9
		var expanded := Rect2(ground+(rect.position-ground)*growth,rect.size*growth)
		expanded.size.y = ground.y-expanded.position.y
		canvas.draw_texture_rect_region(texture,expanded,source,Color(colors[index],alpha),false,true)
