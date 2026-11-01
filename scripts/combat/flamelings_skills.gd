extends RefCounted
## Character-specific straight effects, kept separate from dice selection rules.
const Auto = preload("res://scripts/combat/flamelings_auto.gd")
const BASE_DAMAGE := 5.0
const BURN_STACKS := 2
const MIN_DAMAGE_TICK_INTERVAL := 0.1
const NAMES := ["Fireball", "Fiery Slash", "Fire Storm", "Brimstone"]
const DESCRIPTIONS := [
	"Hit a random foe. Apply 2 Burning.",
	"Hit all foes. Double damage against Burning foes.",
	"Hit all foes 5 times. Double damage against Burning foes; apply 2 Burning after all hits.",
	"Hit all foes 10 times. Double damage against Burning foes."
]

## Only this character's two sustained fire spells replace lethal hits with dust deaths.
static func death_source(skill: MultiHitSkill) -> String:
	if skill.pattern != "straight": return ""
	return "fire_storm" if skill.dice.size() == 5 else "brimstone" if skill.dice.size() == 6 else ""

## Repeated damage belongs to one skill use and does not qualify as a combo.
static func damage_tick_count(dice_count: int) -> int:
	return 10 if dice_count == 6 else 5 if dice_count == 5 else 1

## Calculate the character coefficient before ordinary damage modifiers.
static func damage_factor(skill: MultiHitSkill) -> float:
	if skill.pattern == "match_auto":
		return Auto.damage_factor(skill.dice.size(),skill.face)
	if skill.dice.size() == 6: return 2.0
	if skill.dice.size() == 5: return 1.5
	return [3.0,2.0][clampi(skill.dice.size()-3,0,1)] + 0.1*skill.sum

## The first evolution strengthens Fireball/Storm and gives Slash its own Burning.
static func burning_stacks(skill: MultiHitSkill, evolution: int = 0) -> int:
	if skill.pattern == "match_auto": return Auto.profile(skill.dice.size()).burn
	if skill.pattern != "straight": return 0
	if skill.dice.size() in [3,5]: return BURN_STACKS+(1 if evolution >= 1 else 0)
	if skill.dice.size() == 4 and evolution >= 1: return BURN_STACKS
	return 0

## Storm ignites once after its damage sequence, so its own Burning cannot amplify later pulses.
static func burning_after_cast(skill: MultiHitSkill) -> bool:
	return skill.pattern == "straight" and skill.dice.size() == 5

static func doubles_on_burning(skill: MultiHitSkill) -> bool:
	return skill.pattern == "straight" and skill.dice.size() in [4,5,6]

static func caption(skill: MultiHitSkill, evolution: int = 0) -> Dictionary:
	var tier: int = clampi(skill.dice.size()-3,0,3)
	var description: String = DESCRIPTIONS[tier]
	if evolution >= 1:
		if tier in [0,2]:
			description = description.replace("2 Burning","3 Burning")
		elif tier == 1:
			description += " Then apply 2 Burning."
	return {"name":NAMES[tier],"description":description,"preview":description}
