extends RefCounted
## Relevel live encounter members without replacing state, rerolling traits or resurrecting corpses.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const MAX_LEVEL := 100

static func can_apply(model) -> bool:
	return model.phase in ["new","roll","player","frozen","round_end"] and model.outcome().is_empty() and model.has_living_enemies() and not model.perfect_relic_ready

## Rebuild from catalog values, preserving health percentage, phases, charge and locked intent.
static func set_level(model, level: int) -> bool:
	if level < 1 or level > MAX_LEVEL or not can_apply(model): return false
	for index in model.living():
		var enemy: Dictionary = model.enemies[index]
		var stats: Dictionary = Catalog.make(enemy.role,level,enemy.elite)
		var health: int = stats.max_hp
		if enemy.get("boss",false):
			stats.boss_phase = enemy.boss_phase
			health = Catalog.phase_health(stats,enemy.boss_phase)
			enemy.reinforcement_level = level
		var owner: int = enemy.get("summoner",enemy.get("reinforcement_owner",-1))
		# Previously spawned Commander guards predate the explicit ownership stamp.
		if owner < 0 and enemy.get("reinforcement",false) and enemy.role == Catalog.Role.PALADIN and model.enemies[0].role == Catalog.Role.COMMANDER: owner = 0
		if owner >= 0 and owner < model.enemies.size():
			var master: Dictionary = model.enemies[owner]
			if enemy.get("summoned",false):
				health = Catalog.Level.scaled(Catalog.ITEMS[enemy.role].hp[0],Catalog.BossBalance.summon_health_scale(master.name,enemy.name,level))
				stats.damage_percent = Catalog.BossBalance.summon_damage_percent(master.name,enemy.name,stats.damage_percent)
				stats.damage = Catalog.Damage.base_hit(stats,level)
		var ratio: float = float(enemy.hp)/maxi(1,enemy.max_hp)
		if enemy.has("healthy_max_hp"):
			enemy.healthy_max_hp = health
			health = model.Status.plague_max_hp(health,model.enemy_status_count(index,model.Status.PLAGUE),enemy.get("boss",false))
		if enemy.intent.get("type","") == "attack":
			var friendly: bool = enemy.intent.get("friendly_fire",false)
			var before: int = Catalog.Damage.friendly_base_hit(enemy) if friendly else Catalog.Damage.base_hit(enemy,model.character_level)
			var after: int = Catalog.Damage.friendly_base_hit(stats) if friendly else Catalog.Damage.base_hit(stats,model.character_level)
			enemy.intent.amount = roundi(float(enemy.intent.amount)*after/maxi(1,before))
		enemy.level = level
		enemy.max_hp = health
		enemy.hp = clampi(roundi(health*ratio),1,health)
		enemy.damage_percent = stats.damage_percent
		enemy.damage = stats.damage
	return true
