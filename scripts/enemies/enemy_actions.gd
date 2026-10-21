extends RefCounted
## Weighted intent selection and one action impact. No rendering or wall-clock state.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Weighted = preload("res://scripts/shared/weighted_choice.gd")
const ATTRIBUTES := {Status.FROZEN:Status.Attribute.ICE,Status.BURNING:Status.Attribute.FIRE,Status.STUNNED:Status.Attribute.SHOCK,Status.DARKNESS:Status.Attribute.DARK,Status.CORROSION:Status.Attribute.ACID}

static func support_targets(model, index: int, skill: String) -> Array:
	return model.living().filter(func(i):
		match skill:
			"guard": return i != index and model.enemies[i].shield < Catalog.shield_cap(model.enemies[i]) and model.enemy_status_count(i,Status.CORROSION) == 0
			"empower","team_empower": return not model.enemies[i].attack_boost
			"team_heal": return model.enemies[i].hp < model.enemies[i].max_hp and model.enemy_status_count(i,Status.DARKNESS) == 0
		return false)

static func options(model, index: int) -> Array:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var pool: Array = data.skills.duplicate(true)
	if enemy.elite: pool.append_array(data.elite_skills)
	return pool.filter(func(entry):
		match entry[0]:
			"shield","greater_shield": return enemy.shield < data.shield_cap and model.enemy_status_count(index,Status.CORROSION) == 0
			"heal": return enemy.hp < enemy.max_hp and model.enemy_status_count(index,Status.DARKNESS) == 0
			"guard","empower","team_empower","team_heal": return not support_targets(model,index,entry[0]).is_empty()
			"ice": return not model.is_frozen()
		return true)

static func choose(model, index: int) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var skill: String
	if enemy.get("charging",false):
		skill = data.release if enemy.charge >= data.charge_turns else "charge"
	else:
		var pool: Array = options(model,index)
		skill = pool[Weighted.pick(model.rng,pool.map(func(entry): return entry[1]))][0]
	return intent(model,index,skill)

static func intent(model, index: int, skill: String) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var move := {"skill":skill,"type":"attack","target":-1,"amount":enemy.damage,"name":"Attack","attribute":Status.Attribute.NONE,"hits":1,"status":-1,"stacks":0}
	match skill:
		"shield","greater_shield","guard":
			move.type = "shield"
			move.target = index
			move.amount = (100 if skill == "greater_shield" else 50) if enemy.role == Catalog.Role.PALADIN else 5
			move.name = "Guard Ally" if skill == "guard" else "Greater Shield" if skill == "greater_shield" else "Raise Shield"
			if skill == "guard":
				var targets: Array = support_targets(model,index,skill)
				move.target = targets[model.rng.randi_range(0,targets.size()-1)]
		"heal": move.type = "heal"; move.target = index; move.amount = roundi(enemy.max_hp*0.3); move.name = "Self Mend"
		"team_heal": move.type = "team_heal"; move.target = index; move.name = "Elven Healing"
		"empower","team_empower":
			move.type = skill
			move.name = "Group Blessing" if skill == "team_empower" else "Blessing"
			if skill == "empower":
				var targets: Array = support_targets(model,index,skill)
				move.target = targets[model.rng.randi_range(0,targets.size()-1)]
		"stun","ice","fire","elemental","stun_combo":
			move.stacks = 2 if skill == "elemental" else 1
			move.status = {"stun":Status.STUNNED,"ice":Status.FROZEN,"fire":Status.BURNING,"stun_combo":Status.STUNNED}.get(skill,-1)
			move.name = {"stun":"Stunning Blow","ice":"Ice Arrow","fire":"Fireball","elemental":"Elemental Strike","stun_combo":"Stunning Flurry"}[skill]
			if skill == "elemental":
				var statuses: Array = Status.PLAYER_HARMFUL.filter(func(id): return id != Status.FROZEN or not model.is_frozen())
				move.status = statuses[model.rng.randi_range(0,statuses.size()-1)]
			move.attribute = ATTRIBUTES[move.status]
			if skill == "stun_combo": move.hits = data.release_hits
		"forbidden_rite": move.name = "Forbidden Rite"; move.hits = data.release_hits
		"charge":
			move.type = "charge"; move.target = index; move.amount = 1
			move.name = "Chant" if enemy.role == Catalog.Role.HIGH_PRIEST else "Charge"
			move.progress = enemy.get("charge",0)+1; move.total = data.charge_turns
		"rest": move.type = "rest"; move.target = index; move.amount = 0; move.name = "Rest"
	return move

static func interrupt(enemy: Dictionary) -> void:
	# Retain the commitment, but discard all progress: restart from charge one.
	if enemy.get("charging",false): enemy.charge = 0

static func step(model, index: int) -> Array:
	var enemy: Dictionary = model.enemies[index]
	var move: Dictionary = enemy.intent
	var hit: int = enemy.get("action_hit",0)
	if hit == 0:
		if model.enemy_cannot_act(index):
			interrupt(enemy)
			enemy.acted = true
			var reason: String = "IMMOBILIZED" if model.enemy_status_count(index,Status.IMMOBILIZED) > 0 else "FROZEN"
			for id in Status.ENEMY_ACTION_LOCKS:
				if model.enemy_status_count(index,id) > 0: enemy.statuses[id].consume()
			return [model.event(index,0,"skip",reason)]
		if enemy.canceled:
			interrupt(enemy); enemy.acted = true
			return [model.event(index,0,"cancel","Lost in thought.")]
		if move.is_empty(): enemy.acted = true; return []
	var events: Array = []
	if move.type == "attack":
		if hit == 0:
			enemy.action_multiplier = 1.5 if enemy.attack_boost else 1.0
			enemy.attack_boost = false
			if move.get("skill","") in ["stun_combo","forbidden_rite"]: enemy.charge = 0; enemy.charging = false
		var amount: int = roundi(move.amount*enemy.action_multiplier*(0.5 if model.enemy_status_count(index,Status.DARKNESS) > 0 else 1.0))
		events.append_array(model.receive_damage(amount,false,index))
		# Explicit new moves carry stacks. Attribute-only intents remain supported.
		var status: int = move.get("status",{Status.Attribute.ICE:Status.FROZEN,Status.Attribute.FIRE:Status.BURNING,Status.Attribute.SHOCK:Status.STUNNED}.get(move.get("attribute",0),-1))
		if status >= 0 and events.any(func(e): return e.target == -1 and e.type == "damage" and e.amount > 0):
			events.append_array(model.apply_affliction(status,move.get("stacks",1)))
		enemy.action_hit = hit+1
		enemy.acted = enemy.action_hit >= move.get("hits",1) or not model.outcome().is_empty() or enemy.hp <= 0
	else:
		enemy.acted = true
		match move.type:
			"charge":
				enemy.charging = true; enemy.charge = enemy.get("charge",0)+1
				events.append(model.event(index,enemy.charge,"charge","%d / %d" % [enemy.charge,Catalog.ITEMS[enemy.role].charge_turns]))
			"rest": events.append(model.event(index,0,"skip","REST"))
			"team_heal":
				for target in model.living(): events.append_array(_heal(model,target,roundi(model.enemies[target].max_hp*0.2)))
			"empower","team_empower":
				var targets: Array = support_targets(model,index,move.type)
				if move.type == "empower" and not targets.is_empty(): targets = [move.target if move.target in targets else targets[model.rng.randi_range(0,targets.size()-1)]]
				for target in targets:
					model.enemies[target].attack_boost = true
					events.append(model.event(target,0,"buff","ATTACK x1.5"))
			"heal":
				if model.is_enemy_alive(move.target):
					events.append_array(_heal(model,move.target,move.amount))
					if not events.is_empty() and events[0].amount > 0: enemy.heals += 1
			"shield":
				var target: int = move.target
				if move.get("skill","") == "guard":
					var candidates: Array = support_targets(model,index,"guard")
					if target not in candidates: target = candidates[model.rng.randi_range(0,candidates.size()-1)] if not candidates.is_empty() else -1
				if model.is_enemy_alive(target):
					var amount: int = 0 if model.enemy_status_count(target,Status.CORROSION) > 0 else maxi(0,mini(move.amount,Catalog.shield_cap(model.enemies[target])-model.enemies[target].shield))
					model.enemies[target].shield += amount
					events.append(model.event(target,amount,"buff","+%d SHIELD" % amount))
	if enemy.acted: enemy.action_hit = 0
	return events

static func _heal(model, target: int, amount: int) -> Array:
	var enemy: Dictionary = model.enemies[target]
	var actual: int = 0 if model.enemy_status_count(target,Status.DARKNESS) > 0 else maxi(0,mini(amount,enemy.max_hp-enemy.hp))
	enemy.hp += actual
	return [model.event(target,actual,"heal","+%d HP" % actual)]
