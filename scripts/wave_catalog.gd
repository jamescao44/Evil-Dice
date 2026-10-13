extends RefCounted
## Rows mirror the design table: random general normal/elite counts, then fixed foes.
## Fixed foes are [EnemyCatalog.Role, elite]. All combat stats remain at 1x.
const Enemy = preload("res://scripts/enemy_catalog.gd")
const SQUADS := [
	{"general":[1,0],"special":[]},
	{"general":[2,0],"special":[]},
	{"general":[0,1],"special":[]},
	{"general":[4,0],"special":[]},
	{"general":[2,1],"special":[]},
	{"general":[6,0],"special":[]},
	{"general":[3,2],"special":[]},
	{"general":[0,3],"special":[]},
	{"general":[3,3],"special":[]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,true]]},
	{"general":[2,0],"special":[[Enemy.Role.PALADIN,false]]},
	{"general":[0,5],"special":[]},
	{"general":[0,2],"special":[[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,false],[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,2],"special":[[Enemy.Role.PALADIN,true]]},
	{"general":[2,2],"special":[[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,0],"special":[[Enemy.Role.PALADIN,false],[Enemy.Role.PALADIN,false],[Enemy.Role.HIGH_PRIEST,false]]},
	{"general":[0,5],"special":[[Enemy.Role.PALADIN,false],[Enemy.Role.HIGH_PRIEST,false]]},
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

static func create(stage: int, rng: RandomNumberGenerator) -> Array:
	if stage == CITY_STAGE: return []
	var result: Array = []
	var row: Dictionary = SQUADS[stage]
	for tier in range(2):
		for i in range(row.general[tier]): result.append(Enemy.make(Enemy.GENERAL[rng.randi_range(0,Enemy.GENERAL.size()-1)],1.0,tier == 1))
	for enemy in row.special: result.append(Enemy.make(enemy[0],1.0,enemy[1]))
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
