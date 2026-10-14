extends RefCounted
## Enemy identities, stats and weighted skill pools. General waves only draw GENERAL.
const Status = preload("res://scripts/status/status_effect.gd")
enum Role { VANGUARD, ARCHER, MAGE, PALADIN, HIGH_PRIEST }
const GENERAL := [Role.VANGUARD,Role.ARCHER,Role.MAGE]
const SPECIAL := [Role.PALADIN,Role.HIGH_PRIEST]

static func crystal_reward(enemy: Dictionary) -> int:
	if enemy.role in SPECIAL: return 15 if enemy.get("elite",false) else 10
	return 8 if enemy.get("elite",false) else 5

const ITEMS := [
	{"name":"Vanguard","art":"vanguard","hp":[75,150],"damage":[5,10],"shield_cap":20,"color":Color("ffe388"),"attribute":Status.Attribute.SHOCK,"skills":[["attack",5],["shield",5]],"elite_skills":[["guard",3],["stun",3]]},
	{"name":"Elf Archer","art":"archer","hp":[50,100],"damage":[7,10],"shield_cap":20,"color":Color("82dfff"),"attribute":Status.Attribute.ICE,"skills":[["attack",10],["heal",5]],"elite_skills":[["team_heal",3],["ice",3]]},
	{"name":"Mage","art":"mage","hp":[35,75],"damage":[10,15],"shield_cap":20,"color":Color("ff9955"),"attribute":Status.Attribute.FIRE,"skills":[["attack",10],["empower",10]],"elite_skills":[["fire",5]]},
	{"name":"Paladin","art":"paladin","hp":[500,1000],"damage":[20,30],"shield_cap":100,"color":Color("fff2af"),"attribute":Status.Attribute.SHOCK,"skills":[["attack",3],["shield",3],["charge",3],["rest",10]],"elite_skills":[["greater_shield",3]],"charge_turns":2,"release":"stun_combo","taunt":true},
	{"name":"High Priest","art":"high_priest","hp":[100,200],"damage":[20,20],"shield_cap":20,"color":Color("c9a5ff"),"attribute":Status.Attribute.DARK,"skills":[["attack",3],["team_empower",3],["elemental",3]],"elite_skills":[["charge",3]],"charge_turns":3,"release":"forbidden_rite"},
]

static func make(role: int, health_scale: float = 1.0, elite: bool = false) -> Dictionary:
	var data: Dictionary = ITEMS[role]
	var health: int = roundi(data.hp[int(elite)]*health_scale+0.0001)
	return {"name":("Elite " if elite else "")+data.name,"role":role,"elite":elite,"attribute":data.attribute if elite else Status.Attribute.NONE,"hp":health,"max_hp":health,"shield":10 if elite else 0,"shield_cap":data.shield_cap,"damage":data.damage[int(elite)],"attack_boost":false,"heals":0,"charge":0,"charging":false,"action_hit":0,"action_multiplier":1.0,"intent":{},"canceled":false,"acted":false}

static func shield_cap(enemy: Dictionary) -> int:
	return ITEMS[enemy.role].shield_cap

static func taunts(enemy: Dictionary) -> bool:
	return enemy.hp > 0 and ITEMS[enemy.role].get("taunt",false)
