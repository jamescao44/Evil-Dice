extends RefCounted
## One enemy's level owns its stats and drops, independently of its wave or allies.
const HEALTH_PER_LEVEL := 1.30
const DAMAGE_PER_LEVEL := 1.04
const SOULS_PER_LEVEL := 0.12
const GEMS_PER_LEVEL := 0.10

## Level one is the catalog baseline; invalid lower levels normalize to one.
static func normalized(level: int) -> int:
	return maxi(1,level)

## Durability grows faster than unavoidable incoming damage.
static func health_scale(level: int) -> float:
	return pow(HEALTH_PER_LEVEL,normalized(level)-1)

static func damage_scale(level: int) -> float:
	return pow(DAMAGE_PER_LEVEL,normalized(level)-1)

## Rewards grow linearly so high-level enemies do not exponentially inflate loot.
static func soul_scale(level: int) -> float:
	return 1.0+SOULS_PER_LEVEL*(normalized(level)-1)

static func gem_scale(level: int) -> float:
	return 1.0+GEMS_PER_LEVEL*(normalized(level)-1)

## Round once at spawn or payout; never multiply an already-scaled stat.
static func scaled(base: int, factor: float) -> int:
	return maxi(1,roundi(base*factor+0.0001))
