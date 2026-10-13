extends RefCounted
## Item attacks share shields, statuses and damage events, but never spend a skill,
## Strength, Priestess uses, critical charges or attack-boon charges.
const Skill = preload("res://scripts/multi_hit_skill.gd")
const Status = preload("res://scripts/status_effect.gd")

static func apply(model, source: String, amount: float, fixed: bool = false, all_targets: bool = false, target: int = -1) -> Array:
	var targets: Array = [-2] if model.is_city() and model.city_hp > 0 else (model.living() if all_targets else model.attack_targets())
	if targets.is_empty() or model.hp <= 0: return []
	if not all_targets:
		if target not in targets: target = targets[model.rng.randi_range(0,targets.size()-1)]
		targets = [target]
	var skill = Skill.new(Skill.Kind.PAIR,4 if all_targets else 1,model.pending.dice)
	var damage: int = maxi(0,floori(amount if fixed else (amount+model.relic_base_damage())*model.damage_multiplier(skill)+0.000001))
	var guards: Array = model.taunting_enemies()
	var events: Array = []
	var old_lifesteal: int = model.lifesteal_used
	var old_budgets: Dictionary = model.lifesteal_budgets.duplicate()
	model.lifesteal_used = 0
	model.active_relic_procs.append(source)
	for index in targets:
		if index != -2 and not model.is_enemy_alive(index): continue
		var hit_damage: int = damage
		if not fixed and model.enemy_status_count(index,Status.CORROSION) > 0: hit_damage = floori(hit_damage*1.5)
		if all_targets and index != -2: hit_damage = floori(hit_damage*model.area_damage_factor(index,guards))
		var shield_before: int = 0 if index == -2 else model.enemies[index].shield
		var blocked: bool = shield_before > 0 and model.enemy_status_count(index,Status.CORROSION) == 0
		var loss: int
		if index == -2:
			loss = mini(model.city_hp,hit_damage)
			model.city_hp -= loss
		else: loss = model.hit_enemy(index,hit_damage)
		var actual: int = shield_before-model.enemies[index].shield if blocked else loss
		var hit: Dictionary = model.damage_event(index,actual,hit_damage,"shield_hit" if blocked else "damage")
		if blocked: hit.text = "SHIELD BREAK" if model.enemies[index].shield == 0 else "BLOCKED"
		events.append(hit)
		if loss > 0: events.append_array(model._attack_relic_effects(index,loss,skill))
	events.append_array(model.RelicEffects.attack_used(model))
	model.active_relic_procs.pop_back()
	model.lifesteal_used = old_lifesteal
	model.lifesteal_budgets = old_budgets
	return events
