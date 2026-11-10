extends RefCounted
## Shortcut geometry stays separate from card eligibility and casting transactions.
var ui
func phone() -> bool: return ui.portrait()
func screen() -> Vector2: return ui.battle.fx.canvas_size
func center() -> Vector2: return ui.battle.DICE_CENTER
func radius() -> float: return ui.battle.DICE_RADIUS*0.8
func step() -> float: return 0.42
func card_size(id: String) -> Vector2:
	return Vector2(50,78) if phone() else Vector2(32,50) if id == "field" else Vector2(40,62)

func row_center() -> Vector2:
	return center()+Vector2(0,-320 if phone() else -172)
func left_center() -> Vector2:
	return Vector2(98 if phone() else center().x-ui.battle.DICE_RADIUS-126,center().y)
func right_center() -> Vector2:
	return Vector2(screen().x-30 if phone() else screen().x-45,center().y)
func expanded_center() -> Vector2: return Vector2(screen().x*0.5,screen().y*0.58)
func expanded_size() -> Vector2: return Vector2(112,174) if phone() else Vector2(86,133)

## Only the top row clips at the dice boundary, so it slides underneath when hidden.
func clip_rect(id: String) -> Rect2:
	if id != "field": return Rect2(Vector2.ZERO,screen())
	var y: float = row_center().y-180 if phone() else row_center().y-130
	return Rect2(Vector2(0,y),Vector2(screen().x,center().y-ui.battle.DICE_RADIUS+12-y))

func lane_rect(id: String) -> Rect2:
	if id == "field": return Rect2(row_center()-Vector2(202,55),Vector2(404,110)) if phone() else Rect2(row_center()-Vector2(150,38),Vector2(300,76))
	if id == "now": return Rect2(left_center()-Vector2(96,radius()+45),Vector2(192,radius()*2+90))
	return Rect2(right_center()-Vector2(38,120),Vector2(76,240))

## A generous fixed band lets fingers scrub sideways without accidentally casting.
func field_zone() -> Rect2:
	return Rect2(row_center()-Vector2(270,72),Vector2(540,144)) if phone() else Rect2(row_center()-Vector2(202,48),Vector2(404,96))

## Enlarging one card creates real horizontal room rather than covering its neighbors.
func field_position(index: int) -> Vector2:
	var cards: Array = ui.lanes.field.display
	var sizes: Array = cards.map(func(card): return card_size("field").x*field_scale(card.instance_id))
	var gap: float = 7
	var total: float = gap*maxi(0,cards.size()-1)
	for width in sizes: total += width
	var x: float = -total/2
	for i in range(index): x += sizes[i]+gap
	return row_center()+Vector2(x+sizes[index]/2,0)

func field_scale(instance: int) -> float:
	return lerpf(1.0,2.1,smoothstep(0,1,ui.field_lifts.get(instance,0.0)))

## Stable per-card phases and mixed frequencies add variety without using gameplay RNG.
func idle_motion(card_id: String) -> Vector3:
	var seed: float = float(card_id.hash() & 65535)/65535.0
	var phase: float = seed*TAU
	var t: float = ui.clock
	var bob: float = sin(t*(2.05+seed*0.9)+phase)*(3.5+seed*1.5)+sin(t*1.17+phase*2)*1.4
	var sway: float = sin(t*(1.5+seed*0.7)+phase)*0.09+sin(t*0.83+phase*3)*0.025
	return Vector3(bob,sway,0.55+0.12*sin(t*(2.0+seed)+phase))

## A cyclic arc wraps only where cards are transparent, never popping in the middle.
func offset(index: int, count: int) -> float:
	return wrapf(index-ui.lanes.now.swipe.position,-count/2.0,count/2.0) if count > 1 else 0.0

func pose(id: String, index: int) -> Dictionary:
	var state: Dictionary = ui.lanes[id]
	var count: int = state.display.size()
	var relative: float = index-(count-1)*0.5
	var size: Vector2 = card_size(id)
	var at: Vector2
	var angle := 0.0
	var alpha := 1.0
	var brightness := 1.0
	if id == "field":
		at = field_position(index)
		# Neighbor dimming follows the same enlargement tween, including when focus changes.
		var other_lift := 0.0
		for card in state.display:
			if card.instance_id != state.display[index].instance_id:
				other_lift = maxf(other_lift,smoothstep(0,1,ui.field_lifts.get(card.instance_id,0.0)))
		brightness = lerpf(1.0,0.45,other_lift)
		var scale: float = field_scale(state.display[index].instance_id)
		size *= scale
		at.y -= (size.y-card_size(id).y)*0.5
	elif id == "now":
		var off: float = offset(index,count)
		var theta: float = off*step()
		at = left_center()+Vector2((cos(theta)-1)*radius(),sin(theta)*radius())
		angle = -theta*0.22
		if count > 1: alpha = clampf((count/2.0-absf(off))/0.38,0,1)
	else:
		at = right_center()+Vector2(0,relative*(41 if phone() else 32))
		var expansion: float = smoothstep(0,1,ui.next_expansion)
		brightness = lerpf(0.72,1.0,expansion)
		at = at.lerp(expanded_center()+Vector2(relative*(132 if phone() else 106),0),expansion)
		size = size.lerp(expanded_size(),expansion)
	var item: Dictionary = state.display[index]
	var motion: Vector3 = idle_motion(item.id)
	var still: float = smoothstep(0,1,ui.field_lifts.get(item.instance_id,0.0)) if id == "field" else 0.0
	if not ui.battle.reduced:
		at.y += motion.x*(1-still)
		angle += motion.y*(1-still)
	var visible: float = smoothstep(0,1,state.visibility)
	if id == "field": at.y += (1-visible)*(165 if phone() else 105)
	else: at.x += (1-visible)*(-screen().x*0.55 if id == "now" else screen().x*0.55)
	alpha *= visible
	var enabled: bool = ui.lane_enabled(id)
	return {"at":at,"size":size,"angle":angle,"alpha":alpha,"glow":motion.z*(1.0 if enabled else 0.15),"brightness":brightness*(1.0 if enabled else 0.35)}

