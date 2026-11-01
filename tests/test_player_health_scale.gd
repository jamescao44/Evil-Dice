extends SceneTree
## Check player-unit conversion at combat boundaries, fixed boss tuning and legacy checkpoint recovery.
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(830)
	m.enemies = [Enemy.make(Enemy.Role.VANGUARD)]
	m.begin_round()
	return m

## Exercise normal action execution, including actual stored intent damage.
func act(m, skill: String) -> void:
	m.phase = "enemy"; m.enemies[0].acted = false; m.enemies[0].action_hit = 0
	m.enemies[0].intent = Actions.intent(m,0,skill)
	m.enemy_act(0)

func health_units() -> void:
	var m = fresh()
	check(m.hp == 1000 and m.max_hp == 1000 and m.character_base_damage() == 5,"Start with 1000 HP and unchanged outgoing base damage")
	check(m.enemies[0].hp == 75 and m.enemies[0].damage == 110,"Vanguard HP unchanged; its old 11 damage is now 110")
	act(m,"attack"); check(m.hp == 890,"Actual enemy action consumes player-health units exactly once")
	for role in Enemy.ITEMS:
		for level in [1,5,14]:
			for elite in [false,true]:
				var e: Dictionary = Enemy.make(role,level,elite)
				var data: Dictionary = Enemy.ITEMS[role]
				var percent: float = Enemy.BossBalance.damage_percent(data.name) if data.get("boss",false) else data.damage_percent*(1.25 if elite and data.get("standard_elite",false) else 1.0)
				check(e.damage == roundi(m.Vitals.base_health(level)*percent/100.0),"Catalog stores the same-level percentage budget in player HP units")
	m = fresh(); m.apply_affliction(m.Status.BURNING,2); m.phase = "enemy"; m.enemies[0].acted = true
	m.end_round(); check(m.hp == 900 and m.status_count(m.Status.BURNING) == 1,"Player burning ticks 50 twice and decays once")
	m = fresh(); m.apply_enemy_status(0,m.Status.BURNING,2,false); m._tick_enemy_statuses()
	check(m.enemies[0].hp == 65,"Enemy burning retains 5 damage per stack")
	m = fresh(); m.enemies = [Enemy.make(Enemy.Role.FANATIC,14)]
	var i: int = Fanatic.spawn(m,0,Enemy.Role.OCTOPUS)
	check(m.enemies[i].damage == 60,"Summoned minion damage is scaled once, too")
	m = fresh(); m.enemies = [Enemy.make(Enemy.Role.BOMBER),Enemy.make(Enemy.Role.VANGUARD)]
	m.character_level = 50; m.hit_enemy(0,9999,true)
	check(m.enemies[1].hp == 45 and m.hp == 1000,"Bomber friendly death blast retains its updated 30 enemy-HP damage")
	m = fresh(); m.enemies[0].modifier = "manic"
	m.phase = "enemy"; m.enemies[0].intent = {"type":"attack","target":0,"amount":220,"friendly_fire":true}
	m.enemy_act(0)
	check(m.enemies[0].hp == 53 and m.hp == 1000,"Manic friendly attack converts to enemy HP without inflating damage")

func recovery() -> void:
	var m = fresh(); var card: Dictionary = m.tarots.add("chariot")
	m.tarot_effects.cast(m,card.instance_id)
	check(m.shield == 500,"Chariot provides 500 player shield")
	m.receive_damage(110); check(m.hp == 1000 and m.shield == 390,"Shields absorb correctly scaled enemy attacks")
	m.acquire_relic("bookmark"); m.RelicEffects.tarot_used(m)
	check(m.shield == 490,"Bookmark adds 100 shield")
	m = fresh(); card = m.tarots.add("tower"); m.tarot_effects.cast(m,card.instance_id)
	check(m.hp == 700 and m.enemies[0].hp == 25,"Tower costs 300 player HP but still deals 50 enemy damage")
	m = fresh(); m.hp = 500; m.acquire_relic("bloodstone")
	m.RelicEffects.after_hit(m,0,20,m.Skill.new(m.Kind.NORMAL,0,[1,2,3]))
	check(m.hp == 540,"Bloodstone preserves its recovery value despite unscaled outgoing damage")
	m = fresh(); m.acquire_relic("mysterious_seed"); m.enemies[0].hp = 1000; m.enemies[0].max_hp = 1000
	m.heal(100); m.relic_recovery.finish_player_turn(m)
	check(m.enemies[0].hp == 980,"100 overhealing stores only 20 outgoing damage, preserving seed strength")
	check(m.GemEffects.recovery([{"id":"healing","level":1}],[6],1000,"heal") == 60,"Percentage healing scales naturally with max HP")

func boss_tuning() -> void:
	for level in [9,10,11]:
		var m = fresh(); m.character_level = level; m.base_max_hp = 1000; m.hp = m.max_hp
		m.enemies = [Enemy.make(Enemy.Role.SPELLSWORD,10)]
		m.enemies[0].boss_phase = 2
		m.apply_affliction(m.Status.CORROSION,3)
		act(m,"dark_slash")
		var loss: int = m.max_hp-m.hp
		check(absf(float(loss)/m.max_hp-0.6*pow(1.1,10-level)) < 0.002,"Corroded Spellsword budget uses baseline health, not equipped max HP")
		print("Spellsword vs character LV.%d: %d / %d = %.1f%%" % [level,loss,m.max_hp,100.0*loss/m.max_hp])
		if level == 10: check(absf(float(loss)/m.max_hp-0.6) < 0.01,"Normal LV10 build loses about 60% HP")
	var m = fresh(); m.character_level = 10; m.base_max_hp = 1000; m.hp = m.max_hp; m.acquire_relic("reaper_scythe")
	m.enemies = [Enemy.make(Enemy.Role.SPELLSWORD,10)]; m.apply_affliction(m.Status.CORROSION,3)
	act(m,"dark_slash")
	check(m.hp == 0,"Reduced-health relics retain their risk; no adaptive cap")

func checkpoints() -> void:
	var m = fresh(); m.stage = 7; m.base_max_hp = 1000; m.character_level = 10
	m.acquire_relic("bracelet"); m.grant_tarot("strength"); m.gemstones.add("healing",1)
	var saved: Dictionary = m.Campaign.capture(m)
	var next = Run.new(991)
	check(m.Campaign.restore(next,saved) and next.base_max_hp == 1000,"New checkpoint HP is never multiplied twice")
	check(next.relics.items == saved.relics and next.tarots.items == saved.tarots and next.gemstones.save() == saved.run.gemstones,"All collected inventories survive restoration")
	var legacy: Dictionary = saved.duplicate(true); legacy.erase("health_scale"); legacy.run.base_max_hp = 236
	var path: String = "user://test-health-units-%s.dat" % Time.get_ticks_usec()
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_var({"version":2,"checkpoint":legacy,"cleared_level":1}); file.close()
	var progress = m.Campaign.new(); progress.configure(path); progress.start(next)
	check(next.base_max_hp == 2360 and next.relics.items == saved.relics and next.tarots.items == saved.tarots,"Version2 checkpoint converts HP without losing build")
	progress.start(next); check(next.base_max_hp == 2360,"Retry does not compound legacy HP conversion")
	DirAccess.remove_absolute(path)

func _initialize() -> void:
	health_units(); recovery(); boss_tuning(); checkpoints()
	print("Player health scale: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
