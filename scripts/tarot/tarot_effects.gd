extends RefCounted
## Consumable rules and queued effects. No animation, input, or scene dependencies.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Drops = preload("res://scripts/relics/relic_drop_table.gd")
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var strength: int = 0
var extra_uses: int = 0
var extra_rolls: int = 0
var next_extra_rolls: int = 0
var star_throws: int = 0
var justice: bool = false
var devil: int = 0
var revelation: int = 0
var magician: Array = []
var parity: int = -1
var conditional_order: Array = []
var banned: Array = []
# Concrete reward IDs are locked before a full-inventory replacement picker.
var locked_grants: Dictionary = {}
var bonus_chests: Array = []
var pending_steps: Array = []
# A second activation belongs to the consumed card, not a new inventory item.
# Snapshot the proc so rerolling/removing Prophecy cannot cancel or recurse it.
var pending_repeat: Dictionary = {}

func _card(model, instance_id: int) -> Dictionary:
	if pending_repeat.get("instance_id",0) == instance_id: return pending_repeat
	var index: int = model.tarots.find_instance(instance_id)
	return {} if index < 0 else model.tarots.items[index]

func dismiss_repeat() -> void:
	locked_grants.erase(pending_repeat.get("instance_id",0))
	pending_repeat.clear()

func begin_round() -> void:
	extra_rolls = next_extra_rolls
	next_extra_rolls = 0

func end_round() -> void:
	extra_rolls = 0

func skill_factor(skill: MultiHitSkill) -> float:
	return skill.effect_multiplier if skill.amplifier_locked else 1.0+strength

func begin_skill(skill: MultiHitSkill) -> void:
	if skill.amplifier_locked: return
	skill.effect_multiplier = 1.0+strength
	skill.amplifier_locked = true
	strength = 0

func modify_dice(model, natural: Array) -> Array:
	if not Catalog.ROLL_EFFECTS_ENABLED: return natural.duplicate()
	# A newer direct setting replaces an older setting. Conditional transformations
	# react afterwards; their order is the order the player actually used them.
	var values: Array = natural.duplicate()
	var no_ultimate: bool = model.RelicEffects.has_flag(model.relics.items,"no_ultimate")
	if not magician.is_empty(): values = magician.duplicate()
	elif parity >= 0:
		for i in range(3): values[i] = model.rng.randi_range(0,2)*2+(1 if parity == 1 else 2)
	elif justice:
		var face: int = values[model.rng.randi_range(0,2)]
		if no_ultimate and face == 6: face = model.rng.randi_range(1,5)
		values = [face,face,face]
	var original: Array = values.duplicate()
	var winner: String = ""
	for transform in conditional_order:
		if transform == "hierophant" and revelation > 0 and (revelation in values or revelation in original):
			values = [revelation,revelation,revelation]
			winner = transform
		elif transform == "devil" and devil > 0 and values[0] == values[1] and values[1] == values[2] and not no_ultimate:
			values = [6,6,6]
			winner = transform
	if winner == "devil": devil = 0
	# A direct Magician choice may explicitly override a relic, as requested.
	if no_ultimate and values == [6,6,6] and magician != [6,6,6]: values[2] = model.rng.randi_range(1,5)
	magician.clear()
	parity = -1
	revelation = 0
	justice = false
	conditional_order.erase("hierophant")
	if devil == 0: conditional_order.erase("devil")
	star_throws = maxi(0,star_throws-1)
	return values

func usable(model) -> bool:
	return pending_steps.is_empty() and (model.phase in ["roll","player"] or (model.is_city() and model.phase == "round_end")) and model.outcome().is_empty() and model.tarot_source.is_empty() and model.open_rewards.is_empty()

func error(model, id: String, choice: Dictionary = {}, repeating: bool = false) -> String:
	if not model.outcome().is_empty() or (not repeating and not usable(model)): return "Use tarot between actions, before or after rolling."
	if not Catalog.ITEMS.has(id): return "Unknown tarot card."
	if id in Catalog.DISABLED: return "Temporarily disabled for six-dice turns."
	if id in ["death","judgement"] and model.is_city(): return "This card cannot affect the city."
	if id == "death" and choice.get("target",-1) not in model.attack_targets(): return "Drag Death onto an eligible enemy. Paladins protect their allies."
	if id == "judgement" and (model.living().is_empty() or model.living().size()%6 != 0): return "Judgement needs a multiple of six living enemies."
	if id == "fool" and model.relics.items.is_empty(): return "No relics to reroll."
	if id == "hanged_man" and Catalog.eligible(banned).size() <= 1: return "At least one tarot must remain in the deck."
	return ""

func prepare(model, instance_id: int, choice: Dictionary = {}) -> Dictionary:
	var card: Dictionary = _card(model,instance_id)
	if card.is_empty(): return {"error":"Card already used."}
	var repeating: bool = instance_id < 0
	if (not pending_repeat.is_empty() and not repeating) or not pending_steps.is_empty(): return {"error":"Finish the tarot effect first."}
	var id: String = card.id
	var reason: String = error(model,id,choice,repeating)
	if not reason.is_empty(): return {"error":reason}
	if id in ["magician","lovers","hanged_man"]: return {"choice":id}
	if id in ["emperor","world"]:
		if not locked_grants.has(instance_id):
			var eligible: Array = []
			for relic_id in Relics.ITEMS:
				if model.relics.can_add(relic_id) and (id != "world" or Relics.ITEMS[relic_id].rarity == Relics.Rarity.LEGENDARY): eligible.append(relic_id)
			var rolled: String = Drops.draw(model.reward_rng,eligible,model.relic_drop_weights())
			if rolled.is_empty(): return {"error":"No eligible relic is available."}
			locked_grants[instance_id] = rolled
		var reward: String = locked_grants[instance_id]
		if not model.relics.can_add(reward): return {"error":"This relic is already owned."}
		if model.relics.items.size() >= Relics.MAX_SLOTS and not (reward == "codex_page" and model.relics.has(reward)):
			return {"choice":"replace","relic":reward}
	return {}

func cast(model, instance_id: int, choice: Dictionary = {}) -> Dictionary:
	var setup: Dictionary = prepare(model,instance_id,choice)
	if setup.has("error"): return setup
	var id: String = _card(model,instance_id).id
	var repeating: bool = instance_id < 0
	match setup.get("choice",""):
		"magician":
			var values: Array = choice.get("dice",[])
			if values.size() != 3 or values.any(func(v): return not v is int or v < 1 or v > 6): return {"error":"Choose all three dice."}
		"lovers":
			if choice.get("parity",-1) not in [0,1]: return {"error":"Choose odd or even."}
		"hanged_man":
			if choice.get("ban", "") not in Catalog.eligible(banned): return {"error":"Choose a tarot still in the deck."}
		"replace":
			if choice.get("replace",-1) < 0 or choice.replace >= model.relics.items.size(): return {"error":"Choose a relic to replace."}
	var repeats: Array = pending_repeat.get("sources",[]).duplicate() if repeating else model.RelicEffects.repeat_sources(model.relics.items,"ancient_prophecy")
	if repeating and not repeats.is_empty(): model.RelicEffects.Sequence.activate(model,repeats.pop_front())
	if id in Catalog.ROLL_FACE_SETTINGS:
		magician.clear()
		parity = -1
		justice = false
	if id in Catalog.ROLL_TRIGGERS:
		conditional_order.erase(id)
		conditional_order.append(id)
	# Siege opens its next turn lazily. A committed tarot can begin that turn,
	# while inspecting/canceling a choice must not grant another regen tick.
	var events: Array = model.begin_round() if model.phase == "round_end" and not repeating else []
	var reward: String = ""
	match id:
		"fool":
			var original: Array = model.relics.items.map(func(item): return item.id)
			var pool: Array = Relics.ITEMS.keys().filter(func(key): return key not in original)
			var replacements: Array = []
			for i in range(original.size()):
				var replacement: String = Drops.draw(model.reward_rng,pool,model.relic_drop_weights())
				if replacement.is_empty(): return {"error":"No eligible relic is available."}
				replacements.append(model.relics._new_item(replacement))
				pool.erase(replacement)
				if Relics.CURSED_DICE.has(replacement): pool = pool.filter(func(key): return not Relics.CURSED_DICE.has(key))
			var old_max: int = model.max_hp
			model.relics.items = replacements
			model.relics._fuse()
			model.refresh_relic_health(old_max)
			for item in replacements: model.RelicEffects.acquired(model,item.id,true)
		"magician": magician = choice.dice.duplicate()
		"high_priestess": extra_uses += 1
		"empress":
			model.grant_random_tarots(2)
		"emperor", "world":
			reward = locked_grants[instance_id]
			if not model.acquire_relic(reward,choice.get("replace",-1)): return {"error":"Choose a relic to replace."}
			locked_grants.erase(instance_id)
		"hierophant": revelation = model.rng.randi_range(1,6)
		"lovers": parity = choice.parity
		"strength": strength += 1
		"hermit": model.statuses[Status.HIDDEN].apply(3)
		"wheel":
			if model.reward_rng.randi_range(1,4) == 1: bonus_chests.append(2 if model.reward_rng.randi_range(1,10) == 1 else 1)
			else: events.append(model.event(-1,0,"relic","NO TREASURE"))
		"justice": justice = true
		"hanged_man": banned.append(choice.ban)
		"devil": devil = 1
		"star": star_throws = 3
		"temperance":
			next_extra_rolls += 1
			extra_rolls = 0
			model._finish_player_action(Skill.new(Skill.Kind.NORMAL))
		"death": events.append_array(_execute(model,choice.target))
		"judgement":
			var count: int = model.living().size()/2
			for i in range(count):
				var targets: Array = model.attack_targets()
				events.append_array(_execute(model,targets[model.rng.randi_range(0,targets.size()-1)]))
		"chariot": events.append_array(_chariot(model))
		"moon":
			for target in model.living():
				events.append_array(model.apply_enemy_status(target,Status.DARKNESS,1))
				model.enemies[target].statuses[Status.DARKNESS].permanent = true
		"sun":
			events.append(model.event(-1,model.heal(model.max_hp),"heal","FULL HEAL"))
			for target in model.living(): events.append_array(_status(model,target,Status.BURNING,1))
		"tower":
			for i in range(10):
				var targets: Array = model.attack_targets()+[-1]
				# The city is immune; its troops are not separately targetable characters.
				var target: int = targets[model.rng.randi_range(0,targets.size()-1)]
				var statuses: Array = Status.PLAYER_HARMFUL if target == -1 else Status.ENEMY_HARMFUL
				var status: int = statuses[model.rng.randi_range(0,statuses.size()-1)]
				pending_steps.append({"target":target,"status":status,"count":1})
	if repeating: dismiss_repeat()
	else: model.tarots.remove_instance(instance_id)
	if not repeats.is_empty(): pending_repeat = {"id":id,"instance_id":-absi(instance_id),"sources":repeats}
	if pending_steps.is_empty(): _finish_effect(model,events)
	return {"id":id,"events":events,"relic":reward,"repeated":repeating}

func resolve_next_step(model) -> Dictionary:
	if pending_steps.is_empty(): return {}
	if not model.outcome().is_empty():
		pending_steps.clear()
		return {}
	var step: Dictionary = pending_steps.pop_front()
	step.events = _status(model,step.target,step.status,step.count)
	if pending_steps.is_empty(): _finish_effect(model,step.events)
	return step

func _finish_effect(model, events: Array) -> void:
	if not model.outcome().is_empty():
		if model.saved_skill.is_empty(): model.saved_skill = model.pending.duplicate()
		model.pending = Skill.new()
		model.phase = "finished"
		model._end_buff_turn()
		events.append_array(model._complete_relic_turn())
	# Finish the full burst before handing control to the ice-breaking interaction.
	if model.is_frozen() and model.phase in ["roll","player"]:
		model.pending = Skill.new()
		model._prepare_player_turn()

func _status(model, target: int, status: int, count: int) -> Array:
	return model.apply_affliction(status,count) if target == -1 else model.apply_enemy_status(target,status,count)

func _execute(model, target: int) -> Array:
	var loss: int = model.hit_enemy(target,model.enemies[target].hp,true)
	return [model.damage_event(target,loss,loss,"damage",true)]

func _chariot(model) -> Array:
	var skill = Skill.new(Skill.Kind.SPECIAL,4)
	skill.amplifier_locked = true # Strength and stored critical belong to the next skill.
	return preload("res://scripts/combat/area_attack.gd").apply_fixed(model,50,skill)
