extends RefCounted
## Immediate area damage shared by consumables and boon reapplication effects.
## Does not consume next-skill charges, add uses, or advance turn clocks.
const Status = preload("res://scripts/status_effect.gd")

static func apply(model, base_damage: float, skill: MultiHitSkill) -> Array:
	var damage: int = floori((base_damage+model.relic_base_damage())*model.damage_multiplier(skill)+0.000001)
	var events: Array = []
	model.lifesteal_used = 0
	if model.is_city():
		var loss: int = mini(model.city_hp,damage)
		model.city_hp -= loss
		events.append(model.damage_event(-2,loss,damage))
		if loss > 0: events.append_array(model._attack_relic_effects(-2,loss,skill))
	else:
		for target in model.living():
			var amount: int = model._target_damage(skill,damage,target)
			var shield_before: int = model.enemies[target].shield
			var shielded: bool = shield_before > 0 and model.enemy_status_count(target,Status.CORROSION) == 0
			var loss: int = model.hit_enemy(target,amount)
			var actual: int = shield_before-model.enemies[target].shield if shielded else loss
			var hit: Dictionary = model.damage_event(target,actual,amount,"shield_hit" if shielded else "damage")
			if shielded: hit.text = "SHIELD BREAK" if model.enemies[target].shield == 0 else "BLOCKED"
			events.append(hit)
			if loss > 0: events.append_array(model._attack_relic_effects(target,loss,skill))
	return events
