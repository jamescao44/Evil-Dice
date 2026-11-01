extends SceneTree
## Health-only tuning preserves outgoing damage, saved ownership and enemy-friendly damage.
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func growth() -> void:
	for level in [1,2,5,10,20]:
		var m = Run.new(923)
		m.hp = 1
		m.gain_souls(5*level*(level-1))
		check(m.max_hp == 1000,"Maximum health stays fixed across character levels")
		check(is_equal_approx(m.character_base_damage(),5*pow(1.1,level-1)),"Outgoing base damage keeps 10% growth")
		if level > 1: check(m.hp == m.max_hp,"Level-up still fully heals")
	check(Run.LEVEL_HEALTH_FACTOR == 1.0 and Run.LEVEL_DAMAGE_FACTOR == 1.1,"Health and damage tuning are independent")

func checkpoint() -> void:
	var m = Run.new(923)
	m.gain_souls(450); m.stage = 7
	m.acquire_relic("bracelet"); m.grant_tarot("strength"); m.gemstones.add("healing",1)
	var saved: Dictionary = m.Campaign.capture(m)
	var old: Dictionary = saved.duplicate(true)
	old.erase("health_growth"); old.run.base_max_hp = 2358
	var next = Run.new(3)
	check(m.Campaign.restore(next,old) and next.base_max_hp == 1000 and next.hp == next.max_hp,"Existing level-ten checkpoints immediately receive the new health curve")
	check(next.character_level == 10 and next.souls == m.souls and next.relics.items == saved.relics and next.tarots.items == saved.tarots and next.gemstones.save() == saved.run.gemstones,"Migration preserves XP, relics, tarots and gems")
	check(old.run.base_max_hp == 2358 and not old.has("health_growth"),"Restore does not mutate the stored checkpoint")
	m.Campaign.restore(next,old)
	check(next.base_max_hp == 1000,"Retrying the old checkpoint cannot compound the migration")
	next.stage = 7
	var migrated: Dictionary = next.Campaign.capture(next)
	check(migrated.health_growth == 1.0,"New checkpoints record their health-growth version")
	m.Campaign.restore(next,migrated)
	check(next.base_max_hp == 1000,"Resaving and restoring keeps health unchanged")
	old.run.base_max_hp += 100
	m.Campaign.restore(next,old)
	check(next.base_max_hp == 1100,"Any existing non-level health adjustment is retained")
	old.health_growth = 1.2; old.run.base_max_hp = 5160
	m.Campaign.restore(next,old)
	check(next.base_max_hp == 1000,"The previous 20% growth checkpoint also migrates to fixed health")
	old.health_growth = INF
	check(not m.Campaign.valid(old),"Invalid saved growth cannot corrupt restored health")

func friendly_damage() -> void:
	for level in [1,20]:
		var m = Run.new(923)
		m.character_level = level; m.base_max_hp = m.Vitals.base_health(level); m.hp = m.max_hp
		m.enemies = [Enemy.make(Enemy.Role.MAGE,5),Enemy.make(Enemy.Role.VANGUARD,5)]
		m.enemies[0].modifier = "manic"
		var move := {}
		for attempt in range(100):
			move = Actions.intent(m,0,"attack")
			if move.get("friendly_fire",false): break
		check(move.get("friendly_fire",false) and move.amount == 586,"Manic friendly fire retains the enemy-level budget at any player level")
		var before: int = m.enemies[1].hp
		m.phase = "enemy"; m.enemies[0].intent = move
		m.enemy_act(0)
		check(before-m.enemies[1].hp == 59,"Player health growth does not amplify actual damage between enemies")
		m.enemies = [Enemy.make(Enemy.Role.BOMBER,5),Enemy.make(Enemy.Role.VANGUARD,5)]
		before = m.enemies[1].hp
		m.hit_enemy(0,99999,true)
		check(before-m.enemies[1].hp == 44,"Bomber death blast follows its updated 30% budget, independently of player level")

func _initialize() -> void:
	growth(); checkpoint(); friendly_damage()
	print("Health growth: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
