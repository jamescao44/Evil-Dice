extends RefCounted
## Shared presentation metadata for boons and harmful status objects.
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const ENTRIES := {
	Status.HIDDEN: {"name":"Invisible", "icon":"dark", "text":"Untargetable for 3 turns. Using an attack skill breaks invisibility.", "color":Color("aaa9bf")},
	2: {"name": "Regeneration", "icon": "heal", "text": "Heal 5 at turn start.", "color": Color("aed085")},
	3: {"name": Rules.PAIR_NAMES[2], "icon": "attack", "text": "Adds +0.5 to DMG. Stacks with other bonuses.", "color": Color("dfb866")},
	33: {"name": Rules.SPECIAL_NAMES[2], "icon": "crown", "text": "Adds +2.0 to DMG. Stacks with other bonuses.", "color": Color("c5a4de")},
	6: {"name": Rules.PAIR_NAMES[5], "icon": "shield", "text": "Invincible.", "color": Color("80d8c6")},
	Status.FROZEN: {"name": "Frozen", "icon": "ice", "text": "Tap the ice 3 times to break free and end your turn.", "color": Color("82dfff")},
	Status.BURNING: {"name": "Burning", "icon": "fire", "text": "5 damage per stack after enemies act; lose 1 stack each turn. Maximum 10 stacks.", "color": Color("ff9955")},
	Status.STUNNED: {"name": "Stunned", "icon": "stars", "text": "The next throw's power marker moves unpredictably.", "color": Color("ffe388")},
	Status.DARKNESS: {"name":"Darkness", "icon":"dark", "text":"Attack damage x0.5. Cannot heal. Lose 1 stack each turn.", "color":Color("c18ce8")},
	Status.CORROSION: {"name":"Corrosion", "icon":"acid", "text":"Shields, invincibility and armor do not protect you. Damage taken x1.5. Lose 1 stack each turn.", "color":Color("8ad26a")},
	Status.PLAGUE: {"name":"Plague", "icon":"plague", "text":"Max HP -10 per stack, minimum 1. Gains 1 stack and spreads 1 stack to a random uninfected ally each turn.", "color":Color("93899e")},
	Status.IMMOBILIZED: {"name":"Immobilized", "icon":"broken_shield", "text":"Cannot act for one turn.", "color":Color("dcbf86")},
}
const HELP_TEXT := {
	Status.FROZEN:"Player: tap the ice 3 times to end the turn. Enemies: skip one turn.",
	Status.BURNING:"5 damage per stack each turn. Lose 1 stack per turn; maximum 10 stacks.",
	Status.STUNNED:"Player only. The next throw's Perfect marker moves unpredictably.",
	Status.DARKNESS:"Attack damage x0.5; cannot heal. Lose 1 stack per turn.",
	Status.CORROSION:"No shield, invincibility or armor. Take x1.5 damage. Lose 1 stack per turn.",
	Status.PLAGUE:"Enemies only. Max HP -10/stack (min 1). Gains 1 stack and spreads 1 to a random uninfected ally each turn.",
	Status.IMMOBILIZED:"Skip the next action, then recover. Normal enemies suffer this when their shield breaks; bosses suffer it when their charge is interrupted.",
	Status.HIDDEN:"Untargetable for 3 turns. Using an attack skill breaks invisibility.",
}

static func help_entries() -> Array:
	var items: Array = []
	for id in HELP_TEXT:
		var item: Dictionary = ENTRIES[id].duplicate()
		item.text = HELP_TEXT[id]
		items.append(item)
	return items

static func active(statuses: Dictionary) -> Array:
	var items: Array = []
	for id in ENTRIES:
		if not statuses.has(id) or statuses[id].count <= 0: continue
		var entry: Dictionary = ENTRIES[id].duplicate()
		entry.id = id
		entry.turns = statuses[id].count
		entry.permanent = statuses[id].permanent
		entry.stacking = statuses[id].is_stacking()
		items.append(entry)
	return items

static func remaining(id: int, amount: int) -> String:
	var unit: String = "attack" if id in Status.ATTACK_BOONS else "stack" if id in [Status.BURNING,Status.DARKNESS,Status.CORROSION,Status.PLAGUE] else "throw" if id == Status.STUNNED else "turn"
	return "%d %s%s remaining." % [amount, unit, "" if amount == 1 else "s"]

static func enemy_active(enemy: Dictionary) -> Array:
	# Enemy defenses predate StatusEffect; adapt their live values for one UI list.
	var items: Array = []
	if enemy.get("shield",0) > 0:
		items.append({"id":"enemy_shield","name":"Shield","icon":"shield","color":Color("80d8c6"),"turns":enemy.shield,"permanent":false,"stacking":false,"counter":GameText.format("%d shield",enemy.shield),"badge":str(enemy.shield)})
	if enemy.get("attack_boost",false):
		items.append({"id":"enemy_empower","name":"Attack boost","icon":"attack","color":Color("dfb866"),"turns":1,"permanent":false,"stacking":false,"counter":GameText.text("Next x1.5"),"badge":""})
	if enemy.get("charging",false):
		var total: int = Rules.EnemyCatalog.ITEMS[enemy.role].charge_turns
		items.append({"id":"enemy_charge","name":"Charging","icon":"charge","color":Rules.EnemyCatalog.ITEMS[enemy.role].color,"turns":enemy.charge,"permanent":false,"stacking":false,"counter":"%d / %d" % [enemy.charge,total],"badge":str(enemy.charge)})
	items.append_array(active(enemy.get("statuses",{})))
	return items

static func counter_text(item: Dictionary) -> String:
	if item.has("counter"): return item.counter
	if item.permanent: return GameText.text("Permanent")
	if item.id in Status.ATTACK_BOONS: return GameText.format("%d attack" if item.turns == 1 else "%d attacks",item.turns)
	var unit: String = ("%d stack" if item.turns == 1 else "%d stacks") if item.stacking else ("%d turn" if item.turns == 1 else "%d turns")
	return GameText.format(unit,item.turns)
