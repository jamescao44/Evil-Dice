extends RefCounted
## Character-specific straight effects, kept separate from dice selection rules.
const BASE_DAMAGE := 5.0
const BURN_STACKS := 2
const LEFTOVER_HEAL_PER_PIP := 0.01
const NAMES := ["Fireball", "Fiery Slash", "Fire Storm", "Brimstone"]
const PREVIEWS := ["Single target; +2 Burning.","All enemies; 2x against Burning.","All; 2x vs Burning; +2 Burning.","Destroy all enemies."]
const DESCRIPTIONS := [
	"Single target: (3 + 0.1 x pip sum) x base damage. Then apply 2 Burning.",
	"All enemies: (2 + 0.1 x pip sum) x base damage. Double against Burning enemies.",
	"All enemies: (5 + 0.1 x pip sum) x base damage. Double against Burning enemies, then apply 2 Burning.",
	"Destroy all enemies, ignoring shields."
]

## Calculate the character coefficient before ordinary damage modifiers.
static func damage_factor(skill: MultiHitSkill) -> float:
	if skill.pattern == "match_auto": return 0.5 + 0.1*skill.face
	return [3.0,2.0,5.0,0.0][clampi(skill.dice.size()-3,0,3)] + 0.1*skill.sum

static func burns_after_hit(skill: MultiHitSkill) -> bool:
	return skill.pattern == "straight" and skill.dice.size() in [3,5]

static func doubles_on_burning(skill: MultiHitSkill) -> bool:
	return skill.pattern == "straight" and skill.dice.size() in [4,5]

## Round once after summing all leftovers; no pip is lost between dice.
static func leftover_healing(pips: int, maximum_hp: int) -> int:
	return roundi(pips*LEFTOVER_HEAL_PER_PIP*maximum_hp)

static func caption(skill: MultiHitSkill) -> Dictionary:
	var tier: int = clampi(skill.dice.size()-3,0,3)
	return {"name":NAMES[tier],"description":DESCRIPTIONS[tier],"preview":PREVIEWS[tier]}
