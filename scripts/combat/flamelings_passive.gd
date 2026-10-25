extends RefCounted
## Flamelings fills three embers with eligible casts, then fires two fixed 3-4-5 Fireballs.
const CHARGES := 3
var charge: int = 0

## Every form keeps three embers; the final form broadens which skills fill them.
static func charge_limit(_evolution: int = 0) -> int:
	return CHARGES

func on_cast(skill: MultiHitSkill, evolution: int = 0) -> void:
	if skill.cast_source not in ["manual","missile"] or skill.pattern != "straight" or (evolution < 2 and skill.dice.size() != 3): return
	charge += 1
	if charge < charge_limit(evolution): return
	charge = 0
	# Award separate casts after this skill finishes; never change its use budget.
	skill.grants_bonus_fireballs = true

func displayed_charge(skill: MultiHitSkill, evolution: int = 0) -> int:
	var limit: int = charge_limit(evolution)
	if skill.grants_bonus_fireballs and skill.uses_left() > 0: return limit
	return mini(charge,limit)
