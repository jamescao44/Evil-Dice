extends RefCounted
## Stateful companions and temporary shields share damage hooks; counters live on owned relics.
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
var temporary_shields: Array = []

## Initialize a guardian once, preserving missing health and recovery across waves/checkpoints.
static func sync_guardians(model) -> void:
	for item in model.relics.items:
		var rule: Dictionary = Catalog.ITEMS.get(item.id,{}).get("guardian",{})
		if rule.is_empty(): continue
		var maximum: int = maxi(1,roundi(model.max_hp*rule.health_ratio))
		if not item.has("guardian_hp"):
			item.guardian_hp = maximum
			item.guardian_recovery = 0
		elif item.guardian_hp > 0:
			item.guardian_hp = mini(maximum,item.guardian_hp+maxi(0,maximum-int(item.get("guardian_max_hp",maximum))))
		item.guardian_max_hp = maximum

## Only active guardians may attack; copied activations share the owner's health pool.
static func guardian_active(item: Dictionary) -> bool:
	return item.get("guardian_hp",0) > 0 and item.get("guardian_recovery",0) == 0

## Split damage after player defenses, bounded by the guardian's remaining HP.
func absorb(model, damage: int) -> Dictionary:
	sync_guardians(model)
	var result := {"damage":damage,"counters":[],"events":[]}
	for entry in Sequence.entries(model.relics.items):
		var item: Dictionary = entry.item
		var rule: Dictionary = Catalog.ITEMS[item.id].get("guardian",{})
		if rule.is_empty() or not guardian_active(item) or result.damage <= 0: continue
		var shared: int = mini(item.guardian_hp,floori(result.damage*rule.share))
		if shared <= 0: continue
		Sequence.activate(model,entry)
		item.guardian_hp -= shared
		result.damage -= shared
		if item.guardian_hp == 0: item.guardian_recovery = rule.recovery_turns
		result.counters.append(entry)
		var hit: Dictionary = model.event(-1,shared,"guardian_hit","")
		hit.relic_id = item.id
		result.events.append(hit)
	return result

## Temporary shield points absorb first so expiration never removes an unrelated shield.
func shield_spent(amount: int) -> void:
	for shield in temporary_shields:
		var used: int = mini(amount,shield.remaining)
		shield.remaining -= used
		amount -= used
		if amount <= 0: break

## Trigger once after actual attack HP loss; copies repeat the payout, not the eligibility check.
func after_hp_loss(model, loss: int) -> Array:
	if loss <= 0 or model.hp <= 0 or model.status_count(model.Status.CORROSION) > 0: return []
	var eligible: Array = model.relics.items.filter(func(item): return Catalog.ITEMS[item.id].has("reactive_shield") and not item.get("shield_triggered",false))
	var events: Array = []
	for entry in Sequence.entries(model.relics.items):
		if not eligible.any(func(item): return is_same(item,entry.item)): continue
		var amount: int = roundi(model.max_hp*Catalog.ITEMS[entry.item.id].reactive_shield)
		Sequence.activate(model,entry)
		if model.hp <= 0: break
		entry.item.shield_triggered = true
		model.shield += amount
		temporary_shields.append({"remaining":amount})
		events.append(model.event(-1,amount,"shield","SHIELD"))
	return events

## Counter once per shared hit, including the breaking hit; damage uses the live adjusted base.
static func retaliate(model, target: int, entries: Array) -> Array:
	var events: Array = []
	for entry in entries:
		if model.hp <= 0: break
		var rule: Dictionary = Catalog.ITEMS[entry.item.id].guardian
		events.append_array(model.RelicEffects.Attack.apply(model,entry.item.id,0,false,false,target,Sequence.attack_options(entry,{"base_scale":rule.counter_scale})))
	return events

## Finish exactly once per complete turn; shield remnants expire and downed guardians recover.
func turn_finished(model) -> Array:
	for shield in temporary_shields: model.shield = maxi(0,model.shield-shield.remaining)
	temporary_shields.clear()
	var events: Array = []
	sync_guardians(model)
	for item in model.relics.items:
		item.erase("shield_triggered")
		if item.get("guardian_recovery",0) <= 0: continue
		item.guardian_recovery -= 1
		if item.guardian_recovery == 0:
			item.guardian_hp = item.guardian_max_hp
			model.relic_effect_activated.emit(item.id)
			var returned: Dictionary = model.event(-1,0,"guardian_return","")
			returned.relic_id = item.id
			events.append(returned)
	return events

## Wave shields never carry over, but guardian health and recovery remain on the relic.
func wave_started(model) -> void:
	temporary_shields.clear()
	for item in model.relics.items: item.erase("shield_triggered")
	sync_guardians(model)
