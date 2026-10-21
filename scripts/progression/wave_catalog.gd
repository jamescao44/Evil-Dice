extends RefCounted
## Rows mirror the design table: random general normal/elite counts, then fixed foes.
## Fixed foes are [EnemyCatalog.Role, elite]. Health and damage compound by 1.1 every two waves.
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const SQUADS := [
	{"general":[1,0],"special":[]},
	{"general":[2,0],"special":[]},
	{"general":[0,1],"special":[]},
	{"general":[4,0],"special":[]},
	{"general":[2,1],"special":[]},
	{"general":[5,0],"special":[]},
	{"general":[3,2],"special":[]},
	{"general":[0,3],"special":[]},
	{"general":[2,3],"special":[]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,true]]},
	{"general":[2,0],"special":[[Enemy.Role.PALADIN,false]]},
	{"general":[0,5],"special":[]},
	{"general":[0,2],"special":[[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,false],[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,2],"special":[[Enemy.Role.PALADIN,true]]},
	{"general":[0,3],"special":[[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,false],[Enemy.Role.PALADIN,false],[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,3],"special":[[Enemy.Role.PALADIN,false],[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,true],[Enemy.Role.HIGH_PRIEST,true],[Enemy.Role.HIGH_PRIEST,true]]},
]
const COUNT := 20
const CITY_STAGE := COUNT-1
const CITY_HP := 20000

static func counts() -> Array:
	var result: Array = []
	for row in SQUADS:
		var count: Array = row.general.duplicate()
		for enemy in row.special: count[int(enemy[1])] += 1
		result.append(count)
	return result

## Base roster stats grow in two-wave steps, including wave numbers occupied by shops.
static func stat_scale(stage: int) -> float:
	return pow(1.1,floori(maxi(0,stage)/2.0))

static func create(stage: int, rng: RandomNumberGenerator) -> Array:
	if stage == CITY_STAGE: return []
	var result: Array = []
	var row: Dictionary = SQUADS[stage]
	var scale: float = stat_scale(stage)
	for tier in range(2):
		for i in range(row.general[tier]): result.append(Enemy.make(Enemy.GENERAL[rng.randi_range(0,Enemy.GENERAL.size()-1)],scale,tier == 1,scale))
	for enemy in row.special: result.append(Enemy.make(enemy[0],scale,enemy[1],scale))
	for i in range(result.size()-1,0,-1):
		var other: int = rng.randi_range(0,i)
		var temp: Dictionary = result[i]
		result[i] = result[other]; result[other] = temp
	return result

static func player_size(stage: int) -> float:
	return lerpf(224,288,clampf(float(stage)/CITY_STAGE,0,1))

static func _world_size(stage: int, first: float, final_squad: float, city: float) -> float:
	# Wave 19 keeps the former wave 9 scale. City troops use their own scale.
	if stage >= CITY_STAGE: return city
	return lerpf(first,final_squad,clampf(float(stage)/(CITY_STAGE-1),0,1))

static func enemy_size(stage: int) -> float:
	return _world_size(stage,192,44,20)

static func paving_size(stage: int) -> float:
	return _world_size(stage,96,16,16)

static func scenery_size(stage: int) -> float:
	return _world_size(stage,128,16,12)
