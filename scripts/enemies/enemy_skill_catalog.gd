extends RefCounted
## Reusable move definitions; EnemyActions resolves targets, eligibility and state changes.
const Status = preload("res://scripts/status/status_effect.gd")
const ITEMS := {
	"attack":{"name":"Attack","type":"attack"},
	"flurry":{"name":"Swift Flurry","type":"attack","hits":3},
	"team_mend":{"name":"Group Heal","type":"team_heal","heal_ratio":0.3},
	"team_shield":{"name":"Group Shield","type":"team_shield","shield_ratio":0.1},
	"shield":{"name":"Raise Shield","type":"shield"},
	"greater_shield":{"name":"Greater Shield","type":"shield"},
	"guard":{"name":"Guard Ally","type":"shield"},
	"heal":{"name":"Self Mend","type":"heal","heal_ratio":0.5},
	"spellsword_mend":{"name":"Self Mend","type":"heal","heal_ratio":0.1},
	"team_heal":{"name":"Elven Healing","type":"team_heal","heal_ratio":0.2},
	"empower":{"name":"Blessing","type":"empower"},
	"team_empower":{"name":"Group Blessing","type":"team_empower"},
	"summon_minions":{"name":"Summon Minions","type":"summon_minions","amount":0},
	"split_minions":{"name":"Splintering Grasp","type":"split_minions","amount":0},
	"abyss_gaze":{"name":"Abyssal Gaze","type":"affliction","amount":0,"status":Status.DARKNESS,"stacks":2,"attribute":Status.Attribute.DARK},
	"frost_bind":{"name":"Frost Bind","type":"affliction","amount":0,"status":Status.FROZEN,"stacks":1,"attribute":Status.Attribute.ICE},
	"corrosive_heal":{"name":"Corrosive Heal","type":"corrosive_heal","amount":0,"attribute":Status.Attribute.ACID},
	"bomb_throw":{"name":"Bomb Throw","type":"attack"},
	"cannon_shot":{"name":"Arcane Shot","type":"attack"},
	"demon_slam":{"name":"Demonic Smash","type":"attack"},
	"dark_slash":{"name":"Dark Slash","type":"attack","status":Status.DARKNESS,"stacks":2,"attribute":Status.Attribute.DARK},
	"commander_slam":{"name":"Crushing Blow","type":"attack","status":Status.STUNNED,"stacks":1,"attribute":Status.Attribute.SHOCK},
	"stun":{"name":"Stunning Blow","type":"attack","status":Status.STUNNED,"stacks":1,"attribute":Status.Attribute.SHOCK},
	"ice":{"name":"Ice Arrow","type":"attack","status":Status.FROZEN,"stacks":1,"attribute":Status.Attribute.ICE},
	"fire":{"name":"Fireball","type":"attack","status":Status.BURNING,"stacks":1,"attribute":Status.Attribute.FIRE},
	"elemental":{"name":"Elemental Strike","type":"attack","random_status":true,"status_stacks":{Status.FROZEN:1,Status.BURNING:3,Status.STUNNED:1,Status.DARKNESS:2,Status.CORROSION:2}},
	"stun_combo":{"name":"Stunning Flurry","type":"attack","status":Status.STUNNED,"stacks":1,"attribute":Status.Attribute.SHOCK},
	"forbidden_rite":{"name":"Forbidden Rite","type":"attack"},
	"charge":{"name":"Charge","type":"charge","amount":1},
	"rest":{"name":"Rest","type":"rest","amount":0},
}

## Build fresh intent state; modifying a selected move must never alter its definition.
static func make(skill: String, damage: int) -> Dictionary:
	var data: Dictionary = ITEMS[skill]
	var move := {"skill":skill,"type":"attack","target":-1,"amount":roundi(damage*float(data.get("damage_factor",1.0))),"name":"Attack","attribute":Status.Attribute.NONE,"hits":1,"status":-1,"stacks":0}
	move.merge(data.duplicate(true),true)
	move.erase("damage_factor")
	return move
