extends RefCounted
## Agent-facing adapter: real run rules, explicit player choices, no rendering or save writes.
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Character = preload("res://scripts/combat/flamelings_skills.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
const Statuses = preload("res://scripts/status/status_catalog.gd")
var model
var seed_value: int
var choice: Dictionary = {}
var chest_source := ""
var events: Array = []
var history: Array = []
var stats := {"rolls":0,"skills":0,"tarots":0,"enemy_phases":0,"damage_taken":0,"healing":0,"kills":0,"boss_charges":0,"boss_releases":0,"boss_interrupts":0}
var stop_after_enemy_phases: int = 0 # Optional bounded encounter probe; zero plays normally.
var completed: Dictionary = {}
var campaign = Run.Campaign.new()

## Each session owns fresh RNG and in-memory pity, isolated from the GUI profile.
func _init(run_seed: int = 1) -> void:
	seed_value = run_seed
	model = Run.new(run_seed)
	model.enemy_souls_dropped.connect(_souls_received)
	model.enemy_crystals_dropped.connect(_gems_received)
	model.tarot_granted.connect(_tarot_received)
	model.tarot_expired.connect(func(instances): events.append({"type":"tarot_expired","instances":instances}))
	model.character_leveled.connect(_leveled)
	model.boss_changed.connect(_boss_changed)
	model.damage_redirected.connect(func(source,target,damage,loss): events.append({"type":"redirect","source":source,"target":target,"amount":loss,"display_amount":damage}))
	_settle()

func _boss_changed(_index: int, kind: String) -> void:
	if kind == "boss_break": stats.boss_interrupts += 1

func _souls_received(target: int, amount: int) -> void:
	stats.kills += 1
	events.append({"type":"souls","target":target,"amount":amount})

func _gems_received(target: int, amount: int) -> void:
	events.append({"type":"blood_gems","target":target,"amount":amount})

func _tarot_received(item: Dictionary) -> void:
	events.append({"type":"tarot_received","id":item.id,"instance_id":item.instance_id,"projection":item.get("projection",false)})

func _leveled(level: int) -> void:
	events.append({"type":"level_up","level":level,"hp":model.hp,"max_hp":model.max_hp})

## Collect actual model events; totals describe gameplay, never animation elapsed time.
func _record(batch: Array) -> void:
	for event in batch:
		if event.type == "charge" and event.target >= 0 and (model.enemies[event.target].get("boss",false) or model.EnemyCatalog.ITEMS[model.enemies[event.target].role].get("interruptible",false)):
			stats.boss_charges += 1
			if event.amount == model.EnemyCatalog.ITEMS[model.enemies[event.target].role].charge_turns: stats.boss_releases += 1
		if event.get("target",0) == -1:
			if event.type in ["damage","burn"]: stats.damage_taken += event.amount
			elif event.type == "heal": stats.healing += event.amount
	events.append_array(batch)

## Public commands use one-based die, enemy, reward, inventory and shop slots.
func command(request: Dictionary) -> Dictionary:
	events = []
	var op: String = str(request.get("action","state"))
	var error := _dispatch(op,request)
	if error.is_empty(): _settle()
	return {"ok":error.is_empty(),"error":error,"events":events.duplicate(true),"state":snapshot()}

## Reject commands outside the displayed decision boundary before calling model mutations.
func _dispatch(op: String, args: Dictionary) -> String:
	if op == "state": return ""
	if op == "reorder":
		return "" if model.move_relic(_index(args,"from"),_index(args,"to")) else "Invalid inventory move."
	if op == "sell":
		var amount: int = model.sell_relic(_index(args,"slot"))
		if amount <= 0: return "Invalid relic slot."
		events.append({"type":"relic_sold","amount":amount})
		return ""
	if not choice.is_empty():
		if op == "cancel":
			if choice.type == "replace": return _cast_tarot(choice.instance_id,{"discard":true})
			if choice.instance_id < 0: model.tarot_effects.dismiss_repeat()
			choice.clear()
			return ""
		if op != "choose": return "Finish or cancel the pending tarot choice."
		return _cast_tarot(choice.instance_id,_tarot_options(args))
	if not model.tarot_source.is_empty():
		if op != "choose": return "Choose one of the three revealed tarots."
		return "" if not model.choose_tarot(_index(args,"slot")).is_empty() else "Invalid tarot choice."
	if chest_source == "wave_closed":
		if op != "open": return "Open the battlefield chest first."
		if model.wave_kind == model.WaveRewards.RELIC:
			model.open_wave_chest()
			chest_source = "wave"
			events.append({"type":"chest_gems","amount":model.release_chest_crystals()})
		else:
			events.append({"type":model.wave_kind,"amount":model.claim_wave_resource()})
			model.finish_wave_reward()
			chest_source = ""
		return ""
	if not model.open_rewards.is_empty():
		if op == "skip": model.discard_unclaimed_rewards(); return ""
		if op not in ["take","discard"]: return "Take or discard a revealed reward, or skip the remaining rewards."
		var item: Dictionary = model.claim_reward(_index(args,"slot"),_index(args,"replace"),op == "discard")
		if item.is_empty(): return "Reward unavailable, already claimed, or replacement required."
		events.append({"type":"reward","item":_plain(item)})
		return ""
	if model.shop.active:
		match op:
			"buy":
				var item: Dictionary = model.shop.buy(model,_index(args,"slot"),_index(args,"replace"))
				if item.is_empty(): return "Purchase unavailable: check funds, sold state, or replacement slot."
				events.append({"type":"purchase","item":item})
			"refresh":
				if not model.shop.refresh(model): return "Not enough blood gems."
			"divination":
				if model.begin_tarot_reward("shop").is_empty(): return "Free draw already used."
			"leave": model.shop.close()
			_: return "Choose buy, refresh, divination, or leave."
		return ""
	if not model.route_choices.is_empty():
		if op != "route" or not model.choose_route(_index(args,"slot")): return "Choose an offered route slot."
		if not model.advance_wave(): return "Route could not advance."
		return ""
	if op == "start" and model.level_rewards_complete() and model.has_next_level():
		campaign.complete(model)
		campaign.start(model)
		events.append({"type":"level_start","level":model.level_number()})
		return ""
	if not model.outcome().is_empty(): return "Run has ended."
	match op:
		"roll":
			if args.has("perfect") and not args.perfect is bool: return "perfect must be true or false."
			if model.roll_pool(args.get("perfect",false)).is_empty(): return "Roll unavailable."
			stats.rolls += 1
		"form": return _form(args.get("dice",[]))
		"cancel":
			if not model.cancel_formed_skill(): return "No cancellable skill."
		"cast":
			if model.phase != "player" or model.pending.is_empty(): return "Form a skill first."
			var target: int = _index(args,"target")
			if not model.pending.hits_all() and target not in model.attack_targets(): return "Choose a living eligible enemy."
			if model.pending.hits_all() and target < 0: target = model.attack_targets().front()
			if target not in model.attack_targets(): return "Target protected by taunt or unavailable."
			stats.skills += 1
			_record(model.apply_player(target))
		"end":
			if not model.end_dice_turn(): return "Throw dice and resolve or cancel the formed skill first."
			_record(model.apply_player())
		"ice":
			if model.phase != "frozen": return "Player is not frozen."
			_record(model.break_ice())
		"tarot":
			var instance: int = _integer(args,"instance",0)
			return _cast_tarot(instance,_tarot_options(args))
		"treasure":
			if model.phase != "roll" or not model.pending.is_empty() or model.open_chest(_integer(args,"tier",0)).is_empty(): return "Reroll Treasure unavailable."
			chest_source = "treasure"
			events.append({"type":"chest_gems","amount":model.release_chest_crystals()})
		_: return "Unknown action: "+op
	return ""

## Validate the whole requested combination so a rejected form cannot partly select dice.
func _form(indices: Variant) -> String:
	if not indices is Array or model.phase != "roll" or not model.dice_turn.has_rolled(): return "Roll before selecting dice."
	var picked: Array = []
	for value in indices:
		if not _is_integer(value): return "Dice must be one-based integer indices."
		var index: int = int(value)-1
		if index in picked or index not in model.dice_turn.unused(): return "Repeated, spent, or invalid die."
		picked.append(index)
	if Patterns.classify(picked.map(func(i): return model.dice_turn.values[i])).is_empty(): return "Select a unique three-to-six-face straight."
	model.dice_turn.selected.clear()
	for index in picked: model.dice_turn.select(index)
	return "" if not model.form_selected_skill().is_empty() else "Cannot form that skill."

## Convert explicit card decisions into the existing tarot transaction arguments.
func _tarot_options(args: Dictionary) -> Dictionary:
	var options: Dictionary = {}
	for key in ["target","die","replace"]:
		if args.has(key): options[key] = _index(args,key)
	if args.has("face"): options.face = _integer(args,"face",0)
	if args.has("ban"): options.ban = str(args.ban)
	if args.has("discard"): options.discard = args.discard == true
	return options

## Pause only for real card choices; shared rules own consumption, repeats and rewards.
func _cast_tarot(instance: int, options: Dictionary) -> String:
	var prepared: Dictionary = model.tarot_effects.prepare(model,instance,options)
	if prepared.has("error"): return prepared.error
	var kind: String = prepared.get("choice","")
	# Emperor/World already consumed the card: retain a recoverable replacement choice even on invalid input.
	if kind == "replace": choice = {"type":kind,"instance_id":instance,"relic":_relic({"id":prepared.relic})}
	if (kind == "magician" and not options.has("die")) or (kind == "hanged_man" and not options.has("ban")) or (kind == "replace" and not options.has("replace") and not options.get("discard",false)):
		choice = {"type":kind,"instance_id":instance}
		if kind == "replace": choice.relic = _relic({"id":prepared.relic})
		return ""
	var result: Dictionary = model.tarot_effects.cast(model,instance,options)
	if result.has("error"): return result.error
	choice.clear()
	if instance > 0: stats.tarots += 1
	_record(result.events)
	while not model.tarot_effects.pending_steps.is_empty():
		_record(model.tarot_effects.resolve_next_step(model).get("events",[]))
	if result.get("reroll",false) and model.outcome().is_empty():
		if not model.roll_pool(false,[],true).is_empty(): stats.rolls += 1
	return ""

## Match the GUI's automatic transitions while preserving every player decision boundary.
func _settle() -> void:
	for guard in range(1000):
		if not choice.is_empty() or not model.tarot_source.is_empty(): return
		if not model.open_rewards.is_empty():
			if not model.rewards_collected(): return
			model.close_chest()
			if chest_source == "wave": model.finish_wave_reward()
			chest_source = ""
		if chest_source == "wave_closed": return
		if model.phase == "turn_end": _record(model.end_round()); continue
		if model.perfect_relic_ready: _record(model.resolve_roll_relic_step()); continue
		if model.phase == "roll_attacks": _record(model.resolve_roll_attack_step()); continue
		if model.start_roll_chip_casts(): continue
		if model.phase == "player" and model.pending.cast_source != "manual": _record(model.apply_player()); continue
		if not model.tarot_effects.pending_repeat.is_empty():
			if not model.outcome().is_empty(): model.tarot_effects.dismiss_repeat(); continue
			var repeat: Dictionary = model.tarot_effects.pending_repeat
			if repeat.id == "death": choice = {"type":"target","instance_id":repeat.instance_id}; return
			var error: String = _cast_tarot(repeat.instance_id,{})
			if not error.is_empty():
				events.append({"type":"repeat_skipped","reason":error})
				model.tarot_effects.dismiss_repeat()
			continue
		if model.outcome() == "defeat": _mark_wave(); return
		if model.shop.due(model): model.shop.open(model); return
		if model.shop.active: return
		if not model.outcome().is_empty():
			_mark_wave()
			if model.wave_kind != model.WaveRewards.SHOP and model.wave_chest_stage != model.stage:
				if model.begin_wave_reward(): chest_source = "wave_closed"
				return
			if model.outcome() == "victory":
				if model.auto_claim_victory_chest() > 0:
					chest_source = "victory"
					model.release_chest_crystals()
				return
			model.offer_routes()
			return
		if model.tarot_effects.pending_turn_end:
			model.tarot_effects.pending_turn_end = false
			if model.end_dice_turn(): _record(model.apply_player())
			continue
		if model.phase == "enemy":
			stats.enemy_phases += 1
			for index in model.living(): _record(model.enemy_act(index))
			_record(model.end_round())
			continue
		if model.phase in ["new","round_end"]:
			if stop_after_enemy_phases > 0 and stats.enemy_phases >= stop_after_enemy_phases: return
			_record(model.begin_round()); continue
		if not model.tarot_effects.bonus_chests.is_empty():
			model.open_bonus_chest(); model.release_chest_crystals(); chest_source = "bonus"
		return
	push_error("Playtest settlement exceeded its safety limit.")

## Store cumulative milestone data once per cleared or lost wave.
func _mark_wave() -> void:
	if completed.has(model.stage): return
	completed[model.stage] = true
	history.append({"wave":model.stage+1,"kind":model.wave_kind,"outcome":model.outcome(),"level":model.character_level,"hp":model.hp,"max_hp":model.max_hp,"relics":model.relics.items.map(func(i): return i.id),"totals":stats.duplicate()})

## Snapshot exposes current information only; no RNG state or sealed future rewards.
func snapshot() -> Dictionary:
	var state := {"wave":model.stage+1,"wave_count":Run.PLAYABLE_WAVES,"reward_route":model.wave_kind,"phase":model.phase,"outcome":model.outcome(),"round":model.round_number,
		"level":model.level_number(),"level_wave":model.level_wave(),
		"player":{"hp":model.hp,"max_hp":model.max_hp,"shield":model.shield,"level":model.character_level,"xp":model.souls,"xp_needed":model.level_cost(),"base_damage":model.character_base_damage(),"combo_multiplier":model.combo_multiplier(),"blood_gems":model.blood_gems,"fireball_charges":model.character_passive.charge,"fireball_threshold":model.character_passive.charge_limit(model.character_evolution_stage()),"statuses":_statuses(model.statuses)},
		"dice":[],"rolls_left":model.dice_turn.rolls_left,"has_rolled":model.dice_turn.has_rolled(),"bonus_turns":model.bonus_turn_count,"leftover_heal":model.leftover_total_healing() if model.dice_turn.has_rolled() else 0,
		"enemies":[],"relics":[],"tarots":[],"combinations":[],"treasure":{"progress":model.reroll_progress,"tier":model.chest_tier()},"actions":[],"totals":stats.duplicate(),"wave_history":history.duplicate(true)}
	for i in range(6): state.dice.append({"slot":i+1,"face":model.dice_turn.values[i] if model.dice_turn.has_rolled() else null,"spent":i in model.dice_turn.committed,"locked":i in model.dice_turn.locked})
	for i in model.living():
		var enemy: Dictionary = model.enemies[i]
		var intent: Dictionary = enemy.intent.duplicate()
		if intent.has("target"): intent.target = "player" if intent.target == -1 else str(int(intent.target)+1)
		state.enemies.append({"slot":i+1,"name":enemy.name,"level":enemy.get("level",1),"soul_reward":model.EnemyCatalog.soul_reward(enemy),"gem_reward":model.EnemyCatalog.crystal_reward(enemy),"elite":enemy.elite,"hp":enemy.hp,"max_hp":enemy.max_hp,"shield":enemy.shield,"damage":enemy.damage,"intent":intent,"statuses":_statuses(enemy.get("statuses",{})),"attack_boost":enemy.attack_boost,"boss_phase":enemy.get("boss_phase",0),"charge":enemy.get("charge",0),"break_marks":enemy.get("break_marks",0),"taunt":model.EnemyCatalog.taunts(enemy),"legal_target":i in model.attack_targets()})
	for i in range(model.relics.items.size()):
		var item: Dictionary = _relic(model.relics.items[i]); item.slot = i+1; state.relics.append(item)
	for item in model.tarots.items:
		var card: Dictionary = _tarot(item.id); card.instance = item.instance_id
		card.projection = item.get("projection",false)
		card.blocked_reason = model.tarot_effects.error(model,item.id)
		state.tarots.append(card)
	state.tarot_modifiers = {"strength":model.tarot_effects.strength,"dice_boost":model.tarot_effects.dice_boost,"lovers":model.tarot_effects.lovers,"devil":model.tarot_effects.devil,"perfect_throws":model.tarot_effects.star_throws,"carried_rolls":model.tarot_effects.carried_rolls,"banned":model.tarot_effects.banned.duplicate()}
	if not model.pending.is_empty(): state.skill = _skill(model.pending)
	if not choice.is_empty():
		state.choice = choice.duplicate(true)
		if choice.type == "hanged_man": state.choice.options = Tarot.eligible(model.tarot_effects.banned)
		state.actions = ["choose","cancel"]
	elif not model.tarot_source.is_empty():
		state.tarot_choices = model.tarot_choices.map(func(id): return _tarot(id))
		state.actions = ["choose"]
	elif chest_source == "wave_closed": state.phase = "closed_chest"; state.actions = ["open"]
	elif not model.open_rewards.is_empty():
		state.phase = "rewards"
		state.chest_tier = model.opened_chest_tier
		state.rewards = []
		for i in range(model.open_rewards.size()):
			var reward: Dictionary = model.reward_item(i)
			var item: Dictionary = _relic({"id":reward.relic_id}) if reward.has("relic_id") else _plain(reward)
			item.slot = i+1; item.claimed = i in model.claimed_slots; state.rewards.append(item)
		state.actions = ["take","discard","skip"]
	elif model.shop.active:
		state.phase = "shop"; state.shop = []
		for i in range(model.shop.offers.size()):
			var offer: Dictionary = model.shop.offers[i]
			var item: Dictionary = _relic({"id":offer.id}) if offer.kind == "relic" and not offer.id.is_empty() else _tarot(offer.id) if offer.kind == "tarot" and not offer.id.is_empty() else {"id":offer.id,"name":"Sealed Soul Bottle","description":"Hidden souls: 1 per 10–20 blood gems paid."}
			item.merge({"slot":i+1,"kind":offer.kind,"price":offer.price,"sold":offer.sold,"can_buy":model.shop.can_buy(model,i)},true)
			state.shop.append(item)
		state.free_divination = not model.shop.divination_used
		state.shop_refresh_price = model.shop.refresh_price
		state.actions = ["buy","refresh","leave"]
		if state.free_divination: state.actions.append("divination")
	elif not model.route_choices.is_empty(): state.phase = "routes"; state.routes = model.route_choices.duplicate(); state.actions = ["route"]
	elif model.level_rewards_complete() and model.has_next_level(): state.phase = "level_complete"; state.actions = ["start"]
	elif model.outcome().is_empty():
		if model.phase == "roll":
			if model.dice_turn.can_roll(): state.actions.append("roll")
			state.combinations = _combinations()
			if not state.combinations.is_empty(): state.actions.append("form")
			if model.can_end_dice_turn(): state.actions.append("end")
			if model.chest_tier() > 0: state.actions.append("treasure")
		elif model.phase == "player": state.actions = ["cast","cancel"]
		elif model.phase == "frozen": state.actions = ["ice"]; state.ice_taps_left = model.ice_hits_remaining
		if not model.tarots.items.is_empty(): state.actions.append("tarot")
	state.actions.append("state")
	if not model.relics.items.is_empty(): state.actions.append("sell")
	if model.relics.items.size() > 1: state.actions.append("reorder")
	return state

## List each pip-distinct straight once, using concrete available physical dice.
func _combinations() -> Array:
	if not model.dice_turn.skills_allowed(): return []
	var result: Array = []
	if not model.dice_turn.has_rolled(): return result
	for length in range(6,2,-1):
		for first in range(1,8-length):
			var indices: Array = []
			for face in range(first,first+length):
				var index: int = model.dice_turn.unused().find_custom(func(i): return model.dice_turn.values[i] == face)
				if index >= 0: indices.append(model.dice_turn.unused()[index])
			if indices.size() != length: continue
			var skill = model.relic_skills.preview_upgrade(model,Patterns.classify(range(first,first+length)))
			var item: Dictionary = _skill(skill); item.dice = indices.map(func(i): return i+1)
			result.append(item)
	return result

## Use shared captions and damage previews rather than duplicating character coefficients.
func _skill(skill: MultiHitSkill) -> Dictionary:
	var result: Dictionary = Character.caption(skill,model.character_evolution_stage())
	result.faces = skill.dice.duplicate()
	result.area = skill.hits_all()
	result.uses = model.skill_use_count(skill)
	result.damage_ticks = skill.damage_ticks
	result.damage = []
	var guards: Array = model.taunting_enemies()
	for target in model.living():
		result.damage.append({"target":target+1,"total_per_use":model.skill_damage_total(skill,target,model.area_damage_factor(target,guards) if skill.hits_all() else 1.0)})
	result.damage_note = "Per-use damage before shields/overkill; passive bonus casts are not included."
	return result

## Keep catalog descriptions and live relic counters available for agent decisions.
func _relic(item: Dictionary) -> Dictionary:
	var data: Dictionary = Relics.ITEMS[item.id]
	return {"id":item.id,"name":data.name,"rarity":Relics.RARITY_NAMES[data.rarity],"description":Relics.description(item),"counters":item.duplicate(true)}

func _tarot(id: String) -> Dictionary:
	return {"id":id,"name":Tarot.ITEMS[id].name,"description":Tarot.description(id),"target":Tarot.ITEMS[id].target}

## Convert only active status objects into stable JSON data.
func _statuses(values: Dictionary) -> Array:
	var result: Array = []
	for id in values:
		var status = values[id]
		if status.count > 0: result.append({"id":id,"name":Statuses.ENTRIES.get(id,{"name":str(id)}).name,"count":status.count,"potency":status.potency,"permanent":status.permanent})
	return result

## Strip presentation-only engine types from reward/event payloads.
func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if value[key] is Color or value[key] is Object: continue
			result[str(key)] = _plain(value[key])
		return result
	if value is Array: return value.map(_plain)
	return value

func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

func _integer(args: Dictionary, key: String, fallback: int = -1) -> int:
	return int(args[key]) if args.has(key) and _is_integer(args[key]) else fallback

func _index(args: Dictionary, key: String) -> int:
	return _integer(args,key,0)-1
