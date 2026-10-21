extends RefCounted
## Shared pattern colors and effect strength for dice, previews and summoned skills.
const MATCH_COLORS := [Color.WHITE, Color("63b7ff"), Color("c278ff"), Color("ff5b65"), Color("ffd46a")]
const SHIELD_COLOR := Color("f3e574")
const MATCH_LABELS := ["Two of %s", "Three of %s", "Four of %s", "Five of %s"]
const FACE_LABELS := ["One", "Two", "Three", "Four", "Five", "Six"]

## Include both the committed count and pip value in the localized skill title.
static func match_name(skill: MultiHitSkill) -> String:
	return GameText.format(MATCH_LABELS[skill.dice.size()-2],GameText.text(FACE_LABELS[skill.face-1]))

static func color(skill: MultiHitSkill) -> Color:
	if skill.pattern == "straight": return preload("res://scripts/effects/flame_spell.gd").COLORS[clampi(skill.dice.size()-2,1,4)]
	if skill.pattern in ["match","annihilation"]: return MATCH_COLORS[clampi(skill.dice.size()-2,0,4)]
	if skill.is_empty(): return Color.WHITE
	return [Color("eee0b9"),Color("aed085"),Color("c5a4de"),Color("dfb866")][skill.kind]

static func fire_level(skill: MultiHitSkill) -> int:
	return maxi(0,skill.dice.size()-2) if skill.pattern in ["match","annihilation","straight"] else 0
