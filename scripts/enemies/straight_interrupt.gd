extends RefCounted
## A per-turn straight challenge shared by charging bosses and the Magic Cannon.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

## Three-charge bosses need two matching casts; shorter attacks and cannons need one.
static func required_casts(enemy: Dictionary) -> int:
	return 2 if enemy.get("boss",false) and Catalog.ITEMS[enemy.role].get("charge_turns",0) == 3 else 1

## Share the active-challenge gate between combat, inspection and the HUD.
static func active(enemy: Dictionary) -> bool:
	return enemy.get("charging",false) and enemy.get("charge",0) > 0 and enemy.get("interrupt_straight",0) > 0

## Keep partial interruption progress until release, cancellation or phase transition.
static func remaining_casts(enemy: Dictionary) -> int:
	return int(enemy.get("interrupt_remaining",required_casts(enemy))) if active(enemy) else 0

## Inspection and repeated intent builds cannot reroll the visible requirement.
static func prepare_turn(model, index: int) -> void:
	var enemy: Dictionary = model.enemies[index]
	var shapes: Array = Catalog.ITEMS[enemy.role].get("interrupt_shapes",[])
	if shapes.is_empty(): return
	if not enemy.get("charging",false) or enemy.get("charge",0) <= 0:
		clear(enemy)
		return
	if not enemy.has("interrupt_remaining"): enemy.interrupt_remaining = required_casts(enemy)
	if enemy.get("interrupt_warning_round",-1) == model.round_number: return
	enemy.interrupt_warning_round = model.round_number
	enemy.interrupt_straight = 0 if model.enemy_cannot_act(index) else shapes[model.rng.randi_range(0,shapes.size()-1)]

## Matching the displayed shape interrupts regardless of random targeting or hit count.
static func skill_cast(model, index: int, skill: MultiHitSkill) -> void:
	if skill.pattern != "straight": return
	var enemy: Dictionary = model.enemies[index]
	if not active(enemy) or model.enemy_cannot_act(index): return
	if enemy.get("interrupt_straight",0) != skill.dice.size(): return
	enemy.interrupt_remaining = remaining_casts(enemy)-1
	if enemy.interrupt_remaining > 0:
		model.boss_changed.emit(index,"boss_mark")
		return
	enemy.charge = 0; enemy.charging = false
	clear(enemy)
	var skips_action: bool = Catalog.ITEMS[enemy.role].get("interrupt_skips_action",true)
	enemy.canceled = skips_action
	if skips_action:
		model.apply_enemy_status(index,model.Status.IMMOBILIZED,1,false)
		enemy.intent = {"skill":"rest","type":"rest","target":index,"amount":0,"name":"Interrupted"}
	else:
		# Rebuild charge progress immediately without spending or skipping the next action.
		enemy.intent = model.choose_intent(index)
	model.boss_changed.emit(index,"cannon_break" if enemy.role == Catalog.Role.MAGIC_CANNON else "boss_break")

## Charge release and phase changes retire the old challenge.
static func clear(enemy: Dictionary) -> void:
	enemy.interrupt_straight = 0
	enemy.erase("interrupt_warning_round")
	enemy.erase("interrupt_remaining")
