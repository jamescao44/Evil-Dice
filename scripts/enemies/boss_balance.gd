extends RefCounted
## Boss pacing is tuned independently of ordinary enemy HP/damage and elite modifiers.
const HEALTH_PER_LEVEL := 1.20
const PROFILES := {
	"Knight Commander":{"health":0.56,"phase_two_health":0.36,"damage_percent":20.0},
	"Elf Spellsword":{"health":0.55,"damage_percent":20.0},
	"Fanatical Mage":{"health":0.80,"damage_percent":30.0,"summon_health":{"Bound Demon":0.15,"default":1.0},"summon_damage_percent":{"Octopus Minion":6.0,"Abyssal Tentacle":6.0,"Bound Demon":30.0}},
}

## Phase budgets may differ when reinforcements or new moves add pressure.
static func health_scale(name: String, level: int, phase: int = 1) -> float:
	var profile: Dictionary = PROFILES[name]
	var factor: float = profile.get("phase_two_health",profile.health) if phase == 2 else profile.health
	return pow(HEALTH_PER_LEVEL,maxi(0,level-1))*factor

## Boss attacks use a separately authored same-level percentage budget.
static func damage_percent(name: String) -> float:
	return PROFILES[name].damage_percent

## Summons share the level-gap rule but have their own pressure budget.
static func summon_damage_percent(owner_name: String, unit_name: String, fallback: float) -> float:
	return PROFILES[owner_name].get("summon_damage_percent",{}).get(unit_name,fallback)

## Boss adds have their own durability budget; ordinary versions are unaffected.
static func summon_health_scale(owner_name: String, unit_name: String, level: int) -> float:
	var summons: Dictionary = PROFILES[owner_name].get("summon_health",{})
	var factor: float = summons.get(unit_name,summons.get("default",1.0))
	return pow(HEALTH_PER_LEVEL,maxi(0,level-1))*factor
