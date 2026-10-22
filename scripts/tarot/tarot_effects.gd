extends RefCounted
## Consumable rules and queued effects. No animation, input, or scene dependencies.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Drops = preload("res://scripts/relics/relic_drop_table.gd")
const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var dice_boost: int = 0
var lovers: bool = false
var carried_rolls: int = 0
var carry_wave: int = -1
var pending_turn_end: bool = false
var strength: int = 0
var extra_uses: int = 0
var extra_rolls: int = 0
var next_extra_rolls: int = 0
var star_throws: int = 0
var devil: int = 0
var banned: Array = []
# Concrete reward IDs are locked before a full-inventory replacement picker.
var locked_grants: Dictionary = {}
var committed_grants: Dictionary = {}
var bonus_chests: Array = []
var pending_steps: Array = []
# A second activation belongs to the consumed card, not a new inventory item.
# Snapshot the proc so rerolling/removing Prophecy cannot cancel or recurse it.
var pending_repeat: Dictionary = {}

func _card(model, instance_id: int) -> Dictionary:
	if pending_repeat.get("instance_id",0) == instance_id: return pending_repeat
	if committed_grants.has(instance_id): return committed_grants[instance_id]
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

## Legacy scripted rolls do not use six-die outcome settings.
func modify_dice(_model, natural: Array) -> Array:
	star_throws = maxi(0,star_throws-1)
	return natural.duplicate()

## Reset turn-only boosts and redeem carryover only within its original wave.
func start_pool(model) -> int:
	dice_boost = 0
	var wave: int = model.stage if "stage" in model else 0
	var bonus: int = carried_rolls if wave == carry_wave else 0
	carried_rolls = 0
	carry_wave = -1
	return bonus

## Apply value boosts, then the latest guaranteed outcome to newly rolled dice.
func modify_pool(model, indices: Array) -> void:
	var pool = model.dice_turn
	for index in indices: pool.values[index] = mini(6,pool.values[index]+dice_boost)
	if lovers and indices.size() >= 4:
		# Restrict the start to boosted faces when possible, retaining a real straight.
		var first: int = model.rng.randi_range(mini(3,1+dice_boost),3)
		var slots: Array = indices.duplicate()
		for face in range(first,first+4):
			var at: int = model.rng.randi_range(0,slots.size()-1)
			pool.values[slots.pop_at(at)] = face
		lovers = false
	elif devil > 0 and indices.size() >= 3:
		var slots: Array = indices.duplicate()
		for i in range(mini(indices.size(),devil)):
			pool.values[slots.pop_at(model.rng.randi_range(0,slots.size()-1))] = 6
		devil = 0

func usable(model) -> bool:
	return pending_steps.is_empty() and (model.phase in ["roll","player","frozen"] or (model.is_city() and model.phase == "round_end")) and model.outcome().is_empty() and model.tarot_source.is_empty() and model.open_rewards.is_empty()

func error(model, id: String, choice: Dictionary = {}, repeating: bool = false) -> String:
	if not model.outcome().is_empty() or (not repeating and not usable(model)): return "Use tarot between actions, before or after rolling."
	if not Catalog.ITEMS.has(id): return "Unknown tarot card."
	if model.phase == "frozen" and id != "hierophant": return "Use Hierophant to clear freezing first."
	if id in Catalog.DISABLED: return "Temporarily disabled for six-dice turns."
	if id == "death" and model.is_city(): return "This card cannot affect the city."
	if id == "death" and choice.get("target",-1) not in model.attack_targets(): return "Drag Death onto an eligible enemy. Paladins protect their allies."
	if id == "magician" and (not model.dice_turn.has_rolled() or model.dice_turn.unused().is_empty()): return "Roll first, then choose an unused die."
	if id == "lovers" and model.dice_turn.unused().size() < 4: return "Lovers needs at least four unused dice."
	if id == "devil" and model.dice_turn.unused().size() < 3: return "Devil needs at least three unused dice."
	if id == "judgement" and (not model.dice_turn.has_rolled() or model.Patterns.has_combination(model.dice_turn.unused().map(func(i): return model.dice_turn.values[i]))): return "Judgement needs unused dice with no straight."
	if id == "temperance" and not model.dice_turn.has_rolled(): return "Roll before using Temperance."
	if id == "justice" and (not model.dice_turn.has_rolled() or not (model.dice_turn.can_roll(true) or model.dice_turn.has_pending_group())): return "Roll first and finish the summoned skill before using this card."
	if id in ["magician","hermit","high_priestess","temperance"] and model.dice_turn.has_pending_group(): return "Use or cancel the summoned skill first."
	if id == "hermit" and model.dice_turn.committed.is_empty(): return "No spent dice to restore."
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
	if id in ["magician","hanged_man"]: return {"choice":id}
	if id in ["emperor","world"]:
		if not locked_grants.has(instance_id):
			var eligible: Array = []
			for relic_id in Relics.ITEMS:
				if relic_id in Relics.DISABLED or Relics.ITEMS[relic_id].get("fusion",false): continue
				if model.relics.can_add(relic_id) and (id != "world" or Relics.ITEMS[relic_id].rarity == Relics.Rarity.LEGENDARY): eligible.append(relic_id)
			var rolled: String = "" if eligible.is_empty() else eligible[model.reward_rng.randi_range(0,eligible.size()-1)]
			if rolled.is_empty(): return {"error":"No eligible relic is available."}
			locked_grants[instance_id] = rolled
		var reward: String = locked_grants[instance_id]
		if not model.relics.can_add(reward): return {"error":"This relic is already owned."}
		# Offering a valid reward spends Emperor/World before the replacement decision.
		if not repeating and not committed_grants.has(instance_id):
			committed_grants[instance_id] = card.duplicate(true)
			model.tarots.remove_instance(instance_id)
		if model.relics.items.size() >= Relics.MAX_SLOTS and model.relics.needs_slot(reward):
			return {"choice":"replace","relic":reward}
	return {}

func cast(model, instance_id: int, choice: Dictionary = {}) -> Dictionary:
	var setup: Dictionary = prepare(model,instance_id,choice)
	if setup.has("error"): return setup
	var id: String = _card(model,instance_id).id
	var repeating: bool = instance_id < 0
	match setup.get("choice",""):
		"magician":
			var index: int = choice.get("die",-1)
			var face: int = choice.get("face",0)
			if index not in model.dice_turn.unused() or face < 1 or face > 6: return {"error":"Choose an unused die and a different face."}
			if model.dice_turn.values[index] == face: return {"error":"Choose a different face."}
		"hanged_man":
			if choice.get("ban", "") not in Catalog.eligible(banned): return {"error":"Choose a tarot still in the deck."}
		"replace":
			if not choice.get("discard",false) and (choice.get("replace",-1) < 0 or choice.replace >= model.relics.items.size()): return {"error":"Choose a relic to replace."}
	var repeats: Array = pending_repeat.get("sources",[]).duplicate() if repeating else model.RelicEffects.repeat_sources(model.relics.items,"ancient_prophecy")
	if repeating and not repeats.is_empty(): model.RelicEffects.Sequence.activate(model,repeats.pop_front())
	# Siege opens its next turn lazily. A committed tarot can begin that turn,
	# while inspecting/canceling a choice must not grant another regen tick.
	var events: Array = model.begin_round() if model.phase == "round_end" and not repeating else []
	var reward: String = ""
	var carry: int = pending_repeat.get("carry",0) if repeating else model.dice_turn.rolls_left
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
		"magician":
			model.dice_turn.values[choice.die] = choice.face
			model.dice_turn.selected.clear()
		"high_priestess":
			dice_boost += 1
			if model.dice_turn.has_rolled():
				for index in model.dice_turn.unused(): model.dice_turn.values[index] = mini(6,model.dice_turn.values[index]+1)
			model.dice_turn.selected.clear()
		"empress":
			model.grant_random_tarots(2)
		"emperor", "world":
			if not choice.get("discard",false):
				reward = locked_grants[instance_id]
				if not model.acquire_relic(reward,choice.get("replace",-1)): return {"error":"Choose a relic to replace."}
			locked_grants.erase(instance_id)
			committed_grants.erase(instance_id)
		"hierophant":
			for status in Status.HARMFUL:
				model.statuses[status].count = 0
				model.statuses[status].permanent = false
			if model.phase == "frozen":
				model.ice_hits_remaining = 0
				model.dice_turn.active = true
				model.phase = "roll"
		"lovers":
			lovers = true
			devil = 0
		"strength": strength += 1
		"hermit":
			model.dice_turn.locked.clear()
			model.dice_turn.committed.clear()
			model.dice_turn.groups.clear()
			model.dice_turn.selected.clear()
		"wheel":
			if model.reward_rng.randi_range(1,4) == 1: bonus_chests.append(2 if model.reward_rng.randi_range(1,10) == 1 else 1)
			else: events.append(model.event(-1,0,"relic","NO TREASURE"))
		"justice":
			# Cancel the pending group, then restore all six dice for the free reroll.
			if model.dice_turn.has_pending_group(): model.cancel_formed_skill()
			model.dice_turn.locked.clear()
			model.dice_turn.committed.clear()
			model.dice_turn.groups.clear()
			model.dice_turn.selected.clear()
		"hanged_man": banned.append(choice.ban)
		"devil":
			devil = mini(6,devil+1) if devil > 0 else 3
			lovers = false
		"star": star_throws = 3
		"temperance":
			carried_rolls += carry
			carry_wave = model.stage if "stage" in model else 0
			model.dice_turn.rolls_left = 0
			pending_turn_end = true
		"death": events.append_array(_execute(model,choice.target))
		"judgement": model.dice_turn.rolls_left += 2
		"chariot":
			model.shield += 50
			events.append(model.event(-1,50,"shield","SHIELD +50"))
		"moon":
			for target in model.living():
				events.append_array(model.apply_enemy_status(target,Status.DARKNESS,1))
				model.enemies[target].statuses[Status.DARKNESS].permanent = true
		"sun":
			events.append(model.event(-1,model.heal(model.max_hp),"heal","FULL HEAL"))
			for target in model.living(): events.append_array(_status(model,target,Status.BURNING,1))
		"tower": events.append_array(_tower(model))
	if repeating: dismiss_repeat()
	else: model.tarots.remove_instance(instance_id)
	if not repeats.is_empty(): pending_repeat = {"id":id,"instance_id":-absi(instance_id),"sources":repeats,"carry":carry}
	if pending_steps.is_empty(): _finish_effect(model,events)
	return {"id":id,"events":events,"relic":reward,"repeated":repeating,"reroll":id == "justice"}

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
		if model.SAVED_SKILLS_ENABLED and model.saved_skill.is_empty(): model.saved_skill = model.pending.duplicate()
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

## Fixed tarot damage bypasses offensive modifiers, taunt and player defenses.
func _tower(model) -> Array:
	var events: Array = []
	for target in model.living():
		var enemy: Dictionary = model.enemies[target]
		if enemy.shield > 0:
			var shield: int = enemy.shield
			enemy.shield = 0
			events.append(model.event(target,shield,"shield_break","SHIELD BREAK"))
			if not enemy.elite: events.append_array(model.apply_enemy_status(target,Status.IMMOBILIZED,1))
		var loss: int = mini(enemy.hp,50)
		enemy.hp -= loss
		events.append(model.damage_event(target,loss,50))
		if enemy.hp == 0: model.RelicEffects.enemy_killed(model)
	var loss: int = mini(model.hp,30)
	model.hp -= loss
	events.append(model.damage_event(-1,loss,30))
	if model.hp <= 0: events.append_array(model.RelicEffects.prevent_death(model))
	return events
