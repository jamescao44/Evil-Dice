extends "res://tools/current_balance.gd"
## First-level pacing: natural rewards plus paired trait probes, with no persistent saves.
const Traits = preload("res://scripts/enemies/enemy_modifiers.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
var phase_rows: Array = []
var phase_start: Dictionary = {}

## A phase counts full round IDs it touches; the transition round can belong to both phases.
func stamp(session) -> Dictionary:
	return {"round":session.model.round_number,"stats":session.stats.duplicate(),"hp":session.model.hp,"max_hp":session.model.max_hp}

func close_phase(session, cleared: bool) -> void:
	if phase_start.is_empty(): return
	var finish: Dictionary = stamp(session)
	var row: Dictionary = {"phase":phase_rows.size()+1,"cleared":cleared,"turns":finish.round-phase_start.round+1,"start":phase_start.duplicate(true),"finish":finish}
	phase_rows.append(row)
	phase_start = finish

## Capture the exact model boundary, including transitions inside automatic attack sequences.
func phase_changed(_index: int, kind: String, session) -> void:
	if kind == "boss_phase": close_phase(session,true)

## Override only the elite's trait, retaining class, level, roster and policy in paired probes.
func set_trait(model, label: String) -> void:
	for index in range(model.enemies.size()):
		var enemy: Dictionary = model.enemies[index]
		if not Enemy.ITEMS[enemy.role].get("standard_elite",false) or not enemy.elite: continue
		enemy.modifier = label if label in Traits.ITEMS else ""
		if label.begins_with("element_"):
			enemy.modifier = "elemental"
			enemy.element = int(label.trim_prefix("element_"))
			enemy.attribute = Traits.ATTRIBUTES[enemy.element]
		enemy.intent = Actions.choose(model,index)

## Stop at the first boss; rewards, cards, shops and gems are still real player choices.
func level_run(seed_value: int) -> Dictionary:
	var session = Session.new(seed_value)
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	phase_rows = []; phase_start = {}
	session.model.boss_changed.connect(phase_changed.bind(session))
	var entries: Dictionary = {}; var boss_start := {}; var count := 0
	var minima: Dictionary = {}
	while session.model.outcome() != "defeat" and count < 2000:
		var state: Dictionary = session.snapshot()
		if not entries.has(str(state.wave)):
			entries[str(state.wave)] = stamp(session)
			entries[str(state.wave)].enemies = state.enemies.duplicate(true)
		if state.wave == 8 and phase_start.is_empty():
			phase_start = stamp(session); boss_start = state.duplicate(true)
		if state.wave == 8 and not state.outcome.is_empty(): break
		var command: Dictionary = choose(state,timing)
		if command.is_empty(): failures.append({"seed":seed_value,"state":state}); break
		var result: Dictionary = session.command(command)
		if not result.ok: failures.append({"seed":seed_value,"command":command,"error":result.error}); break
		minima[str(state.wave)] = minf(minima.get(str(state.wave),1.0),float(session.model.hp)/session.model.max_hp)
		count += 1
	if not phase_start.is_empty(): close_phase(session,session.model.outcome() == "victory")
	var result := {"seed":seed_value,"tarots":allow_tarots,"outcome":session.model.outcome(),"wave":session.model.stage+1,"history":session.history.duplicate(true),"entries":entries,"min_hp":minima,"phases":phase_rows.duplicate(true),"boss_start":boss_start,"stats":session.stats.duplicate(),"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

## Compare traits on wave seven with three ordinary items and identical timing seeds.
func trait_probe(label: String, seed_value: int, build: String = "typical") -> Dictionary:
	var session = Session.new(seed_value)
	var model = session.model
	model.stage = 6; model.wave_kind = "relic"; model._load_wave()
	model.gain_souls(prior_xp(7))
	for id in loadout(7,build): model.acquire_relic(id)
	model.hp = model.max_hp
	set_trait(model,label)
	session._settle()
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	var count := 0; var events: Dictionary = {}; var lowest: int = model.hp
	while model.outcome().is_empty() and count < 600:
		var command: Dictionary = choose(session.snapshot(),timing,false)
		if command.is_empty(): failures.append({"trait":label,"seed":seed_value,"state":session.snapshot()}); break
		var result: Dictionary = session.command(command)
		if not result.ok: failures.append({"trait":label,"command":command,"error":result.error}); break
		for event in result.events: events[event.type] = events.get(event.type,0)+1
		lowest = mini(lowest,model.hp)
		count += 1
	var result := {"trait":label,"build":build,"seed":seed_value,"outcome":model.outcome(),"turns":model.round_number,"min_hp":lowest,"stats":session.stats.duplicate(),"events":events,"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

## Offset seeds are reserved for validation after tuning, rather than reused for fitting.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "test-output/first-level.json"
	var offset: int = int(args[1]) if args.size() > 1 else 0
	var runs: Array = []; var probes: Array = []
	if args.size() < 3 or args[2] != "traits":
		for seed_value in SEEDS:
			for cards in [false,true]:
				allow_tarots = cards
				var result: Dictionary = level_run(seed_value+offset)
				runs.append(result)
				print("Seed %d cards=%s: %s wave %d phases=%s" % [seed_value+offset,cards,result.outcome,result.wave,result.phases.map(func(p): return p.turns)])
	if args.size() < 3 or args[2] != "runs":
		var labels: Array = ["none","shielding","manic","thorns"]
		for element in Traits.ELEMENTS: labels.append("element_%d" % element)
		allow_tarots = false
		for label in labels:
			for build in ["bare","typical"]:
				for seed_value in SEEDS: probes.append(trait_probe(label,seed_value+offset,build))
			print("Probed ",label)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"runs":runs,"traits":probes,"failures":failures},"\t"))
	print("Saved ",output,"; failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
