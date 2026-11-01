extends RefCounted
## Health and outgoing damage are separate balance controls.
const DAMAGE_GROWTH := 1.10
const HEALTH_GROWTH := 1.0

static func damage_scale_at(level: int) -> float:
	return pow(DAMAGE_GROWTH,maxi(0,level-1))

static func health_scale_at(level: int) -> float:
	return pow(HEALTH_GROWTH,maxi(0,level-1))
