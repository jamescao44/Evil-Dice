extends RefCounted
## Stable enemy formations reserve separate lanes for heads, intents and health.

## Keep portrait front ranks beside the player and landscape ranks interleaved.
static func feet(arena: Rect2, index: int, count: int, side: float, portrait: bool) -> Vector2:
	if portrait:
		if count == 1: return Vector2(530,620)
		if count <= 3:
			return Vector2(486+(index-(count-1)/2.0)*maxf(144,side+20),530)
		# Four across fits the larger six-enemy wave and leaves only two in front.
		var cols: int = 2 if count == 4 else 3 if count == 5 else 4
		var row: int = index/cols
		var in_row: int = mini(cols,count-row*cols)
		var step: float = maxf(112,side+20)
		var center: float = 414 if row == 0 else 560
		center = minf(center,arena.end.x-18-side/2-(in_row-1)*step/2)
		var top: float = arena.position.y+side+100
		return Vector2(center+(index%cols-(in_row-1)/2.0)*step,top+row*maxf(180,side+124))
	if count == 1: return Vector2(856,384)
	var step: float = maxf(132,side+28)
	if count <= mini(5,floori(780/step)):
		return Vector2(824+(index-(count-1)/2.0)*step,380)
	# Alternate rows horizontally so a lower intent sits in a gap, never on a face.
	var cols: int = ceili(count/2.0)
	var row: int = index/cols
	step = maxf(140,side+88)
	var extra: float = step/2 if count%2 == 0 else 0
	var left: float = 824-((cols-1)*step+extra)/2
	var top: float = maxf(270,arena.position.y+side+80)
	return Vector2(left+(index%cols)*step+row*step/2,top if row == 0 else 400)
