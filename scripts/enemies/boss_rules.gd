extends RefCounted
## Shared boss phases and cast-based interruption, independent of rendering and ticks.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const Commander = preload("res://scripts/enemies/knight_commander.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
const Spellsword = preload("res://scripts/enemies/elf_spellsword.gd")

## Register a distinct committed skill or bonus cast, including a shield-blocked hit.
static func skill_contact(model, index: int) -> void:
	var enemy: Dictionary = model.enemies[index]
	if not (enemy.get("boss",false) or Catalog.ITEMS[enemy.role].get("interruptible",false)) or not enemy.get("charging",false) or enemy.hp <= 0: return
	var key: String = "%d:%d" % [index,enemy.get("boss_phase",0)]
	if model.boss_cast_contacts.has(key): return
	model.boss_cast_contacts[key] = true
	enemy.break_marks -= 1
	if enemy.break_marks > 0:
		model.boss_changed.emit(index,"boss_mark")
		return
	enemy.charge = 0
	enemy.charging = false
	enemy.break_marks = Catalog.ITEMS[enemy.role].break_casts
	enemy.canceled = true
	model.apply_enemy_status(index,model.Status.IMMOBILIZED,1,false)
	enemy.intent = {"skill":"rest","type":"rest","target":index,"amount":0,"name":"Interrupted"}
	model.boss_changed.emit(index,"boss_break")

## Hold a depleted first bar until the current skill or roll attack sequence finishes.
static func handle_defeat(model, index: int) -> bool:
	var enemy: Dictionary = model.enemies[index]
	if not enemy.get("boss",false) or enemy.get("boss_phase",1) != 1 or enemy.hp > 0: return false
	if model.phase in ["executing","roll_attacks"] or model.perfect_relic_ready:
		enemy.phase_transition_pending = true
		return true
	return enter_second_phase(model,index)

## Restore queued boss bars once all impacts, bonus casts and on-hit effects are done.
static func finish_attack_sequence(model) -> void:
	for index in range(model.enemies.size()):
		if model.enemies[index].get("phase_transition_pending",false): enter_second_phase(model,index)

## Replace a defeated first health bar once; overkill never spills into the next phase.
static func enter_second_phase(model, index: int) -> bool:
	var enemy: Dictionary = model.enemies[index]
	if not enemy.get("boss",false) or enemy.get("boss_phase",1) != 1 or enemy.hp > 0: return false
	enemy.erase("phase_transition_pending")
	enemy.boss_phase = 2
	# Each health bar starts from level-one data, without inheriting damage or plague.
	enemy.hp = Catalog.phase_health(enemy,2)
	enemy.max_hp = enemy.hp
	enemy.shield = 0
	enemy.charge = 0
	enemy.charging = false
	enemy.break_marks = Catalog.ITEMS[enemy.role].break_casts
	enemy.forced_charge = false
	enemy.canceled = false
	enemy.acted = true
	enemy.action_hit = 0
	enemy.attack_boost = false
	enemy.erase("healthy_max_hp")
	enemy.erase("statuses")
	enemy.intent = {"skill":"rest","type":"rest","target":index,"amount":0,"name":"PHASE II"}
	match enemy.role:
		Catalog.Role.COMMANDER: Commander.enter_phase_two(model,index)
		Catalog.Role.SPELLSWORD: Spellsword.enter_phase_two(model,index)
		Catalog.Role.FANATIC: Fanatic.enter_phase_two(model,index)
	model.boss_changed.emit(index,"boss_phase")
	return true
