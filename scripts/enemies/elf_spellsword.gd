extends RefCounted
## Spellsword curses share the status model without borrowing player item bonuses.
const Status = preload("res://scripts/status/status_effect.gd")

## The second health bar begins with a one-time shared darkness curse.
static func enter_phase_two(model, index: int) -> void:
	apply_shared_curse(model,index,Status.DARKNESS,2)
	model.enemies[index].intent.name = "Selfless Curse"

## Corrosive Heal replaces healing and commits the next action to charging.
static func corrosive_heal(model, index: int) -> Array:
	var events: Array = apply_shared_curse(model,index,Status.CORROSION,3)
	model.enemies[index].forced_charge = true
	# These three turns begin after application, so corrosion reaches the heavy blow.
	if model.enemy_status_count(index,Status.CORROSION) > 0:
		model.enemies[index].statuses[Status.CORROSION].defer_decay = true
	if events.any(func(e): return e.target == -1 and e.type == "status"):
		model.statuses[Status.CORROSION].defer_decay = true
	return events

## Apply exact stacks to both sides while retaining their ordinary immunities.
static func apply_shared_curse(model, index: int, status: int, stacks: int) -> Array:
	var events: Array = model.apply_enemy_status(index,status,stacks,false)
	events.append_array(model.apply_affliction(status,stacks))
	return events
