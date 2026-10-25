extends RefCounted
## Authored rosters: every entry owns a role, level and optional elite flag.
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const SQUADS := [
	# 1-1: 先锋：攻击与举盾
	{"introduction":true,"units":[{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-2: 新敌：弓手；优先击杀与自疗
	{"introduction":true,"units":[{"role":Enemy.Role.ARCHER,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-3: 新敌：法师；支援与目标选择
	{"introduction":true,"units":[{"role":Enemy.Role.MAGE,"level":1},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-4: 熟悉组合／首次商店
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":2},{"role":Enemy.Role.ARCHER,"level":2},{"role":Enemy.Role.MAGE,"level":1}]},
	# 1-5: 新敌：精英法师；燃烧
	{"introduction":true,"units":[{"role":Enemy.Role.MAGE,"level":4,"elite":true},{"role":Enemy.Role.VANGUARD,"level":1}]},
	# 1-6: 练习：燃烧与混合等级
	{"introduction":false,"units":[{"role":Enemy.Role.MAGE,"level":3,"elite":true},{"role":Enemy.Role.VANGUARD,"level":3},{"role":Enemy.Role.ARCHER,"level":2}]},
	# 1-7: 新敌：圣骑士；嘲讽与护盾
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":2},{"role":Enemy.Role.MAGE,"level":2}]},
	# 1-8: 缓冲：已知敌人与商店机会
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":4},{"role":Enemy.Role.ARCHER,"level":3},{"role":Enemy.Role.MAGE,"level":3}]},
	# 1-9: 新敌：精英先锋；晕眩与护卫
	{"introduction":true,"units":[{"role":Enemy.Role.VANGUARD,"level":5,"elite":true},{"role":Enemy.Role.PALADIN,"level":3},{"role":Enemy.Role.MAGE,"level":3}]},
	# 1-10: Boss：骑士团长；二阶段2名Lv.2圣骑士
	{"introduction":true,"units":[{"role":Enemy.Role.COMMANDER,"level":5,"elite":true,"reinforcement_level":2}]},
	# 2-1: 新敌：精英弓手；冰冻与群疗
	{"introduction":true,"units":[{"role":Enemy.Role.ARCHER,"level":9,"elite":true},{"role":Enemy.Role.MAGE,"level":7,"elite":true},{"role":Enemy.Role.VANGUARD,"level":7}]},
	# 2-2: 练习：熟悉敌人的混合小队
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":8},{"role":Enemy.Role.MAGE,"level":8,"elite":true},{"role":Enemy.Role.VANGUARD,"level":8},{"role":Enemy.Role.ARCHER,"level":7}]},
	# 2-3: 新敌：大祭祀；群体祝福与元素
	{"introduction":true,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":10},{"role":Enemy.Role.VANGUARD,"level":8,"elite":true},{"role":Enemy.Role.MAGE,"level":7}]},
	# 2-4: 跃升：保护与远程支援
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":10},{"role":Enemy.Role.ARCHER,"level":11,"elite":true},{"role":Enemy.Role.MAGE,"level":9}]},
	# 2-5: 新敌：精英圣骑士；蓄力后下回合双击
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":10,"elite":true},{"role":Enemy.Role.MAGE,"level":10}]},
	# 2-6: 混合小队：支援与输出
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":11},{"role":Enemy.Role.VANGUARD,"level":11,"elite":true},{"role":Enemy.Role.MAGE,"level":10,"elite":true},{"role":Enemy.Role.ARCHER,"level":10}]},
	# 2-7: 新敌：精英大祭祀；蓄满即双击
	{"introduction":true,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":13,"elite":true},{"role":Enemy.Role.VANGUARD,"level":11}]},
	# 2-8: 练习：嘲讽保护蓄力者
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":12},{"role":Enemy.Role.HIGH_PRIEST,"level":13,"elite":true},{"role":Enemy.Role.MAGE,"level":11,"elite":true}]},
	# 2-9: Boss前压力：高等级前排与较弱支援
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":13,"elite":true},{"role":Enemy.Role.HIGH_PRIEST,"level":12,"elite":true},{"role":Enemy.Role.ARCHER,"level":13}]},
	# 2-10: Boss：精灵魔剑士；双阶段
	{"introduction":true,"units":[{"role":Enemy.Role.SPELLSWORD,"level":11,"elite":true}]},
	# 3-1: 断层：重甲与火力
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":14,"elite":true},{"role":Enemy.Role.MAGE,"level":13,"elite":true},{"role":Enemy.Role.ARCHER,"level":14}]},
	# 3-2: 缓冲：已知远程小队
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":14,"elite":true},{"role":Enemy.Role.ARCHER,"level":14,"elite":true},{"role":Enemy.Role.MAGE,"level":13,"elite":true}]},
	# 3-3: 熟悉：祝福与保护
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":14},{"role":Enemy.Role.HIGH_PRIEST,"level":14},{"role":Enemy.Role.VANGUARD,"level":14,"elite":true}]},
	# 3-4: 断层：双线压力
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":16,"elite":true},{"role":Enemy.Role.HIGH_PRIEST,"level":15,"elite":true},{"role":Enemy.Role.MAGE,"level":14,"elite":true}]},
	# 3-5: 缓冲：远程与群疗
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":16,"elite":true},{"role":Enemy.Role.ARCHER,"level":16,"elite":true},{"role":Enemy.Role.MAGE,"level":15,"elite":true}]},
	# 3-6: 熟悉：蓄力与支援
	{"introduction":false,"units":[{"role":Enemy.Role.HIGH_PRIEST,"level":16,"elite":true},{"role":Enemy.Role.VANGUARD,"level":16,"elite":true},{"role":Enemy.Role.MAGE,"level":15,"elite":true}]},
	# 3-7: 断层：内殿卫队
	{"introduction":true,"units":[{"role":Enemy.Role.PALADIN,"level":18,"elite":true},{"role":Enemy.Role.HIGH_PRIEST,"level":17,"elite":true},{"role":Enemy.Role.ARCHER,"level":18}]},
	# 3-8: 缓冲：破阵后的火力
	{"introduction":false,"units":[{"role":Enemy.Role.VANGUARD,"level":17,"elite":true},{"role":Enemy.Role.MAGE,"level":18,"elite":true},{"role":Enemy.Role.ARCHER,"level":17,"elite":true}]},
	# 3-9: Boss前压力：最终护卫
	{"introduction":false,"units":[{"role":Enemy.Role.PALADIN,"level":17,"elite":true},{"role":Enemy.Role.HIGH_PRIEST,"level":18,"elite":true},{"role":Enemy.Role.MAGE,"level":17,"elite":true}]},
	# 3-10: Boss：狂热法师与恶魔契约
	{"introduction":true,"units":[{"role":Enemy.Role.FANATIC,"level":13,"elite":true}]},
]
const COUNT := 31
const CITY_STAGE := COUNT-1
const CITY_HP := 20000

## Boss milestones always remain combat destinations.
static func is_boss_stage(stage: int) -> bool:
	return stage >= 0 and stage < SQUADS.size() and SQUADS[stage].units.any(func(entry): return Enemy.ITEMS[entry.role].get("boss",false))

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
	return {"art":Enemy.ITEMS[entry.role].art,"highlight":entry.get("elite",false) or entry.role in Enemy.SPECIAL}

## Roll positioning only; types and levels remain predictable across seeds and routes.
static func create(stage: int, rng: RandomNumberGenerator) -> Array:
	if stage < 0 or stage >= SQUADS.size(): return []
	var result: Array = []
	for entry in SQUADS[stage].units:
		var unit: Dictionary = Enemy.make(entry.role,entry.level,entry.get("elite",false))
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
