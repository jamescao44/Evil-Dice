extends RefCounted
## Data from the Mandarin design document, including tarot-related relics.
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, CURSED }
const Sets = preload("res://scripts/relics/relic_sets.gd")
const MAX_SLOTS := 10
const RARITY_WEIGHTS := [58.0, 30.0, 10.0, 1.0, 1.0]
const RARITY_NAMES := ["COMMON", "RARE", "EPIC", "LEGENDARY", "CURSED"]
const COLORS := [Color.WHITE, Color("72bbfe"), Color("c060ff"), Color("f9cb9c"), Color("dd7e6b")]
const STONES := ["orange_stone", "blue_stone", "purple_stone", "yellow_stone", "green_stone", "black_stone"]
const CURSED_DICE := {"cursed_die":6,"cursed_die_5":5,"cursed_die_4":4,"cursed_die_3":3,"cursed_die_2":2,"cursed_die_1":1}
const DISABLED := ["cursed_watch", "cursed_die", "cursed_die_5", "cursed_die_4", "cursed_die_3", "cursed_die_2", "cursed_die_1"]
const ITEMS := {
	"lemon_soda": {"name": "Lemon Soda", "rarity": 0, "icon": "lemon_soda", "text": "Auto-attack damage +20. Meal ingredient."},
	"oreo_sundae": {"name": "Oreo Sundae", "rarity": 1, "icon": "oreo_sundae", "text": "Base damage +20. Meal ingredient."},
	"fried_chicken": {"name": "Fried Chicken", "rarity": 1, "icon": "fried_chicken", "text": "Damage multiplier x1.1. Meal ingredient."},
	"budget_meal": {"name": "Budget Meal", "rarity": 0, "icon": "budget_meal", "text": "Combines two food effects, then adds 10 base damage.", "fusion": true},
	"happy_meal": {"name": "Happy Trio", "rarity": 1, "icon": "happy_meal", "text": "Combines three food effects, then adds 20 base damage.", "fusion": true},
	"deluxe_meal": {"name": "Deluxe Quartet", "rarity": 2, "icon": "deluxe_meal", "text": "Combines four food effects, then adds 20 base damage and +2 damage multiplier.", "fusion": true},
	"super_meal": {"name": "Super Feast", "rarity": 3, "icon": "super_meal", "text": "Combines five food effects, then adds 50 base damage and doubles the damage multiplier.", "fusion": true},

	"codex_page": {"counter":"count", "name":"Codex Page", "rarity":0, "icon":"page", "text":"DMG +0.2 per page. Pages share one slot; 10 fuse into an Ancient Codex."},
	"heart": {"name":"Beating Heart", "rarity":0, "icon":"heart", "text":"Maximum health +10%."},
	"bracelet": {"name":"Spell Bracelet", "rarity":0, "icon":"bracelet", "text":"Base damage +10."},
	"armor": {"name":"Rusty Armor", "rarity":0, "icon":"armor", "text":"Take 10% less damage."},
	"coin": {"name":"Game Coin", "rarity":0, "icon":"coin", "text":"Gain 10 blood gems after clearing a wave."},
	"fortune_cookie": {"name":"Fortune Cookie", "rarity":0, "icon":"cookie", "text":"Receive a random tarot immediately, then another every 5 completed turns."},
	"magic_shield": {"counter":"charges", "name":"Magic Shield", "rarity":1, "icon":"shield", "text":"Every 6 completed turns, store a shield that blocks one whole hit."},
	"magic_sword": {"counter":"charges", "name":"Magic Sword", "rarity":1, "icon":"sword", "text":"Every 6 completed turns, store a 3x critical for the next attack skill and all its hits."},
	"runestone": {"name":"Runestone", "rarity":2, "icon":"rune", "text":"Apply 1 extra stack of harmful status effects."},
	"lucky_die": {"name":"Lucky Die", "rarity":1, "icon":"die", "text":"After 10 throws, the next throw with at least four unused dice guarantees a four-straight. Tarot rules take priority."},
	"bloodstone": {"name":"Bloodstone", "rarity":1, "icon":"blood", "text":"Heal for 20% of attack damage. Cap: 10% max HP, or 5% per combo hit."},
	"twin_scythes": {"name":"Twin Scythes", "rarity":3, "icon":"scythes", "text":"Double the number of hits in combo skills."},
	"contract": {"name":"Last Contract", "rarity":2, "icon":"contract", "text":"Prevent death once and restore 60% max HP. Consumed on use."},
	"crystal_ball": {"name":"Crystal Ball", "rarity":2, "icon":"orb", "text":"Receive a random tarot after every completed turn."},
	"orange_stone": {"name":"Orange Magic Stone", "rarity":2, "icon":"stone", "color":Color("ff9955"), "text":"Immune to freeze. Every attack applies 1 burning stack."},
	"blue_stone": {"name":"Blue Magic Stone", "rarity":2, "icon":"stone", "color":Color("82dfff"), "text":"Immune to burning. Attacks have a 30% chance to freeze."},
	"purple_stone": {"name":"Purple Magic Stone", "rarity":2, "icon":"stone", "color":Color("c18ce8"), "text":"Immune to darkness. Attacks have a 30% chance to inflict darkness."},
	"yellow_stone": {"name":"Yellow Magic Stone", "rarity":2, "icon":"stone", "color":Color("ffe388"), "text":"Immune to stun. Each Perfect adds 2 to the combo counter."},
	"green_stone": {"name":"Green Magic Stone", "rarity":2, "icon":"stone", "color":Color("8ad26a"), "text":"Immune to corrosion. Attacks have a 50% chance to corrode."},
	"black_stone": {"name":"Black Magic Stone", "rarity":2, "icon":"stone", "color":Color("8b8599"), "text":"Every attack applies plague."},
	"prismatic_stone": {"name":"Prismatic Stone", "rarity":3, "icon":"prism", "fusion":true, "text":"All six stone effects. Each Perfect fires a 100-base-damage attack at a random foe."},
	"mithril_blade": {"name":"Mithril Blade", "rarity":3, "icon":"blade", "text":"Base damage +100."},
	"ancient_prophecy": {"name":"Ancient Prophecy", "rarity":3, "icon":"book", "text":"Each tarot activates twice. Make new choices when needed; normal stacking and overwrite rules apply."},
	"ancient_codex": {"name":"Ancient Codex", "rarity":3, "icon":"book", "fusion":true, "text":"Double damage independently. Made by combining 10 Codex Pages."},
	"cursed_skull": {"name":"Cursed Skull", "rarity":4, "icon":"skull", "text":"A skill containing 6 doubles DMG; without 6, halves DMG."},
	"cursed_die": {"name":"Cursed Die - 6", "rarity":4, "icon":"die", "text":"Perfect rolls always contain 6. Other rolls never contain 6."},
	"reaper_scythe": {"counter":"kills", "name":"Reaper's Scythe", "rarity":4, "icon":"scythe", "text":"Each enemy killed multiplies damage by 1.1. Halve max HP. City troops do not count."},
	"cursed_bow": {"counter":"waves", "name":"Cursed Bow", "rarity":4, "icon":"bow", "text":"Each wave cleared while owned adds 1 combo hit and multiplies single-target damage by 0.95. Compounds each wave."},
	"cursed_watch": {"name":"Cursed Stopwatch", "rarity":4, "icon":"watch", "text":"Always Perfect. Never roll 666. Cannot gain Reroll Treasure progress."},
	"worn_dagger": {"name": "Worn Dagger", "rarity": 0, "icon": "worn_dagger", "text": "Combo skills gain 1 extra hit."},
	"worn_bow": {"name": "Worn Longbow", "rarity": 0, "icon": "worn_bow", "text": "After each throw, deal 5 base damage to a random enemy."},
	"four_leaf_clover": {"name": "Four-leaf Clover", "rarity": 1, "icon": "four_leaf_clover", "text": "Each eligible throw has a 10% chance to guarantee at least a four-straight. Tarot rules take priority."},
	"fries": {"name": "Fries", "rarity": 0, "icon": "fries", "text": "Damage multiplier +0.5."},
	"tissue_pack": {"name": "Tissue Pack", "rarity": 0, "icon": "tissue_pack", "text": "After a throw with no playable straight, deal 10 base damage to a random enemy."},
	"pet_bat": {"name": "Pet Bat", "rarity": 0, "icon": "pet_bat", "text": "Heal 5 HP per attack. Combo hits heal separately."},
	"magic_slingshot": {"name": "Magic Slingshot", "rarity": 1, "icon": "magic_slingshot", "text": "After each throw, attack a random enemy for half the rolled pip sum as base damage."},
	"hamburger": {"name": "Hamburger", "rarity": 1, "icon": "hamburger", "text": "Damage multiplier +1."},
	"soul_vessel": {"name": "Soul Vessel", "rarity": 1, "icon": "soul_vessel", "text": "Blood gem gains +15%. Fractional bonuses carry over."},
	"pet_lizard": {"name": "Pet Lizard", "rarity": 1, "icon": "pet_lizard", "text": "Apply 1 extra burning stack to enemies."},
	"ice_rose": {"name": "Ice Rose", "rarity": 1, "icon": "ice_rose", "text": "Freezing an enemy deals 10 base damage to it."},
	"pet_slime": {"name": "Pet Slime", "rarity": 1, "icon": "pet_slime", "text": "Corrosion on enemies becomes permanent."},
	"spiked_helmet": {"name": "Spiked Helmet", "rarity": 1, "icon": "spiked_helmet", "text": "Retaliate for 10 fixed damage when attacked. Each Perfect deals 10 base damage to a random enemy."},
	"royal_dagger": {"name": "Royal Dagger", "rarity": 2, "icon": "royal_dagger", "text": "Combo skills gain 3 extra hits."},
	"disguise_mask": {"name": "Disguise Mask", "rarity": 2, "icon": "disguise_mask", "text": "Retrigger the relic immediately to the left once, except Ancient Tentacle."},
	"five_leaf_clover": {"name": "Five-leaf Clover", "rarity": 2, "icon": "five_leaf_clover", "text": "Each eligible throw has a 5% chance to guarantee at least a five-straight. Tarot rules take priority."},
	"pet_ghost": {"name": "Pet Ghost", "rarity": 2, "icon": "pet_ghost", "text": "After each throw, deal 50 fixed damage to all enemies."},
	"ancient_tentacle": {"name": "Ancient Tentacle", "rarity": 3, "icon": "ancient_tentacle", "text": "Retrigger every relic to the left once."},
	"pet_dragon": {"name": "Pet Dragon", "rarity": 3, "icon": "pet_dragon", "text": "After each throw, attack random enemies twice for 50 base damage each."},
	"cursed_die_5": {"name": "Cursed Die - 5", "rarity": 4, "icon": "cursed_die_5", "text": "Perfect rolls always contain 5. Other rolls never contain 5."},
	"cursed_die_4": {"name": "Cursed Die - 4", "rarity": 4, "icon": "cursed_die_4", "text": "Perfect rolls always contain 4. Other rolls never contain 4."},
	"cursed_die_3": {"name": "Cursed Die - 3", "rarity": 4, "icon": "cursed_die_3", "text": "Perfect rolls always contain 3. Other rolls never contain 3."},
	"cursed_die_2": {"name": "Cursed Die - 2", "rarity": 4, "icon": "cursed_die_2", "text": "Perfect rolls always contain 2. Other rolls never contain 2."},
	"cursed_die_1": {"name": "Cursed Die - 1", "rarity": 4, "icon": "cursed_die_1", "text": "Perfect rolls always contain 1. Other rolls never contain 1."},
}

static func rarity_color(id: String) -> Color:
	return COLORS[ITEMS[id].rarity]

static func color(id: String) -> Color:
	# Element colors tint magic stones and their effects; rarity colors identify loot.
	return ITEMS[id].get("color", rarity_color(id))

static func counter_value(item: Dictionary) -> int:
	var field: String = ITEMS[item.id].get("counter","")
	return maxi(0,int(item.get(field,1 if field == "count" else 0))) if not field.is_empty() else 0

static func charged(item: Dictionary) -> bool:
	return item.get("throws",0) >= 10 if item.id == "lucky_die" else ITEMS[item.id].get("counter","") == "charges" and counter_value(item) > 0

static func description(item: Dictionary, translate: Callable = Callable()) -> String:
	var localize: Callable = translate if translate.is_valid() else func(value: String) -> String: return value
	var text: String = localize.call(ITEMS[item.id].text)
	if item.id in DISABLED: text = localize.call("Temporarily disabled for six-dice turns.") + "\n" + text
	if CURSED_DICE.has(item.id): text += "\n" + localize.call("Only one Cursed Die can be held.")
	if item.id == "codex_page": text += "\n" + localize.call("Pages: %d / 10.") % item.get("count", 1)
	if item.id in ["magic_shield", "magic_sword"]: text += "\n" + localize.call("Turns: %d / 6. Stored charges: %d.") % [item.get("turns", 0),item.get("charges", 0)]
	if item.id == "lucky_die": text += "\n" + localize.call("Throws: %d / 10.") % item.get("throws",0)
	if Sets.is_fused(item.id):
		for id in Sets.ingredients(item): text += "\n" + localize.call(ITEMS[id].name) + ": " + localize.call(ITEMS[id].text)
	if item.id == "fortune_cookie": text += "\n" + localize.call("Turns: %d / 5.") % item.get("turns",0)
	if item.id == "reaper_scythe": text += "\n" + localize.call("Kills: %d.") % item.get("kills", 0)
	if item.id == "cursed_bow":
		text += "\n" + localize.call("Extra hits: %d.") % item.get("waves", 0)
		text += "\n" + localize.call("Single-target damage: x%.3f.") % pow(0.95,item.get("waves",0))
	return text
