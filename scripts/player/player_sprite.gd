extends RefCounted
## James's intact 64px atlas, numbered left-to-right and then top-to-bottom.
const SHEET = preload("res://assets/art/player/diablo/diablo_3.png")
const EARLY_SHEET = preload("res://assets/art/player/diablo/diablo_2.png")
const DivineRing = preload("res://scripts/player/divine_ring.gd")
const CELL := 64
const COLUMNS := 20
const FRAME_COUNT := 133
const EARLY_FRAME_COUNT := 64
const IDLE_FPS := 10.0
const REST_BOUNDS := Rect2(0,1.0/64,59.0/64,63.0/64)
const EARLY_REST_BOUNDS := Rect2(17.0/64,18.0/64,39.0/64,33.0/64)
static var white_sheets: Dictionary = {}
static var frames: Dictionary = {}

## Public frame numbers match the artist's one-based ranges.
static func region(frame_number: int, form: int = 2) -> Rect2:
	var cell: int = clampi(frame_number,1,FRAME_COUNT if form >= 2 else EARLY_FRAME_COUNT)-1
	return Rect2((cell%COLUMNS)*CELL,(cell/COLUMNS)*CELL,CELL,CELL)

## The second sheet temporarily supplies both early forms; only the final form has a ring.
static func sheet(form: int) -> Texture2D:
	return SHEET if form >= 2 else EARLY_SHEET

static func has_divine_ring(form: int) -> bool:
	return form >= 2

static func rest_bounds(form: int) -> Rect2:
	return REST_BOUNDS if form >= 2 else EARLY_REST_BOUNDS

## Remove the early sheet's bottom padding so every form shares the same ground line.
static func grounded_rect(rect: Rect2, form: int) -> Rect2:
	return Rect2(rect.position+Vector2(0,rect.size.y*(1.0-rest_bounds(form).end.y)),rect.size)

## Preview textures retain a single cell so callers never squeeze the whole atlas.
static func texture(frame_number: int = 1, form: int = 2) -> AtlasTexture:
	frame_number = clampi(frame_number,1,FRAME_COUNT if form >= 2 else EARLY_FRAME_COUNT)
	var key := Vector2i(2 if form >= 2 else 0,frame_number)
	if frames.has(key): return frames[key]
	var result := AtlasTexture.new()
	result.atlas = sheet(form)
	result.region = region(frame_number,form)
	result.filter_clip = true
	frames[key] = result
	return result

## Build one reusable alpha silhouette for evolution flashes across every animation.
static func silhouette(form: int = 2) -> Texture2D:
	var key: int = 2 if form >= 2 else 0
	if white_sheets.has(key): return white_sheets[key]
	var mask: Image = sheet(form).get_image()
	for y in range(mask.get_height()):
		for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
	white_sheets[key] = ImageTexture.create_from_image(mask)
	return white_sheets[key]

## Draw a bounded cell without sampling its neighboring frames.
static func paint(canvas: CanvasItem, rect: Rect2, frame_number: int, tint: Color = Color.WHITE, white: bool = false, form: int = 2) -> void:
	canvas.draw_texture_rect_region(silhouette(form) if white else sheet(form),rect,region(frame_number,form),tint,false,true)

## Keep the rear ring on its resting rectangle while the body can squash independently.
static func paint_actor(canvas: CanvasItem, rect: Rect2, frame_number: int, age: float, tint: Color = Color.WHITE, reduced: bool = false, form: int = 2, body_rect: Rect2 = Rect2()) -> void:
	if has_divine_ring(form): DivineRing.paint(canvas,rect,age,tint,reduced)
	paint(canvas,body_rect if body_rect.has_area() else rect,frame_number,tint,false,form)

## Home and help use the same seven-frame idle loop as the battlefield.
static func idle_frame(age: float, form: int = 2) -> int:
	return (1 if form >= 2 else 2)+posmod(floori(age*IDLE_FPS),7)
