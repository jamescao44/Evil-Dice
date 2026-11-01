extends RefCounted
## Friendly damage honors enemy defenses without applying the player's relic multipliers.
const Status = preload("res://scripts/status/status_effect.gd")

static func hit(model, target: int, amount: int) -> Array:
	if not model.is_enemy_alive(target): return []
	var corroded: bool = model.enemy_status_count(target,Status.CORROSION) > 0
	var shielded: bool = model.enemies[target].shield > 0 and not corroded
	var damage: int = roundi(amount*(1.5 if corroded else 1.0))
	var loss: int = model.hit_enemy(target,damage,false,"enemy")
	return [model.event(target,damage,"shield_hit","SHIELD") if shielded else model.damage_event(target,loss,damage)]
