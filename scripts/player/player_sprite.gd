extends RefCounted
## James's intact 64px atlas, numbered left-to-right and then top-to-bottom.
const SHEET = preload("res://assets/art/player/diablo/diablo_3.png")
const DivineRing = preload("res://scripts/player/divine_ring.gd")
const CELL := 64
const COLUMNS := 20
const FRAME_COUNT := 109
const IDLE_FPS := 10.0
const WALK_FPS := 14.0
const REST_BOUNDS := Rect2(0,1.0/64,59.0/64,63.0/64)
static var white_sheet: Texture2D
static var frames: Dictionary = {}

## Public frame numbers match the artist's one-based ranges.
static func region(frame_number: int) -> Rect2:
	var cell: int = clampi(frame_number,1,FRAME_COUNT)-1
	return Rect2((cell%COLUMNS)*CELL,(cell/COLUMNS)*CELL,CELL,CELL)

## Preview textures retain a single cell so callers never squeeze the whole atlas.
static func texture(frame_number: int = 1) -> AtlasTexture:
	frame_number = clampi(frame_number,1,FRAME_COUNT)
	if frames.has(frame_number): return frames[frame_number]
	var result := AtlasTexture.new()
	result.atlas = SHEET
	result.region = region(frame_number)
	result.filter_clip = true
	frames[frame_number] = result
	return result

## Build one reusable alpha silhouette for evolution flashes across every animation.
static func silhouette() -> Texture2D:
	if white_sheet != null: return white_sheet
	var mask: Image = SHEET.get_image()
	for y in range(mask.get_height()):
		for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
	white_sheet = ImageTexture.create_from_image(mask)
	return white_sheet

## Draw a bounded cell without sampling its neighboring frames.
static func paint(canvas: CanvasItem, rect: Rect2, frame_number: int, tint: Color = Color.WHITE, white: bool = false) -> void:
	canvas.draw_texture_rect_region(silhouette() if white else SHEET,rect,region(frame_number),tint,false,true)

## Share the same rear-ring layering in battle, Home and character previews.
static func paint_actor(canvas: CanvasItem, rect: Rect2, frame_number: int, age: float, tint: Color = Color.WHITE, reduced: bool = false) -> void:
	DivineRing.paint(canvas,rect,age,tint,reduced)
	paint(canvas,rect,frame_number,tint)

## Home and help use the same seven-frame idle loop as the battlefield.
static func idle_frame(age: float) -> int:
	return 1+posmod(floori(age*IDLE_FPS),7)
