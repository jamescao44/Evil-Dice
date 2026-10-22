extends RefCounted
## Six physical dice and their roll budget, independent of skills and presentation.
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const COUNT := 6
const ROLLS := 3
var active: bool = false
var values: Array = [1, 2, 3, 4, 5, 6]
var locked: Array = []
var selected: Array = []
var groups: Array = []
var committed: Array = []
var rolls_left: int = ROLLS
var rolls_made: int = 0
var last_perfect: bool = false
var turn_id: int = 0

## Start a turn with six unused dice and three available throws.
func reset() -> void:
	turn_id += 1
	active = true
	locked.clear()
	selected.clear()
	groups.clear()
	committed.clear()
	rolls_left = ROLLS
	rolls_made = 0
	last_perfect = false

## Return the physical dice that may change on the next throw.
func unused() -> Array:
	return range(COUNT).filter(func(index): return index not in locked)

func has_rolled() -> bool:
	return rolls_made > 0

func can_roll(free: bool = false) -> bool:
	return active and not has_pending_group() and (free or rolls_left > 0) and locked.size() < COUNT

## A summoned group suspends the rest of the pool until used or cancelled.
func has_pending_group() -> bool:
	return locked.any(func(index): return index not in committed)

## Roll every unused die independently; test overrides never change locked dice.
func roll(rng: RandomNumberGenerator, perfect: bool, forced: Array = [], free: bool = false) -> Array:
	if not can_roll(free): return []
	var indices: Array = unused()
	if not forced.is_empty() and (forced.size() != indices.size() or forced.any(func(face): return not face is int or face < 1 or face > 6)): return []
	for offset in range(indices.size()):
		values[indices[offset]] = rng.randi_range(1, 6) if forced.is_empty() else forced[offset]
	if not free: rolls_left -= 1
	rolls_made += 1
	last_perfect = perfect
	selected.clear()
	return indices

## Toggle an available die only when the selection can still form a useful pattern.
func select(index: int) -> bool:
	if not active or has_pending_group() or not has_rolled() or index < 0 or index >= COUNT or index in locked: return false
	if index in selected: selected.erase(index)
	elif can_select(index): selected.append(index)
	else: return false
	return true

## Check a potential selection against patterns still possible in this pool.
func can_select(index: int) -> bool:
	if index in locked or index < 0 or index >= COUNT: return false
	return Patterns.can_extend(selection_values()+[values[index]],unused().map(func(i): return values[i]))

func selection_values() -> Array:
	return selected.map(func(index): return values[index])

## Reserve a valid variable-length combination until it is used or cancelled.
func form() -> Array:
	if not active or not has_rolled() or has_pending_group() or Patterns.classify(selection_values()).is_empty(): return []
	var faces: Array = selection_values()
	groups.append(selected.duplicate())
	locked.append_array(selected)
	selected.clear()
	return faces

## Unlock only a still-pending group; used dice stay spent.
func release_group(indices: Array) -> bool:
	if not active or indices.is_empty() or indices.any(func(index): return index in committed): return false
	if not groups.has(indices): return false
	groups.erase(indices)
	for index in indices: locked.erase(index)
	selected.clear()
	return true

## Commit formation bonuses once when the player actually uses a skill.
func commit_group(indices: Array) -> bool:
	if not active or indices.is_empty() or not groups.has(indices) or indices.any(func(index): return index in committed): return false
	committed.append_array(indices)
	return true
