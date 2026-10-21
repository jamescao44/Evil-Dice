extends RefCounted
## Presentation clocks for selectable-die waves and available straight hints.
const WAVE_PERIOD := 2.0
const HINT_DURATION := 1.15
const GROUP_GAP := 0.15
const CYCLE_REST := 0.65
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
var wave_age: float = 0.0
var hint_age: float = 0.0
var groups: Array = []
var ring_indices: Array = []
var ring_signature: Array = []
var signature: Array = []
var active: bool = false
var animate_hints: bool = false

## Cache only the longest available straights when faces change; never move hitboxes.
func advance(delta: float, pool, enabled: bool, reduced: bool) -> void:
	active = enabled and pool.active and pool.rolls_left < pool.ROLLS and not pool.has_pending_group()
	animate_hints = active and pool.selected.is_empty() and not reduced
	if not active:
		wave_age = 0
		hint_age = 0
		signature.clear()
		ring_indices.clear()
		ring_signature.clear()
		return
	wave_age = fmod(wave_age+delta,WAVE_PERIOD)
	var next_signature: Array = [pool.values,pool.locked,pool.rolls_left]
	if signature != next_signature:
		signature = next_signature.duplicate(true)
		groups = longest_straights(pool.values,pool.unused())
		hint_age = 0
	var next_ring_signature: Array = [next_signature,pool.selected]
	if ring_signature != next_ring_signature:
		ring_signature = next_ring_signature.duplicate(true)
		ring_indices = combination_indices(pool.values,pool.unused(),pool.selected)
	if not animate_hints or groups.is_empty(): hint_age = 0
	else: hint_age = fmod(hint_age+delta,CYCLE_REST+groups.size()*(HINT_DURATION+GROUP_GAP))

## Ring only dice that belong to a usable straight compatible with the current selection.
static func combination_indices(values: Array, unused: Array, selected: Array = []) -> Array:
	var available: Array = unused.map(func(index): return values[index])
	return unused.filter(func(index):
		var selection: Array = selected.map(func(i): return values[i])
		if index not in selected: selection.append(values[index])
		return Patterns.can_extend(selection,available))

## Retain every physical-dice alternative at the maximum length, excluding shorter subsets.
static func longest_straights(values: Array, unused: Array) -> Array:
	for length in range(6,2,-1):
		var longest: Array = []
		for first in range(7-length,0,-1):
			var alternatives: Array = [[]]
			for face in range(first,first+length):
				var candidates: Array = unused.filter(func(index): return values[index] == face)
				var extended: Array = []
				for group in alternatives:
					for index in candidates: extended.append(group+[index])
				alternatives = extended
				if alternatives.is_empty(): break
			longest.append_array(alternatives)
		if not longest.is_empty(): return longest
	return []

## Each available straight grows gently and rocks twice before the next hint.
func hint_pose(index: int) -> Vector2:
	if not animate_hints or groups.is_empty() or hint_age < CYCLE_REST: return Vector2.ZERO
	var slot: int = floori((hint_age-CYCLE_REST)/(HINT_DURATION+GROUP_GAP))
	var age: float = fmod(hint_age-CYCLE_REST,HINT_DURATION+GROUP_GAP)
	if slot >= groups.size() or index not in groups[slot] or age >= HINT_DURATION: return Vector2.ZERO
	var t: float = age/HINT_DURATION
	var envelope: float = smoothstep(0.0,0.18,t)*(1.0-smoothstep(0.80,1.0,t))
	return Vector2(0.10*envelope,sin(t*TAU*2)*0.12*envelope)
