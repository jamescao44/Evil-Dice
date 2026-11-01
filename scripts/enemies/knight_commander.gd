extends RefCounted
## Commander-only phase transition: summon two explicitly leveled support guards.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

static func enter_phase_two(model, index: int) -> void:
	var enemy: Dictionary = model.enemies[index]
	for i in range(2):
		var guard: Dictionary = Catalog.make(Catalog.Role.PALADIN,enemy.reinforcement_level)
		guard.max_hp = maxi(1,roundi(guard.max_hp*Catalog.BossBalance.summon_factor(enemy.name)))
		guard.hp = guard.max_hp
		guard.acted = true
		guard["reinforcement"] = true
		guard["reinforcement_owner"] = index
		guard.intent = {"skill":"rest","type":"rest","target":model.enemies.size(),"amount":0,"name":"Rally"}
		model.enemies.append(guard)
