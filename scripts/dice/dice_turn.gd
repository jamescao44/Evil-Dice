extends RefCounted
## Six physical dice and their roll budget, independent of skills and presentation.
const COUNT := 6
const ROLLS := 3
var active: bool = false
var values: Array = [1, 2, 3, 4, 5, 6]
var locked: Array = []
var selected: Array = []
var groups: Array = []
var committed: Array = []
var rolls_left: int = ROLLS
var last_perfect: bool = false

## Start a turn with six unused dice and three available throws.
func reset() -> void:
	active = true
	locked.clear()
	selected.clear()
	groups.clear()
	committed.clear()
	rolls_left = ROLLS
	last_perfect = false

## Return the physical dice that may change on the next throw.
func unused() -> Array:
	return range(COUNT).filter(func(index): return index not in locked)

func can_roll() -> bool:
	return active and not has_pending_group() and rolls_left > 0 and locked.size() < COUNT

## A summoned group suspends the rest of the pool until used, saved or cancelled.
func has_pending_group() -> bool:
	return locked.any(func(index): return index not in committed)

## Roll every unused die independently; test overrides never change locked dice.
func roll(rng: RandomNumberGenerator, perfect: bool, forced: Array = []) -> Array:
	if not can_roll(): return []
	var indices: Array = unused()
	if not forced.is_empty() and (forced.size() != indices.size() or forced.any(func(face): return not face is int or face < 1 or face > 6)): return []
	for offset in range(indices.size()):
		values[indices[offset]] = rng.randi_range(1, 6) if forced.is_empty() else forced[offset]
	rolls_left -= 1
	last_perfect = perfect
	selected.clear()
	return indices

## Toggle up to three available dice after the first throw.
func select(index: int) -> bool:
	if not active or has_pending_group() or rolls_left == ROLLS or index < 0 or index >= COUNT or index in locked: return false
	if index in selected: selected.erase(index)
	elif selected.size() < 3: selected.append(index)
	else: return false
	return true

func selection_values() -> Array:
	return selected.map(func(index): return values[index])

## Reserve a selected trio until its skill is used, saved or cancelled.
func form() -> Array:
	if has_pending_group() or selected.size() != 3: return []
	var faces: Array = selection_values()
	groups.append(selected.duplicate())
	locked.append_array(selected)
	selected.clear()
	return faces

## Unlock only a still-pending group; used or saved dice stay spent.
func release_group(indices: Array) -> bool:
	if not active or indices.size() != 3 or indices.any(func(index): return index in committed): return false
	if not groups.has(indices): return false
	groups.erase(indices)
	for index in indices: locked.erase(index)
	selected.clear()
	return true

## Commit formation bonuses once when the player actually uses or saves a skill.
func commit_group(indices: Array) -> bool:
	if not active or indices.size() != 3 or not groups.has(indices) or indices.any(func(index): return index in committed): return false
	committed.append_array(indices)
	return true
