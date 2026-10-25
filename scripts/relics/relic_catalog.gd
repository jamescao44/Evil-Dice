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
const DISABLED := ["cursed_watch", "cursed_die_5", "cursed_die_4", "cursed_die_3", "cursed_die_2", "cursed_die_1"]
const ITEMS := {
	"mystery_potion": {"name": "Mysterious Potion", "rarity": 0, "icon": "mystery_potion", "text": "Attacks have a 10% chance to apply 1 random status stack."},
	"ticket": {"name": "Ticket", "rarity": 0, "icon": "ticket", "text": "Gain 1 extra roll each turn. Spent last; does not earn treasure progress."},
	"banana": {"name": "Banana", "rarity": 0, "icon": "banana", "text": "Damage multiplier +0.5. 20% chance to disappear at turn end."},
	"unknown_arm": {"name": "Unidentified Arm", "rarity": 0, "icon": "unknown_arm", "text": "After each throw, deal 5 base damage to a random enemy."},
	"unknown_pelvis": {"name": "Unidentified Pelvis", "rarity": 0, "icon": "unknown_pelvis", "text": "After each throw, deal 5 base damage to a random enemy."},
	"unknown_leg": {"name": "Unidentified Leg Bone", "rarity": 0, "icon": "unknown_leg", "text": "After each throw, deal 5 base damage to a random enemy."},
	"broken_blade": {"name": "Broken Blade", "rarity": 1, "icon": "broken_blade", "text": "Damage multiplier +0.3."},
	"broken_hilt": {"name": "Broken Hilt", "rarity": 1, "icon": "broken_hilt", "text": "A broken sword handle."},
	"precognition_eye": {"name": "Precognition Eye", "rarity": 1, "icon": "precognition_eye", "text": "Each tarot used while held permanently adds +0.05 damage multiplier to this relic."},
	"frozen_tilapia": {"name": "Frozen Tilapia", "rarity": 1, "icon": "frozen_tilapia", "text": "At player-turn end, attack a random enemy for the leftover pip sum as base damage."},
	"unknown_sternum": {"name": "Unidentified Sternum", "rarity": 1, "icon": "unknown_sternum", "text": "After each throw, deal 10 base damage to a random enemy."},
	"unknown_skull": {"name": "Unidentified Skull", "rarity": 1, "icon": "unknown_skull", "text": "After each throw, deal 10 base damage to a random enemy."},
	"magic_banana": {"name": "Magic Banana", "rarity": 2, "icon": "magic_banana", "text": "Damage multiplier x1.5. 1% chance to disappear at turn end."},
	"general_sword": {"name": "General's Sword", "rarity": 2, "icon": "general_sword", "text": "Fuse both broken sword parts. Damage multiplier +2.", "fusion": true},
	"red_chip": {"name": "Enchanted Chip - Red", "rarity": 2, "icon": "red_chip", "text": "After a throw, cast its longest straight at 30% base damage without spending dice."},
	"blue_chip": {"name": "Enchanted Chip - Blue", "rarity": 2, "icon": "blue_chip", "text": "After a throw, cast its shortest straight at 30% base damage without spending dice."},
	"black_chip": {"name": "Enchanted Chip - Black", "rarity": 2, "icon": "black_chip", "text": "A throw with no straight grants +5 damage multiplier until the next throw or turn end."},
	"unidentified_ring": {"name": "Unidentified Ring", "rarity": 2, "icon": "unidentified_ring", "text": "Appears in rewards after gathering all five bones."},
	"hellfire": {"name": "Hellfire", "rarity": 3, "icon": "hellfire", "text": "Burning enemies take 30% more damage."},
	"nightmare_totem": {"name": "Nightmare Totem", "rarity": 3, "icon": "nightmare_totem", "text": "Enemies in Darkness take 30% more damage."},
	"corrupt_crystal": {"name": "Corrupted Crystal", "rarity": 3, "icon": "corrupt_crystal", "text": "Corroded enemies take 30% more damage."},
	"potion_x": {"name": "Potion X", "rarity": 3, "icon": "potion_x", "text": "At 10 Plague, kill the enemy; bosses lose 30% of current HP. Once per enemy or boss phase."},
	"witch_ghost": {"name": "Ghost of the Witch", "rarity": 3, "icon": "witch_ghost", "text": "Fuse all six Remains. After each throw, deal 50 base damage to a random enemy.", "fusion": true},
	"holy_grail": {"name": "Holy Grail", "rarity": 4, "icon": "holy_grail", "text": "Item damage x2. Skill damage x0.5."},
	"vodka": {"name":"Vodka", "rarity":1, "icon":"vodka", "text":"Enemy Burning damage x2."},
	"mysterious_seed": {"name":"Mysterious Seed", "rarity":1, "icon":"mysterious_seed", "text":"Store twice your overhealing as base damage. Fire at a random enemy at player-turn end."},
	"magic_bandage": {"name":"Magic Bandage", "rarity":1, "icon":"magic_bandage", "text":"If a turn starts below full HP, healing is doubled for that turn."},
	"steel_sword": {"name":"Steel Sword", "rarity":2, "icon":"steel_sword", "text":"Damage multiplier +3."},
	"split_arrow": {"name":"Split Arrow", "rarity":2, "icon":"split_arrow", "text":"Single-target skills split into two random hits at 50% damage each."},
	"pet_orb": {"name":"Super Pet Ball", "rarity":3, "icon":"pet_orb", "fusion":true, "text":"Fuse all five pets, keeping their upgraded effects."},
	"book_of_dead": {"name":"Book of the Dead", "rarity":4, "icon":"book_of_dead", "text":"Maximum HP x3. Lose 30% of current HP at turn end; cannot kill you."},
	"glass_marble": {"name":"Glass Marble", "rarity":0, "icon":"glass_marble", "text":"Three-straight skill damage +10%. Marble bonuses add together."},
	"blood_bag": {"name":"Blood Bag", "rarity":0, "icon":"blood_bag", "text":"Healing and lifesteal +10%."},
	"piggy_bank": {"counter":"savings", "name":"Piggy Bank", "rarity":0, "icon":"piggy_bank", "text":"Store an extra 20% of enemy blood gem drops in this relic's sale value."},
	"bookmark": {"name":"Bookmark", "rarity":0, "icon":"bookmark", "text":"Gain 10 shield when using a tarot."},
	"cross": {"name":"Cross", "rarity":1, "icon":"cross", "text":"Enemy tarot drop chance +5 percentage points."},
	"light_sword": {"name":"Light Sword", "rarity":1, "icon":"light_sword", "text":"Damage multiplier +2 while only one enemy remains."},
	"steel_marble": {"name":"Steel Marble", "rarity":1, "icon":"steel_marble", "text":"Three-straight skill damage +20%. Marble bonuses add together."},
	"perfectionist": {"counter":"charges", "name":"Perfectionism", "rarity":1, "icon":"perfectionist", "text":"Three consecutive Perfect throws protect your combo from one miss. Stores one protection."},
	"overflow_prism": {"name":"Overflow Prism", "rarity":2, "icon":"overflow_prism", "text":"Transfer 50% of excess killing damage to a random enemy."},
	"gold_marble": {"name":"Golden Marble", "rarity":2, "icon":"gold_marble", "text":"Three-straight skill damage +30%. Marble bonuses add together."},
	"powder_keg": {"name":"Powder Keg", "rarity":2, "icon":"powder_keg", "text":"At 10 Burning, consume 5 stacks and explode for 3x base damage to all enemies."},
	"echo_bell": {"name":"Echo Bell", "rarity":2, "icon":"echo_bell", "text":"Every third skill repeats at 50% effect. The repeat does not count as a skill cast."},
	"alternating_gears": {"name":"Alternating Gears", "rarity":2, "icon":"alternating_gears", "text":"Skill damage +50% when its type differs from the previous skill."},
	"enchanted_missile": {"name":"Enchanted Missile", "rarity":3, "icon":"enchanted_missile", "fusion":true, "text":"Fuse three marbles and Magic Slingshot. Base damage +10; three-straight damage +100%. Fire a half-pip-sum attack after each throw. At turn start, cast your character's 3-4-5 straight skill."},
	"royal_seal": {"name":"Royal Seal", "rarity":3, "icon":"royal_seal", "text":"Your first manual skill each wave casts one tier higher, up to a six-straight."},
	"magician_hat": {"name":"Magician's Hat", "rarity":3, "icon":"magician_hat", "text":"Receive a Magician tarot immediately, then another every 4 completed turns."},
	"lemon_soda": {"name": "Lemon Soda", "rarity": 0, "icon": "lemon_soda", "text": "Auto-attack damage +5. Meal ingredient."},
	"oreo_sundae": {"name": "Cookie Sundae", "rarity": 1, "icon": "oreo_sundae", "text": "Base damage +10. Meal ingredient."},
	"fried_chicken": {"name": "Fried Chicken", "rarity": 1, "icon": "fried_chicken", "text": "Damage multiplier x1.1. Meal ingredient."},
	"budget_meal": {"name": "Budget Meal", "rarity": 0, "icon": "budget_meal", "text": "Combines two food effects, then adds +0.3 damage multiplier.", "fusion": true},
	"happy_meal": {"name": "Happy Trio", "rarity": 1, "icon": "happy_meal", "text": "Combines three food effects, then adds +0.5 damage multiplier.", "fusion": true},
	"deluxe_meal": {"name": "Deluxe Quartet", "rarity": 2, "icon": "deluxe_meal", "text": "Combines four food effects, then adds 8 base damage and +0.5 damage multiplier.", "fusion": true},
	"super_meal": {"name": "Super Feast", "rarity": 3, "icon": "super_meal", "text": "Combines five food effects, then adds 15 base damage and multiplies damage by 1.3.", "fusion": true},

	"codex_page": {"counter":"count", "name":"Codex Page", "rarity":0, "icon":"page", "text":"DMG +0.2 per page. Pages share one slot; 10 fuse into an Ancient Codex."},
	"heart": {"name":"Beating Heart", "rarity":0, "icon":"heart", "text":"Maximum health +10%."},
	"bracelet": {"name":"Spell Bracelet", "rarity":0, "icon":"bracelet", "text":"Base damage +5."},
	"armor": {"name":"Rusty Armor", "rarity":0, "icon":"armor", "text":"Take 10% less damage."},
	"coin": {"name":"Game Coin", "rarity":0, "icon":"coin", "text":"Gain 10 blood gems after clearing a wave."},
	"fortune_cookie": {"name":"Fortune Cookie", "rarity":0, "icon":"cookie", "text":"Receive a random tarot immediately, then another every 5 completed turns."},
	"magic_shield": {"counter":"charges", "name":"Magic Shield", "rarity":1, "icon":"shield", "text":"Every 6 completed turns, store a shield that blocks one whole hit."},
	"magic_sword": {"counter":"charges", "name":"Magic Sword", "rarity":2, "icon":"sword", "text":"Base damage +10. Every 6 completed turns, store a 3x critical for the next attack skill and all its hits."},
	"runestone": {"name":"Runestone", "rarity":2, "icon":"rune", "text":"Base damage +5. Apply 1 extra stack of harmful status effects."},
	"lucky_die": {"name":"Lucky Die", "rarity":1, "icon":"die", "text":"After 10 throws, the next throw with at least four unused dice guarantees a four-straight. Tarot rules take priority."},
	"bloodstone": {"name":"Bloodstone", "rarity":1, "icon":"blood", "text":"Heal for 20% of attack damage. Cap: 10% max HP, or 5% per combo hit."},
	"twin_scythes": {"name":"Twin Scythes", "rarity":3, "icon":"scythes", "text":"Double the number of hits in combo skills."},
	"contract": {"name":"Last Contract", "rarity":2, "icon":"contract", "text":"Base damage +20%. Prevent death once and restore 60% max HP. Consumed on use."},
	"crystal_ball": {"name":"Crystal Ball", "rarity":3, "icon":"orb", "text":"At turn start, receive a random projection tarot. Unused projections vanish at turn end."},
	"orange_stone": {"name":"Fire Stone", "rarity":2, "icon":"stone", "color":Color("ff9955"), "text":"Base damage +5. Immune to burning. Every attack applies 1 burning stack."},
	"blue_stone": {"name":"Ice Stone", "rarity":2, "icon":"stone", "color":Color("82dfff"), "text":"Base damage +5. Immune to freeze. Attacks have a 30% chance to freeze."},
	"purple_stone": {"name":"Dark Stone", "rarity":2, "icon":"stone", "color":Color("c18ce8"), "text":"Base damage +5. Immune to darkness. Attacks have a 30% chance to inflict darkness."},
	"yellow_stone": {"name":"Mind Stone", "rarity":2, "icon":"stone", "color":Color("ffe388"), "text":"Base damage +5. Immune to stun. Each Perfect adds 2 to the combo counter."},
	"green_stone": {"name":"Corruption Stone", "rarity":2, "icon":"stone", "color":Color("8ad26a"), "text":"Base damage +5. Immune to corrosion. Attacks have a 50% chance to corrode."},
	"black_stone": {"name":"Plague Stone", "rarity":2, "icon":"stone", "color":Color("8b8599"), "text":"Base damage +5. Every attack applies plague."},
	"prismatic_stone": {"name":"Prismatic Stone", "rarity":3, "icon":"prism", "fusion":true, "text":"Base damage +30. All six stone effects. Each Perfect fires a 100-base-damage attack at a random foe."},
	"mithril_blade": {"name":"Mithril Blade", "rarity":3, "icon":"blade", "text":"Damage multiplier x2 (+100%)."},
	"ancient_prophecy": {"name":"Ancient Prophecy", "rarity":3, "icon":"book", "text":"Each tarot activates twice. Make new choices when needed; normal stacking and overwrite rules apply."},
	"ancient_codex": {"name":"Ancient Codex", "rarity":3, "icon":"book", "fusion":true, "text":"Double damage independently. Made by combining 10 Codex Pages."},
	"cursed_skull": {"name":"Cursed Skull", "rarity":4, "icon":"skull", "text":"A skill containing 6 doubles DMG; without 6, halves DMG."},
	"cursed_die": {"name":"Cursed Die", "rarity":4, "icon":"die", "text":"Three visible sixes turn all dice into sixes. No skills while no six is visible."},
	"reaper_scythe": {"counter":"kills", "name":"Cursed Scythe", "rarity":4, "icon":"scythe", "text":"Each kill adds +5% damage, up to +200%. Halve max HP. City troops do not count."},
	"cursed_bow": {"counter":"waves", "name":"Cursed Bow", "rarity":4, "icon":"bow", "text":"Each wave cleared while owned adds 1 combo hit and multiplies single-target damage by 0.95. Compounds each wave."},
	"cursed_watch": {"name":"Cursed Stopwatch", "rarity":4, "icon":"watch", "text":"Always Perfect. Never roll 666. Cannot gain Reroll Treasure progress."},
	"worn_dagger": {"name": "Worn Dagger", "rarity": 0, "icon": "worn_dagger", "text": "Base damage +2. Combo skills gain 1 extra hit."},
	"worn_bow": {"name": "Worn Longbow", "rarity": 0, "icon": "worn_bow", "text": "After each throw, deal 5 base damage to a random enemy."},
	"three_leaf_clover": {"name":"Three-leaf Clover", "rarity":0, "icon":"three_leaf_clover", "text":"Each eligible throw has a 20% chance to guarantee at least a three-straight. Tarot rules take priority."},
	"four_leaf_clover": {"name": "Four-leaf Clover", "rarity": 1, "icon": "four_leaf_clover", "text": "Each eligible throw has a 10% chance to guarantee at least a four-straight. Tarot rules take priority."},
	"fries": {"name": "Fries", "rarity": 0, "icon": "fries", "text": "Damage multiplier +0.3."},
	"tissue_pack": {"name": "Tissue Pack", "rarity": 0, "icon": "tissue_pack", "text": "After a throw with no playable straight, deal 10 base damage to a random enemy."},
	"pet_bat": {"name": "Pet Bat", "rarity": 0, "icon": "pet_bat", "text": "Heal 1% max HP per attack. With all five pets: 2%."},
	"magic_slingshot": {"name": "Magic Slingshot", "rarity": 1, "icon": "magic_slingshot", "text": "Base damage +5. After each throw, attack a random enemy for half the rolled pip sum as base damage."},
	"hamburger": {"name": "Hamburger", "rarity": 1, "icon": "hamburger", "text": "Damage multiplier +0.6."},
	"soul_vessel": {"name": "Soul Vessel", "rarity": 1, "icon": "soul_vessel", "text": "Souls dropped by enemies +15%."},
	"pet_lizard": {"name": "Pet Lizard", "rarity": 1, "icon": "pet_lizard", "text": "Apply 2 extra Burning stacks. With all five pets: 4."},
	"ice_rose": {"name": "Ice Rose", "rarity": 1, "icon": "ice_rose", "text": "Freezing an enemy deals 10 base damage to it."},
	"pet_slime": {"name": "Pet Slime", "rarity": 1, "icon": "pet_slime", "text": "Enemy Corrosion becomes permanent. With all five pets: skill hits apply 1 Corrosion."},
	"spiked_helmet": {"name": "Spiked Helmet", "rarity": 1, "icon": "spiked_helmet", "text": "Retaliate for 10 fixed damage when attacked. Each Perfect deals 10 base damage to a random enemy."},
	"royal_dagger": {"name": "Royal Dagger", "rarity": 2, "icon": "royal_dagger", "text": "Base damage +10. Combo skills gain 3 extra hits."},
	"disguise_mask": {"name": "Disguise Mask", "rarity": 2, "icon": "disguise_mask", "text": "Retrigger the relic immediately to the left once, except Ancient Tentacle."},
	"five_leaf_clover": {"name": "Five-leaf Clover", "rarity": 2, "icon": "five_leaf_clover", "text": "Each eligible throw has a 5% chance to guarantee at least a five-straight. Tarot rules take priority."},
	"pet_ghost": {"name": "Pet Ghost", "rarity": 2, "icon": "pet_ghost", "text": "After each throw, deal 20 fixed damage to all enemies. With all five pets: also use the damage multiplier."},
	"ancient_tentacle": {"name": "Ancient Tentacle", "rarity": 3, "icon": "ancient_tentacle", "text": "Retrigger every relic to the left once."},
	"pet_dragon": {"name": "Pet Dragon", "rarity": 3, "icon": "pet_dragon", "text": "After each throw, fire two random 15-base attacks. With all five pets: three attacks, each applying 1 Burning."},
	"cursed_die_5": {"name": "Cursed Die - 5", "rarity": 4, "icon": "cursed_die_5", "text": "Perfect rolls always contain 5. Other rolls never contain 5."},
	"cursed_die_4": {"name": "Cursed Die - 4", "rarity": 4, "icon": "cursed_die_4", "text": "Perfect rolls always contain 4. Other rolls never contain 4."},
	"cursed_die_3": {"name": "Cursed Die - 3", "rarity": 4, "icon": "cursed_die_3", "text": "Perfect rolls always contain 3. Other rolls never contain 3."},
	"cursed_die_2": {"name": "Cursed Die - 2", "rarity": 4, "icon": "cursed_die_2", "text": "Perfect rolls always contain 2. Other rolls never contain 2."},
	"cursed_die_1": {"name": "Cursed Die - 1", "rarity": 4, "icon": "cursed_die_1", "text": "Perfect rolls always contain 1. Other rolls never contain 1."},
}

static func rarity_color(id: String) -> Color:
	return COLORS[ITEMS[id].rarity]

## Base salvage follows rarity; stacked pages pay once per page, fusions as one item.
static func forfeit_value(id: String, count: int = 1) -> int:
	if not ITEMS.has(id): return 0
	return [10,30,80,120,120][ITEMS[id].rarity]*maxi(1,count)

## Owned savings are paid only when this particular inventory instance leaves.
static func sale_value(item: Dictionary) -> int:
	return forfeit_value(item.id,item.get("count",1))+floori(item.get("savings",0.0)+0.000001)

static func color(id: String) -> Color:
	# Element colors tint magic stones and their effects; rarity colors identify loot.
	return ITEMS[id].get("color", rarity_color(id))

static func counter_value(item: Dictionary) -> int:
	var field: String = ITEMS[item.id].get("counter","")
	return maxi(0,int(item.get(field,1 if field == "count" else 0))) if not field.is_empty() else 0

static func charged(item: Dictionary) -> bool:
	return item.get("throws",0) >= 10 if item.id == "lucky_die" else ITEMS[item.id].get("counter","") == "charges" and counter_value(item) > 0

static func description(item: Dictionary, translate: Callable = Callable()) -> String:
	var localize: Callable = translate
	if not localize.is_valid(): localize = _untranslated
	var text: String = short_description(item.id,localize)
	if item.id in DISABLED: text = localize.call("Temporarily disabled for six-dice turns.") + "\n" + text
	if CURSED_DICE.has(item.id): text += "\n" + localize.call("Only one Cursed Die can be held.")
	if item.id == "codex_page": text += "\n" + localize.call("Pages: %d / 10.") % item.get("count", 1)
	if item.id in ["magic_shield", "magic_sword"]: text += "\n" + localize.call("Turns: %d / 6. Stored charges: %d.") % [item.get("turns", 0),item.get("charges", 0)]
	if item.id == "lucky_die": text += "\n" + localize.call("Throws: %d / 10.") % item.get("throws",0)
	if Sets.is_fused(item.id) and Sets.recipe_for(item.id).get("retain_effects",true):
		for id in Sets.ingredients(item): text += "\n" + localize.call(ITEMS[id].name) + ": " + localize.call(ITEMS[id].text)
	if item.id == "fortune_cookie": text += "\n" + localize.call("Turns: %d / 5.") % item.get("turns",0)
	if item.id == "magician_hat": text += "\n" + localize.call("Turns: %d / 4.") % item.get("turns",0)
	if item.id == "piggy_bank": text += "\n" + localize.call("Saved blood gems: %d.") % floori(item.get("savings",0.0))
	if item.id == "precognition_eye": text += "\n" + localize.call("Stored multiplier: +%.2f.") % item.get("damage_growth",0.0)
	if item.id == "echo_bell": text += "\n" + localize.call("Skills: %d / 3.") % item.get("casts",0)
	if item.id == "reaper_scythe": text += "\n" + localize.call("Kills: %d.") % item.get("kills", 0)
	if item.id == "cursed_bow":
		text += "\n" + localize.call("Extra hits: %d.") % item.get("waves", 0)
		text += "\n" + localize.call("Single-target damage: x%.3f.") % pow(0.95,item.get("waves",0))
	return text

## Reuse set hints in compact offers and full inventory descriptions.
static func short_description(id: String, translate: Callable = Callable()) -> String:
	var localize: Callable = translate
	if not localize.is_valid(): localize = _untranslated
	var text: String = localize.call(ITEMS[id].text)
	var set_title: String = Sets.set_label(id)
	if not set_title.is_empty():
		var label: String = localize.call("(Set: %s)") % localize.call(set_title)
		text = text + "\n" + label
	return text

## Identity translator keeps catalogue helpers usable outside the UI.
static func _untranslated(value: String) -> String:
	return value
