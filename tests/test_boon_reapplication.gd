extends SceneTree
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Catalog = preload("res://scripts/status/status_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(city: bool = false):
	var m = Run.new(64) if city else Rules.new(64)
	if city:
		m.stage = Waves.CITY_STAGE
		m._load_wave()
	m.max_hp = 1000
	m.hp = 100
	for e in m.enemies:
		e.hp = 1000
		e.max_hp = 1000
		e.damage = 0
	return m

func freezing() -> void:
	for spare in [1,3,4,5,6]:
		var m = fresh()
		m.begin_round()
		m.enemies[0].shield = 20
		m.enemies[2].hp = 0
		m.apply_enemy_status(1,Status.FROZEN,2)
		m.statuses[Status.MIGHT].apply(4)
		m.statuses[Status.HIDDEN].apply(3)
		m.tarot_effects.extra_uses = 2
		m.set_test_roll([2,2,spare])
		check(not m.pending.is_attack() and m.pending.is_freeze(),"Double-2 is a non-attack freeze")
		var events: Array = m.apply_player()
		check(events.size() == 2 and events.all(func(e): return e.type == "status" and e.amount == 1),"Freeze adds exactly one stack per living enemy regardless of spare die")
		check(m.enemies[0].hp == 1000 and m.enemies[0].shield == 20 and m.hp == 100 and m.status_count(2) == 0,"Freeze neither damages shields/health nor grants regeneration")
		check(m.enemy_status_count(0,Status.FROZEN) == 1 and m.enemy_status_count(1,Status.FROZEN) == 3 and m.enemy_status_count(2,Status.FROZEN) == 0,"Freeze adds to existing stacks and ignores corpses")
		check(m.status_count(Status.MIGHT) == 4 and m.status_count(Status.HIDDEN) == 3 and m.tarot_effects.extra_uses == 2,"Freeze preserves attack charges, invisibility and High Priestess")
		check(m.apply_player().is_empty(),"A resolved freeze cannot apply twice")
		for i in m.living():
			m.enemies[i].intent = {"type":"attack","target":-1,"amount":20}
			check(m.enemy_act(i)[0].type == "skip","Every frozen enemy skips its queued action")
		m.end_round()
		check(m.hp == 100 and m.enemy_status_count(0,Status.FROZEN) == 0 and m.enemy_status_count(1,Status.FROZEN) == 2,"One layer is spent per missed action")
	var m = fresh()
	m.begin_round()
	m.tarot_effects.strength = 2
	m.saved_skill = Rules.classify([2,2,5])
	m.set_test_roll([1,2,3])
	var pending = m.pending.duplicate()
	check(m.begin_saved_cast(),"Saved freeze can cast before a waiting attack")
	m.apply_player()
	check(m.pending.same_as(pending) and m.phase == "player" and m.enemy_status_count(0,Status.FROZEN) == 3,"Strength increases freeze potency and the saved cast preserves the waiting skill")
	check(m.tarot_effects.strength == 0,"Freeze consumes the next-support Strength modifier")
	m = fresh(true)
	m.begin_round()
	m.set_test_roll([2,2,4])
	var events: Array = m.apply_player()
	check(events.size() == 1 and events[0].type == "immune" and events[0].target == -2,"City freeze shows immunity and completes normally")
	check(m.city_hp == Run.CITY_MAX_HP and m.hp == 100 and m.status_count(2) == 0 and m.pending.is_empty(),"Freeze cannot damage, heal or lock the city")

func shockwaves() -> void:
	for city in [false,true]:
		for strong in [false,true]:
			var m = fresh(city)
			m.begin_round()
			var id: int = 33 if strong else 3
			var values: Array = [3,3,3] if strong else [3,3,4]
			m.statuses[id].apply(1)
			m.set_test_roll(values)
			var events: Array = m.apply_player()
			var damage: Array = events.filter(func(e): return e.type == "damage")
			var expected: int = 150 if strong else 15
			check(damage.size() == (1 if city else 3) and damage.all(func(e): return e.display_amount == expected),"Same-boon reapplication hits every enemy using old active damage modifiers")
			check(events.filter(func(e): return e.type == "boon_wave").size() == 1,"One shockwave event per reapplication")
			check(m.status_count(id) == (3 if strong else 4),"Attack boon refreshes after the wave")
			m = fresh(city)
			m.begin_round()
			m.statuses[3 if strong else 33].apply(2)
			m.set_test_roll(values)
			events = m.apply_player()
			check(not events.any(func(e): return e.type == "boon_wave"),"Different attack boons do not trigger one another's recast")
	var m = fresh()
	m.begin_round()
	m.statuses[3].apply(4)
	m.enemies[0].shield = 10
	m.enemies[1].hp = 2
	m.apply_enemy_status(2,Status.CORROSION,3)
	m.acquire_relic("bracelet")
	m.acquire_relic("orange_stone")
	m.set_test_roll([3,3,4])
	var events: Array = m.apply_player()
	check(m.enemies[0].hp == 1000 and m.enemies[0].shield == 0,"Shockwave respects shield without HP spill")
	check(m.enemies[1].hp == 0 and events.any(func(e): return e.target == 1 and e.get("display_amount",0) == 30),"Relic base bonus and full overkill damage are applied")
	check(m.enemies[2].hp == 955,"Corrosion increases area damage")
	check(m.enemy_status_count(2,Status.BURNING) == 1,"Damage applies attack relic status effects")
	m = fresh()
	m.begin_round()
	m.statuses[3].apply(2)
	for e in m.enemies: e.hp = 1
	m.set_test_roll([3,3,1])
	m.apply_player()
	check(m.outcome() == "victory" and m.pending.is_empty(),"Shockwave can complete a fight without leaving a pending skill")

func immunity() -> void:
	var m = fresh()
	m.begin_round()
	m.statuses[6].apply(3)
	m.set_test_roll([6,6,4])
	m.apply_player()
	check(m.status_count(6) == 7,"Invulnerability adds all new turns")
	for i in m.living():
		m.enemies[i].intent = {"type":"attack","target":-1,"amount":20}
		m.enemy_act(i)
	m.end_round()
	check(m.status_count(6) == 6 and m.hp == 100,"Extended invulnerability ticks once after all enemies")
	m = fresh(true)
	m.begin_round()
	m.statuses[6].apply(3)
	m.city_immunity_clock = 1.25
	m.set_test_roll([6,6,4])
	m.apply_player()
	check(is_equal_approx(m.city_immunity_seconds(),12.75),"City extension preserves the partially elapsed old stack")
	m.tick_city(0,12.75)
	check(m.status_count(6) == 0,"Extended city protection still expires on time")

func enemy_buffs() -> void:
	var m = fresh()
	m.begin_round()
	m.enemies[0].shield = 12
	m.enemies[0].attack_boost = true
	m.apply_enemy_status(0,Status.BURNING,2)
	var rows: Array = Catalog.enemy_active(m.enemies[0])
	check(rows.size() == 3 and rows[0].id == "enemy_shield" and rows[1].id == "enemy_empower" and rows[2].id == Status.BURNING,"Buffs and harmful statuses share one ordered presentation list")
	check(rows[0].turns == 12 and rows[1].counter == GameText.text("Next x1.5"),"Buffs display shield points and next-attack potency, not fake turn durations")
	m.hit_enemy(0,12)
	m.phase = "enemy"
	m.enemies[0].intent = {"type":"attack","target":-1,"amount":10}
	m.enemy_act(0)
	check(m.enemies[0].attack_boost,"Shield break skips the enemy action without spending its attack boost")
	m.enemies[0].acted = false
	m.enemy_act(0)
	rows = Catalog.enemy_active(m.enemies[0])
	check(rows.size() == 1 and rows[0].id == Status.BURNING,"Consumed buffs disappear immediately while afflictions remain")

func shield_break() -> void:
	var m = fresh()
	m.begin_round()
	m.enemies[0].shield = 10
	m.hit_enemy(0,9)
	check(not m.enemy_cannot_act(0),"Partial shield damage does not immobilize")
	m.hit_enemy(0,1)
	check(m.enemy_status_count(0,Status.IMMOBILIZED) == 1 and m.enemies[0].hp == 1000,"An exact shield break applies one missed action without HP spill")
	m.hit_enemy(0,1)
	check(m.enemy_status_count(0,Status.IMMOBILIZED) == 1,"Subsequent unshielded hits do not extend the action lock")
	m.phase = "enemy"
	m.enemies[0].intent = {"type":"attack","target":-1,"amount":10}
	var hp: int = m.hp
	check(m.enemy_act(0)[0].type == "skip" and m.hp == hp,"Broken shield suppresses the queued attack")
	check(not m.enemy_cannot_act(0) and m.enemy_act(0).is_empty(),"Skipped action consumes immobilization exactly once")
	for i in m.living(): m.enemies[i].acted = true
	m.end_round()
	m.begin_round()
	m.phase = "enemy"
	m.enemies[0].intent = {"type":"attack","target":-1,"amount":10}
	m.enemy_act(0)
	check(m.hp == hp-10,"Enemy acts normally in the next round")
	for type in ["heal","shield","empower","team_heal"]:
		m = fresh()
		m.begin_round()
		m.enemies[0].shield = 5
		m.hit_enemy(0,50)
		m.phase = "enemy"
		m.enemies[0].intent = {"type":type,"target":0,"amount":10}
		check(m.enemy_act(0)[0].type == "skip","Immobilization suppresses support move: "+type)
	m = fresh()
	m.begin_round()
	m.enemies[0].shield = 5
	m.apply_enemy_status(0,Status.CORROSION,3)
	m.hit_enemy(0,10)
	check(not m.enemy_cannot_act(0) and m.enemies[0].shield == 5,"Corrosion bypass does not count as breaking a shield")
	m.enemies[1].shield = 5
	m.hit_enemy(1,10,true)
	check(not m.enemy_cannot_act(1),"Ignoring a shield does not cause shield-break immobilization")
	m.enemies[2].shield = 5
	m.enemies[2].acted = true
	m.hit_enemy(2,5)
	for i in m.living(): m.enemies[i].acted = true
	m.phase = "enemy"
	m.end_round()
	m.begin_round()
	check(m.enemy_cannot_act(2),"Breaking after an enemy acts carries the skip to its next action")
	m.apply_enemy_status(2,Status.FROZEN,1)
	m.phase = "enemy"
	m.enemy_act(2)
	check(not m.enemy_cannot_act(2),"Overlapping freeze and shield break consume the same missed action")
	m = fresh(true)
	check(m.apply_enemy_status(-2,Status.IMMOBILIZED,1).is_empty(),"City remains immune")

func run() -> void:
	freezing()
	shockwaves()
	immunity()
	enemy_buffs()
	shield_break()
	print("Boon reapplication: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
