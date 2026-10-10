class_name StatusEffect
extends RefCounted
## One boon or affliction. Counts mean remaining turns/throws, or burning stacks.
const REGEN := 2
const MIGHT := 3
const ASCENSION := 33
const IMMUNITY := 6
const FROZEN := 100
const BURNING := 101
const STUNNED := 102
const IDS := [REGEN, MIGHT, ASCENSION, IMMUNITY, FROZEN, BURNING, STUNNED]
enum Attribute { NONE, ICE, FIRE, SHOCK }
var id: int
var count: int = 0:
	set(value): count = maxi(0, value)

func _init(effect_id: int) -> void:
	id = effect_id

func apply(amount: int) -> void:
	count = count+maxi(0,amount) if id == BURNING else maxi(0,amount)

func consume(amount: int = 1) -> void:
	count -= amount

func is_harmful() -> bool:
	return id in [FROZEN, BURNING, STUNNED]

func is_stacking() -> bool:
	return id == BURNING
