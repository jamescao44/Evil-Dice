extends RefCounted
## Presentation clocks for selectable-die waves and descending matching hints.
const WAVE_PERIOD := 2.0
const HINT_DURATION := 1.15
const GROUP_GAP := 0.15
const CYCLE_REST := 0.65
var wave_age: float = 0.0
var hint_age: float = 0.0
var groups: Array = []
var signature: Array = []
var active: bool = false
var animate_hints: bool = false

## Cache matching groups only when the available faces change; never move hitboxes.
func advance(delta: float, pool, enabled: bool, reduced: bool) -> void:
	active = enabled and pool.active and pool.rolls_left < pool.ROLLS and not pool.has_pending_group()
	animate_hints = active and pool.selected.is_empty() and not reduced
	if not active:
		wave_age = 0
		hint_age = 0
		signature.clear()
		return
	wave_age = fmod(wave_age+delta,WAVE_PERIOD)
	var next_signature: Array = [pool.values,pool.locked,pool.rolls_left]
	if signature != next_signature:
		signature = next_signature.duplicate(true)
		groups.clear()
		var unused: Array = pool.unused()
		for face in range(6,0,-1):
			var group: Array = unused.filter(func(index): return pool.values[index] == face)
			if group.size() >= 2: groups.append(group)
		hint_age = 0
	if not animate_hints or groups.is_empty(): hint_age = 0
	else: hint_age = fmod(hint_age+delta,CYCLE_REST+groups.size()*(HINT_DURATION+GROUP_GAP))

## Each matching group grows gently and rocks twice before the next lower face.
func hint_pose(index: int) -> Vector2:
	if not animate_hints or groups.is_empty() or hint_age < CYCLE_REST: return Vector2.ZERO
	var slot: int = floori((hint_age-CYCLE_REST)/(HINT_DURATION+GROUP_GAP))
	var age: float = fmod(hint_age-CYCLE_REST,HINT_DURATION+GROUP_GAP)
	if slot >= groups.size() or index not in groups[slot] or age >= HINT_DURATION: return Vector2.ZERO
	var t: float = age/HINT_DURATION
	var envelope: float = smoothstep(0.0,0.18,t)*(1.0-smoothstep(0.80,1.0,t))
	return Vector2(0.10*envelope,sin(t*TAU*2)*0.12*envelope)
