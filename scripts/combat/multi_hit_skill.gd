class_name MultiHitSkill
extends RefCounted
## One rolled skill, including its use budget. All skill effects share this type.
## Modifiers affect previews immediately; the budget freezes when casting begins.
enum Kind { NORMAL, PAIR, SPECIAL, ULTIMATE }

var pattern: String = "" # Empty retains scripted legacy effects; dice use named patterns.
var kind: int = -1
var face: int = 0
var sum: int = 0
var spare: int = 0
var dice: Array = []
var base_uses: int = 1
var damage_ticks: int = 1 # Damage pulses within one use, never extra uses or combo orbs.
var damage_ticks_spent: int = 0
var use_modifiers: Dictionary = {}
var target: int = -1
var uses_spent: int = 0
var grants_bonus_fireballs: bool = false
var calculated_damage_total: int = -1 # Last resolved use, before target defenses.
var inherited_damage: int = -1 # Generated Fireballs reuse this total without modifiers.
var _cast_uses: int = 0
var perfect: bool = false
var critical: bool = false
var effect_multiplier: float = 1.0
var amplifier_locked: bool = false
var source_dice: Array = [] # Physical dice spent before a skill-tier upgrade.
var cast_source: String = "manual"
var relic_cast_locked: bool = false
var alternating_bonus: bool = false
var relic_effect_scale: float = 1.0
var royal_activations: Array = []

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
	if not pattern.is_empty(): return pattern != "cleanup"
	return face in [1,4,5] if kind in [Kind.PAIR,Kind.SPECIAL] else true

func is_freeze() -> bool:
	return pattern.is_empty() and kind == Kind.PAIR and face == 2

func hits_all() -> bool:
	if not pattern.is_empty(): return pattern == "annihilation" or (pattern == "straight" and dice.size() >= 4) or (pattern == "match_auto" and dice.size() == 6)
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
	damage_ticks_spent = 0
	return true

func has_use_orbs(additional_modifiers: Dictionary = {}) -> bool:
	return use_count(additional_modifiers) > 1

## Rolled auto-attacks are separate from skills eligible for multi-hit relics.
func is_combo_attack() -> bool:
	return pattern == "match" or (pattern.is_empty() and random_target_per_use())

func random_target_per_use() -> bool:
	if cast_source == "character_bonus": return true
	if not pattern.is_empty(): return pattern == "match_auto"
	return face == 5 and kind in [Kind.PAIR, Kind.SPECIAL]

## Selected-target casts keep their target through death; future overflow can override this policy.
func keeps_selected_target() -> bool:
	return is_attack() and not hits_all() and not random_target_per_use()

func duplicate(_deep: bool = true) -> MultiHitSkill:
	var copy := MultiHitSkill.new(kind, face, dice, base_uses)
	copy.pattern = pattern
	copy.damage_ticks = damage_ticks
	copy.damage_ticks_spent = damage_ticks_spent
	copy.use_modifiers = use_modifiers.duplicate()
	copy.target = target
	copy.uses_spent = uses_spent
	copy.grants_bonus_fireballs = grants_bonus_fireballs
	copy.calculated_damage_total = calculated_damage_total
	copy.inherited_damage = inherited_damage
	copy._cast_uses = _cast_uses
	copy.perfect = perfect
	copy.critical = critical
	copy.effect_multiplier = effect_multiplier
	copy.amplifier_locked = amplifier_locked
	copy.source_dice = source_dice.duplicate()
	copy.cast_source = cast_source
	copy.relic_cast_locked = relic_cast_locked
	copy.alternating_bonus = alternating_bonus
	copy.relic_effect_scale = relic_effect_scale
	copy.royal_activations = royal_activations.duplicate(true)
	return copy

func same_as(other: MultiHitSkill) -> bool:
	if other == null or calculated_damage_total != other.calculated_damage_total or inherited_damage != other.inherited_damage or source_dice != other.source_dice or cast_source != other.cast_source or relic_effect_scale != other.relic_effect_scale or relic_cast_locked != other.relic_cast_locked or alternating_bonus != other.alternating_bonus: return false
	return other != null and pattern == other.pattern and kind == other.kind and face == other.face and dice == other.dice and damage_ticks == other.damage_ticks and damage_ticks_spent == other.damage_ticks_spent and base_uses == other.base_uses and use_modifiers == other.use_modifiers and target == other.target and grants_bonus_fireballs == other.grants_bonus_fireballs and uses_spent == other.uses_spent and _cast_uses == other._cast_uses and perfect == other.perfect and critical == other.critical and effect_multiplier == other.effect_multiplier and amplifier_locked == other.amplifier_locked
