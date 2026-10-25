extends RefCounted
## Weighted intent selection and one action impact. No rendering or wall-clock state.
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Weighted = preload("res://scripts/shared/weighted_choice.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
const Spellsword = preload("res://scripts/enemies/elf_spellsword.gd")
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
	if enemy.get("boss_phase",1) == 2 and data.has("phase_two_skills"): pool = data.phase_two_skills.duplicate(true)
	if enemy.elite: pool.append_array(data.elite_skills)
	return pool.filter(func(entry):
		match entry[0]:
			"shield","greater_shield": return enemy.shield < data.shield_cap and model.enemy_status_count(index,Status.CORROSION) == 0
			"heal","spellsword_mend": return enemy.hp < enemy.max_hp and model.enemy_status_count(index,Status.DARKNESS) == 0
			"guard","empower","team_empower","team_heal": return not support_targets(model,index,entry[0]).is_empty()
			"ice": return not model.is_frozen()
			"summon_minions": return Fanatic.servants(model,index).size() <= Fanatic.MAX_MINIONS-2
			"split_minions": return Fanatic.servants(model,index,true).size() >= 2 and Fanatic.servants(model,index).size() < Fanatic.MAX_MINIONS
			"frost_bind": return not model.is_frozen() and enemy.get("last_skill","") != "frost_bind"
		return true)

static func choose(model, index: int) -> Dictionary:
	var enemy: Dictionary = model.enemies[index]
	var data: Dictionary = Catalog.ITEMS[enemy.role]
	var skill: String
	if enemy.get("forced_charge",false):
		skill = "charge"
	elif enemy.get("charging",false):
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
			if enemy.get("boss",false): move.amount = 100 if enemy.boss_phase == 2 else 50
			move.name = "Guard Ally" if skill == "guard" else "Greater Shield" if skill == "greater_shield" else "Raise Shield"
			if skill == "guard":
				var targets: Array = support_targets(model,index,skill)
				move.target = targets[model.rng.randi_range(0,targets.size()-1)]
		"heal","spellsword_mend": move.type = "heal"; move.target = index; move.amount = roundi(enemy.max_hp*(0.1 if skill == "spellsword_mend" else 0.3)); move.name = "Self Mend"
		"summon_minions","split_minions":
			move.type = skill; move.target = index; move.amount = 0
			move.name = "Summon Minions" if skill == "summon_minions" else "Splintering Grasp"
		"abyss_gaze":
			move.type = "affliction"; move.amount = 0; move.name = "Abyssal Gaze"
			move.status = Status.DARKNESS; move.stacks = 2; move.attribute = Status.Attribute.DARK
		"demon_slam": move.name = "Demonic Smash"; move.amount = enemy.damage*2
		"frost_bind":
			move.type = "affliction"; move.amount = 0; move.name = "Frost Bind"
			move.status = Status.FROZEN; move.stacks = 1; move.attribute = Status.Attribute.ICE
		"corrosive_heal": move.type = "corrosive_heal"; move.amount = 0; move.name = "Corrosive Heal"; move.attribute = Status.Attribute.ACID
		"dark_slash":
			move.name = "Dark Slash"; move.amount = enemy.damage*2
			move.status = Status.DARKNESS; move.stacks = 2; move.attribute = Status.Attribute.DARK
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
		"commander_slam":
			move.name = "Crushing Blow"; move.amount = enemy.damage*3
			move.status = Status.STUNNED; move.stacks = 1; move.attribute = Status.Attribute.SHOCK
		"forbidden_rite": move.name = "Forbidden Rite"; move.hits = data.release_hits
		"charge":
			move.type = "charge"; move.target = index; move.amount = 1
			move.name = "Chant" if enemy.role == Catalog.Role.HIGH_PRIEST else "Charge"
			move.progress = enemy.get("charge",0)+1; move.total = data.charge_turns
		"rest": move.type = "rest"; move.target = index; move.amount = 0; move.name = "Rest"
	return move

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
			enemy.action_multiplier = 1.5 if enemy.attack_boost else 1.0
			enemy.attack_boost = false
			if move.get("skill","") in ["stun_combo","forbidden_rite","commander_slam","dark_slash","demon_slam"]:
				enemy.charge = 0; enemy.charging = false
				if enemy.get("boss",false) or Catalog.ITEMS[enemy.role].get("interruptible",false): enemy.break_marks = Catalog.ITEMS[enemy.role].break_casts
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
			"affliction":
				if model.status_count(Status.HIDDEN) == 0: events.append_array(model.apply_affliction(move.status,move.stacks))
			"summon_minions": events.append_array(Fanatic.summon(model,index))
			"split_minions": events.append_array(Fanatic.split(model,index))
			"corrosive_heal": events.append_array(Spellsword.corrosive_heal(model,index))
			"charge":
				enemy.forced_charge = false
				enemy.charging = true; enemy.charge = enemy.get("charge",0)+1
				var data: Dictionary = Catalog.ITEMS[enemy.role]
				events.append(model.event(index,enemy.charge,"charge","%d / %d" % [enemy.charge,data.charge_turns]))
				# Show the last charge, then release within this same enemy action.
				if data.get("release_on_full_charge",false) and enemy.charge >= data.charge_turns:
					enemy.intent = intent(model,index,data.release)
					enemy.acted = false
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
					var corroded: bool = model.enemy_status_count(target,Status.CORROSION) > 0
					var amount: int = 0 if corroded else maxi(0,mini(move.amount,Catalog.shield_cap(model.enemies[target])-model.enemies[target].shield))
					model.enemies[target].shield += amount
					# Shield gains need their own popup; a blocked shield names its cause.
					events.append(model.event(target,amount,"immune" if corroded else "shield","Corrosion" if corroded else "+%d SHIELD" % amount))
	if enemy.acted: enemy.action_hit = 0
	return events

static func _heal(model, target: int, amount: int) -> Array:
	var enemy: Dictionary = model.enemies[target]
	var actual: int = 0 if model.enemy_status_count(target,Status.DARKNESS) > 0 else maxi(0,mini(amount,enemy.max_hp-enemy.hp))
	enemy.hp += actual
	return [model.event(target,actual,"heal","+%d HP" % actual)]
