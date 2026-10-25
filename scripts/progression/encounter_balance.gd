extends RefCounted
## Route-chest XP remains separate from individually leveled enemy rewards.
const SOUL_CHEST_GROWTH := 0.08

## Soul routes retain their rarity bands as character level costs rise.
static func soul_chest_scale(stage: int) -> float:
	return 1.0+SOUL_CHEST_GROWTH*maxi(0,stage)
