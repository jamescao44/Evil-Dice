extends RefCounted
## One source atlas for battle dice, home previews and miniature skill icons.
const SHEET = preload("res://assets/art/dice/basic_dice.png")
const CELL := 48
const FACE_COUNT := 6
const ROLL_FIRST := 6
const ROLL_COUNT := 7
const DRAW_SIDE := 144.0

## Source cells are ordered left to right: six faces, then seven rolling poses.
static func frame_rect(frame: int) -> Rect2:
	return Rect2(clampi(frame,0,FACE_COUNT+ROLL_COUNT-1)*CELL,0,CELL,CELL)

## Clip UVs to one cell so rotation and small previews cannot sample a neighbor.
static func paint_frame(canvas: CanvasItem, frame: int, destination: Rect2, color: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(SHEET,destination,frame_rect(frame),color,false,true)

## Compensate for transparent margins so existing icon sizes remain legible.
static func paint_face(canvas: CanvasItem, at: Vector2, face: int, side: float, color: Color = Color.WHITE) -> void:
	var extent: float = side*CELL/36.0
	paint_frame(canvas,clampi(face,1,FACE_COUNT)-1,Rect2(at-Vector2.ONE*extent/2,Vector2.ONE*extent),color)
