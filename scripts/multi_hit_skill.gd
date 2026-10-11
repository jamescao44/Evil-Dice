class_name MultiHitSkill
extends RefCounted
## One rolled skill, including its use budget. All skill effects share this type.
## Modifiers affect previews immediately; the budget freezes when casting begins.
enum Kind { NORMAL, PAIR, SPECIAL, ULTIMATE }

var kind: int = -1
var face: int = 0
var sum: int = 0
var spare: int = 0
var dice: Array = []
var base_uses: int = 1
var use_modifiers: Dictionary = {}
var target: int = -1
var uses_spent: int = 0
var _cast_uses: int = 0
var perfect: bool = false
var critical: bool = false

func _init(skill_kind: int = -1, skill_face: int = 0, values: Array = [], uses: int = 1) -> void:
	kind = skill_kind
	face = skill_face
	dice = values.duplicate()
	for value in dice: sum += value
	spare = sum-face*2 if kind == Kind.PAIR else 0
	base_uses = maxi(1, uses)

func is_empty() -> bool:
	return kind < 0

func is_attack() -> bool:
	if is_empty(): return false
	return face in [1,4,5] if kind in [Kind.PAIR,Kind.SPECIAL] else true

func hits_all() -> bool:
	return kind == Kind.ULTIMATE or (kind in [Kind.PAIR,Kind.SPECIAL] and face == 4)

func set_use_multiplier(source: String, multiplier: int) -> void:
	# Named sources replace their own contribution instead of compounding on refresh.
	if multiplier <= 1: use_modifiers.erase(source)
	else: use_modifiers[source] = multiplier

func use_count(additional_modifiers: Dictionary = {}) -> int:
	if is_empty(): return 0
	if _cast_uses > 0: return _cast_uses
	var total: int = maxi(1, base_uses)
	for multiplier in use_modifiers.values(): total *= maxi(1, int(multiplier))
	for modifier in additional_modifiers.values():
		if modifier is Dictionary: total += maxi(0, int(modifier.get("add", 0)))
		else: total *= maxi(1, int(modifier))
	return total

func begin_cast(additional_modifiers: Dictionary = {}) -> void:
	if _cast_uses == 0: _cast_uses = use_count(additional_modifiers)

func uses_left(additional_modifiers: Dictionary = {}) -> int:
	return maxi(0, use_count(additional_modifiers)-uses_spent)

func consume_use() -> bool:
	begin_cast()
	if uses_left() == 0: return false
	uses_spent += 1
	return true

func has_use_orbs(additional_modifiers: Dictionary = {}) -> bool:
	return use_count(additional_modifiers) > 1

func random_target_per_use() -> bool:
	return face == 5 and kind in [Kind.PAIR, Kind.SPECIAL]

func duplicate(_deep: bool = true) -> MultiHitSkill:
	var copy := MultiHitSkill.new(kind, face, dice, base_uses)
	copy.use_modifiers = use_modifiers.duplicate()
	copy.target = target
	copy.uses_spent = uses_spent
	copy._cast_uses = _cast_uses
	copy.perfect = perfect
	copy.critical = critical
	return copy

func same_as(other: MultiHitSkill) -> bool:
	return other != null and kind == other.kind and face == other.face and dice == other.dice and base_uses == other.base_uses and use_modifiers == other.use_modifiers and target == other.target and uses_spent == other.uses_spent and _cast_uses == other._cast_uses and perfect == other.perfect and critical == other.critical
