extends RefCounted
## Plan stable inventory moves using real ordered modifiers and copy expansion, never activations.
const Effects = preload("res://scripts/relics/relic_effects.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
var signature := ""
var desired: Array = []
const UTILITY := {"armor":4.0,"bloodstone":4.0,"fortune_cookie":3.0,"crystal_ball":5.0,"magic_sword":5.0,"magic_shield":3.0,"pet_ghost":3.0,"pet_dragon":3.0,"blue_stone":2.0,"green_stone":2.0,"black_stone":2.0,"orange_stone":2.0,"soul_vessel":2.0}

## Inventory changes rebuild the plan; temporary HP, combo, charge and status changes do not.
func action(state: Dictionary) -> Dictionary:
	if "reorder" not in state.actions: return {}
	var items: Array = state.relics.map(func(r): return r.counters.duplicate(true))
	var identities: Array = items.map(identity)
	var sorted: Array = identities.duplicate(); sorted.sort()
	var key := str(sorted)+":"+str(state.player.level)
	if key != signature:
		signature = key
		desired = optimize(items,state.player.base_damage).map(identity)
	for i in range(desired.size()):
		if identities[i] == desired[i]: continue
		for j in range(i+1,identities.size()):
			if identities[j] == desired[i]: return {"action":"reorder","from":j+1,"to":i+1}
	return {}

## Ignore mutable counters in identity while retaining distinct quantities and set ingredients.
static func identity(item: Dictionary) -> String:
	return str([item.id,item.get("count",1),item.get("ingredients",[])])

## Hill-climb both single moves and swaps; ties preserve order and cannot create a reorder loop.
static func optimize(items: Array, base: float) -> Array:
	var result: Array = items.duplicate(true)
	for pass_index in range(12):
		var candidate: Array = result; var highest: float = score(result,base)
		for from in range(result.size()):
			for to in range(result.size()):
				if from == to: continue
				for swap in [false,true]:
					var trial: Array = result.duplicate()
					if swap:
						var old: Dictionary = trial[from]; trial[from] = trial[to]; trial[to] = old
					else:
						var moved: Dictionary = trial.pop_at(from); trial.insert(to,moved)
					var value: float = score(trial,base)
					if value > highest+0.00001: highest = value; candidate = trial
		if candidate == result: break
		result = candidate
	return result

## Prefer sustained damage while assigning smaller value to copied defense and utility.
static func score(items: Array, base: float) -> float:
	var damage := 0.0
	for faces in [[3,4,5],[2,3,4,5],[1,2,3,4,5],[1,2,3,4,5,6]]:
		var skill = Patterns.classify(faces)
		skill.begin_cast(Effects.use_modifiers(items,skill,{}))
		damage += (base+Effects.base_damage(items,base))*Effects.damage_multiplier(items,1.0,skill)*skill.use_count()/4.0
	var value: float = 100.0*log(maxf(0.001,damage/base))+30.0*log(Effects.max_health(items,1000)/1000.0)
	for entry in Effects.Sequence.entries(items): value += UTILITY.get(entry.item.id,0.0)
	return value
