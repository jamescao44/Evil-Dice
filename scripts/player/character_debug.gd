extends RefCounted
## Direct debug levels reuse normal stat curves without replaying XP rewards or changing the encounter.
const MAX_LEVEL := 100
const Damage = preload("res://scripts/enemies/enemy_damage.gd")
const Skills = preload("res://scripts/enemies/enemy_skill_catalog.gd")
const Modifiers = preload("res://scripts/enemies/enemy_modifiers.gd")

## Avoid changing stats partway through an attack or an enemy action.
static func can_apply(model) -> bool:
	return model.hp > 0 and model.phase in ["new","roll","player","frozen","round_end","shop"] and not model.perfect_relic_ready

## Set the requested level, start its XP bar empty and heal as a normal level-up would.
static func set_level(model, level: int) -> bool:
	if level < 1 or level > MAX_LEVEL or not can_apply(model): return false
	model.character_level = level
	model.souls = 0
	model.base_max_hp = model.Vitals.base_health(level)
	model.hp = model.max_hp
	# Keep chosen enemy moves and targets, but update their player-level damage budgets.
	for index in model.living():
		var enemy: Dictionary = model.enemies[index]
		if enemy.intent.get("type","") != "attack" or enemy.intent.get("friendly_fire",false): continue
		var skill: String = enemy.intent.get("skill","")
		if not Skills.ITEMS.has(skill): continue
		var updated: Dictionary = Skills.make(skill,Damage.base_hit(enemy,level))
		enemy.intent.amount = roundi(updated.amount*Modifiers.attack_factor(enemy))
	return true
