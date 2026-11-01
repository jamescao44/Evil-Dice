extends RefCounted
## A per-turn straight challenge shared by charging bosses and the Magic Cannon.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

## Inspection and repeated intent builds cannot reroll the visible requirement.
static func prepare_turn(model, index: int) -> void:
	var enemy: Dictionary = model.enemies[index]
	var shapes: Array = Catalog.ITEMS[enemy.role].get("interrupt_shapes",[])
	if shapes.is_empty() or not enemy.get("charging",false): return
	if enemy.get("interrupt_warning_round",-1) == model.round_number: return
	enemy.interrupt_warning_round = model.round_number
	enemy.interrupt_straight = 0 if model.enemy_cannot_act(index) else shapes[model.rng.randi_range(0,shapes.size()-1)]

## Matching the displayed shape interrupts regardless of random targeting or hit count.
static func skill_cast(model, index: int, skill: MultiHitSkill) -> void:
	if skill.pattern != "straight": return
	var enemy: Dictionary = model.enemies[index]
	if not enemy.get("charging",false) or model.enemy_cannot_act(index): return
	if enemy.get("interrupt_straight",0) != skill.dice.size(): return
	enemy.charge = 0; enemy.charging = false; enemy.interrupt_straight = 0
	enemy.canceled = true
	model.apply_enemy_status(index,model.Status.IMMOBILIZED,1,false)
	enemy.intent = {"skill":"rest","type":"rest","target":index,"amount":0,"name":"Interrupted"}
	model.boss_changed.emit(index,"cannon_break" if enemy.role == Catalog.Role.MAGIC_CANNON else "boss_break")

## Charge release and phase changes retire the old challenge.
static func clear(enemy: Dictionary) -> void:
	enemy.interrupt_straight = 0
	enemy.erase("interrupt_warning_round")
