extends RefCounted
## Shared combination rules and tuning for selection, combat and help previews.
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const BONUS_TURN_HELP := "Use all six dice in skills: bonus turn with three rolls. Automatic attacks and leftover healing do not count."

## Only three or more consecutive unique faces can summon a skill.
static func has_combination(values: Array) -> bool:
	for first in range(1,5):
		if first in values and first+1 in values and first+2 in values: return true
	return false

## Connection order is free, but repeated faces cannot form a straight.
static func classify(values: Array) -> MultiHitSkill:
	if values.size() < 3 or values.size() > 6 or values.any(func(face): return not face is int or face < 1 or face > 6): return Skill.new()
	var ordered: Array = values.duplicate()
	ordered.sort()
	for i in range(1,ordered.size()):
		if ordered[i] != ordered[i-1]+1: return Skill.new()
	var skill := Skill.new(Skill.Kind.ULTIMATE if values.size() == 6 else Skill.Kind.SPECIAL if values.size() > 3 else Skill.Kind.NORMAL,0,values)
	skill.pattern = "straight"
	return skill

## Snapshot matching groups from newly rolled indices only, highest pip first.
static func automatic_groups(values: Array, indices: Array) -> Array:
	var groups: Array = []
	for face in range(6,0,-1):
		var sources: Array = indices.filter(func(i): return values[i] == face)
		if sources.size() < 2: continue
		var skill := Skill.new(Skill.Kind.NORMAL,face,sources.map(func(_i): return face),sources.size())
		skill.pattern = "match_auto"
		skill.amplifier_locked = true
		groups.append({"skill":skill,"indices":sources})
	return groups

## Reject partial selections that cannot complete a pattern with the unused dice.
static func can_extend(values: Array, available: Array) -> bool:
	if values.is_empty(): return true
	if values.size() > 6: return false
	for face in values:
		if values.count(face) > 1: return false
	for length in range(3,7):
		for first in range(1,8-length):
			var straight: Array = range(first,first+length)
			if values.all(func(face): return face in straight) and straight.all(func(face): return face in available): return true
	return false

## Leftovers form one internal healing action, with no summoned skill bubble.
static func cleanup(values: Array) -> MultiHitSkill:
	if values.is_empty(): return Skill.new()
	var skill := Skill.new(Skill.Kind.NORMAL,0,values)
	skill.pattern = "cleanup"
	skill.base_uses = 1
	return skill

## Shared help copy keeps both screen layouts and the home catalogue aligned.
static func help_entries(straights: bool) -> Array:
	var character = preload("res://scripts/combat/flamelings_skills.gd")
	if straights:
		var entries: Array = []
		for tier in range(4): entries.append({"name":character.NAMES[tier],"text":character.DESCRIPTIONS[tier]})
		return entries
	return [
		{"name":"Matching Auto Attacks","text":"Each newly rolled group of 2+ matching dice attacks random enemies. One hit per matching die; damage = base x (0.5 + 0.1 x pip)."},
		{"name":"Dice Stay Available","text":"Automatic attacks do not spend dice. Use them in straights or reroll all unused dice, up to three rolls per turn."},
		{"name":"Healing Embers","text":"End Turn: leftover pip sum x 1% of maximum HP is restored. Darkness blocks healing."},
	]
