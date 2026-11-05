extends RefCounted
## Authored rosters: every entry owns a role, level and optional elite flag.
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const WAVES_PER_LEVEL := 8
const SHOP_AFTER_WAVES := [3,6]
const SPECIAL_INTRO_WAVE := 4
const DISPLAY_GROWTH_CAP_STAGE := 11 # Wave 12, using its existing proportions.
const SCENERY_CURVE_SPAN := 24.0 # Authored distant-building keyframes; independent of campaign length.
const RANDOM_BOSSES := [Enemy.Role.COMMANDER,Enemy.Role.SPELLSWORD,Enemy.Role.FANATIC]
## Offline tuning targets relative to kill-only player XP; live spawns never read player level.
const REFERENCE_LEVEL_GAPS := [
	0,0,-1,2,2,1,3,5,
	1,1,0,3,2,2,4,5,
	3,2,1,3,2,1,4,5,
	1,1,0,3,2,1,4,5,
	1,1,0,3,2,1,4,5,
]
const SQUADS := [
	# 1-1
	{"introduction":true,"units":[{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-2
	{"introduction":true,"units":[{"role":Enemy.Role.ARCHER,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-3
	{"introduction":true,"units":[{"role":Enemy.Role.MAGE,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-4: first special, with a familiar damage dealer behind its taunt.
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":4},{"role":Enemy.Role.MAGE,"level":4}]},
	# 1-5
	{"introduction":true,"units":[{"role":Enemy.Role.CLERIC,"level":5},{"role":Enemy.Role.VANGUARD,"level":5}]},
	# 1-6
	{"introduction":true,"units":[{"role":Enemy.Role.ASSASSIN,"level":5},{"role":Enemy.Role.ARCHER,"level":5}]},
	# 1-7
	{"introduction":false,"units":[{"role":Enemy.Role.ARCHER,"level":7},{"role":Enemy.Role.MAGE,"level":7}]},
	# 1-8
	{"introduction":true,"units":[{"role":Enemy.Role.COMMANDER,"level":9,"elite":true,"reinforcement_level":1}]},
	# 2-1
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":8},{"role":Enemy.Role.ARCHER,"level":8}]},
	# 2-2
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":8,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":8}]},
	# 2-3
	{"introduction":false,"units":[{"role":Enemy.Role.MAGE,"level":8},{"role":Enemy.Role.VANGUARD,"level":8}]},
	# 2-4: a new support enemy and interruptible cannon after the first shop.
	{"introduction":true,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":11},{"role":Enemy.Role.MAGIC_CANNON,"level":11}]},
	# 2-5
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":11},{"role":Enemy.Role.MAGE,"level":11}]},
	# 2-6
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":11,"elite":true},{"role":Enemy.Role.ARCHER,"level":11}]},
	# 2-7
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":14,"elite":true},{"role":Enemy.Role.MAGE,"level":14,"elite":true}]},
	# 2-8
	{"introduction":true,"units":[{"role":Enemy.Role.SPELLSWORD,"level":15,"elite":true}]},
	# 3-1
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":14,"elite":true},{"role":Enemy.Role.MAGE,"level":14}]},
	# 3-2
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":14,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":14,"elite":true},{"role":Enemy.Role.VANGUARD,"level":14}]},
	# 3-3
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":14},{"role":Enemy.Role.MAGE,"level":14,"elite":true}]},
	# 3-4: normal Bomber beside the now-familiar cannon; elites come later.
	{"introduction":true,"units":[{"role":Enemy.Role.MAGIC_CANNON,"level":16},{"role":Enemy.Role.BOMBER,"level":16}]},
	# 3-5
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":16,"elite":true},{"role":Enemy.Role.ARCHER,"level":16,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":16}]},
	# 3-6
	{"introduction":true,"units":[{"role":Enemy.Role.BOMBER,"level":16,"elite":true},{"role":Enemy.Role.CLERIC,"level":16,"elite":true}]},
	# 3-7
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":19,"elite":true},{"role":Enemy.Role.MAGE,"level":19,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":19,"elite":true}]},
	# 3-8
	{"introduction":true,"units":[{"role":Enemy.Role.FANATIC,"level":21,"elite":true}]},
	# 4-1 through 4-3: regroup with familiar mixed squads before the pressure step.
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":18,"elite":true},{"role":Enemy.Role.MAGE,"level":18,"elite":true},{"role":Enemy.Role.ARCHER,"level":18}]},
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":18,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":18,"elite":true},{"role":Enemy.Role.ARCHER,"level":18}]},
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":18},{"role":Enemy.Role.MAGE,"level":18,"elite":true}]},
	# 4-4 through 4-7: alternate interruptible threats, protection and support.
	{"introduction":false,"units":[{"role":Enemy.Role.MAGIC_CANNON,"level":21,"elite":true},{"role":Enemy.Role.CLERIC,"level":21}]},
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":21},{"role":Enemy.Role.ASSASSIN,"level":21,"elite":true},{"role":Enemy.Role.MAGE,"level":21}]},
	{"introduction":false,"units":[{"role":Enemy.Role.BOMBER,"level":21,"elite":true},{"role":Enemy.Role.ARCHER,"level":21,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":24,"elite":true},{"role":Enemy.Role.VANGUARD,"level":24,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":24,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.COMMANDER,"random_roles":RANDOM_BOSSES,"level":26,"elite":true,"reinforcement_level":1}]},
	# 5-1 through 5-3: a brief recovery before the final level's later steps.
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":23},{"role":Enemy.Role.ARCHER,"level":23,"elite":true},{"role":Enemy.Role.MAGE,"level":23,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.CLERIC,"level":23,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":23,"elite":true},{"role":Enemy.Role.VANGUARD,"level":23,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":23,"elite":true},{"role":Enemy.Role.MAGE,"level":23,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.BOMBER,"level":26,"elite":true},{"role":Enemy.Role.MAGIC_CANNON,"level":26}]},
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":26,"elite":true},{"role":Enemy.Role.ARCHER,"level":26,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":26,"elite":true},{"role":Enemy.Role.CLERIC,"level":26,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":26}]},
	{"introduction":false,"units":[{"role":Enemy.Role.MAGIC_CANNON,"level":30,"elite":true},{"role":Enemy.Role.MAGE,"level":30,"elite":true},{"role":Enemy.Role.ASSASSIN,"level":30,"elite":true}]},
	{"introduction":false,"units":[{"role":Enemy.Role.COMMANDER,"random_roles":RANDOM_BOSSES,"level":32,"elite":true,"reinforcement_level":1}]},
]
const LEVEL_COUNT := 5
const COUNT := LEVEL_COUNT*WAVES_PER_LEVEL+1
const CITY_STAGE := COUNT-1
const CITY_HP := 20000

## Boss milestones always remain combat destinations.
static func is_boss_stage(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and SQUADS[stage].units.any(func(entry): return Enemy.ITEMS[entry.role].get("boss",false))

## Shops are intermissions after fixed battles, never replacements for an encounter.
static func has_shop_after(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and stage%WAVES_PER_LEVEL+1 in SHOP_AFTER_WAVES

## New specials arrive at the fourth battle of each level, immediately after a shop.
static func is_pressure_step(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and stage%WAVES_PER_LEVEL+1 == SPECIAL_INTRO_WAVE

## Fixed target gaps are used by the offline progression tool, never live player scaling.
static func reference_level_gap(stage: int) -> int:
	return REFERENCE_LEVEL_GAPS[clampi(stage,0,REFERENCE_LEVEL_GAPS.size()-1)]

## Preserve first encounters and designed difficulty steps as combat waves.
static func requires_combat(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and (SQUADS[stage].introduction or is_boss_stage(stage) or is_pressure_step(stage))

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
	if entry.has("random_roles"): return {"art":"crown","highlight":true}
	return {"art":Enemy.ITEMS[entry.role].art,"highlight":entry.get("elite",false) or Enemy.ITEMS[entry.role].get("reward_class","normal") == "special"}

## Types and levels are authored; elite traits and formation use the seeded combat stream.
static func create(stage: int, rng: RandomNumberGenerator) -> Array:
	if stage < 0 or stage >= SQUADS.size(): return []
	var result: Array = []
	for entry in SQUADS[stage].units:
		var role: int = entry.role
		if entry.has("random_roles"): role = entry.random_roles[rng.randi_range(0,entry.random_roles.size()-1)]
		var unit: Dictionary = Enemy.make(role,entry.level,entry.get("elite",false),rng)
		if entry.has("reinforcement_level"): unit.reinforcement_level = entry.reinforcement_level
		result.append(unit)
	for i in range(result.size()-1,0,-1):
		var other: int = rng.randi_range(0,i)
		var temp: Dictionary = result[i]
		result[i] = result[other]; result[other] = temp
	return result

## Freeze scenery at the existing wave-12 scale; actors use evolution proportions.
static func display_stage(stage: float) -> float:
	return clampf(stage,0,DISPLAY_GROWTH_CAP_STAGE)

static func _world_size(stage: int, first: float, final_squad: float, city: float) -> float:
	# Keep dormant city art separate; playable waves stop shrinking after wave 12.
	if stage >= CITY_STAGE: return city
	return lerpf(first,final_squad,display_stage(stage)/18.0)

static func paving_size(stage: int) -> float:
	return _world_size(stage,96,16,16)

static func scenery_size(stage: int) -> float:
	return _world_size(stage,128,16,12)
