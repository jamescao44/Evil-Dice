extends SceneTree
## Reproducible balance probes use the real CLI adapter, with an explicit visible-state policy.
const Session = preload("res://scripts/testing/playtest_session.gd")
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const SEEDS := [11,29,47,83,109,157,211,307,401,503,601,701]
const WAVES := [1,3,5,7,9,10,11,13,15,17,19,20]
const RANK := {"bracelet":90,"oreo_sundae":85,"magic_sword":85,"orange_stone":90,"fries":70,"hamburger":85,"lemon_soda":75,"fried_chicken":70,"mithril_blade":110,"pet_dragon":105,"pet_ghost":95,"runestone":85,"disguise_mask":95,"ancient_tentacle":110,"crystal_ball":90,"bloodstone":80,"armor":65,"heart":55,"blue_stone":85,"green_stone":90,"black_stone":90,"purple_stone":80,"yellow_stone":65,"contract":90,"clover":80,"five_leaf_clover":95,"ancient_prophecy":85,"fortune_cookie":75,"pet_slime":70,"reaper_scythe":35}
var decisions: Array = []
var failures: Array = []
var perfect_rate := 0.35
var last_wave: int = 0

## Score a skill using visible damage, kills, burning and imminent charge interruption.
func best_skill(state: Dictionary) -> Dictionary:
	var best := {}; var score := -1.0
	for skill in state.combinations:
		var area_score := 0.0; var single_score := -1.0; var target := -1
		for hit in skill.damage:
			var found: Array = state.enemies.filter(func(e): return e.slot == hit.target)
			if found.is_empty(): continue
			var enemy: Dictionary = found[0]
			if not skill.area and not enemy.legal_target: continue
			var damage: float = hit.total_per_use*skill.uses
			var value: float = minf(enemy.hp+enemy.shield,damage)
			if damage >= enemy.hp+enemy.shield: value += 20+enemy.damage*2
			if enemy.charge > 0: value += 25 if enemy.break_marks > 1 else 90
			if skill.faces.size() in [3,5]: value += 8
			area_score += value
			if value > single_score: single_score = value; target = enemy.slot
		var value: float = (area_score if skill.area else single_score)/pow(skill.dice.size(),0.55)
		if state.player.fireball_charges == state.player.fireball_threshold-1 and (skill.faces.size() == 3 or state.player.level >= 10): value += 20
		if value > score: score = value; best = {"dice":skill.dice,"target":target}
	return best

## Stable preference ordering values synergies while allowing defensive purchases.
func relic_rank(id: String, state: Dictionary) -> float:
	var value: float = RANK.get(id,40)
	# A fused inventory slot retains every ingredient; never price it as one unknown item.
	var fusion_rank: Dictionary = {"budget_meal":140,"happy_meal":180,"deluxe_meal":220,"super_meal":270,"prismatic_stone":250,"ancient_codex":180}
	value = fusion_rank.get(id,value)
	if id in ["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken"]:
		value += 70 # Prefer collecting meal components over generic damage upgrades.
		if state.relics.any(func(r): return r.id.ends_with("meal")): value += 80
	if id in ["bloodstone","armor","contract"] and state.player.hp < state.player.max_hp*0.5: value += 20
	return value

## Replace only the lowest-ranked item; never inspect unopened rewards or future rolls.
func replacement(id: String, state: Dictionary) -> int:
	if state.relics.size() < 10: return 0
	var worst: Dictionary = state.relics[0]
	for item in state.relics:
		if relic_rank(item.id,state) < relic_rank(worst.id,state): worst = item
	return worst.slot if relic_rank(id,state) > relic_rank(worst.id,state) else -1

## Use emergency healing, boss utility and consumables according to current visible threats.
func tarot_action(state: Dictionary) -> Dictionary:
	if "tarot" not in state.actions: return {}
	for card in state.tarots:
		if not card.blocked_reason.is_empty(): continue
		var use := false
		match card.id:
			"emperor","world","wheel_of_fortune": use = true
			"sun","empress": use = state.player.hp < state.player.max_hp*0.6
			"strength": use = not state.combinations.is_empty() and state.enemies.any(func(e): return e.hp > 100)
			"star","lovers","high_priestess","devil": use = "roll" in state.actions and state.combinations.is_empty()
			"hermit": use = state.enemies.any(func(e): return e.charge > 0) or state.player.hp < state.player.max_hp*0.4
			"justice","judgement": use = state.combinations.is_empty() and state.has_rolled and state.rolls_left == 0
			"chariot": use = state.enemies.size() >= 2
			"death":
				var foes: Array = state.enemies.filter(func(e): return e.boss_phase == 0 and e.legal_target)
				foes.sort_custom(func(a,b): return a.hp > b.hp)
				if not foes.is_empty() and foes[0].hp > 150: return {"action":"tarot","instance":card.instance,"target":foes[0].slot}
		if use: return {"action":"tarot","instance":card.instance}
	return {}

## Decide from the published CLI state, with no forced dice or omniscient forecasting.
func choose(state: Dictionary, timing: RandomNumberGenerator, use_tarots: bool = true, passive_only: bool = false) -> Dictionary:
	if "start" in state.actions: return {"action":"start"}
	if state.has("choice"):
		if state.choice.type == "replace":
			var slot: int = replacement(state.choice.relic.id,state)
			return {"action":"choose","discard":true} if slot < 0 else {"action":"choose","replace":slot}
		return {"action":"cancel"}
	if state.has("tarot_choices"):
		var order := ["world","emperor","sun","strength","lovers","hermit","death"]
		var best := 0
		for i in range(state.tarot_choices.size()):
			var rank: int = order.find(state.tarot_choices[i].id)
			if rank >= 0 and (order.find(state.tarot_choices[best].id) < 0 or rank < order.find(state.tarot_choices[best].id)): best = i
		return {"action":"choose","slot":best+1}
	if state.phase == "closed_chest": return {"action":"open"}
	if state.phase == "rewards":
		# Ultra loot is deliberately not accepted in this balance study.
		if state.chest_tier == 3: return {"action":"skip"}
		for item in state.rewards:
			if item.claimed: continue
			var slot: int = replacement(item.id,state)
			return {"action":"discard","slot":item.slot} if slot < 0 else {"action":"take","slot":item.slot,"replace":slot}
	if state.phase == "routes":
		var best := 0; var value := -1.0
		for i in range(state.routes.size()):
			var score: float = {"relic":80,"blood_gems":65,"souls":35,"shop":90 if state.player.blood_gems >= 200 else 25}.get(state.routes[i],0)
			if state.routes[i] == "souls" and state.player.xp_needed-state.player.xp <= 30: score = 85
			if score > value: value = score; best = i
		return {"action":"route","slot":best+1}
	if state.phase == "shop":
		if state.free_divination: return {"action":"divination"}
		var best := {}; var score := 0.0
		for offer in state.shop:
			if offer.sold or offer.price > state.player.blood_gems or offer.kind != "relic": continue
			var slot: int = replacement(offer.id,state)
			if slot < 0: continue
			var value: float = relic_rank(offer.id,state)/sqrt(offer.price)
			if value > score: best = {"action":"buy","slot":offer.slot,"replace":slot}; score = value
		return best if not best.is_empty() else {"action":"leave"}
	if "ice" in state.actions: return {"action":"ice"}
	if "treasure" in state.actions: return {"action":"treasure"}
	if use_tarots:
		var card: Dictionary = tarot_action(state)
		if not card.is_empty(): return card
	if "cast" in state.actions:
		var target := -1; var score := -1.0
		for hit in state.skill.damage:
			for enemy in state.enemies:
				if hit.target != enemy.slot or not enemy.legal_target: continue
				var value: float = minf(hit.total_per_use,enemy.hp)+ (100 if hit.total_per_use >= enemy.hp else 0)+enemy.damage
				if value > score: score = value; target = enemy.slot
		return {"action":"cast","target":target}
	if not passive_only and "form" in state.actions: return {"action":"form","dice":best_skill(state).dice}
	var unused: int = state.dice.filter(func(d): return not d.spent and not d.locked).size()
	if "roll" in state.actions and (not state.has_rolled or unused >= 3): return {"action":"roll","perfect":timing.randf() < perfect_rate}
	if "end" in state.actions: return {"action":"end"}
	return {}

## Construct a fixed inventory without replacing the combat or reward implementation.
func loadout(wave: int, name: String) -> Array:
	if name == "bare": return []
	if name in ["meal_core","meal_synergy"]:
		var foods: Array = ["lemon_soda","fries","hamburger","oreo_sundae","fried_chicken","bracelet","orange_stone"]
		if name == "meal_synergy": foods.append_array(["mithril_blade","magic_sword","echo_bell"])
		return foods
	if name == "dragon_only": return ["pet_dragon"]
	if name == "mithril_only": return ["mithril_blade"]
	if name == "reaper_only": return ["reaper_scythe"]
	var result: Array = ["bracelet","fries","magic_sword","armor","orange_stone","runestone"].slice(0,clampi(ceili(wave/3.0),1,6))
	if name == "dragon_build": result.append("pet_dragon")
	if name == "copy_build": result.append_array(["pet_dragon","disguise_mask","ancient_tentacle"])
	return result

## Estimate combat-only XP before a wave; scripted probes start healthy and retain no rolled loot.
func prior_xp(wave: int) -> int:
	var total := 0
	for stage in range(wave-1):
		for enemy in Waves.create(stage,RandomNumberGenerator.new()): total += Enemy.soul_reward(enemy)
	return total

## Sample selected encounters and isolated item ablations using identical policy/timing seeds.
func encounter(wave: int, build: String, seed_value: int, passive_only: bool = false) -> Dictionary:
	var session = Session.new(seed_value)
	var model = session.model
	model.stage = wave-1; model.wave_kind = "relic"; model._load_wave()
	model.gain_souls(prior_xp(wave))
	for id in loadout(wave,build): model.acquire_relic(id)
	if build == "reaper_only": model.relics.items[0].kills = maxi(0,(wave-1)*3)
	model.hp = model.max_hp
	session._settle()
	var start: Dictionary = session.snapshot()
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	var count := 0; var min_hp := 1.0
	while model.outcome().is_empty() and count < 600:
		var state: Dictionary = session.snapshot()
		var command: Dictionary = choose(state,timing,false,passive_only)
		if command.is_empty(): failures.append({"wave":wave,"build":build,"state":state}); break
		var result: Dictionary = session.command(command)
		if not result.ok: failures.append({"command":command,"error":result.error}); break
		min_hp = minf(min_hp,float(model.hp)/model.max_hp)
		count += 1
	var result := {"wave":wave,"build":build,"seed":seed_value,"passive_only":passive_only,"outcome":model.outcome(),"start_level":start.player.level,"end_level":model.character_level,"start_hp":start.player.max_hp,"end_hp":model.hp,"min_hp_ratio":min_hp,"stats":session.stats.duplicate(),"commands":count}
	_cleanup(session)
	return result

## Run natural rewards, routes, consumables and inventory choices as a separate integration check.
func full_run(seed_value: int) -> Dictionary:
	var session = Session.new(seed_value)
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	var actions: Array = []; var count := 0
	var wave_min_hp: Dictionary = {}
	while session.model.outcome() != "defeat" and count < 3000:
		var state: Dictionary = session.snapshot()
		if state.outcome == "victory" and session.model.stage >= (last_wave-1 if last_wave > 0 else Session.Run.LAST_PLAYABLE_STAGE): break
		var command: Dictionary = choose(state,timing)
		if command.is_empty(): failures.append({"seed":seed_value,"state":state}); break
		var result: Dictionary = session.command(command)
		actions.append(command)
		var wave_key: String = str(state.wave)
		wave_min_hp[wave_key] = minf(wave_min_hp.get(wave_key,1.0),float(session.model.hp)/session.model.max_hp)
		if not result.ok: failures.append({"seed":seed_value,"command":command,"error":result.error}); break
		count += 1
	var result := {"seed":seed_value,"outcome":session.model.outcome(),"wave":session.model.stage+1,"stats":session.stats.duplicate(),"history":session.history.duplicate(true),"wave_min_hp":wave_min_hp,"actions":actions,"final":session.snapshot()}
	_cleanup(session)
	return result

## Break signal references so large deterministic batches do not retain every session.
func _cleanup(session) -> void:
	for signal_info in session.model.get_signal_list():
		for connection in session.model.get_signal_connection_list(signal_info.name): session.model.disconnect(signal_info.name,connection.callable)

## Write raw results once; external summaries retain failures and excluded Ultra rewards.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "test-output/balance-20261024/probe.json"
	if args.size() > 1: perfect_rate = float(args[1])
	if args.size() > 4: last_wave = int(args[4])
	var probes: Array = []; var runs: Array = []
	var third_probes: bool = args.size() > 2 and args[2] == "third"
	var meal_probes: bool = args.size() > 2 and args[2] == "meals"
	var selected_waves: Array = range(21,31) if third_probes else range(11,30) if meal_probes else [] if args.size() > 2 and args[2] == "runs" else WAVES
	var offset: int = int(args[3]) if args.size() > 3 else 0
	for wave in selected_waves:
		for build in (["typical","meal_core","meal_synergy"] if third_probes else ["meal_core","meal_synergy"] if meal_probes else ["bare","typical","dragon_only","dragon_build","mithril_only","reaper_only","copy_build"]):
			for seed_value in SEEDS: probes.append(encounter(wave,build,seed_value))
		if wave in [5,10,15,20]:
			for seed_value in SEEDS: probes.append(encounter(wave,"dragon_only",seed_value,true))
		print("Probed wave ",wave)
	for seed_value in ([] if meal_probes or third_probes else SEEDS):
		runs.append(full_run(seed_value+offset)); print("Run ",seed_value+offset,": ",runs[-1].outcome," wave ",runs[-1].wave)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"probes":probes,"runs":runs,"failures":failures},"\t"))
	print("Saved ",output,"; probes=",probes.size(),", failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
