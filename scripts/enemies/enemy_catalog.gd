extends RefCounted
const Vitals = preload("res://scripts/combat/player_vitals.gd")
## Enemy identities and weighted moves; every recruitable elite shares health/damage factors and one trait.
const Status = preload("res://scripts/status/status_effect.gd")
const Modifiers = preload("res://scripts/enemies/enemy_modifiers.gd")
const BossBalance = preload("res://scripts/enemies/boss_balance.gd")
const Damage = preload("res://scripts/enemies/enemy_damage.gd")
const ELITE_HEALTH_FACTOR := 1.5
const ELITE_DAMAGE_FACTOR := 1.25
const Level = preload("res://scripts/enemies/enemy_level.gd")
# Explicit IDs remain stable in saves, wave data and CLI commands when rows move.
enum Role { VANGUARD = 0, ARCHER = 1, MAGE = 2, PALADIN = 3, HIGH_PRIEST = 4, COMMANDER = 5, SPELLSWORD = 6, FANATIC = 7, OCTOPUS = 8, TENTACLE = 9, BOUND_DEMON = 10, MAGIC_CANNON = 11, CLERIC = 12, ASSASSIN = 13, BOMBER = 14 }
const REWARDS := {"normal":{"gems":[5,8],"souls":[5,10]}, "special":{"gems":[10,15],"souls":[20,50]}}

static func crystal_reward(enemy: Dictionary) -> int:
	if enemy.get("summoned",false): return 0
	var base: int = REWARDS[ITEMS[enemy.role].get("reward_class","normal")].gems[int(enemy.get("elite",false))]
	return Level.scaled(base,Level.gem_scale(enemy.get("level",1)))

## Soul XP depends on the defeated enemy's class, independently of gem bonuses.
static func soul_reward(enemy: Dictionary) -> int:
	if enemy.get("summoned",false): return 0
	var base: int = REWARDS[ITEMS[enemy.role].get("reward_class","normal")].souls[int(enemy.get("elite",false))]
	return Level.scaled(base,Level.soul_scale(enemy.get("level",1))*enemy.get("soul_reward_factor",1.0))

const ITEMS := {
	Role.VANGUARD: {"name":"Vanguard","art":"vanguard","standard_elite":true,"hp":[75,75],"damage_percent":11.0,"shield_cap":20,"color":Color("ffe388"),"attribute":Status.Attribute.SHOCK,"skills":[["attack",5],["shield",5]],"elite_skills":[]},
	Role.ARCHER: {"name":"Elf Archer","art":"archer","standard_elite":true,"hp":[50,50],"damage_percent":15.0,"shield_cap":20,"color":Color("82dfff"),"attribute":Status.Attribute.ICE,"skills":[["attack",5],["heal",3]],"elite_skills":[]},
	Role.MAGE: {"name":"Mage","art":"mage","standard_elite":true,"hp":[35,35],"damage_percent":20.0,"shield_cap":20,"color":Color("ff9955"),"attribute":Status.Attribute.FIRE,"skills":[["attack",5],["empower",5]],"elite_skills":[],"normal_art":"mage_normal","normal_art_file":"res://assets/art/enemies/mage/sprite.png"},
	Role.CLERIC: {"name":"Cleric","art":"cleric","standard_elite":true,"hp":[50,50],"damage_percent":15.0,"shield_cap":20,"color":Color("ffe6bd"),"attribute":Status.Attribute.NONE,"skills":[["team_mend",5],["team_shield",2],["attack",2]],"elite_skills":[]},
	Role.ASSASSIN: {"name":"Assassin","art":"assassin","standard_elite":true,"swift":true,"hp":[40,40],"damage_percent":8.0,"shield_cap":20,"color":Color("b4b6e9"),"attribute":Status.Attribute.NONE,"skills":[["flurry",1]],"elite_skills":[]},
	Role.PALADIN: {"name":"Paladin","art":"paladin","standard_elite":true,"hp":[280,280],"damage_percent":15.0,"shield_cap":100,"color":Color("fff2af"),"attribute":Status.Attribute.SHOCK,"skills":[["attack",3],["shield",3],["rest",3]],"elite_skills":[],"taunt":true,"reward_class":"special","shield_gain":50},
	Role.HIGH_PRIEST: {"name":"High Priest","art":"high_priest","standard_elite":true,"hp":[100,100],"damage_percent":20.0,"shield_cap":20,"color":Color("c9a5ff"),"attribute":Status.Attribute.DARK,"skills":[["attack",3],["team_empower",3],["elemental",3]],"elite_skills":[],"reward_class":"special"},
	Role.COMMANDER: {"name":"Knight Commander","art":"paladin","boss":true,"interrupt_shapes":[3,4,5],"break_casts":0,"phase_two_hp":1100,"hp":[750,750],"shield_cap":200,"color":Color("ffcc68"),"attribute":Status.Attribute.NONE,"skills":[["shield",3],["charge",5]],"elite_skills":[],"charge_turns":3,"release":"commander_slam","release_hits":1,"size_multiplier":2.0,"release_on_full_charge":true,"reward_class":"special","shield_gain":50,"phase_two_shield_gain":100},
	Role.SPELLSWORD: {"name":"Elf Spellsword","art":"spellsword","boss":true,"interrupt_shapes":[3,4,5],"break_casts":0,"phase_two_hp":1200,"hp":[1000,1000],"shield_cap":0,"color":Color("b9a0ff"),"attribute":Status.Attribute.NONE,"skills":[["charge",5],["frost_bind",2],["spellsword_mend",2]],"phase_two_skills":[["charge",5],["frost_bind",2],["corrosive_heal",2]],"elite_skills":[],"charge_turns":2,"release":"dark_slash","release_hits":1,"size_multiplier":2.0,"release_on_full_charge":true,"reward_class":"special"},
	Role.FANATIC: {"name":"Fanatical Mage","art":"fanatic","boss":true,"break_casts":0,"phase_two_hp":1500,"hp":[900,900],"shield_cap":0,"color":Color("d290ff"),"attribute":Status.Attribute.NONE,"skills":[["summon_minions",2],["abyss_gaze",3],["split_minions",3]],"elite_skills":[],"size_multiplier":2.0,"reward_class":"special"},
	Role.OCTOPUS: {"name":"Octopus Minion","art":"octopus","hp":[50,50],"damage_percent":12.0,"shield_cap":0,"color":Color("b090df"),"attribute":Status.Attribute.NONE,"skills":[["attack",1]],"elite_skills":[],"size_multiplier":0.8},
	Role.TENTACLE: {"name":"Abyssal Tentacle","art":"tentacle","hp":[10,10],"damage_percent":12.0,"shield_cap":0,"color":Color("c785e2"),"attribute":Status.Attribute.NONE,"skills":[["attack",1]],"elite_skills":[],"size_multiplier":0.65},
	Role.BOUND_DEMON: {"name":"Bound Demon","art":"bound_demon","hp":[10000,10000],"damage_percent":30.0,"shield_cap":0,"color":Color("ff8775"),"attribute":Status.Attribute.NONE,"skills":[["charge",1]],"elite_skills":[],"charge_turns":2,"release":"demon_slam","release_hits":1,"interrupt_shapes":[3,4,5],"break_casts":0,"interruptible":true,"size_multiplier":1.8,"release_on_full_charge":true,"taunt":true,"death_tarot_immune":true},
	Role.BOMBER: {"name":"Bomber","art":"bomber","standard_elite":true,"hp":[250,250],"damage_percent":30.0,"shield_cap":0,"color":Color("ffb465"),"attribute":Status.Attribute.NONE,"skills":[["charge",1]],"elite_skills":[],"charge_turns":3,"release":"bomb_throw","release_hits":1,"release_on_full_charge":true,"reward_class":"special","death_blast":true,"art_file":"res://assets/art/enemies/bomber.svg"},
	Role.MAGIC_CANNON: {"name":"Magic Cannon","art":"magic_cannon","standard_elite":true,"hp":[500,500],"damage_percent":50.0,"shield_cap":0,"color":Color("d6a0ff"),"attribute":Status.Attribute.NONE,"skills":[["charge",3]],"elite_skills":[],"interrupt_shapes":[3,4,5],"interrupt_skips_action":false,"charge_turns":3,"release":"cannon_shot","release_hits":1,"release_on_full_charge":true,"reward_class":"special","art_file":"res://assets/art/enemies/magic_cannon.svg"},
}

## Spawn from an explicit level, shared by combat, previews, bosses and rewards.
static func make(role: int, level: int = 1, elite: bool = false, rng: RandomNumberGenerator = null) -> Dictionary:
	var data: Dictionary = ITEMS[role]
	level = Level.normalized(level)
	var boss: bool = data.get("boss",false)
	var standard: bool = data.get("standard_elite",false)
	var elite_health: float = ELITE_HEALTH_FACTOR if elite and standard else 1.0
	var elite_damage: float = ELITE_DAMAGE_FACTOR if elite and standard else 1.0
	var health_factor: float = BossBalance.health_scale(data.name,level) if boss else Level.health_scale(level)
	var health: int = Level.scaled(data.hp[int(elite)],health_factor*elite_health)
	var percent: float = BossBalance.damage_percent(data.name) if boss else data.damage_percent*elite_damage
	var damage: int = Damage.amount(percent,level,level)
	var enemy: Dictionary = {"name":("Elite " if elite and not boss else "")+data.name,"role":role,"level":level,"elite":elite,"attribute":data.attribute if elite and not standard else Status.Attribute.NONE,"hp":health,"max_hp":health,"shield":10 if elite and not standard else 0,"shield_cap":data.shield_cap,"damage":damage,"damage_percent":percent,"attack_boost":false,"heals":0,"charge":0,"charging":false,"action_hit":0,"action_multiplier":1.0,"intent":{},"canceled":false,"acted":false}
	if boss:
		enemy.merge({"elite":true,"boss":true,"boss_phase":1,"break_marks":data.break_casts,"forced_charge":false,"last_skill":"","shield":0,"reinforcement_level":maxi(1,level-3)},true)
	if standard and elite:
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.seed = role*1009+level
		Modifiers.assign(enemy,rng)
	return enemy

## Both boss bars start from their own base HP at the same individual level.
static func phase_health(enemy: Dictionary, phase: int) -> int:
	var data: Dictionary = ITEMS[enemy.role]
	var base: int = data.phase_two_hp if phase == 2 and data.has("phase_two_hp") else data.hp[int(enemy.elite)]
	return Level.scaled(base,BossBalance.health_scale(data.name,enemy.get("level",1),phase))

static func shield_cap(enemy: Dictionary) -> int:
	return ITEMS[enemy.role].shield_cap

static func taunts(enemy: Dictionary) -> bool:
	return enemy.hp > 0 and enemy.get("taunt",ITEMS[enemy.role].get("taunt",false))

## Death tarot cannot erase a boss or the demon sustaining the third boss's pact.
static func death_tarot_immune(enemy: Dictionary) -> bool:
	return enemy.get("boss",false) or ITEMS[enemy.role].get("death_tarot_immune",false)

## Swift hides individual targets while a living non-Swift ally is present; area effects ignore it.
static func targetable(enemies: Array, index: int) -> bool:
	if index < 0 or index >= enemies.size() or (enemies[index].hp <= 0 and not enemies[index].get("phase_transition_pending",false)): return false
	if not ITEMS[enemies[index].role].get("swift",false): return true
	return not enemies.any(func(e): return (e.hp > 0 or e.get("phase_transition_pending",false)) and not ITEMS[e.role].get("swift",false))
