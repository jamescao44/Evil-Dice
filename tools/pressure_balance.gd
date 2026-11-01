extends "res://tools/current_balance.gd"
## Natural CLI runs record damage opportunity, actual enemy phases, XP and boss phase length.
const Moves = preload("res://scripts/enemies/enemy_skill_catalog.gd")
var entries: Dictionary = {}
var phases: Array = []
var phase_start: Dictionary = {}

## Attack capacity excludes buffs and defenses; it is not the average of weighted support turns.
func attack_capacity(enemy: Dictionary, player_level: int) -> int:
	var data: Dictionary = Enemy.ITEMS[enemy.role]
	var maximum := 0
	for option in data.skills:
		var skill: String = data.get("release",option[0]) if option[0] == "charge" else option[0]
		var move: Dictionary = Moves.make(skill,Enemy.Damage.base_hit(enemy,player_level))
		if move.type == "attack": maximum = maxi(maximum,move.amount*move.hits)
	return maximum

## Capture counters at the real boundary without peeking at future rolls or consuming RNG.
func stamp(session) -> Dictionary:
	return {"wave":session.model.stage+1,"round":session.model.round_number,"stats":session.stats.duplicate(),"hp":session.model.hp,"max_hp":session.model.max_hp,"level":session.model.character_level}

## Close the measured health bar at its transition or final outcome.
func finish_phase(session, cleared: bool) -> void:
	if phase_start.is_empty(): return
	var finish: Dictionary = stamp(session)
	phases.append({"wave":phase_start.wave,"phase":phase_start.phase,"cleared":cleared,"turns":finish.round-phase_start.round+1,"start":phase_start.duplicate(true),"finish":finish})
	phase_start = {}

## Both boss health bars are measured separately, including automatic-attack transitions.
func phase_changed(index: int, kind: String, session) -> void:
	if kind != "boss_phase": return
	finish_phase(session,true)
	phase_start = stamp(session)
	phase_start.phase = session.model.enemies[index].boss_phase

## Run with every prize tier available and real visible-state decisions, never user saves.
func pressure_run(seed_value: int) -> Dictionary:
	var session = Session.new(seed_value)
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	entries = {}; phases = []; phase_start = {}
	session.model.boss_changed.connect(phase_changed.bind(session))
	var enemy_phases: Array = []; var level_ups: Array = []; var count := 0
	while session.model.outcome() != "defeat" and count < 4000:
		var state: Dictionary = session.snapshot()
		var key := str(state.wave)
		if not entries.has(key) and not session.model.at_shop:
			var row: Dictionary = stamp(session)
			row.relics = state.relics.map(func(r): return r.id)
			row.base_damage = state.player.base_damage
			row.enemies = []
			row.capacity = 0
			for enemy in session.model.enemies:
				var capacity: int = attack_capacity(enemy,session.model.character_level)
				row.enemies.append({"name":enemy.name,"level":enemy.level,"hp":enemy.max_hp,"damage":Enemy.Damage.base_hit(enemy,session.model.character_level),"damage_percent":enemy.damage_percent,"capacity":capacity,"souls":Enemy.soul_reward(enemy),"modifier":enemy.get("modifier","")})
				row.capacity += capacity
			row.capacity_ratio = float(row.capacity)/row.max_hp
			entries[key] = row
			if session.model.enemies.any(func(e): return e.get("boss",false)):
				phase_start = stamp(session); phase_start.phase = 1
		if not state.outcome.is_empty() and not phase_start.is_empty(): finish_phase(session,state.outcome == "victory")
		if state.outcome == "victory" and state.wave >= Session.Run.PLAYABLE_WAVES: break
		var command: Dictionary = choose(state,timing)
		if command.is_empty(): failures.append({"seed":seed_value,"state":state}); break
		var before: Dictionary = stamp(session)
		var result: Dictionary = session.command(command)
		if not result.ok: failures.append({"seed":seed_value,"command":command,"error":result.error}); break
		var damage: int = session.stats.damage_taken-before.stats.damage_taken
		if session.stats.enemy_phases > before.stats.enemy_phases:
			enemy_phases.append({"wave":state.wave,"round":before.round,"max_hp":before.max_hp,"damage":damage,"ratio":float(damage)/before.max_hp,"events":result.events.filter(func(e): return e.type in ["charge","damage","skip"] and (e.type != "damage" or e.target == -1))})
		for event in result.events:
			if event.type == "level_up": level_ups.append({"wave":state.wave,"level":event.level})
		count += 1
	if not phase_start.is_empty(): finish_phase(session,false)
	var result := {"seed":seed_value,"tarots":allow_tarots,"outcome":session.model.outcome(),"wave":session.model.stage+1,"entries":entries.duplicate(true),"boss_phases":phases.duplicate(true),"enemy_phases":enemy_phases,"level_ups":level_ups,"history":session.history.duplicate(true),"stats":session.stats.duplicate(),"final":session.snapshot(),"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

## Check early durability with a level-one player, natural dice and no relics or cards.
func early_special(role: int, seed_value: int) -> Dictionary:
	var session = Session.new(seed_value)
	var model = session.model
	model.enemies = [Enemy.make(role,1)]
	model.phase = "new"; model.round_number = 0; model.begin_round()
	session._settle()
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	var shots := 0; var count := 0
	while model.outcome().is_empty() and count < 600:
		var command: Dictionary = choose(session.snapshot(),timing,false)
		if command.is_empty(): failures.append({"early_role":role,"seed":seed_value}); break
		var result: Dictionary = session.command(command)
		if not result.ok: failures.append({"command":command,"error":result.error}); break
		for event in result.events:
			if event.type == "charge" and event.amount == 3: shots += 1
		count += 1
	var result := {"role":Enemy.ITEMS[role].name,"seed":seed_value,"outcome":model.outcome(),"shots":shots,"stats":session.stats.duplicate(),"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

## Separate offsets are validation seeds; a small limit supports quick iteration.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0]
	if args.size() > 1 and args[1] == "early":
		allow_tarots = false
		var probes: Array = []
		for role in [Enemy.Role.MAGIC_CANNON,Enemy.Role.BOMBER]:
			for seed_value in SEEDS: probes.append(early_special(role,seed_value))
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"probes":probes,"failures":failures},"\t"))
		print("Early special probes: ",probes.size(),"; failures=",failures.size())
		quit(1 if not failures.is_empty() else 0)
		return
	var offset: int = int(args[1]) if args.size() > 1 else 0
	var limit: int = int(args[2]) if args.size() > 2 else SEEDS.size()
	if limit < 1 or limit > SEEDS.size():
		push_error("Seed count must be between 1 and %d." % SEEDS.size())
		quit(1)
		return
	var runs: Array = []
	for seed_value in SEEDS.slice(0,limit):
		for cards in ([false,true] if args.size() > 3 and args[3] == "paired" else [true]):
			allow_tarots = cards
			var result: Dictionary = pressure_run(seed_value+offset)
			runs.append(result)
			print("Seed %d cards=%s: %s wave %d, boss phases=%s" % [seed_value+offset,cards,result.outcome,result.wave,result.boss_phases.map(func(p): return p.turns)])
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"runs":runs,"failures":failures},"\t"))
	print("Saved ",output,"; failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
