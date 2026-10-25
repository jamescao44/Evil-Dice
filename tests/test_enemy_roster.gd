extends SceneTree
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(role: int, elite: bool = false):
	var m = Rules.new(781)
	m.enemies = [Rules.make_enemy(role,1,elite),Rules.make_enemy(0)]
	m.max_hp = 10000; m.hp = 10000
	return m
func act(m, index: int, skill: String) -> Array:
	m.phase = "enemy"; m.enemies[index].acted = false; m.enemies[index].action_hit = 0
	m.enemies[index].intent = Actions.intent(m,index,skill)
	return m.enemy_act(index)
func pool_checks() -> void:
	var expected_hp := [[75,150],[50,100],[35,75],[400,560],[100,200]]
	var expected_damage := [[7,10],[10,15],[15,20],[18,26],[22,30]]
	for role in range(5):
		for elite in [false,true]:
			var m = fresh(role,elite)
			var enemy: Dictionary = m.enemies[0]
			check(enemy.max_hp == expected_hp[role][int(elite)] and enemy.damage == expected_damage[role][int(elite)],"Enemy base stats match the updated design table")
			check(enemy.max_hp == Enemy.ITEMS[role].hp[int(elite)] and enemy.damage == Enemy.ITEMS[role].damage[int(elite)],"Roster stats: %d/%s" % [role,elite])
			enemy.hp -= 1
			var expected: Array = Enemy.ITEMS[role].skills.duplicate()
			if elite: expected.append_array(Enemy.ITEMS[role].elite_skills)
			check(Actions.options(m,0) == expected,"Eligible normal/elite weighted skill pool")
			var counts: Dictionary = {}
			for i in range(6000):
				var move: Dictionary = m.choose_intent(0)
				counts[move.skill] = counts.get(move.skill,0)+1
				if move.skill == "elemental": check(move.status in Status.PLAYER_HARMFUL and move.stacks == 2,"Elemental attack locks two stacks of a player-safe status")
			var total: float = expected.reduce(func(sum,entry): return sum+entry[1],0.0)
			for entry in expected: check(absf(counts.get(entry[0],0)/6000.0-entry[1]/total) < 0.035,"Actual weighted frequency: %d %s" % [role,entry[0]])
	var m = fresh(0,true)
	m.enemies[0].shield = 20; m.enemies[1].shield = 20
	check(Actions.options(m,0).map(func(e): return e[0]) == ["attack","stun"],"Full shields exclude both shield skills")
	m = fresh(1,true)
	check(Actions.options(m,0).map(func(e): return e[0]) == ["attack","ice"],"Full party health excludes both healing moves")
	m.apply_affliction(Status.FROZEN,1)
	check(Actions.options(m,0).map(func(e): return e[0]) == ["attack"],"Frozen player excludes Ice Arrow")
	m = fresh(4,true); m.apply_affliction(Status.FROZEN,1)
	for i in range(100): check(Actions.intent(m,0,"elemental").status != Status.FROZEN,"Elemental strikes cannot refreeze an already frozen player")
	m = fresh(2)
	m.enemies[1].attack_boost = true
	check(Actions.intent(m,0,"empower").target == 0,"Mage may bless itself")
	m.enemies[0].attack_boost = true
	check(Actions.options(m,0).map(func(e): return e[0]) == ["attack"],"No blessing when everyone already has it")
func action_checks() -> void:
	var m = fresh(0,true)
	act(m,0,"shield"); check(m.enemies[0].shield == 15,"Vanguard raises five shield")
	act(m,0,"guard"); check(m.enemies[1].shield == 5,"Elite guards a teammate")
	m = fresh(1)
	m.enemies[0].hp = 1; act(m,0,"heal")
	check(m.enemies[0].hp == 16,"Archer heals thirty percent of maximum")
	m = fresh(2,true); act(m,0,"fire")
	check(m.status_count(Status.BURNING) == 1,"Fireball applies one burning stack")
	m = fresh(4); act(m,0,"team_empower")
	check(m.enemies.all(func(e): return e.attack_boost),"Group blessing includes the caster")
	m = fresh(3,true); m.enemies[0].shield = 0
	act(m,0,"shield"); check(m.enemies[0].shield == 50,"Paladin raises fifty shield")
	act(m,0,"greater_shield"); check(m.enemies[0].shield == 100,"Elite shield caps at one hundred")
	var before: int = m.hp; act(m,0,"rest"); check(m.hp == before,"Rest does nothing")
	# Normal specials introduce support only; charging is reserved for elites.
	for role in [3,4]:
		m = fresh(role)
		check(not Actions.options(m,0).has(["charge",3]),"Normal special units never select charging")
		m = fresh(role,true)
		var immediate: bool = role == Enemy.Role.HIGH_PRIEST
		act(m,0,"charge")
		check(m.enemies[0].charge == 1 and m.hp == 10000 and m.choose_intent(0).skill == "charge","First charge commits the next action without damage")
		m.enemies[0].attack_boost = true
		m.phase = "enemy"; m.enemies[0].acted = false; m.enemies[0].action_hit = 0
		m.enemies[0].intent = m.choose_intent(0)
		m.enemy_act_step(0)
		check(m.enemies[0].charge == 2 and m.hp == 10000,"Second charge fills before any attack impact")
		check(m.enemies[0].acted == not immediate,"Priest remains in its action; Paladin waits until next turn")
		if not immediate:
			m.enemies[0].acted = false; m.enemies[0].intent = m.choose_intent(0)
		check(m.enemies[0].intent.skill == Enemy.ITEMS[role].release,"Full charge selects the correct burst")
		for i in range(2):
			m.enemy_act_step(0)
			check(m.hp == 10000-roundi(m.enemies[0].damage*1.5)*(i+1),"Blessing scales each burst impact once")
			check(m.enemies[0].acted == (i == 1),"Burst completes only after both hits")
		check(not m.enemies[0].charging and m.enemies[0].charge == 0 and not m.enemies[0].attack_boost,"Release consumes charge and blessing")
		check(m.enemy_act_step(0).is_empty(),"Finished burst cannot repeat")
		for status in [Status.FROZEN,Status.IMMOBILIZED]:
			act(m,0,"charge")
			m.apply_enemy_status(0,status,1,false)
			m.phase = "enemy"; m.enemies[0].acted = false; m.enemies[0].action_hit = 0; m.enemies[0].intent = m.choose_intent(0)
			before = m.hp; m.enemy_act(0)
			check(m.hp == before and m.enemies[0].charge == 0 and m.choose_intent(0).skill == "charge","Freeze or immobilization cancels progress and restarts elite charging")
func taunt_checks() -> void:
	var m = fresh(3)
	m.enemies.append(Rules.make_enemy(3))
	check(m.attack_targets() == [0,2],"Single/random attacks target either living Paladin")
	m.begin_round(); m.set_test_roll([4,4,4])
	var preview: Array = m.preview(m.pending,0)
	check(preview.map(func(e): return e.damage) == [30,15,30],"Area attacks damage Paladins fully and protected allies by half")
	check(m.apply_player_step(1).is_empty(),"Target API refuses a protected ally")
	m.apply_player(0)
	check(m.enemies.map(func(e): return e.hp) == [370,60,370],"Area damage matches preview")
	m = fresh(3); m.begin_round(); m.set_test_roll([2,2,3]); m.apply_player()
	check(m.living().all(func(i): return m.enemy_status_count(i,Status.FROZEN) == 1),"Area freeze still reaches protected allies")
	m = fresh(3); m.begin_round(); m.set_test_roll([6,6,6]); m.apply_player()
	check(m.living().is_empty(),"666 bypasses Paladin protection")
	m = fresh(3); m.enemies[0].hp = 1; m.begin_round(); m.set_test_roll([5,5,5])
	m.apply_player_step(0)
	check(m.attack_targets() == [1],"Later hits can target allies after the Paladin falls")
	m = fresh(3)
	var hits: Array = m.RelicEffects.Attack.apply(m,"test",50,true,true).filter(func(e): return e.type == "damage")
	check(hits.map(func(e): return e.display_amount) == [50,25],"Item area damage respects protection")
	var r = Run.new(9); r.enemies = [Rules.make_enemy(3),Rules.make_enemy(0)]; r.begin_round()
	var card: Dictionary = r.tarots.add("death")
	check(r.tarot_effects.cast(r,card.instance_id,{"target":1}).has("error"),"Targeted tarot cannot bypass a living Paladin")
	card = r.tarots.add("chariot"); r.tarot_effects.cast(r,card.instance_id)
	check(r.shield == 50 and r.enemies[0].hp == 400 and r.enemies[1].hp == 75,"Updated Chariot grants player shields without damaging protected allies")
func wave_checks() -> void:
	var m = Run.new(19)
	for wave in range(1,21):
		check(m.load_debug_wave(wave),"Debug loads wave %d" % wave)
		check(m.max_hp == 100 and m.power == 1.0,"Debug loading does not grant player wave bonuses")
		check(m.enemies.size() == Run.Waves.SQUADS[wave-1].units.size(),"Debug uses the authored roster count")
		for enemy in m.enemies:
			var expected: Dictionary = Enemy.make(enemy.role,enemy.level,enemy.elite)
			check(enemy.hp == expected.hp and enemy.damage == expected.damage,"Wave spawns use each enemy's own level")
		if wave in [10,20,30]: check(m.enemies.size() == 1 and m.enemies[0].get("boss",false),"Level finales remain boss encounters")
		check(Run.Waves.player_size(wave) >= Run.Waves.player_size(wave-1),"Horror grows every transition")
	check(Run.Waves.player_size(0) == 224 and Run.Waves.player_size(19) == 288,"Horror starts at 224 and reaches 288 at the city")
	check(Run.Waves.enemy_size(18) == 88 and Run.Waves.enemy_size(29) == 88 and Run.Waves.enemy_size(Run.Waves.CITY_STAGE) == 40,"Late waves preserve the larger readable enemies; city troops keep their separate size")
	check(Run.Waves.paving_size(18) == 16 and Run.Waves.scenery_size(18) == 16,"Final squad retains old wave nine map scale")
	for stage in range(1,Run.Waves.COUNT):
		check(Run.Waves.player_size(stage) >= Run.Waves.player_size(stage-1) and Run.Waves.player_size(stage) <= 288,"Player grows without overshooting or shrinking at city entry")
		check(Run.Waves.enemy_size(stage) <= Run.Waves.enemy_size(stage-1),"Enemies shrink each wave without early-wave size bumps")
		check(Run.Waves.paving_size(stage) <= Run.Waves.paving_size(stage-1) and Run.Waves.scenery_size(stage) <= Run.Waves.scenery_size(stage-1),"Map scale decreases throughout the route")
## Shield breaks interrupt normal enemies, but preserve elite actions and charges.
func shield_break_checks() -> void:
	for role in range(5):
		for elite in [false,true]:
			var m = fresh(role,elite)
			m.enemies[0].shield = 5
			m.enemies[0].intent = Actions.intent(m,0,"attack")
			var hp: int = m.hp
			m.hit_enemy(0,5)
			check(m.enemies[0].shield == 0 and m.enemy_cannot_act(0) == not elite,"Only normal enemies lose their action on shield break")
			m.phase = "enemy"
			m.enemy_act(0)
			check(m.hp == hp-(m.enemies[0].damage if elite else 0),"Elite queued attack still lands after shield breaks")
	for role in [3,4]:
		var m = fresh(role,true)
		act(m,0,"charge")
		m.enemies[0].shield = 5
		m.hit_enemy(0,5)
		check(m.enemies[0].charge == 1 and not m.enemy_cannot_act(0),"Breaking an elite shield preserves its first charge")
		var before: int = m.hp
		act(m,0,"charge")
		check(m.enemies[0].charge == (0 if role == 4 else 2) and m.hp == before-(m.enemies[0].damage*2 if role == 4 else 0),"Full-charge timing survives elite shield break")
		if role == 4: act(m,0,"charge")
		m.apply_enemy_status(0,Status.FROZEN,1)
		act(m,0,"charge")
		check(m.enemies[0].charge == 0,"Freeze still interrupts elite charging")

func _initialize() -> void:
	pool_checks(); action_checks(); taunt_checks(); wave_checks(); shield_break_checks()
	print("Enemy roster and waves: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
