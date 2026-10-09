extends RefCounted
## Presentation metadata only. Each model buff owns its own duration and lifetime.
const Rules = preload("res://scripts/battle_rules.gd")
const ENTRIES := {
	2: {"name": Rules.PAIR_NAMES[1], "icon": "heal", "text": "Heal 5 at turn start.", "color": Color("aed085")},
	3: {"name": Rules.PAIR_NAMES[2], "icon": "attack", "text": "1.5x attack power.", "color": Color("dfb866")},
	33: {"name": Rules.SPECIAL_NAMES[2], "icon": "crown", "text": "3x attack power.", "color": Color("c5a4de")},
	6: {"name": Rules.PAIR_NAMES[5], "icon": "shield", "text": "Invincible.", "color": Color("80d8c6")},
}

static func active(buffs: Dictionary) -> Array:
	var items: Array = []
	for id in ENTRIES:
		if int(buffs.get(id, 0)) <= 0: continue
		var entry: Dictionary = ENTRIES[id].duplicate()
		entry.id = id
		entry.turns = int(buffs[id])
		items.append(entry)
	return items
