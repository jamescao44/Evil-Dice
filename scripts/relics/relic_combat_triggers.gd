extends RefCounted
## Secondary damage uses explicit proc guards so copied effects cannot recurse.
const Effects = preload("res://scripts/relics/relic_effects.gd")
const Status = preload("res://scripts/status/status_effect.gd")

## Killing excess never carries boss-phase damage, shield absorption or instant kills.
static func overflow(model, target: int, damage: int, hp_before: int, blocked: bool, instant: bool = false) -> Array:
	if instant or blocked or hp_before <= 0 or damage <= hp_before: return []
	if model.is_enemy_alive(target) or model.enemies[target].get("phase_transition_pending",false): return []
	if "overflow_prism" in model.active_relic_procs: return []
	var events: Array = []
	for entry in Effects.repeat_sources(model.relics.items,"overflow_prism"):
		if model.attack_targets().is_empty(): break
		Effects.Sequence.activate(model,entry)
		events.append_array(Effects.Attack.apply(model,"overflow_prism",floori((damage-hp_before)*0.5),true,false,-1,{"no_damage_modifiers":true}))
	return events

## Consume five stacks once at the threshold; explosions cannot ignite another explosion.
static func burning_applied(model, target: int) -> Array:
	if model.enemy_status_count(target,Status.BURNING) < 10 or "powder_keg" in model.active_relic_procs: return []
	var sources: Array = Effects.repeat_sources(model.relics.items,"powder_keg")
	if sources.is_empty(): return []
	model.enemies[target].statuses[Status.BURNING].count -= 5
	var events: Array = [model.event(target,0,"relic_explosion","")]
	for entry in sources:
		Effects.Sequence.activate(model,entry)
		events.append_array(Effects.Attack.apply(model,"powder_keg",0,false,true,-1,{"base_scale":3.0}))
	return events
