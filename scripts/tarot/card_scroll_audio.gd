extends RefCounted
## One quiet tick per crossed card; fast flicks never queue a burst of overlapping sounds.
var previous := 0
var initialized := false
var last_click := -1000
const MIN_INTERVAL_MS := 65

func update(position: float, moving: bool, stamp: int = Time.get_ticks_msec()) -> bool:
	var current: int = roundi(position)
	var crossed: bool = initialized and current != previous
	previous = current
	initialized = true
	if not moving or not crossed or stamp-last_click < MIN_INTERVAL_MS: return false
	last_click = stamp
	return true

func reset(position: float = 0) -> void:
	previous = roundi(position)
	initialized = true
