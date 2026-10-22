extends RefCounted
## Flamelings gains one ember per committed Fireball cast, then echoes it twice.
const CHARGES := 3
var charge: int = 0

func on_cast(skill: MultiHitSkill) -> void:
	if skill.pattern != "straight" or skill.dice.size() != 3: return
	charge += 1
	if charge < CHARGES: return
	charge = 0
	# Append a fixed two echoes after relic-added hits; echoes never charge this passive.
	skill.bonus_random_from = skill.use_count()
	skill._cast_uses += 2

func displayed_charge(skill: MultiHitSkill) -> int:
	if skill.bonus_random_from >= 0 and skill.uses_spent < skill.bonus_random_from: return CHARGES
	return charge
