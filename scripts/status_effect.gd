class_name StatusEffect
extends RefCounted
## One boon or affliction. Counts mean remaining turns/throws, or burning stacks.
const REGEN := 2
const MIGHT := 3
const ASCENSION := 33
const IMMUNITY := 6
const FROZEN := 100
const BURNING := 101
const MAX_BURNING_STACKS := 10
const STUNNED := 102
const DARKNESS := 103
const CORROSION := 104
const PLAGUE := 105
const HIDDEN := 106
const IMMOBILIZED := 107
const ENEMY_ACTION_LOCKS := [FROZEN, IMMOBILIZED]
const HARMFUL := [FROZEN, BURNING, STUNNED, DARKNESS, CORROSION, PLAGUE, IMMOBILIZED]
const PLAYER_HARMFUL := [FROZEN, BURNING, STUNNED, DARKNESS, CORROSION]
const ENEMY_HARMFUL := [FROZEN, BURNING, DARKNESS, CORROSION, PLAGUE, IMMOBILIZED]
const IDS := [REGEN, MIGHT, ASCENSION, IMMUNITY, FROZEN, BURNING, STUNNED, DARKNESS, CORROSION, PLAGUE, HIDDEN, IMMOBILIZED]
enum Attribute { NONE, ICE, FIRE, SHOCK, DARK, ACID, DISEASE }
var permanent: bool = false
var potency: float = 1.0
var id: int
var count: int = 0:
	set(value):
		count = clampi(value, 0, MAX_BURNING_STACKS) if id == BURNING else maxi(0, value)
		if count == 0: potency = 1.0

func _init(effect_id: int) -> void:
	id = effect_id

func apply(amount: int, effect_potency: float = 1.0) -> void:
	count = count+maxi(0,amount) if is_stacking() else maxi(0,amount)
	if count > 0: potency = maxf(1.0,effect_potency)

func consume(amount: int = 1) -> void:
	if not permanent: count -= amount

func is_harmful() -> bool:
	return id in HARMFUL

func is_stacking() -> bool:
	return id in [BURNING, DARKNESS, CORROSION, PLAGUE]
