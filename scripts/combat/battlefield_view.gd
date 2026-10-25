extends RefCounted
## One camera projection for terrain, characters, touch targets and world effects.
const ENTER_TIME := 0.16
const EXIT_TIME := 0.19
var transform := Transform2D.IDENTITY
var zoom: float = 1.0
var focused: bool = false
var _from := Transform2D.IDENTITY
var _to := Transform2D.IDENTITY
var _age: float = 0.0
var _duration: float = ENTER_TIME

## Center the living formation and reserve room for its scaled head indicators.
static func focus_transform(arena: Rect2, bounds: Rect2, portrait: bool, enemy_size: float) -> Transform2D:
	if not bounds.has_area(): return Transform2D.IDENTITY
	var big: float = smoothstep(80,180,enemy_size)
	var cap: float = lerpf(1.85 if portrait else 1.65,1.10,big)
	var headroom: float = 84 if portrait else 64
	var magnification: float = clampf(minf((arena.size.x-56)/bounds.size.x,(arena.size.y-24)/(bounds.size.y+headroom*2)),1.0,cap)
	# Center the formation itself; padded terrain permits panning at a gentle zoom.
	var offset: Vector2 = arena.get_center()-bounds.get_center()*magnification
	return Transform2D(0,Vector2.ONE*magnification,0,offset)

## Return immediately after target commitment, without waiting for the skill to finish.
func advance(delta: float, requested: bool, arena: Rect2, bounds: Rect2, portrait: bool, enemy_size: float, rest: Transform2D = Transform2D.IDENTITY) -> void:
	var destination: Transform2D = focus_transform(arena,bounds,portrait,enemy_size) if requested else rest
	if rest != Transform2D.IDENTITY and requested:
		# A giant boss is already framed; avoid cropping it on target selection.
		destination = rest
	if requested != focused or not destination.is_equal_approx(_to):
		focused = requested
		_from = transform
		_to = destination
		_duration = ENTER_TIME if focused else EXIT_TIME
		_age = 0
	_age = minf(_duration,_age+delta)
	transform = _from.interpolate_with(_to,smoothstep(0,1,_age/_duration))
	zoom = transform.get_scale().x

## Share the scenery's easing with enemies entering from beyond the right edge.
static func entrance_offset(arena: Rect2, progress: float) -> float:
	return (arena.size.x+128)*(1-clampf(progress,0,1))

## The upward arrow advances diagonally; the right arrow keeps horizontal travel.
static func route_direction(index: int) -> Vector2:
	return Vector2(1,-0.6) if index == 1 else Vector2.RIGHT

## Ease formations along the same direction as the scenery, ending exactly in place.
static func entrance_translation(arena: Rect2, progress: float, direction: Vector2) -> Vector2:
	return direction*entrance_offset(arena,progress)

## Drop stale focus immediately when a new run or debug wave is loaded.
func reset() -> void:
	transform = Transform2D.IDENTITY
	zoom = 1
	focused = false
	_from = transform
	_to = transform
	_age = 0
