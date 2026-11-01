extends RefCounted
## Authored rosters: every entry owns a role, level and optional elite flag.
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const WAVES_PER_LEVEL := 8
const SHOP_AFTER_WAVES := [3,6]
## Offline tuning targets relative to kill-only player XP; live spawns never read player level.
const REFERENCE_LEVEL_GAPS := [
	0,0,-1,-1,-2,-2,2,1,
	1,0,0,-1,3,2,1,0,
	-1,-2,3,2,1,0,-1,-2,
]
const SQUADS := [
	# 1-1
	{"introduction":true,"units":[{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-2
	{"introduction":true,"units":[{"role":Enemy.Role.ARCHER,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-3
	{"introduction":true,"units":[{"role":Enemy.Role.MAGE,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-4
	{"introduction":false,"units":[{"role":Enemy.Role.ARCHER,"level":1},{"role":Enemy.Role.MAGE,"level":1}]},
	# 1-5
	{"introduction":true,"units":[{"role":Enemy.Role.CLERIC,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-6
	{"introduction":true,"units":[{"role":Enemy.Role.ASSASSIN,"level":1},{"role":Enemy.Role.ARCHER,"level":1}]},
	# 1-7
	{"introduction":true,"units":[{"role":Enemy.Role.VANGUARD,"level":5,"elite":true},{"role":Enemy.Role.MAGE,"level":5},{"role":Enemy.Role.CLERIC,"level":5}]},
	# 1-8
	{"introduction":true,"units":[{"role":Enemy.Role.COMMANDER,"level":5,"elite":true,"reinforcement_level":1}]},
	# 2-1
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":7},{"role":Enemy.Role.ARCHER,"level":7}]},
	# 2-2
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":7,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":7}]},
	# 2-3
	{"introduction":true,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":7},{"role":Enemy.Role.VANGUARD,"level":7}]},
	# 2-4
	{"introduction":true,"units":[{"role":Enemy.Role.MAGIC_CANNON,"level":7},{"role":Enemy.Role.MAGE,"level":7}]},
	# 2-5
	{"introduction":true,"units":[{"role":Enemy.Role.BOMBER,"level":11},{"role":Enemy.Role.VANGUARD,"level":11}]},
	# 2-6
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":11,"elite":true},{"role":Enemy.Role.ARCHER,"level":11}]},
	# 2-7
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":11,"elite":true},{"role":Enemy.Role.MAGE,"level":11,"elite":true}]},
	# 2-8
	{"introduction":true,"units":[{"role":Enemy.Role.SPELLSWORD,"level":10,"elite":true}]},
	# 3-1
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":10,"elite":true},{"role":Enemy.Role.MAGE,"level":10}]},
	# 3-2
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":10,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":10,"elite":true},{"role":Enemy.Role.VANGUARD,"level":10}]},
	# 3-3
	{"introduction":false,"units":[{"role":Enemy.Role.MAGIC_CANNON,"level":15},{"role":Enemy.Role.BOMBER,"level":15,"elite":true}]},
	# 3-4
	{"introduction":true,"units":[{"role":Enemy.Role.VANGUARD,"level":15},{"role":Enemy.Role.MAGE,"level":15,"elite":true}]},
	# 3-5
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":14,"elite":true},{"role":Enemy.Role.ARCHER,"level":14,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":14}]},
	# 3-6
	{"introduction":false,"units":[{"role":Enemy.Role.MAGIC_CANNON,"level":14},{"role":Enemy.Role.CLERIC,"level":14,"elite":true}]},
	# 3-7
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":14,"elite":true},{"role":Enemy.Role.MAGE,"level":14,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":14,"elite":true}]},
	# 3-8
	{"introduction":true,"units":[{"role":Enemy.Role.FANATIC,"level":13,"elite":true}]},
]
const COUNT := 25
const CITY_STAGE := COUNT-1
const CITY_HP := 20000

## Boss milestones always remain combat destinations.
static func is_boss_stage(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and SQUADS[stage].units.any(func(entry): return Enemy.ITEMS[entry.role].get("boss",false))

## Shops are intermissions after fixed battles, never replacements for an encounter.
static func has_shop_after(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and stage%WAVES_PER_LEVEL+1 in SHOP_AFTER_WAVES

## Pressure steps after each six battles continue across eight-wave level boundaries.
static func reference_level_gap(stage: int) -> int:
	return REFERENCE_LEVEL_GAPS[clampi(stage,0,REFERENCE_LEVEL_GAPS.size()-1)]

## Preserve first encounters and designed difficulty steps as combat waves.
static func requires_combat(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and (SQUADS[stage].introduction or is_boss_stage(stage))

## Keep legacy count consumers derived from the authored roster.
static func counts() -> Array:
	var result: Array = []
	for row in SQUADS:
		var count := [0,0]
		for entry in row.units: count[int(entry.get("elite",false))] += 1
		result.append(count)
	return result

## The home map uses the lead enemy; display code does not depend on roster fields.
static func map_marker(stage: int) -> Dictionary:
	if stage == CITY_STAGE: return {"art":"crown","highlight":true}
	var entry: Dictionary = SQUADS[stage].units[0]
	return {"art":Enemy.ITEMS[entry.role].art,"highlight":entry.get("elite",false) or Enemy.ITEMS[entry.role].get("reward_class","normal") == "special"}

## Types and levels are authored; elite traits and formation use the seeded combat stream.
static func create(stage: int, rng: RandomNumberGenerator) -> Array:
	if stage < 0 or stage >= SQUADS.size(): return []
	var result: Array = []
	for entry in SQUADS[stage].units:
		var unit: Dictionary = Enemy.make(entry.role,entry.level,entry.get("elite",false),rng)
		if entry.has("reinforcement_level"): unit.reinforcement_level = entry.reinforcement_level
		result.append(unit)
	for i in range(result.size()-1,0,-1):
		var other: int = rng.randi_range(0,i)
		var temp: Dictionary = result[i]
		result[i] = result[other]; result[other] = temp
	return result

static func player_size(stage: int) -> float:
	return lerpf(224,288,clampf(float(stage)/19.0,0,1))

static func _world_size(stage: int, first: float, final_squad: float, city: float) -> float:
	# World elements shrink gradually through wave 19; city elements use a separate scale.
	if stage >= CITY_STAGE: return city
	return lerpf(first,final_squad,clampf(float(stage)/18.0,0,1))

static func enemy_size(stage: int) -> float:
	return _world_size(stage,192,88,40)

static func paving_size(stage: int) -> float:
	return _world_size(stage,96,16,16)

static func scenery_size(stage: int) -> float:
	return _world_size(stage,128,16,12)
