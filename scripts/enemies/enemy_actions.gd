extends RefCounted
const Vitals = preload("res://scripts/combat/player_vitals.gd")
## Weighted intent selection and one action impact. No rendering or wall-clock state.
const Modifiers = preload("res://scripts/enemies/enemy_modifiers.gd")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Skills = preload("res://scripts/enemies/enemy_skill_catalog.gd")
const Weighted = preload("res://scripts/shared/weighted_choice.gd")
const Behaviors = preload("res://scripts/enemies/enemy_behaviors.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
const Spellsword = preload("res://scripts/enemies/elf_spellsword.gd")
const ATTRIBUTES := {Status.FROZEN:Status.Attribute.ICE,Status.BURNING:Status.Attribute.FIRE,Status.STUNNED:Status.Attribute.SHOCK,Status.DARKNESS:Status.Attribute.DARK,Status.CORROSION:Status.Attribute.ACID}

static func support_targets(model, index: int, skill: String) -> Array:
	return model.living().filter(func(i):
		match skill:
			"guard": return i != index and model.enemies[i].shield < Catalog.shield_cap(model.enemies[i]) and model.enemy_status_count(i,Status.CORROSION) == 0
			"empower","team_empower": return not model.enemies[i].attack_boost
			"team_heal","team_mend": return model.enemies[i].hp < model.enemies[i].max_hp and model.enemy_status_count(i,Status.DARKNESS) == 0
			"team_shield": return model.enemies[i].shield < Catalog.shield_cap(model.enemies[i]) and model.enemy_status_count(i,Status.CORROSION) == 0
		return false)

static func options(model, index: int) -> Array:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var pool: Array = data.skills.duplicate(true)
	if enemy.get("boss_phase",1) == 2 and data.has("phase_two_skills"): pool = data.phase_two_skills.duplicate(true)
	if enemy.elite: pool.append_array(data.elite_skills)
	return pool.filter(func(entry):
		match entry[0]:
			"shield","greater_shield": return enemy.shield < data.shield_cap and model.enemy_status_count(index,Status.CORROSION) == 0
			"heal","spellsword_mend": return enemy.hp < enemy.max_hp and model.enemy_status_count(index,Status.DARKNESS) == 0
			"guard","empower","team_empower","team_heal","team_mend": return not support_targets(model,index,entry[0]).is_empty()
			"ice": return not model.is_frozen()
			"summon_minions": return Fanatic.servants(model,index).size() <= Fanatic.MAX_MINIONS-2
			"split_minions": return Fanatic.servants(model,index,true).size() >= 2 and Fanatic.servants(model,index).size() < Fanatic.MAX_MINIONS
			"frost_bind": return not model.is_frozen() and enemy.get("last_skill","") != "frost_bind"
		return true)

static func choose(model, index: int) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var skill: String
	Behaviors.prepare_turn(model,index)
	if enemy.get("forced_charge",false):
		skill = "charge"
	elif enemy.get("charging",false):
		skill = data.release if enemy.charge >= data.charge_turns else "charge"
	else:
		var pool: Array = options(model,index)
		var selected: int = Weighted.pick(model.rng,pool.map(func(entry): return entry[1]))
		skill = pool[selected][0] if selected >= 0 else "rest"
	return intent(model,index,skill)

static func intent(model, index: int, skill: String) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var move: Dictionary = Skills.make(skill,Catalog.Damage.base_hit(enemy,model.character_level))
	if move.type == "attack": move.friendly_amount = Skills.make(skill,Catalog.Damage.friendly_base_hit(enemy)).amount
	match move.type:
		"shield":
			move.target = index
			move.amount = data.get("greater_shield_gain",data.get("shield_gain",5)) if skill == "greater_shield" else data.get("shield_gain",5)
			if enemy.get("boss_phase",1) == 2: move.amount = data.get("phase_two_shield_gain",move.amount)
			if skill == "guard":
				var targets: Array = support_targets(model,index,skill)
				move.target = targets[model.rng.randi_range(0,targets.size()-1)]
		"heal":
			move.target = index
			move.amount = roundi(enemy.max_hp*move.heal_ratio)
		"summon_minions","split_minions","team_heal","rest": move.target = index
		"empower":
			var targets: Array = support_targets(model,index,skill)
			move.target = targets[model.rng.randi_range(0,targets.size()-1)]
		"attack":
			if move.get("random_status",false):
				var statuses: Array = move.status_stacks.keys().filter(func(id): return id in Status.PLAYER_HARMFUL and (id != Status.FROZEN or not model.is_frozen()))
				move.status = statuses[model.rng.randi_range(0,statuses.size()-1)]
				move.stacks = move.status_stacks[move.status]
				move.attribute = ATTRIBUTES[move.status]
			if skill == data.get("release",""): move.hits = data.get("release_hits",1)
		"charge":
			move.target = index
			move.name = data.get("charge_name",move.name)
			move.progress = enemy.get("charge",0)+1
			move.total = data.charge_turns
	return Modifiers.decorate_intent(model,index,move)

## Freeze pauses bosses without discarding charge progress or broken marks.
static func interrupt(enemy: Dictionary, cause: int = -1) -> void:
	if cause == Status.FROZEN and (enemy.get("boss",false) or Catalog.ITEMS[enemy.role].get("interruptible",false)): return
	# Retain the commitment, but discard all progress: restart from charge one.
	if enemy.get("charging",false):
		enemy.charge = 0
		if enemy.get("boss",false) or Catalog.ITEMS[enemy.role].get("interruptible",false):
			enemy.charging = false; enemy.break_marks = Catalog.ITEMS[enemy.role].break_casts

static func step(model, index: int) -> Array:
	var enemy: Dictionary = model.enemies[index]
	var move: Dictionary = enemy.intent
	var hit: int = enemy.get("action_hit",0)
	if hit == 0:
		if model.enemy_cannot_act(index):
			var cause: int = Status.IMMOBILIZED if model.enemy_status_count(index,Status.IMMOBILIZED) > 0 else Status.FROZEN
			interrupt(enemy,cause)
			enemy.acted = true
			var reason: String = "IMMOBILIZED" if model.enemy_status_count(index,Status.IMMOBILIZED) > 0 else "FROZEN"
			for id in Status.ENEMY_ACTION_LOCKS:
				if model.enemy_status_count(index,id) > 0: enemy.statuses[id].consume()
			return [model.event(index,0,"skip",reason)]
		if enemy.canceled:
			interrupt(enemy); enemy.acted = true
			return [model.event(index,0,"cancel","Lost in thought.")]
		if move.is_empty(): enemy.acted = true; return []
		enemy.last_skill = move.get("skill","")
	var events: Array = []
	if move.type == "attack":
		if hit == 0:
			enemy.element_applied = false
			enemy.action_multiplier = 1.5 if enemy.attack_boost else 1.0
			enemy.attack_boost = false
			if not Catalog.ITEMS[enemy.role].get("release","").is_empty() and move.get("skill","") == Catalog.ITEMS[enemy.role].release:
				enemy.charge = 0; enemy.charging = false
				Behaviors.released(model,index)
				if enemy.get("boss",false) or Catalog.ITEMS[enemy.role].get("interruptible",false): enemy.break_marks = Catalog.ITEMS[enemy.role].break_casts
		var amount: int = roundi(move.amount*enemy.action_multiplier*(0.5 if model.enemy_status_count(index,Status.DARKNESS) > 0 else 1.0))
		if move.get("friendly_fire",false):
			if model.is_enemy_alive(move.target): events.append_array(_damage_ally(model,move.target,roundi(Vitals.to_combat(amount))))
		else: events.append_array(model.receive_damage(amount,false,index))
		# Explicit new moves carry stacks. Attribute-only intents remain supported.
		var status: int = move.get("status",{Status.Attribute.ICE:Status.FROZEN,Status.Attribute.FIRE:Status.BURNING,Status.Attribute.SHOCK:Status.STUNNED}.get(move.get("attribute",0),-1))
		if status >= 0 and (not move.get("status_once",false) or not enemy.get("element_applied",false)) and events.any(func(e): return e.target == -1 and e.type == "damage" and e.amount > 0):
			events.append_array(model.apply_affliction(status,move.get("stacks",1)))
		if move.has("extra_status") and not enemy.get("element_applied",false) and events.any(func(e): return e.target == -1 and e.type == "damage" and e.amount > 0):
			events.append_array(model.apply_affliction(move.extra_status,1))
		enemy.element_applied = true
		enemy.action_hit = hit+1
		enemy.acted = enemy.action_hit >= move.get("hits",1) or not model.outcome().is_empty() or enemy.hp <= 0
	else:
		enemy.acted = true
		match move.type:
			"affliction":
				if model.status_count(Status.HIDDEN) == 0: events.append_array(model.apply_affliction(move.status,move.stacks))
			"summon_minions": events.append_array(Fanatic.summon(model,index))
			"split_minions": events.append_array(Fanatic.split(model,index))
			"corrosive_heal": events.append_array(Spellsword.corrosive_heal(model,index))
			"charge":
				enemy.forced_charge = false
				enemy.charging = true; enemy.charge = enemy.get("charge",0)+1
				Behaviors.StraightInterrupt.prepare_turn(model,index)
				var data: Dictionary = Catalog.ITEMS[enemy.role]
				events.append(model.event(index,enemy.charge,"charge","%d / %d" % [enemy.charge,data.charge_turns]))
				# Show the last charge, then release within this same enemy action.
				if data.get("release_on_full_charge",false) and enemy.charge >= data.charge_turns:
					enemy.intent = intent(model,index,data.release)
					enemy.acted = false
			"rest": events.append(model.event(index,0,"skip","REST"))
			"team_heal":
				for target in model.living():
					var amount: int = roundi(model.enemies[target].max_hp*move.get("heal_ratio",0.2)*move.get("heal_factor",1.0))
					events.append_array(_damage_ally(model,target,amount) if move.get("inverted",false) else _heal(model,target,amount))
			"team_shield":
				for target in model.living(): events.append_array(_shield(model,target,roundi(model.enemies[target].max_hp*move.shield_ratio)))
			"empower","team_empower":
				var targets: Array = support_targets(model,index,move.type)
				if move.type == "empower" and not targets.is_empty(): targets = [move.target if move.target in targets else targets[model.rng.randi_range(0,targets.size()-1)]]
				for target in targets:
					model.enemies[target].attack_boost = true
					events.append(model.event(target,0,"buff","ATTACK x1.5"))
			"heal":
				if model.is_enemy_alive(move.target):
					var amount: int = roundi(move.amount*move.get("heal_factor",1.0))
					events.append_array(_damage_ally(model,move.target,amount) if move.get("inverted",false) else _heal(model,move.target,amount))
					if not events.is_empty() and events[0].amount > 0: enemy.heals += 1
			"shield":
				var target: int = move.target
				if move.get("skill","") == "guard":
					var candidates: Array = support_targets(model,index,"guard")
					if target not in candidates: target = candidates[model.rng.randi_range(0,candidates.size()-1)] if not candidates.is_empty() else -1
				if model.is_enemy_alive(target):
					events.append_array(_shield(model,target,move.amount))
	if enemy.acted: enemy.action_hit = 0
	events.append_array(Modifiers.resolve(model))
	return events

static func _heal(model, target: int, amount: int) -> Array:
	var enemy: Dictionary = model.enemies[target]
	var actual: int = 0 if model.enemy_status_count(target,Status.DARKNESS) > 0 else maxi(0,mini(amount,enemy.max_hp-enemy.hp))
	enemy.hp += actual
	return [model.event(target,actual,"heal","+%d HP" % actual)]

## All sources of ordinary enemy shielding respect corrosion and the recipient's cap.
static func _shield(model, target: int, amount: int) -> Array:
	var enemy: Dictionary = model.enemies[target]
	var corroded: bool = model.enemy_status_count(target,Status.CORROSION) > 0
	var gain: int = 0 if corroded else maxi(0,mini(amount,Catalog.shield_cap(enemy)-enemy.shield))
	enemy.shield += gain
	return [model.event(target,gain,"immune" if corroded else "shield","Corrosion" if corroded else "+%d SHIELD" % gain)]

## Friendly fire uses enemy defenses without player item multipliers or retaliation loops.
static func _damage_ally(model, target: int, amount: int) -> Array:
	return preload("res://scripts/enemies/enemy_friendly_damage.gd").hit(model,target,amount)
