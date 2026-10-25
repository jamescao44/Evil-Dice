extends RefCounted
## Enemy identities, level-one stats and weighted skill pools.
const Status = preload("res://scripts/status/status_effect.gd")
const Level = preload("res://scripts/enemies/enemy_level.gd")
enum Role { VANGUARD, ARCHER, MAGE, PALADIN, HIGH_PRIEST, COMMANDER, SPELLSWORD, FANATIC, OCTOPUS, TENTACLE, BOUND_DEMON }
const GENERAL := [Role.VANGUARD,Role.ARCHER,Role.MAGE]
const SPECIAL := [Role.PALADIN,Role.HIGH_PRIEST,Role.COMMANDER,Role.SPELLSWORD,Role.FANATIC]

static func crystal_reward(enemy: Dictionary) -> int:
	if enemy.get("summoned",false): return 0
	var base: int = (15 if enemy.get("elite",false) else 10) if enemy.role in SPECIAL else (8 if enemy.get("elite",false) else 5)
	return Level.scaled(base,Level.gem_scale(enemy.get("level",1)))

## Soul XP depends on the defeated enemy's class, independently of gem bonuses.
static func soul_reward(enemy: Dictionary) -> int:
	if enemy.get("summoned",false): return 0
	var base: int = (50 if enemy.get("elite",false) else 20) if enemy.role in SPECIAL else (10 if enemy.get("elite",false) else 5)
	return Level.scaled(base,Level.soul_scale(enemy.get("level",1))*enemy.get("soul_reward_factor",1.0))

const ITEMS := [
	{"name":"Vanguard","art":"vanguard","hp":[75,150],"damage":[7,10],"shield_cap":20,"color":Color("ffe388"),"attribute":Status.Attribute.SHOCK,"skills":[["attack",5],["shield",5]],"elite_skills":[["guard",3],["stun",3]]},
	{"name":"Elf Archer","art":"archer","hp":[50,100],"damage":[10,15],"shield_cap":20,"color":Color("82dfff"),"attribute":Status.Attribute.ICE,"skills":[["attack",5],["heal",5]],"elite_skills":[["team_heal",3],["ice",3]]},
	{"name":"Mage","art":"mage","hp":[35,75],"damage":[15,20],"shield_cap":20,"color":Color("ff9955"),"attribute":Status.Attribute.FIRE,"skills":[["attack",5],["empower",5]],"elite_skills":[["fire",5]]},
	{"name":"Paladin","art":"paladin","hp":[400,560],"damage":[18,26],"shield_cap":100,"color":Color("fff2af"),"attribute":Status.Attribute.SHOCK,"skills":[["attack",3],["shield",3],["rest",3]],"elite_skills":[["greater_shield",3],["charge",3]],"charge_turns":2,"release":"stun_combo","release_hits":2,"taunt":true},
	{"name":"High Priest","art":"high_priest","hp":[100,200],"damage":[22,30],"shield_cap":20,"color":Color("c9a5ff"),"attribute":Status.Attribute.DARK,"skills":[["attack",3],["team_empower",3],["elemental",3]],"elite_skills":[["charge",3]],"charge_turns":2,"release":"forbidden_rite","release_hits":2,"release_on_full_charge":true},
	{"name":"Knight Commander","art":"paladin","boss":true,"break_casts":5,"phase_two_hp":1100,"hp":[750,750],"damage":[20,20],"shield_cap":200,"color":Color("ffcc68"),"attribute":Status.Attribute.NONE,"skills":[["shield",3],["charge",5]],"elite_skills":[],"charge_turns":3,"release":"commander_slam","release_hits":1,"size_multiplier":2.0,"release_on_full_charge":true},
	{"name":"Elf Spellsword","art":"spellsword","boss":true,"break_casts":3,"phase_two_hp":1200,"hp":[1000,1000],"damage":[20,20],"shield_cap":0,"color":Color("b9a0ff"),"attribute":Status.Attribute.NONE,"skills":[["charge",5],["frost_bind",2],["spellsword_mend",2]],"phase_two_skills":[["charge",5],["frost_bind",2],["corrosive_heal",2]],"elite_skills":[],"charge_turns":2,"release":"dark_slash","release_hits":1,"size_multiplier":2.0,"release_on_full_charge":true},
	{"name":"Fanatical Mage","art":"fanatic","boss":true,"break_casts":0,"phase_two_hp":1500,"hp":[900,900],"damage":[30,30],"shield_cap":0,"color":Color("d290ff"),"attribute":Status.Attribute.NONE,"skills":[["summon_minions",2],["abyss_gaze",3],["split_minions",3]],"elite_skills":[],"size_multiplier":2.0},
	{"name":"Octopus Minion","art":"octopus","hp":[50,50],"damage":[5,5],"shield_cap":0,"color":Color("b090df"),"attribute":Status.Attribute.NONE,"skills":[["attack",1]],"elite_skills":[],"size_multiplier":0.8},
	{"name":"Abyssal Tentacle","art":"tentacle","hp":[10,10],"damage":[5,5],"shield_cap":0,"color":Color("c785e2"),"attribute":Status.Attribute.NONE,"skills":[["attack",1]],"elite_skills":[],"size_multiplier":0.65},
	{"name":"Bound Demon","art":"bound_demon","hp":[10000,10000],"damage":[30,30],"shield_cap":0,"color":Color("ff8775"),"attribute":Status.Attribute.NONE,"skills":[["charge",1]],"elite_skills":[],"charge_turns":2,"release":"demon_slam","release_hits":1,"break_casts":3,"interruptible":true,"size_multiplier":1.8,"release_on_full_charge":true,"taunt":true},
]

## Spawn from an explicit level, shared by combat, previews, bosses and rewards.
static func make(role: int, level: int = 1, elite: bool = false) -> Dictionary:
	var data: Dictionary = ITEMS[role]
	level = Level.normalized(level)
	var health: int = Level.scaled(data.hp[int(elite)],Level.health_scale(level))
	var boss: bool = data.get("boss",false)
	var enemy: Dictionary = {"name":("Elite " if elite and not boss else "")+data.name,"role":role,"level":level,"elite":elite,"attribute":data.attribute if elite else Status.Attribute.NONE,"hp":health,"max_hp":health,"shield":10 if elite else 0,"shield_cap":data.shield_cap,"damage":Level.scaled(data.damage[int(elite)],Level.damage_scale(level)),"attack_boost":false,"heals":0,"charge":0,"charging":false,"action_hit":0,"action_multiplier":1.0,"intent":{},"canceled":false,"acted":false}
	if boss:
		enemy.merge({"elite":true,"boss":true,"boss_phase":1,"break_marks":data.break_casts,"forced_charge":false,"last_skill":"","shield":0,"reinforcement_level":maxi(1,level-3)},true)
	return enemy

## Both boss bars start from their own base HP at the same individual level.
static func phase_health(enemy: Dictionary, phase: int) -> int:
	var data: Dictionary = ITEMS[enemy.role]
	var base: int = data.phase_two_hp if phase == 2 and data.has("phase_two_hp") else data.hp[int(enemy.elite)]
	return Level.scaled(base,Level.health_scale(enemy.get("level",1)))

static func shield_cap(enemy: Dictionary) -> int:
	return ITEMS[enemy.role].shield_cap

static func taunts(enemy: Dictionary) -> bool:
	return enemy.hp > 0 and ITEMS[enemy.role].get("taunt",false)
