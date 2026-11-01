extends RefCounted
## Optional enemy lifecycle hooks keep special species out of the shared battle model.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const StraightInterrupt = preload("res://scripts/enemies/straight_interrupt.gd")
const SCRIPTS := {
	Catalog.Role.COMMANDER: preload("res://scripts/enemies/knight_commander.gd"),
	Catalog.Role.SPELLSWORD: preload("res://scripts/enemies/elf_spellsword.gd"),
	Catalog.Role.FANATIC: preload("res://scripts/enemies/fanatical_mage.gd"),
	Catalog.Role.BOUND_DEMON: preload("res://scripts/enemies/fanatical_mage.gd"),
	Catalog.Role.BOMBER: preload("res://scripts/enemies/bomber.gd"),
	Catalog.Role.MAGIC_CANNON: preload("res://scripts/enemies/magic_cannon.gd"),
}

## Missing hooks are intentional: ordinary catalog enemies need no behavior script.
static func _call(model, index: int, hook: String, extra: Array = []) -> Variant:
	var behavior: Script = SCRIPTS.get(model.enemies[index].role)
	if behavior == null or not behavior.has_method(hook): return null
	return behavior.callv(hook,[model,index]+extra)

static func prepare_turn(model, index: int) -> void:
	_call(model,index,"prepare_turn")
	StraightInterrupt.prepare_turn(model,index)

static func phase_two(model, index: int) -> void:
	_call(model,index,"enter_phase_two")

static func released(model, index: int) -> void:
	StraightInterrupt.clear(model.enemies[index])
	_call(model,index,"released")

## Each committed skill notifies each living enemy once, independently of hit count.
static func skill_cast(model, skill: MultiHitSkill) -> void:
	for index in model.living():
		StraightInterrupt.skill_cast(model,index,skill)
		_call(model,index,"skill_cast",[skill])

static func protector(model, index: int) -> int:
	var target: Variant = _call(model,index,"protector")
	return int(target) if target != null else -1

static func died(model, index: int) -> void:
	_call(model,index,"died")

## Snapshot turn-end order; a hook may dismiss or kill another enemy in that list.
static func turn_finished(model) -> Array:
	var events: Array = []
	for index in model.living():
		if not model.is_enemy_alive(index): continue
		var result: Variant = _call(model,index,"turn_finished")
		if result is Array: events.append_array(result)
	return events
