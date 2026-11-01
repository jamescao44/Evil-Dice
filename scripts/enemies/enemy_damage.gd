extends RefCounted
## Attack budgets use unmodified character HP; equipment and defenses remain meaningful.
const Vitals = preload("res://scripts/combat/player_vitals.gd")
const LEVEL_GAP_FACTOR := 1.10

## Signed gaps make lower-level enemies gentler; +3 means 1.331 times the same-level budget.
static func gap_factor(enemy_level: int, player_level: int) -> float:
	return pow(LEVEL_GAP_FACTOR,maxi(1,enemy_level)-maxi(1,player_level))

## Percentages are authored in percentage points (20 means 20%), rounded only at the hit.
static func amount(percent: float, enemy_level: int, player_level: int, multiplier: float = 1.0) -> int:
	return maxi(0,roundi(Vitals.base_health(player_level)*percent*0.01*gap_factor(enemy_level,player_level)*multiplier))

## Old hand-authored intent fixtures may still provide only an absolute damage value.
static func base_hit(enemy: Dictionary, player_level: int) -> int:
	if not enemy.has("damage_percent"): return enemy.get("damage",0)
	return amount(enemy.damage_percent,enemy.get("level",1),player_level)

## Friendly fire keeps its original enemy-level budget when player health growth changes.
static func friendly_base_hit(enemy: Dictionary) -> int:
	if not enemy.has("damage_percent"): return enemy.get("damage",0)
	return roundi(Vitals.STARTING_HEALTH*enemy.damage_percent*0.01*pow(LEVEL_GAP_FACTOR,maxi(0,enemy.get("level",1)-1)))
