extends "res://tools/current_balance.gd"
## Natural, goal-directed CLI runs: no seeded loadouts, forced dice, unlocked sins or save writes.
const SinCatalog = preload("res://scripts/sins/sin_catalog.gd")
const Types = preload("res://scripts/relics/relic_types.gd")
var goal := ""
var refreshes: Dictionary = {}
var awakenings: Array = []
var progress_peak := 0

## Sloth never forecasts rerolls it has deliberately ruled out.
func prepare_choice(session, state: Dictionary) -> Dictionary:
	return state if goal == "sloth" and goal not in state.sins.unlocked else super.prepare_choice(session,state)

func progress(state: Dictionary) -> int:
	if goal == "envy": return state.sins.tarot_uses
	if goal == "pride": return state.completed_sets
	if goal == "sloth": return 8 if goal in state.sins.unlocked else state.sins.cleared_waves.size() if not state.sins.level_rerolled else 0
	return state.relic_types.get(SinCatalog.ITEMS[goal].get("type",""),0)

## Value actual ingredient ownership, keeping both combat strength and the chosen collection goal.
func relic_rank(id: String, state: Dictionary) -> float:
	var base: float = super.relic_rank(id,state)
	if goal in state.sins.unlocked:
		if goal == "gluttony" and Relics.ITEMS[id].get("type","") == "food": return base+350
		return base
	var item: Dictionary = {"id":id,"count":1}
	for owned in state.relics:
		if owned.id == id: item = owned.counters; break
	if goal == "pride":
		var collection: Vector2i = Relics.Sets.collection_progress(id,state.relics.map(func(r): return r.counters))
		if collection.y > 0: return base+1000+300*collection.x+600*int(collection.x == collection.y)
		return base
	if goal == "envy": return base+1000 if id in ["fortune_cookie","magician_hat","crystal_ball","cross"] else base
	if goal == "sloth": return base+100 if id in ["clover","four_leaf_clover","five_leaf_clover","lucky_die","pet_dragon","war_hammer","magic_slingshot","tissue_pack"] else base
	var count: int = Types.stacks(item,Relics.ITEMS).get(SinCatalog.ITEMS[goal].get("type",""),0)
	return base+count*1000

## Spend and refresh toward the collection rather than exhausting the budget on unrelated shelves.
func goal_item(id: String, state: Dictionary) -> bool:
	if goal == "pride": return not Relics.Sets.set_label(id).is_empty()
	if goal == "envy": return id in ["fortune_cookie","magician_hat","crystal_ball","cross"]
	if goal == "sloth": return true
	return Types.stacks({"id":id,"count":1},Relics.ITEMS).get(SinCatalog.ITEMS[goal].get("type",""),0) > 0

## Completing a fusion or eating Food does not require discarding a relic from a full backpack.
func replacement(id: String, state: Dictionary) -> int:
	if goal == "gluttony" and goal in state.sins.unlocked and Relics.ITEMS[id].get("type","") == "food": return 0
	var inventory: Array = state.relics.map(func(r): return r.counters)
	if Relics.Sets.can_merge(inventory,id) or id == "codex_page" and state.relics.any(func(r): return r.id == id): return 0
	return super.replacement(id,state)

## Envy actively spends usable tactical cards; Sloth preserves a clean level, including free rerolls.
func tarot_action(state: Dictionary) -> Dictionary:
	if goal == "envy" and goal not in state.sins.unlocked and "tarot" in state.actions:
		for card in state.tarots:
			if not card.blocked_reason.is_empty(): continue
			if card.id in ["fool","hanged_man","tower","magician","death"]: continue
			return {"action":"tarot","instance":card.instance}
	if goal == "sloth" and goal not in state.sins.unlocked:
		var safe: Dictionary = state.duplicate(true)
		safe.tarots = safe.tarots.filter(func(card): return card.id != "justice")
		return super.tarot_action(safe)
	return super.tarot_action(state)

## Shop refreshes cost real currency; budget at most three per visit while pursuing the goal.
func choose(state: Dictionary, timing: RandomNumberGenerator, use_tarots: bool = true, passive_only: bool = false) -> Dictionary:
	var result: Dictionary = super.choose(state,timing,use_tarots,passive_only)
	if goal == "sloth" and goal not in state.sins.unlocked and result.get("action","") == "reroll":
		return {"action":"form","dice":best_skill(state).dice} if not state.combinations.is_empty() else {"action":"end"}
	if state.phase == "shop" and result.get("action","") in ["buy","leave"] and goal not in state.sins.unlocked:
		var best := {}; var value := -1.0
		for offer in state.shop:
			if offer.sold or offer.price > state.player.blood_gems: continue
			if offer.kind == "tarot" and goal == "envy":
				var score: float = 180.0/sqrt(offer.price)
				if score > value: best = {"action":"buy","slot":offer.slot}; value = score
			if offer.kind != "relic" or not goal_item(offer.id,state): continue
			var slot: int = replacement(offer.id,state)
			var score: float = relic_rank(offer.id,state)/sqrt(offer.price)
			if slot >= 0 and score > value: best = {"action":"buy","slot":offer.slot,"replace":slot}; value = score
		if not best.is_empty(): return best
		var key: String = str(state.wave)
		if refreshes.get(key,0) < 3 and state.player.blood_gems >= state.shop_refresh_price+250:
			refreshes[key] = refreshes.get(key,0)+1
			return {"action":"refresh"}
	return result

## Counterfactual previews change no dice, inventory, health, turn counters or random state.
func payoff(model) -> Dictionary:
	var skill = model.make_straight_skill([3,4,5])
	var auto = model.Patterns.automatic_groups([6,6,1,2,3,4],range(6))[0].skill
	var before: Vector2 = model.standing_damage_values()
	var skill_on: float = model.raw_attack_damage(skill)
	var auto_on: float = model.raw_attack_damage(auto)
	var heal_on: int = model.modified_healing(100)
	var old: Array = model.sins.unlocked.duplicate()
	var foods: int = model.sins.food_consumed
	model.sins.unlocked.erase(goal)
	if goal == "gluttony": model.sins.food_consumed = 0
	var without: Vector2 = model.standing_damage_values()
	var result := {"base":before.x,"mult":before.y,"without_base":without.x,"without_mult":without.y,"fireball":skill_on,"fireball_without":model.raw_attack_damage(skill),"auto":auto_on,"auto_without":model.raw_attack_damage(auto),"heal_100":heal_on,"heal_100_without":model.modified_healing(100),"food_consumed":foods}
	model.sins.unlocked = old; model.sins.food_consumed = foods
	return result

func awakened(id: String, session) -> void:
	awakenings.append({"id":id,"wave":session.model.stage+1,"turn":session.model.round_number,"command":session.metrics.command_index,"hp":session.model.hp,"relics":session.model.relics.items.duplicate(true),"payoff":payoff(session.model) if id == goal else {}})

## Retain per-wave skill/auto counts, HP, Fireball damage and all acquisition/sale decisions.
func hunt(seed_value: int) -> Dictionary:
	var session = Session.new(seed_value)
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	refreshes = {}; awakenings = []; progress_peak = 0
	relic_order = RelicOrder.new(); straight_planner = StraightPlanner.new()
	session.model.sins.awakened.connect(awakened.bind(session))
	var commands := 0; var tagged_damage := 0; var tagged_hits := 0; var error := ""
	while session.model.outcome() != "defeat" and commands < 5000:
		var state: Dictionary = prepare_choice(session,session.snapshot())
		progress_peak = maxi(progress_peak,progress(state))
		if state.outcome == "victory" and state.wave >= Session.Run.PLAYABLE_WAVES: break
		var command: Dictionary = choose(state,timing)
		if command.is_empty(): error = "No legal policy action"; break
		var reply: Dictionary = session.command(command)
		if not reply.ok: error = str(command)+": "+reply.error; break
		for event in reply.events:
			if event.get("sin","") == goal and event.get("target",-1) >= 0 and event.type in ["damage","shield_hit"]:
				tagged_damage += event.amount; tagged_hits += 1
		commands += 1
		if commands%150 == 0: print("HUNT_PROGRESS ",goal," seed=",seed_value," wave=",session.model.stage+1," goal=",progress_peak," awakened=",goal in session.model.sins.unlocked)
	var result := {"goal":goal,"seed":seed_value,"outcome":session.model.outcome(),"wave":session.model.stage+1,"commands":commands,"error":error,"awakened":session.model.sins.has(goal),"awakenings":awakenings.duplicate(true),"peak_progress":progress_peak,"tagged_damage":tagged_damage,"tagged_hits":tagged_hits,"final_payoff":payoff(session.model),"final":session.snapshot(),"history":session.history.duplicate(true),"stats":session.stats.duplicate(),"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	goal = args[0]
	var seed_value: int = int(args[1])
	var path: String = args[2]
	var result: Dictionary = hunt(seed_value)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"runs":[result],"failures":failures},"\t"))
	print("HUNT_RESULT ",goal," ",seed_value," ",result.outcome," wave=",result.wave," awakened=",result.awakened," peak=",result.peak_progress," error=",result.error)
	quit(0 if result.error.is_empty() and failures.is_empty() else 1)
