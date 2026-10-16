extends RefCounted
## Shared combination rules and tuning for selection, combat and help previews.
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const BASE_PER_DIE := 5.0
const LEFTOVER_FACTOR := 0.25
const MATCH_NAMES := ["Two Alike", "Three Alike", "Four Alike", "Five Alike", "Annihilation"]

## Classify a match or a consecutive set, regardless of connection order.
static func classify(values: Array) -> MultiHitSkill:
	if values.size() < 2 or values.size() > 6 or values.any(func(face): return not face is int or face < 1 or face > 6): return Skill.new()
	var skill: MultiHitSkill
	if values.all(func(face): return face == values[0]):
		skill = Skill.new(Skill.Kind.ULTIMATE if values.size() == 6 else Skill.Kind.PAIR if values.size() == 2 else Skill.Kind.SPECIAL, values[0], values, 1 if values.size() == 6 else values[0])
		skill.pattern = "annihilation" if values.size() == 6 else "match"
		skill.spare = 0
		return skill
	var ordered: Array = values.duplicate()
	ordered.sort()
	if ordered.size() < 3: return Skill.new()
	for i in range(1,ordered.size()):
		if ordered[i] != ordered[i-1]+1: return Skill.new()
	skill = Skill.new(Skill.Kind.NORMAL,0,values)
	skill.pattern = "straight"
	return skill

## Reject partial selections that cannot complete a pattern with the unused dice.
static func can_extend(values: Array, available: Array) -> bool:
	if values.is_empty(): return true
	if values.size() > 6: return false
	if values.all(func(face): return face == values[0]) and available.count(values[0]) >= maxi(2,values.size()): return true
	for face in values:
		if values.count(face) > 1: return false
	for length in range(3,7):
		for first in range(1,8-length):
			var straight: Array = range(first,first+length)
			if values.all(func(face): return face in straight) and straight.all(func(face): return face in available): return true
	return false

## One internal attack budget powers direct pip projectiles without summoning a skill.
static func cleanup(values: Array) -> MultiHitSkill:
	if values.is_empty(): return Skill.new()
	var skill := Skill.new(Skill.Kind.NORMAL,0,values)
	skill.pattern = "cleanup"
	skill.base_uses = skill.sum
	return skill

## Map each projectile, including extra uses, back to its die and printed pip.
static func cleanup_source(skill: MultiHitSkill, use: int) -> Vector2i:
	var pip: int = use % maxi(1,skill.sum)
	for die in range(skill.dice.size()):
		if pip < skill.dice[die]: return Vector2i(die,pip)
		pip -= skill.dice[die]
	return Vector2i.ZERO

static func tier_multiplier(skill: MultiHitSkill) -> float:
	return 1.0+(skill.dice.size()-1)*0.5 if skill.pattern == "match" else 1.0

static func base_damage(skill: MultiHitSkill) -> float:
	return BASE_PER_DIE*LEFTOVER_FACTOR if skill.pattern == "cleanup" else BASE_PER_DIE*skill.dice.size()*tier_multiplier(skill)

static func shield_points(skill: MultiHitSkill) -> int:
	return skill.sum*(skill.dice.size()-2) if skill.pattern == "straight" else 0

## Shared help copy keeps both screen layouts and the home catalogue aligned.
static func help_entries(shields: bool) -> Array:
	if shields:
		return [
			{"name":"3-Dice Straight","text":"Three consecutive faces: shield = pip sum x1. Example: 123 gives 6."},
			{"name":"4-Dice Straight","text":"Four consecutive faces: shield = pip sum x2. Example: 1234 gives 20."},
			{"name":"5-Dice Straight","text":"Five consecutive faces: shield = pip sum x3. Example: 12345 gives 45."},
			{"name":"6-Dice Straight","text":"123456: shield = 21 x4 = 84."},
			{"name":"Wave Shields","text":"Shields absorb damage, have no cap, and clear on the next wave. Shield skills are not attacks."},
		]
	return [
		{"name":"Two Alike","text":"2 dice x5 base x1.5 = 15 per hit. The matching face sets the number of hits."},
		{"name":"Three Alike","text":"3 dice x5 base x2 = 30 per hit. The matching face sets the number of hits."},
		{"name":"Four Alike","text":"4 dice x5 base x2.5 = 50 per hit. The matching face sets the number of hits."},
		{"name":"Five Alike","text":"5 dice x5 base x3 = 75 per hit. The matching face sets the number of hits."},
		{"name":"Annihilation","text":"Six alike of any face: destroy all enemies, ignoring shields. Heal 12 HP."},
	]
