extends RefCounted
const Vitals = preload("res://scripts/combat/player_vitals.gd")
const Damage = preload("res://scripts/enemies/enemy_damage.gd")
## A defeated Bomber explodes once; living allies can trigger their own death reactions.
const Friendly = preload("res://scripts/enemies/enemy_friendly_damage.gd")
const Modifiers = preload("res://scripts/enemies/enemy_modifiers.gd")
const Status = preload("res://scripts/status/status_effect.gd")

static func died(model, index: int) -> void:
	var enemy: Dictionary = model.enemies[index]
	if enemy.get("blast_resolved",false): return
	enemy.blast_resolved = true
	var move: Dictionary = Modifiers.decorate_intent(model,index,{"type":"attack","amount":Damage.friendly_base_hit(enemy),"status":-1,"stacks":0})
	var amount: int = roundi(move.amount*(1.5 if enemy.attack_boost else 1.0)*(0.5 if model.enemy_status_count(index,Status.DARKNESS) > 0 else 1.0))
	model.enemy_reaction_events.append(model.event(index,amount,"enemy_explosion",""))
	for ally in model.living():
		if ally == index: continue
		var events: Array = Friendly.hit(model,ally,roundi(Vitals.to_combat(amount)))
		model.enemy_reaction_events.append_array(events)
		if move.status >= 0 and events.any(func(e): return e.type == "damage" and e.amount > 0):
			model.enemy_reaction_events.append_array(model.apply_enemy_status(ally,move.status,move.stacks,false))
