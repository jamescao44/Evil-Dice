extends RefCounted
## Data from the Mandarin design document. Tarot-dependent entries are excluded.
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, CURSED }
const MAX_SLOTS := 10
const RARITY_WEIGHTS := [45.0, 30.0, 15.0, 5.0, 5.0]
const RARITY_NAMES := ["COMMON", "RARE", "EPIC", "LEGENDARY", "CURSED"]
const COLORS := [Color("b6d7a8"), Color("72bbfe"), Color("b4a7d6"), Color("f9cb9c"), Color("dd7e6b")]
const STONES := ["orange_stone", "blue_stone", "purple_stone", "yellow_stone", "green_stone", "black_stone"]
const ITEMS := {
	"codex_page": {"counter":"count", "name":"Codex Page", "rarity":0, "icon":"page", "text":"DMG +0.2 per page. Pages share one slot; 10 fuse into an Ancient Codex."},
	"heart": {"name":"Beating Heart", "rarity":0, "icon":"heart", "text":"Maximum health +10%."},
	"bracelet": {"name":"Spell Bracelet", "rarity":0, "icon":"bracelet", "text":"Base damage +10."},
	"armor": {"name":"Rusty Armor", "rarity":0, "icon":"armor", "text":"Take 10% less damage."},
	"coin": {"name":"Game Coin", "rarity":0, "icon":"coin", "text":"Gain 10 rubies after clearing a wave."},
	"magic_shield": {"counter":"charges", "name":"Magic Shield", "rarity":1, "icon":"shield", "text":"Every 6 completed turns, store a shield that blocks one whole hit."},
	"magic_sword": {"counter":"charges", "name":"Magic Sword", "rarity":1, "icon":"sword", "text":"Every 6 completed turns, store a 3x critical for the next attack skill and all its hits."},
	"runestone": {"name":"Runestone", "rarity":1, "icon":"rune", "text":"Apply 1 extra stack of harmful status effects."},
	"lucky_die": {"name":"Lucky Die", "rarity":1, "icon":"die", "text":"Chance of a throw containing a 6 increases by 5%."},
	"bloodstone": {"name":"Bloodstone", "rarity":1, "icon":"blood", "text":"Heal for 20% of attack damage. Cap: 10% max HP, or 5% per combo hit."},
	"twin_scythes": {"name":"Twin Scythes", "rarity":2, "icon":"scythes", "text":"Double the number of hits in combo skills."},
	"contract": {"name":"Last Contract", "rarity":2, "icon":"contract", "text":"Prevent death once and restore 60% max HP. Consumed on use."},
	"orange_stone": {"name":"Orange Magic Stone", "rarity":2, "icon":"stone", "color":Color("ff9955"), "text":"Immune to freeze. Every attack applies 1 burning stack."},
	"blue_stone": {"name":"Blue Magic Stone", "rarity":2, "icon":"stone", "color":Color("82dfff"), "text":"Immune to burning. Attacks have a 30% chance to freeze."},
	"purple_stone": {"name":"Purple Magic Stone", "rarity":2, "icon":"stone", "color":Color("c18ce8"), "text":"Immune to darkness. Attacks have a 30% chance to inflict darkness."},
	"yellow_stone": {"name":"Yellow Magic Stone", "rarity":2, "icon":"stone", "color":Color("ffe388"), "text":"Immune to stun. Each Perfect adds 2 to the combo counter."},
	"green_stone": {"name":"Green Magic Stone", "rarity":2, "icon":"stone", "color":Color("8ad26a"), "text":"Immune to corrosion. Attacks have a 50% chance to corrode."},
	"black_stone": {"name":"Black Magic Stone", "rarity":2, "icon":"stone", "color":Color("8b8599"), "text":"Every attack applies plague."},
	"prismatic_stone": {"name":"Prismatic Stone", "rarity":3, "icon":"prism", "fusion":true, "text":"All six stone effects. Each Perfect fires a 100-base-damage attack at a random foe."},
	"mithril_blade": {"name":"Mithril Blade", "rarity":3, "icon":"blade", "text":"Base damage +100."},
	"ancient_codex": {"name":"Ancient Codex", "rarity":3, "icon":"book", "fusion":true, "text":"Double damage independently. Made by combining 10 Codex Pages."},
	"cursed_skull": {"name":"Cursed Skull", "rarity":4, "icon":"skull", "text":"A skill containing 6 doubles DMG; without 6, halves DMG."},
	"cursed_die": {"name":"Cursed Die - 6", "rarity":4, "icon":"die", "text":"Perfect rolls always contain 6. Other rolls never contain 6."},
	"reaper_scythe": {"counter":"kills", "name":"Reaper's Scythe", "rarity":4, "icon":"scythe", "text":"Each enemy killed multiplies damage by 1.1. Halve max HP. City troops do not count."},
	"cursed_bow": {"counter":"waves", "name":"Cursed Bow", "rarity":4, "icon":"bow", "text":"Each wave cleared adds 1 combo hit. Single-target damage x0.95."},
	"cursed_watch": {"name":"Cursed Stopwatch", "rarity":4, "icon":"watch", "text":"Always Perfect. Never roll 666. Perfects cannot advance the treasure bank."},
}

static func color(id: String) -> Color:
	return ITEMS[id].get("color", COLORS[ITEMS[id].rarity])

static func counter_value(item: Dictionary) -> int:
	var field: String = ITEMS[item.id].get("counter","")
	return maxi(0,int(item.get(field,1 if field == "count" else 0))) if not field.is_empty() else 0

static func charged(item: Dictionary) -> bool:
	return ITEMS[item.id].get("counter","") == "charges" and counter_value(item) > 0

static func description(item: Dictionary, translate: Callable = Callable()) -> String:
	var localize: Callable = translate if translate.is_valid() else func(value: String) -> String: return value
	var text: String = localize.call(ITEMS[item.id].text)
	if item.id == "codex_page": text += "\n" + localize.call("Pages: %d / 10.") % item.get("count", 1)
	if item.id in ["magic_shield", "magic_sword"]: text += "\n" + localize.call("Turns: %d / 6. Stored charges: %d.") % [item.get("turns", 0),item.get("charges", 0)]
	if item.id == "reaper_scythe": text += "\n" + localize.call("Kills: %d.") % item.get("kills", 0)
	if item.id == "cursed_bow": text += "\n" + localize.call("Extra hits: %d.") % item.get("waves", 0)
	return text
