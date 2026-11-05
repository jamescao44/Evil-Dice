extends RefCounted
## Lower skills flash together; higher skills charge backward without delaying confirmation.
const LINK_SECONDS := 0.17
const FLASH_SECONDS := 0.36
var order: Array = []
var color := Color.WHITE
var age: float = 0.0
var signature: Array = []
var travels: bool = false

## A different valid selection restarts at its last die; preview polling does not replay it.
func sync(indices: Array, skill_faces: Array, skill_color: Color, valid: bool) -> void:
	if not valid or indices.size() < 2:
		clear()
		return
	var next: Array = [indices,skill_faces,skill_color]
	if signature == next: return
	signature = next.duplicate(true)
	order = indices.duplicate()
	color = skill_color
	travels = skill_faces.size() >= 5
	age = 0.0

## Invalid combinations, cancellation and rerolls return every connection to neutral.
func clear() -> void:
	order.clear()
	signature.clear()
	color = Color.WHITE
	travels = false
	age = 0.0

## Reduced effects apply the final colors immediately without traveling flashes.
func advance(delta: float, reduced: bool) -> void:
	var end: float = (maxf(0,order.size()-1)*LINK_SECONDS if travels else 0.0)+FLASH_SECONDS
	age = end if reduced else minf(end,age+maxf(0,delta))

## Segment zero joins the first two dice; color fills each segment from its later endpoint.
func segment_fill(segment: int) -> float:
	if segment < 0 or segment >= order.size()-1: return 0.0
	if not travels: return 1.0
	return clampf(age/LINK_SECONDS-(order.size()-2-segment),0,1)

func arrival_time(index: int) -> float:
	var position: int = order.find(index)
	if position < 0: return INF
	return (order.size()-1-position)*LINK_SECONDS if travels else 0.0

func reached(index: int) -> bool:
	return age >= arrival_time(index)

## A white-hot arrival decays into the persistent skill-colored die halo.
func flash(index: int) -> float:
	var arrival: float = arrival_time(index)
	if age < arrival or age >= arrival+FLASH_SECONDS: return 0.0
	return pow(1.0-(age-arrival)/FLASH_SECONDS,2)

func die_color(index: int) -> Color:
	return color if reached(index) else Color.WHITE
