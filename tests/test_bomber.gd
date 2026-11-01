extends SceneTree
## Bomber death chains and shared elite-special rules exercise actual combat and rewards.
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _initialize() -> void:
	for role in [Enemy.Role.PALADIN,Enemy.Role.HIGH_PRIEST,Enemy.Role.MAGIC_CANNON,Enemy.Role.BOMBER]:
		for level in [1,4,8]:
			var normal := Enemy.make(role,level)
			var elite := Enemy.make(role,level,true)
			check(elite.max_hp == Enemy.Level.scaled(Enemy.ITEMS[role].hp[0],Enemy.Level.health_scale(level)*1.5),"Special elite HP uses common scalar")
			check(elite.damage == roundi(Run.Vitals.base_health(level)*Enemy.ITEMS[role].damage_percent*1.25/100.0),"Special elite damage rounds once")
			check(elite.modifier in Enemy.Modifiers.ITEMS and elite.shield == 0,"Special elite has one trait, no legacy starting shield")
			check(Enemy.ITEMS[role].elite_skills.is_empty(),"Elite special keeps the normal move pool")
	for role in [Enemy.Role.COMMANDER,Enemy.Role.SPELLSWORD,Enemy.Role.FANATIC]:
		check(not Enemy.make(role,1,true).has("modifier"),"Bosses keep their separate balance and mechanics")
	var m = Run.new(441)
	m.enemies = [Enemy.make(Enemy.Role.BOMBER),Enemy.make(Enemy.Role.VANGUARD)]
	m.character_level = 1
	m.hp = 1000; m.max_hp = 1000
	for turn in range(3):
		m.phase = "enemy"; m.enemies[0].acted = false
		m.enemies[0].intent = Actions.choose(m,0)
		m.enemy_act(0)
		check(m.hp == (700 if turn == 2 else 1000),"Bomber hits immediately on third charge only")
	check(m.enemies[0].charge == 0 and not m.enemies[0].charging,"Firing resets Bomber charge")
	m.character_level = 50 # Isolate death reactions from level-up healing.
	m.enemies[1].hp = 200; m.enemies[1].max_hp = 200
	var gems: int = m.blood_gems
	m.hit_enemy(0,99999,true,"burn")
	check(m.enemies[1].hp == 170 and m.hp == 700,"Death blast hits allies once, never player")
	check(m.enemy_reaction_events.any(func(e): return e.type == "enemy_explosion"),"Death blast queues presentation")
	check(m.blood_gems > gems,"Bomber grants ordinary special rewards")
	gems = m.blood_gems
	m.hit_enemy(0,99999,true)
	check(m.enemies[1].hp == 170 and m.blood_gems == gems,"Corpse cannot explode or reward twice")
	m.enemies = [Enemy.make(Enemy.Role.BOMBER),Enemy.make(Enemy.Role.BOMBER),Enemy.make(Enemy.Role.VANGUARD)]
	m.enemies[1].hp = 30
	m.enemies[2].hp = 300; m.enemies[2].max_hp = 300
	m.hit_enemy(0,99999,true)
	check(m.enemies[1].hp == 0 and m.enemies[2].hp == 240,"Death chains resolve each Bomber exactly once")
	m.enemies = [Enemy.make(Enemy.Role.BOMBER),Enemy.make(Enemy.Role.VANGUARD)]
	m.enemies[1].shield = 5
	m.hit_enemy(0,99999,true)
	check(m.enemies[1].hp == 75 and m.enemies[1].shield == 0,"Blast honors normal shield absorption")
	m.character_level = 1; m.hp = m.max_hp
	m.enemies = [Enemy.make(Enemy.Role.HIGH_PRIEST,1,true)]
	m.enemies[0].modifier = "elemental"; m.enemies[0].element = m.Status.CORROSION
	m.enemies[0].attribute = m.Status.Attribute.ACID
	var move: Dictionary = Actions.intent(m,0,"elemental")
	while not move.has("extra_status"): move = Actions.intent(m,0,"elemental")
	check(move.stacks == 2 and move.extra_status == m.Status.CORROSION,"Native elemental stacks survive the elite trait")
	m.phase = "enemy"; m.enemies[0].intent = move
	m.enemy_act(0)
	check(m.status_count(move.status) == (3 if move.status == m.Status.CORROSION else 2),"Native and elite status applications both resolve")
	print("Bomber and elite specials: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
