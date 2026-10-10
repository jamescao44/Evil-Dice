extends RefCounted
## Shared presentation metadata for boons and harmful status objects.
const Rules = preload("res://scripts/battle_rules.gd")
const Status = preload("res://scripts/status_effect.gd")
const ENTRIES := {
	2: {"name": Rules.PAIR_NAMES[1], "icon": "heal", "text": "Heal 5 at turn start.", "color": Color("aed085")},
	3: {"name": Rules.PAIR_NAMES[2], "icon": "attack", "text": "1.5x attack power.", "color": Color("dfb866")},
	33: {"name": Rules.SPECIAL_NAMES[2], "icon": "crown", "text": "3x attack power.", "color": Color("c5a4de")},
	6: {"name": Rules.PAIR_NAMES[5], "icon": "shield", "text": "Invincible.", "color": Color("80d8c6")},
	Status.FROZEN: {"name": "Frozen", "icon": "ice", "text": "Tap the ice 3 times to break free and end your turn.", "color": Color("82dfff")},
	Status.BURNING: {"name": "Burning", "icon": "fire", "text": "1 damage per stack after enemies act; lose 1 stack each turn.", "color": Color("ff9955")},
	Status.STUNNED: {"name": "Stunned", "icon": "stars", "text": "The next throw's power marker moves unpredictably.", "color": Color("ffe388")},
}

static func active(statuses: Dictionary) -> Array:
	var items: Array = []
	for id in ENTRIES:
		if not statuses.has(id) or statuses[id].count <= 0: continue
		var entry: Dictionary = ENTRIES[id].duplicate()
		entry.id = id
		entry.turns = statuses[id].count
		entry.stacking = statuses[id].is_stacking()
		items.append(entry)
	return items

static func remaining(id: int, amount: int) -> String:
	var unit: String = "stack" if id == Status.BURNING else "throw" if id == Status.STUNNED else "turn"
	return "%d %s%s remaining." % [amount, unit, "" if amount == 1 else "s"]
