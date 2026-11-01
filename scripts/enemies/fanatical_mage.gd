extends RefCounted
## Summon ownership, taunt and the phase-two pact stay separate from enemy action timing.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const MAX_MINIONS := 6

static func servants(model, owner: int, octopus_only: bool = false) -> Array:
	return model.living().filter(func(i): return model.enemies[i].get("summoner",-1) == owner and model.enemies[i].role in ([Catalog.Role.OCTOPUS] if octopus_only else [Catalog.Role.OCTOPUS,Catalog.Role.TENTACLE]))

## New servants wait until the next enemy phase, and never create farmable loot.
static func spawn(model, owner: int, role: int) -> int:
	var unit: Dictionary = Catalog.make(role,model.enemies[owner].level)
	var master: Dictionary = model.enemies[owner]
	unit.max_hp = Catalog.Level.scaled(Catalog.ITEMS[role].hp[0],Catalog.BossBalance.summon_health_scale(master.name,unit.name,master.level))
	unit.hp = unit.max_hp
	unit.damage_percent = Catalog.BossBalance.summon_damage_percent(master.name,unit.name,unit.damage_percent)
	unit.damage = Catalog.Damage.base_hit(unit,master.level)
	unit.summoner = owner
	unit.summoned = true
	unit.taunt = true
	unit.acted = true
	unit.reinforcement = true
	unit.charging = false
	unit.break_marks = Catalog.ITEMS[role].get("break_casts",0)
	var used: Array = servants(model,owner).map(func(i): return model.enemies[i].get("summon_slot",0))
	var slot := 0
	while slot in used: slot += 1
	unit.summon_slot = slot
	unit.intent = {"skill":"rest","type":"rest","target":model.enemies.size(),"amount":0,"name":"Summoned"}
	model.enemies.append(unit)
	return model.enemies.size()-1

## Removing a servant during a split, phase change or pact expiry is not a kill.
static func dismiss(model, index: int) -> void:
	model.enemies[index].hp = 0
	model.enemies[index].dismissed = true
	model.enemies[index].acted = true

static func summon(model, index: int) -> Array:
	for i in range(mini(2,MAX_MINIONS-servants(model,index).size())): spawn(model,index,Catalog.Role.OCTOPUS)
	model.RelicFocus.sync(model)
	model.boss_changed.emit(index,"boss_summon")
	return [model.event(index,0,"summon","Summon Minions")]

## Each octopus is replaced once by three small tentacles, within the live-summon cap.
static func split(model, index: int) -> Array:
	var sources: Array = servants(model,index,true)
	for source in sources: dismiss(model,source)
	for i in range(mini(sources.size()*3,MAX_MINIONS-servants(model,index).size())): spawn(model,index,Catalog.Role.TENTACLE)
	model.RelicFocus.sync(model)
	model.boss_changed.emit(index,"boss_summon")
	return [model.event(index,0,"summon","Splintering Grasp")]

static func enter_phase_two(model, index: int) -> void:
	for servant in servants(model,index): dismiss(model,servant)
	spawn(model,index,Catalog.Role.BOUND_DEMON)

## The demon's pact costs its master's HP after each complete enemy phase, even if interrupted.
static func end_turn(model) -> Array:
	var events: Array = []
	for index in model.living(): events.append_array(turn_finished(model,index))
	return events

## One living demon pays its pact through the shared enemy turn-end lifecycle.
static func turn_finished(model, index: int) -> Array:
	var demon: Dictionary = model.enemies[index]
	if demon.role != Catalog.Role.BOUND_DEMON: return []
	var owner: int = demon.get("summoner",-1)
	if not model.is_enemy_alive(owner): dismiss(model,index); return []
	var mage: Dictionary = model.enemies[owner]
	var amount: int = ceili(300*Catalog.BossBalance.health_scale(mage.name,mage.level))
	# Sacrifice bypasses servants, shields and status modifiers, but uses normal death rewards.
	var loss: int = model.direct_enemy_hp_damage(owner,amount)
	return [model.damage_event(owner,loss,amount,"burn")]

## Final master death dismisses the demon and any remaining servants immediately.
static func died(model, index: int) -> void:
	if model.enemies[index].role != Catalog.Role.FANATIC: return
	for i in model.living():
		if model.enemies[i].get("summoner",-1) == index: dismiss(model,i)
