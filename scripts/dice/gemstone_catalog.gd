extends RefCounted
## One definition supplies gem tiers, drop eligibility, combat hooks and presentation.
const Status = preload("res://scripts/status/status_effect.gd")
const DROP_CHANCE := 0.10
const HELP := "Gemstones enhance matching attacks and straight skills. Equip or merge them in the backpack."
const ITEMS := {
	"burning": {"name":"Burning Gem", "color":Color("ff9b4f"), "icon":"fire", "levels":[1,2,3], "status":Status.BURNING, "attack_hooks":["skill","automatic"], "auto_chance":5, "skill_chance":10, "chance_cap":-1.0, "description":"Matches: %s%%; skills: %s%% chance to apply Burning."},
	"healing": {"name":"Healing Gem", "color":Color("f5a4c6"), "icon":"plus", "levels":[1,2,3], "recovery":"heal", "description":"Heal max HP per pip: matches %s%%; skills %s%%."},
	"corrosive": {"name":"Corrosive Gem", "color":Color("a3df63"), "icon":"acid", "levels":[1,2,3], "status":Status.CORROSION, "attack_hooks":["skill","automatic"], "auto_chance":5, "skill_chance":10, "chance_cap":-1.0, "description":"Matches: %s%%; skills: %s%% chance to apply Corrosion."},
	"guarding": {"name":"Guarding Gem", "color":Color("a8dafa"), "icon":"shield", "levels":[1,2,3], "recovery":"shield", "description":"Gain max-HP shield per pip: matches %s%%; skills %s%%."},
	"freezing": {"name":"Freezing Gem", "color":Color("5ee7ee"), "icon":"ice", "levels":[1,2,3], "status":Status.FROZEN, "attack_hooks":["skill","automatic"], "auto_chance":2.5, "skill_chance":5, "chance_cap":100.0, "description":"Matches: %s%%; skills: %s%% chance to apply Freeze."},
	"plague": {"name":"Plague Gem", "color":Color("45434d"), "icon":"plague", "levels":[1,2,3], "status":Status.PLAGUE, "attack_hooks":["skill","automatic"], "auto_chance":5, "skill_chance":10, "chance_cap":-1.0, "description":"Matches: %s%%; skills: %s%% chance to apply Plague."},
	"darkness": {"name":"Darkness Gem", "color":Color("a36be1"), "icon":"dark", "levels":[1,2,3], "status":Status.DARKNESS, "attack_hooks":["skill","automatic"], "auto_chance":15, "skill_chance":30, "chance_cap":-1.0, "description":"Matches: %s%%; skills: %s%% chance to apply Darkness."},
	"critical": {"name":"Critical Gem", "color":Color("f4f2ec"), "icon":"stars", "levels":[1,2,3], "modifier":"critical", "description":"Combined gem levels: +10% critical chance and +0.1 critical multiplier each; starts at x1.5."},
	"strength": {"name":"Strength Gem", "color":Color("ed454c"), "icon":"sword", "levels":[1,2,3], "modifier":"base", "description":"Combined gem levels: +10% base damage each."},
	"focus": {"name":"Focus Gem", "color":Color("cf417e"), "icon":"boost", "levels":[1,2,3], "modifier":"mult", "description":"Combined gem levels: +10% damage multiplier each."},
	"empower": {"name":"Empowering Gem", "color":Color("f5ce42"), "icon":"boost", "levels":[1,2,3], "modifier":"potency", "description":"Combined gem levels: +10% attack damage or character healing each."},
}

## Catalog order keeps existing seeded rewards stable when definitions are unchanged.
static func ids() -> Array:
	return ITEMS.keys()

## Each gem may gain additional tiers without changing inventory or merge code.
static func max_level(id: String) -> int:
	return ITEMS[id].levels.size() if ITEMS.has(id) else 0

static func valid(gem: Dictionary) -> bool:
	return gem.get("id","") in ITEMS and gem.get("level",0) is int and gem.level > 0 and gem.level <= max_level(gem.id)

static func potency(gem: Dictionary) -> int:
	return ITEMS[gem.id].levels[gem.level-1] if valid(gem) else 0

static func can_merge(gem: Dictionary) -> bool:
	return valid(gem) and gem.level < max_level(gem.id)

static func color(id: String) -> Color:
	return ITEMS[id].color

## Show both source rates from the same metadata used by combat.
static func description(gem: Dictionary) -> String:
	if not valid(gem): return GameText.text("Empty socket")
	var data: Dictionary = ITEMS[gem.id]
	var power: int = potency(gem)
	if data.has("status"):
		return GameText.format(data.description,[str(snappedf(data.auto_chance*power,0.1)),str(snappedf(data.skill_chance*power,0.1))])
	if data.has("recovery"):
		return GameText.format(data.description,[str(power*0.5),str(power)])
	return GameText.text(data.description)
