extends RefCounted
## Player HP uses larger units; outgoing damage and enemy HP keep their combat units.
const SCALE := 10
const LevelCurve = preload("res://scripts/progression/level_curve.gd")
const STARTING_HEALTH := 100 * SCALE
const BURN_DAMAGE := 5 * SCALE
const REGEN_HEAL := 5 * SCALE
const LEGACY_ULTIMATE_HEAL := 12 * SCALE
const BOOKMARK_SHIELD := 10 * SCALE
const CHARIOT_SHIELD := 50 * SCALE
const TOWER_SELF_DAMAGE := 30 * SCALE

## Unmodified health is the level baseline for enemy damage budgets, never current equipment.
static func base_health(level: int) -> int:
	return roundi(STARTING_HEALTH*LevelCurve.health_scale_at(level))

## Convert a completed enemy attack or recovery amount into player-health units.
static func from_combat(amount: float) -> int:
	return roundi(amount * SCALE)

## Keep friendly fire and overheal attacks in the unchanged enemy-health units.
static func to_combat(amount: float) -> float:
	return amount / SCALE
