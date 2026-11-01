extends RefCounted
## Reusable elite traits; decisions are locked into intents, reactions belong to full turns.
const Damage = preload("res://scripts/enemies/enemy_damage.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const ELEMENTS := [Status.BURNING,Status.FROZEN,Status.CORROSION,Status.DARKNESS,Status.STUNNED]
const ATTRIBUTES := {Status.BURNING:Status.Attribute.FIRE,Status.FROZEN:Status.Attribute.ICE,Status.CORROSION:Status.Attribute.ACID,Status.DARKNESS:Status.Attribute.DARK,Status.STUNNED:Status.Attribute.SHOCK}
const ELEMENT_COLORS := {Status.BURNING:Color("ff9955"),Status.FROZEN:Color("82dfff"),Status.CORROSION:Color("8ad26a"),Status.DARKNESS:Color("c18ce8"),Status.STUNNED:Color("ffe388")}
const ITEMS := {
	"shielding":{"name":"Shielding","icon":"shield","color":Color("9bdcff"),"text":"After losing HP, gain 20% max HP as shield. Once per turn."},
	"elemental":{"name":"Elemental","icon":"stars","color":Color("e0c1ff"),"text":"Attacks have a 50% chance to inflict its element."},
	"manic":{"name":"Manic","icon":"attack","color":Color("ff7f7f"),"text":"Double damage and healing. 30% chance to attack allies or turn healing into damage."},
	"thorns":{"name":"Thorns","icon":"plague","color":Color("b0db84"),"text":"Retaliate after an attack finishes. Once per turn."},
}

## Each category has equal weight; an elemental enemy keeps its element for its lifetime.
static func assign(enemy: Dictionary, rng: RandomNumberGenerator) -> void:
	enemy.modifier = ITEMS.keys()[rng.randi_range(0,ITEMS.size()-1)]
	if enemy.modifier == "elemental":
		enemy.element = ELEMENTS[rng.randi_range(0,ELEMENTS.size()-1)]
		enemy.attribute = ATTRIBUTES[enemy.element]

## Select friendly fire and elemental procs once per whole action, never per impact.
static func decorate_intent(model, index: int, move: Dictionary) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	match enemy.get("modifier",""):
		"elemental":
			if move.type == "attack" and (enemy.element != Status.FROZEN or not model.is_frozen()) and model.rng.randf() < 0.5:
				if move.get("status",-1) >= 0:
					# Native status attacks keep their own stacks; the trait is additional.
					move.extra_status = enemy.element
				else:
					move.status = enemy.element; move.stacks = 1; move.attribute = enemy.attribute
					move.status_once = true
		"manic":
			if move.type == "attack":
				move.amount *= 2
				if model.rng.randf() < 0.3:
					var allies: Array = model.living().filter(func(i): return i != index)
					move.target = index if allies.is_empty() else allies[model.rng.randi_range(0,allies.size()-1)]
					move.friendly_fire = true
					move.amount = move.get("friendly_amount",move.amount/2)*2
			elif move.type in ["heal","team_heal"]:
				move.heal_factor = 2.0
				move.inverted = model.rng.randf() < 0.3
	return move

## Record HP-loss reactions before later hits; defeated enemies cannot gain shields or counter.
static func hurt(model, index: int, hp_loss: int, source: String) -> void:
	var enemy: Dictionary = model.enemies[index]
	if hp_loss <= 0 or enemy.hp <= 0 or enemy.get("phase_transition_pending",false): return
	match enemy.get("modifier",""):
		"shielding":
			if enemy.get("shielding_turn",-1) == model.round_number or model.enemy_status_count(index,Status.CORROSION) > 0: return
			enemy.shielding_turn = model.round_number
			var amount: int = roundi(enemy.max_hp*0.2)
			enemy.shield += amount
			model.enemy_reaction_events.append(model.event(index,amount,"shield","+%d SHIELD" % amount))
		"thorns":
			if source in ["enemy","retaliation","burn","cost"] or enemy.get("thorns_turn",-1) == model.round_number: return
			enemy.thorns_turn = model.round_number
			enemy.counter_pending = true

## Resolve queued counters at sequence boundaries, with no chained counterattacks.
static func resolve(model) -> Array:
	var events: Array = model.enemy_reaction_events.duplicate()
	model.enemy_reaction_events.clear()
	for index in range(model.enemies.size()):
		var enemy: Dictionary = model.enemies[index]
		if not enemy.get("counter_pending",false): continue
		enemy.counter_pending = false
		if enemy.hp <= 0 or model.enemy_cannot_act(index) or not model.outcome().is_empty(): continue
		events.append(model.event(index,0,"counter","Thorns"))
		var amount: int = roundi(Damage.base_hit(enemy,model.character_level)*(0.5 if model.enemy_status_count(index,Status.DARKNESS) > 0 else 1.0))
		events.append_array(model.receive_damage(amount,false,index))
	return events

## Trait presentation reads only stored state and never consumes combat randomness.
static func color(enemy: Dictionary, fallback: Color) -> Color:
	if enemy.get("modifier","") == "elemental": return ELEMENT_COLORS.get(enemy.get("element",-1),fallback)
	return ITEMS.get(enemy.get("modifier",""),{}).get("color",fallback)

static func description(enemy: Dictionary) -> String:
	return ITEMS.get(enemy.get("modifier",""),{}).get("text","")
