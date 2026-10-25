extends RefCounted
## Turn-scoped healing conditions and non-recursive overheal attacks.
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
const Attack = preload("res://scripts/relics/relic_attack.gd")
var healing_factor: float = 1.0
var stored: Dictionary = {}
var releasing: bool = false
var finished: bool = false
var leftover_sum: int = 0

## Snapshot missing HP before any start-of-turn recovery occurs.
func begin_turn(model) -> void:
	healing_factor = 1.0
	stored.clear()
	finished = false
	leftover_sum = 0
	if model.hp >= model.max_hp: return
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id == "magic_bandage":
			healing_factor *= 2.0
			Sequence.activate(model,entry)

## Bank only wasted healing; a seed's own lifesteal cannot refill the seed.
func overhealed(model, amount: int) -> void:
	if releasing or finished or amount <= 0: return
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id != "mysterious_seed": continue
		var key := str(entry.activators)
		stored[key] = stored.get(key,0)+amount*2

## Release one projectile per active seed trigger before enemies begin acting.
func finish_player_turn(model) -> Array:
	if finished: return []
	finished = true
	releasing = true
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id == "frozen_tilapia" and leftover_sum > 0:
			Sequence.activate(model,entry)
			events.append_array(Attack.apply(model,entry.item.id,leftover_sum))
		if entry.item.id != "mysterious_seed": continue
		var amount: int = stored.get(str(entry.activators),0)
		if amount <= 0: continue
		Sequence.activate(model,entry)
		events.append_array(Attack.apply(model,entry.item.id,amount))
	stored.clear()
	releasing = false
	return events

## HP costs ignore protection, never kill, and do not trigger attack retaliation.
static func full_turn_finished(model) -> Array:
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		if entry.item.id != "book_of_dead" or model.hp <= 1: continue
		var loss := mini(model.hp-1,ceili(model.hp*0.3))
		model.hp -= loss
		Sequence.activate(model,entry)
		events.append(model.damage_event(-1,loss,loss,"damage"))
	return events
