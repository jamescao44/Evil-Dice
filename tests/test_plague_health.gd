extends SceneTree
## Percentage Plague shares one rule across combat, boss phases and debug level changes.
const Run = preload("res://scripts/progression/run_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Adjust = preload("res://scripts/enemies/enemy_debug.gd")
const Text = preload("res://scripts/status/status_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(role: int = Enemy.Role.VANGUARD, elite: bool = false):
	var model = Run.new(20261109)
	model.enemies = [Enemy.make(role,1,elite)]
	model.phase = "player"
	return model

func _initialize() -> void:
	for elite in [false,true]:
		for role in [Enemy.Role.VANGUARD,Enemy.Role.PALADIN,Enemy.Role.MAGIC_CANNON]:
			var m = fresh(role,elite)
			var enemy: Dictionary = m.enemies[0]
			enemy.hp = 1000; enemy.max_hp = 1000
			m.apply_enemy_status(0,Status.PLAGUE,1,false)
			check(enemy.max_hp == 950 and enemy.hp == 950,"All non-boss variants lose five percent per stack")
			m.apply_enemy_status(0,Status.PLAGUE,2,false)
			check(enemy.max_hp == 850 and enemy.healthy_max_hp == 1000,"Stacks add against the original health pool")
			enemy.hp = 100
			m.apply_enemy_status(0,Status.PLAGUE,1,false)
			check(enemy.max_hp == 800 and enemy.hp == 100,"Lowering the cap never heals or removes HP already below it")
			m.apply_enemy_status(0,Status.PLAGUE,100,false)
			check(enemy.hp == 1 and enemy.max_hp == 1,"Plague alone never kills its target")
	for role in [Enemy.Role.COMMANDER,Enemy.Role.SPELLSWORD,Enemy.Role.FANATIC]:
		var m = fresh(role)
		var enemy: Dictionary = m.enemies[0]
		enemy.hp = 10000; enemy.max_hp = 10000
		m.apply_enemy_status(0,Status.PLAGUE,1,false)
		check(enemy.max_hp == 9800,"All bosses lose two percent per stack")
		m.apply_enemy_status(0,Status.PLAGUE,9,false)
		check(enemy.max_hp == 8000,"Ten boss stacks remove twenty percent, without compounding")
		m.apply_enemy_status(0,Status.PLAGUE,40,false)
		check(enemy.max_hp == 1 and enemy.hp == 1,"Boss Plague also respects the one-HP floor")
		m.phase = "executing"
		m.direct_enemy_hp_damage(0,1)
		m.BossRules.finish_attack_sequence(m)
		check(enemy.boss_phase == 2 and not enemy.has("healthy_max_hp") and m.enemy_status_count(0,Status.PLAGUE) == 0,"New boss phase clears Plague and its old baseline")
		var healthy: int = enemy.max_hp
		m.apply_enemy_status(0,Status.PLAGUE,1,false)
		check(enemy.max_hp == roundi(healthy*0.98),"A new phase uses its own original maximum")
	for role in [Enemy.Role.PALADIN,Enemy.Role.COMMANDER]:
		var m = fresh(role)
		m.apply_enemy_status(0,Status.PLAGUE,2,false)
		check(Adjust.set_level(m,10),"Debug can relevel an infected enemy")
		var expected: Dictionary = Enemy.make(role,10)
		var boss: bool = expected.get("boss",false)
		var healthy: int = Enemy.phase_health(expected,1) if boss else expected.max_hp
		check(m.enemies[0].healthy_max_hp == healthy and m.enemies[0].max_hp == Status.plague_max_hp(healthy,2,boss),"Debug recalculates percentage loss from the newly scaled health")
	var m = fresh()
	m.enemies.append(Enemy.make(Enemy.Role.ARCHER))
	for enemy in m.enemies: enemy.max_hp = 1000; enemy.hp = 1000
	m.apply_enemy_status(0,Status.PLAGUE,1,false)
	m._tick_enemy_statuses()
	check(m.enemies[0].max_hp == 900 and m.enemies[1].max_hp == 950,"Growth and spread apply the same percentage rule")
	check(m.apply_affliction(Status.PLAGUE,1).is_empty() and m.status_count(Status.PLAGUE) == 0,"Player remains immune")
	check(Status.plague_max_hp(101,1) == 96 and Status.plague_max_hp(101,1,true) == 99,"Fractional maximum health rounds to whole HP")
	check(Enemy.make(Enemy.Role.PALADIN).max_hp == 280,"Normal level-one Paladin has thirty percent less HP")
	check(Enemy.make(Enemy.Role.PALADIN,1,true).max_hp == 420,"Elite Paladin inherits the same health reduction")
	for level in [4,10,25]:
		check(Enemy.make(Enemy.Role.PALADIN,level).max_hp == Enemy.Level.scaled(280,Enemy.Level.health_scale(level)),"Paladin reduction follows every level")
	for source in [Text.ENTRIES[Status.PLAGUE].text,Text.HELP_TEXT[Status.PLAGUE]]:
		check(source.contains("5%") and source.contains("2%"),"Inspection and help show both percentages")
	print("Plague health and Paladins: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
