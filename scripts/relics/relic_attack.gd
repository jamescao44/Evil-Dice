extends RefCounted
## Item attacks share shields, statuses and damage events, but never spend a skill,
## Strength, Priestess uses, critical charges or attack-boon charges.
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Status = preload("res://scripts/status/status_effect.gd")

static func apply(model, source: String, amount: float, fixed: bool = false, all_targets: bool = false, target: int = -1, options: Dictionary = {}) -> Array:
	var targets: Array = [-2] if model.is_city() and model.city_hp > 0 else (model.living() if all_targets else model.attack_targets())
	if targets.is_empty() or model.hp <= 0: return []
	if not all_targets:
		if target not in targets: target = targets[model.rng.randi_range(0,targets.size()-1)]
		targets = [target]
	var skill = Skill.new(Skill.Kind.PAIR,4 if all_targets else 1,model.pending.dice)
	skill.cast_source = "relic"
	var attack_base: float = amount+model.RelicEffects.base_damage(model.relics.items,amount)
	if options.has("base_scale"): attack_base = (model.character_base_damage()+model.relic_base_damage())*options.base_scale
	var damage: int = maxi(0,floori(amount if fixed else attack_base*model.damage_multiplier(skill)+0.000001))
	if fixed and not options.get("no_damage_modifiers",false): damage = floori(damage*pow(2,model.RelicEffects.repeat_sources(model.relics.items,"holy_grail").size()))
	if options.get("multiplier_only",false): damage = floori(amount*model.damage_multiplier(skill)+0.000001)
	if not fixed or options.get("multiplier_only",false): model.RelicEffects.activate_damage_modifiers(model,skill)
	var guards: Array = model.taunting_enemies()
	var events: Array = []
	var old_lifesteal: int = model.lifesteal_used
	var old_budgets: Dictionary = model.lifesteal_budgets.duplicate()
	model.lifesteal_used = 0
	model.active_relic_procs.append(source)
	for index in targets:
		if index != -2 and not model.is_enemy_alive(index): continue
		if index != -2 and model.enemies[index].get("phase_transition_pending",false): continue
		var hit_damage: int = damage
		if not options.get("no_damage_modifiers",false): hit_damage = floori(hit_damage*model.RelicEffects.Conditions.target_factor(model,index,true)+0.000001)
		if not fixed and model.enemy_status_count(index,Status.CORROSION) > 0: hit_damage = floori(hit_damage*1.5)
		if all_targets and index != -2: hit_damage = floori(hit_damage*model.area_damage_factor(index,guards))
		var shield_before: int = 0 if index == -2 else model.enemies[index].shield
		var hp_before: int = model.city_hp if index == -2 else model.enemies[index].hp
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
		if index >= 0:
			if options.get("burning",0) > 0: events.append_array(model.apply_enemy_status(index,Status.BURNING,options.burning))
			events.append_array(model.RelicCombat.overflow(model,index,hit_damage,hp_before,blocked))
	events.append_array(model.RelicEffects.attack_used(model))
	model.active_relic_procs.pop_back()
	model.lifesteal_used = old_lifesteal
	model.lifesteal_budgets = old_budgets
	return events
