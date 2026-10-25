extends RefCounted
## Character-specific straight effects, kept separate from dice selection rules.
const BASE_DAMAGE := 5.0
const BURN_STACKS := 2
const LEFTOVER_HEAL_PER_PIP := 0.01
const MIN_DAMAGE_TICK_INTERVAL := 0.1
const NAMES := ["Fireball", "Fiery Slash", "Fire Storm", "Brimstone"]
const PREVIEWS := ["Single target; +2 Burning.","All enemies; 2x against Burning.","All: 5 hits; 2x vs Burning; then +2 Burning.","All: 10 hits; 2x vs Burning."]
const DESCRIPTIONS := [
	"Single target: (3 + 0.1 x pip sum) x base damage. Then apply 2 Burning.",
	"All enemies: (2 + 0.1 x pip sum) x base damage. Double against Burning enemies.",
	"All enemies: 5 hits at 1.5x base damage each. Double against Burning; apply 2 Burning after all hits.",
	"All enemies: 10 hits at 2x base damage each. Double against Burning enemies."
]

## Repeated damage belongs to one skill use and does not qualify as a combo.
static func damage_tick_count(dice_count: int) -> int:
	return 10 if dice_count == 6 else 5 if dice_count == 5 else 1

## Calculate the character coefficient before ordinary damage modifiers.
static func damage_factor(skill: MultiHitSkill) -> float:
	if skill.pattern == "match_auto":
		return (0.5 + 0.05*skill.face)*(8.0 if skill.dice.size() == 6 else 4.0 if skill.dice.size() == 5 else 1.0)
	if skill.dice.size() == 6: return 2.0
	if skill.dice.size() == 5: return 1.5
	return [3.0,2.0][clampi(skill.dice.size()-3,0,1)] + 0.1*skill.sum

## The first evolution strengthens Fireball/Storm and gives Slash its own Burning.
static func burning_stacks(skill: MultiHitSkill, evolution: int = 0) -> int:
	if skill.pattern != "straight": return 0
	if skill.dice.size() in [3,5]: return BURN_STACKS+(1 if evolution >= 1 else 0)
	if skill.dice.size() == 4 and evolution >= 1: return BURN_STACKS
	return 0

## Storm ignites once after its damage sequence, so its own Burning cannot amplify later pulses.
static func burning_after_cast(skill: MultiHitSkill) -> bool:
	return skill.pattern == "straight" and skill.dice.size() == 5

static func doubles_on_burning(skill: MultiHitSkill) -> bool:
	return skill.pattern == "straight" and skill.dice.size() in [4,5,6]

## Round once after summing all leftovers; no pip is lost between dice.
static func leftover_healing(pips: int, maximum_hp: int) -> int:
	return roundi(pips*LEFTOVER_HEAL_PER_PIP*maximum_hp)

static func caption(skill: MultiHitSkill, evolution: int = 0) -> Dictionary:
	var tier: int = clampi(skill.dice.size()-3,0,3)
	var description: String = DESCRIPTIONS[tier]
	var preview: String = PREVIEWS[tier]
	if evolution >= 1:
		if tier in [0,2]:
			description = description.replace("2 Burning","3 Burning")
			preview = preview.replace("2 Burning","3 Burning")
		elif tier == 1:
			description += " Then apply 2 Burning."
			preview = "All; 2x vs Burning; +2 Burning."
	return {"name":NAMES[tier],"description":description,"preview":preview}
