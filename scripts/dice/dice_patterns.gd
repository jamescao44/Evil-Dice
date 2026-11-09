extends RefCounted
## Shared combination rules and tuning for selection, combat and help previews.
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Auto = preload("res://scripts/combat/flamelings_auto.gd")
const TURN_HELP := "One throw + four single-die rerolls. One straight skill per turn."

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
	skill.damage_ticks = preload("res://scripts/combat/flamelings_skills.gd").damage_tick_count(values.size())
	return skill

## Larger alike groups fire first; equal-sized groups retain highest-pip priority.
static func automatic_groups(values: Array, indices: Array) -> Array:
	var groups: Array = []
	for face in range(6,0,-1):
		var sources: Array = indices.filter(func(i): return values[i] == face)
		if sources.size() < 2: continue
		var skill := Skill.new(Skill.Kind.NORMAL,face,sources.map(func(_i): return face),Auto.profile(sources.size()).uses)
		skill.pattern = "match_auto"
		skill.amplifier_locked = true
		groups.append({"skill":skill,"indices":sources})
	groups.sort_custom(func(a,b):
		if a.indices.size() != b.indices.size(): return a.indices.size() > b.indices.size()
		return a.skill.face > b.skill.face)
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

## Leftovers form an internal turn-ending action, with no summoned skill bubble.
static func cleanup(values: Array) -> MultiHitSkill:
	if values.is_empty(): return Skill.new()
	var skill := Skill.new(Skill.Kind.NORMAL,0,values)
	skill.pattern = "cleanup"
	skill.base_uses = 1
	return skill

## Shared help copy keeps both screen layouts and the home catalogue aligned.
static func help_entries(straights: bool, evolution: int = 0) -> Array:
	var character = preload("res://scripts/combat/flamelings_skills.gd")
	if straights:
		var entries: Array = []
		for tier in range(4):
			var caption: Dictionary = character.caption(classify(range(1,tier+4)),evolution)
			entries.append({"name":caption.name,"text":caption.description})
		return entries
	return [
		{"name":"Two Alike","text":"2 random shots. Each hit: base x (0.5 + 0.05 x pip)."},
		{"name":"Three Alike","text":"One explosive fireball at 6x auto-attack damage. Applies 2 Burning."},
		{"name":"Four Alike","text":"One fiery eruption hits all enemies at 8x auto-attack damage."},
		{"name":"Five Alike","text":"5 random laser hits, each at 4x auto-attack damage."},
		{"name":"Six Alike","text":"One huge beam hits all enemies 6 times, each at 8x auto-attack damage."},
	]
