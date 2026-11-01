extends "res://tools/current_balance.gd"
## Test-only frequency ablation: identical live rules, with optional matches after corrections.
class FrequencyRun extends Session.Run:
	var repeat_matches := false
	var match_sequences := 0
	var match_hits := 0
	var match_hp_damage := 0
	var measuring_match := false
	func roll_pool(perfect: bool = false, forced: Array = [], free: bool = false, requested: Array = []) -> Array:
		var opening: bool = not dice_turn.has_rolled()
		var changed: Array = super.roll_pool(perfect,forced,free,requested)
		if changed.is_empty(): return changed
		if repeat_matches and not opening:
			# Only groups involving the corrected die fire; unrelated matches cannot repeat.
			roll_attacks = Patterns.automatic_groups(dice_turn.values,dice_turn.unused()).filter(func(group): return group.indices.any(func(i): return i in changed))
			for group in roll_attacks:
				group.skill.socket_gems = gemstones.snapshot(group.indices)
				group.skill.begin_cast(RelicEffects.use_modifiers(relics.items,group.skill,{}))
			if not roll_attacks.is_empty(): phase = "roll_attacks"
		if not roll_attacks.is_empty(): match_sequences += 1
		return changed
	func resolve_roll_attack_step() -> Array:
		measuring_match = true
		var result: Array = super.resolve_roll_attack_step()
		measuring_match = false
		match_hits += result.filter(func(e): return e.type == "damage" and e.target >= 0).size()
		return result
	func hit_enemy(index: int, damage: int, ignore: bool = false, source: String = "") -> int:
		var loss: int = super.hit_enemy(index,damage,ignore,source)
		if measuring_match: match_hp_damage += loss
		return loss

var repeat_matches := false
var phase_start := {}
var phases: Array = []

## Rebind the adapter's existing event callbacks to a fresh, nonpersistent experiment model.
func make_session(seed_value: int):
	var session = Session.new(seed_value)
	var original = session.model
	var model = FrequencyRun.new(seed_value)
	model.repeat_matches = repeat_matches
	for signal_info in original.get_signal_list():
		for link in original.get_signal_connection_list(signal_info.name):
			original.disconnect(signal_info.name,link.callable)
			model.connect(signal_info.name,link.callable)
	session.model = model
	session._settle()
	return session

func stamp(session) -> Dictionary:
	return {"wave":session.model.stage+1,"round":session.model.round_number,"stats":session.stats.duplicate(),"hp":session.model.hp,"max_hp":session.model.max_hp,"level":session.model.character_level,"match_sequences":session.model.match_sequences,"match_hits":session.model.match_hits,"match_hp_damage":session.model.match_hp_damage}

func finish_phase(session, cleared: bool) -> void:
	if phase_start.is_empty(): return
	var finish: Dictionary = stamp(session)
	phases.append({"wave":phase_start.wave,"phase":phase_start.phase,"cleared":cleared,"turns":finish.round-phase_start.round+1,"start":phase_start.duplicate(true),"finish":finish})
	phase_start = {}

func phase_changed(index: int, kind: String, session) -> void:
	if kind != "boss_phase": return
	finish_phase(session,true)
	phase_start = stamp(session); phase_start.phase = session.model.enemies[index].boss_phase

## Use the same visible-state policy, collect every prize, and measure each combat separately.
func play(seed_value: int, probe_wave: int = 0, build: String = "") -> Dictionary:
	var session = make_session(seed_value)
	var model = session.model
	if probe_wave > 0:
		model.stage = probe_wave-1; model.wave_kind = "relic"; model._load_wave()
		model.gain_souls(prior_xp(probe_wave))
		for id in loadout(probe_wave,build): model.acquire_relic(id)
		model.hp = model.max_hp
		session._settle()
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	var waves: Array = []; var wave_start := {}; var wave_min := 1.0
	var entered_stage := -1
	var rerolls := 0; var useful_rerolls := 0; var casts: Dictionary = {}; var cards: Dictionary = {}
	var actions: Array = []; var count := 0; var abort := ""
	phases = []; phase_start = {}
	model.boss_changed.connect(phase_changed.bind(session))
	while model.outcome() != "defeat" and count < 4000:
		var state: Dictionary = session.snapshot()
		if model.stage != entered_stage and not model.at_shop:
			entered_stage = model.stage
			wave_start = stamp(session); wave_start.relics = state.relics.map(func(r): return r.id)
			wave_min = float(model.hp)/model.max_hp
			if model.enemies.any(func(e): return e.get("boss",false)):
				phase_start = stamp(session); phase_start.phase = 1
		if not state.outcome.is_empty() and not wave_start.is_empty():
			waves.append({"start":wave_start.duplicate(true),"finish":stamp(session),"outcome":state.outcome,"min_hp_ratio":wave_min})
			wave_start = {}
			if not phase_start.is_empty(): finish_phase(session,state.outcome == "victory")
		if (probe_wave > 0 and not state.outcome.is_empty()) or (state.outcome == "victory" and state.wave >= Session.Run.PLAYABLE_WAVES): break
		var command: Dictionary = choose(state,timing,probe_wave == 0)
		if command.is_empty(): abort = "no action in "+state.phase; break
		if command.action == "cast": casts[str(state.skill.faces.size())] = casts.get(str(state.skill.faces.size()),0)+1
		if command.action == "tarot":
			var card: Array = state.tarots.filter(func(t): return t.instance == command.instance)
			if not card.is_empty(): cards[card[0].id] = cards.get(card[0].id,0)+1
		var result: Dictionary = session.command(command)
		if not result.ok: abort = result.error; break
		if command.action == "reroll":
			rerolls += 1
			if not result.state.combinations.is_empty(): useful_rerolls += 1
		wave_min = minf(wave_min,float(model.hp)/model.max_hp)
		actions.append({"wave":state.wave,"action":command})
		count += 1
	if count >= 4000: abort = "command limit"
	if not wave_start.is_empty(): waves.append({"start":wave_start.duplicate(true),"finish":stamp(session),"outcome":model.outcome(),"min_hp_ratio":wave_min})
	if not phase_start.is_empty(): finish_phase(session,false)
	if not abort.is_empty(): failures.append({"seed":seed_value,"wave":probe_wave,"mode":repeat_matches,"error":abort})
	var result := {"seed":seed_value,"mode":"repeat_matches" if repeat_matches else "first_only","probe_wave":probe_wave,"build":build,"outcome":model.outcome(),"wave":model.stage+1,"stats":session.stats.duplicate(),"waves":waves,"boss_phases":phases.duplicate(true),"casts":casts,"cards":cards,"rerolls":rerolls,"useful_rerolls":useful_rerolls,"matches":{"sequences":model.match_sequences,"hits":model.match_hits,"hp_damage":model.match_hp_damage},"final_level":model.character_level,"final_relics":session.snapshot().relics.map(func(r):return r.id),"abort":abort,"actions":actions if probe_wave == 0 else [],"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

## Instrumentation must match an untouched session before trusting any ablation results.
func parity() -> void:
	for seed_value in SEEDS:
		var original = Session.new(seed_value)
		var observed = make_session(seed_value)
		var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
		for step in range(80):
			if JSON.stringify(original.snapshot()) != JSON.stringify(observed.snapshot()):
				failures.append({"seed":seed_value,"step":step,"error":"instrumentation changed state"}); break
			if original.model.outcome() == "defeat": break
			var command: Dictionary = choose(original.snapshot(),timing)
			if command.is_empty(): break
			var expected: Dictionary = original.command(command)
			var actual: Dictionary = observed.command(command)
			if JSON.stringify(expected) != JSON.stringify(actual):
				failures.append({"seed":seed_value,"step":step,"error":"instrumentation changed events"}); break
		_cleanup(original); _cleanup(observed)
	print("Instrumentation parity: ",failures)
	quit(1 if not failures.is_empty() else 0)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "parity":
		parity(); return
	var output: String = args[0]
	var limit: int = int(args[1]) if args.size() > 1 else 12
	var probe: bool = args.size() > 2 and args[2] == "probes"
	var runs: Array = []
	for wave in ([1,3,5,7,8,12,16,23,24] if probe else [0]):
		for build in (["typical","meal_core"] if probe else [""]):
			for index in range(limit):
				var seed_value: int = SEEDS[index%SEEDS.size()]+44000+(index/SEEDS.size())*1000
				for mode in [false,true]:
					repeat_matches = mode
					var result: Dictionary = play(seed_value,wave,build)
					runs.append(result)
					print("wave=%d build=%s seed=%d mode=%s outcome=%s stop=%d rolls=%d enemy_phases=%d" % [wave,build,seed_value,result.mode,result.outcome,result.wave,result.stats.rolls,result.stats.enemy_phases])
				var file := FileAccess.open(output+".tmp",FileAccess.WRITE)
				file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"runs":runs,"failures":failures},"\t"))
				file.close()
				DirAccess.rename_absolute(output+".tmp",output)
	print("Saved ",output,"; runs=",runs.size()," failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
