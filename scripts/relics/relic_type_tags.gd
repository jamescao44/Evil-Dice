extends RefCounted
## Shared type badges use actual fusion ingredients and wrap inside their caller's text band.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
static var style: StyleBoxFlat

## Stable type order and counts match collection rules without exposing awakening conditions.
static func labels(item: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var counts: Dictionary = Catalog.Types.stacks(item,Catalog.ITEMS)
	for kind in Catalog.Types.NAMES:
		if counts.get(kind,0) > 0:
			result.append(GameText.text(Catalog.Types.NAMES[kind])+(" ×%d" % counts[kind] if counts[kind] > 1 else ""))
	if result.is_empty(): result.append(GameText.text("Untyped"))
	return result

## Center each row independently; narrow chest columns shrink only an oversized badge.
static func layout(item: Dictionary, font: Font, width: float, size: int, centered: bool = true) -> Array:
	var rows: Array = []
	var row: Array = []
	var x := 0.0
	var y := 0.0
	var height := 0.0
	for label in labels(item):
		var point_size: int = size
		while point_size > 10 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x+16 > width: point_size -= 1
		var extent := Vector2(font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x+16,font.get_height(point_size)+8)
		if x > 0 and x+extent.x > width:
			rows.append({"tags":row,"width":x-6,"height":height})
			row = []; x = 0; height = 0
		row.append({"text":label,"size":point_size,"rect":Rect2(x,0,extent.x,extent.y)})
		x += extent.x+6
		height = maxf(height,extent.y)
	if not row.is_empty(): rows.append({"tags":row,"width":x-6,"height":height})
	var result: Array = []
	for line in rows:
		for tag in line.tags:
			tag.rect.position += Vector2((width-line.width)*0.5 if centered else 0,y)
			result.append(tag)
		y += line.height+6
	return result

static func height(item: Dictionary, font: Font, width: float, size: int) -> float:
	var bottom := 0.0
	for tag in layout(item,font,width,size): bottom = maxf(bottom,tag.rect.end.y)
	return bottom

## Rounded muted boxes keep type distinct from rarity colors and effect descriptions.
static func paint(canvas: CanvasItem, item: Dictionary, font: Font, at: Vector2, width: float, size: int, centered: bool = true) -> float:
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = Color("25302e")
		style.border_color = Color("857e68")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.corner_detail = 5
	var bottom: float = at.y
	for tag in layout(item,font,width,size,centered):
		var rect: Rect2 = tag.rect
		rect.position += at
		canvas.draw_style_box(style,rect)
		canvas.draw_string(font,rect.position+Vector2(8,4+font.get_ascent(tag.size)),tag.text,HORIZONTAL_ALIGNMENT_LEFT,-1,tag.size,Color("eee5ce"))
		bottom = maxf(bottom,rect.end.y)
	return bottom
