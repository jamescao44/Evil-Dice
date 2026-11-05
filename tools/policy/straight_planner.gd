extends RefCounted
## Visible-state, two-correction lookahead; never samples combat RNG or future rewards.
const HORIZON := 2
const REROLL_COST := 0.025
const Status = preload("res://scripts/status/status_effect.gd")
const RerollRules = preload("res://scripts/dice/reroll_rules.gd")
var options: Array = []
var memo: Dictionary = {}
var terminal: Dictionary = {}
var cost := 1.0
var boost := 0
var curse := false
var fixed_six := false

## Value real damage, kills and matching interruptions; random attacks average legal targets.
static func utility(state: Dictionary, option: Dictionary) -> float:
	var total := 0.0; var targets := 0
	for hit in option.damage:
		var found: Array = state.enemies.filter(func(e): return e.slot == hit.target)
		if found.is_empty(): continue
		var enemy: Dictionary = found[0]
		if not option.area and not enemy.legal_target: continue
		var hp: float = enemy.hp+enemy.shield
		var damage: float = hit.total
		var value: float = minf(hp,damage)
		if damage >= hp: value += enemy.max_hp*0.35
		elif enemy.charge > 0 and enemy.interrupt_straight == option.faces.size():
			value += enemy.max_hp*0.25/maxi(1,enemy.get("interrupt_remaining",1))
		value += minf(maxf(0.0,enemy.hp-maxf(0.0,damage-enemy.shield)),hit.get("burn_value",0.0))
		total += value; targets += 1
	return (total if option.area else total/maxi(1,targets))+option.get("counter_value",0.0)

## Compile physical-die subsets once so socket bonuses and duplicate-face choices remain real.
static func capture(model, state: Dictionary, cache_equivalent: bool = true) -> Array:
	var result: Array = []
	var cache: Dictionary = {}
	var available: Array = model.dice_turn.unused()
	var guards: Array = model.taunting_enemies()
	for mask in range(1,1 << available.size()):
		var indices: Array = []
		for i in range(available.size()):
			if mask & (1 << i): indices.append(available[i])
		if indices.size() < 3: continue
		for first in range(1,8-indices.size()):
			var faces: Array = range(first,first+indices.size())
			var gems: Array = model.gemstones.snapshot(indices)
			var key := str([faces,gems])
			if cache_equivalent and cache.has(key):
				var reused: Dictionary = cache[key].duplicate(true)
				reused.indices = indices; reused.dice = indices.map(func(i): return i+1)
				result.append(reused)
				continue
			var skill = model.relic_skills.preview_upgrade(model,model.make_straight_skill(faces))
			skill.socket_gems = gems
			skill.perfect = model.dice_turn.last_perfect
			var row := {"indices":indices,"dice":indices.map(func(i): return i+1),"required":faces,"faces":skill.dice.duplicate(),"area":skill.hits_all(),"damage":[],"burning":model.CharacterSkills.burning_stacks(skill,model.character_evolution_stage())}
			var stacks: int = model.selection_statuses(skill).get(Status.BURNING,0)
			for target in model.living():
				var current_burn: int = model.enemy_status_count(target,Status.BURNING)
				var applied: int = mini(Status.MAX_BURNING_STACKS,current_burn+stacks)
				var extra_ticks: int = applied-current_burn+maxi(0,applied-1)-maxi(0,current_burn-1)
				var burn_factor: float = pow(2,model.RelicEffects.repeat_sources(model.relics.items,"vodka").size())*model.RelicEffects.Conditions.target_factor(model,target)
				if model.enemy_status_count(target,Status.CORROSION) > 0: burn_factor *= 1.5
				row.damage.append({"target":target+1,"total":model.skill_preview_total(skill,target,model.area_damage_factor(target,guards) if skill.hits_all() else 1.0,model.skill_use_count(skill)),"burn_value":extra_ticks*model.Vitals.to_combat(model.Vitals.BURN_DAMAGE)*burn_factor})
			row.counter_value = counter_value(model,state,skill)
			row.score = utility(state,row)
			row.mask = 0
			for face in faces: row.mask |= 1 << (face-1)
			row.clears = row.damage.all(func(hit): return state.enemies.any(func(e): return e.slot == hit.target and hit.total >= e.hp+e.shield)) and (row.area or state.enemies.size() == 1)
			result.append(row)
			cache[key] = row
	return result

## A reserved skill is usable even though the unselected-combinations list is empty.
static func needs_rescue_roll(state: Dictionary) -> bool:
	return state.phase == "roll" and state.get("manual_skills_left",1) > 0 and state.combinations.is_empty() and state.has_rolled and state.rolls_left == 0

## Clone the character counter/bonus queue to value charge progress without touching the live counter.
static func counter_value(model, state: Dictionary, skill: MultiHitSkill) -> float:
	var passive = model.character_passive.get_script().new()
	passive.charge = model.character_passive.charge
	passive.on_cast(skill,model.character_evolution_stage())
	if passive.charge == model.character_passive.charge and not skill.grants_bonus_fireballs: return 0.0
	var queue = model.relic_skills.get_script().new()
	skill.calculated_damage_total = model.unmitigated_damage(skill)*skill.damage_ticks
	queue.queue_character_fireballs(skill)
	var value := 0.0
	for entry in queue.queued:
		var targets := 0; var damage := 0.0
		for enemy in state.enemies:
			if not enemy.legal_target: continue
			damage += minf(enemy.hp+enemy.shield,model.skill_damage_total(entry.skill,enemy.slot-1))
			targets += 1
		value += damage/maxi(1,targets)
	# Banked charge has discounted future value; the final charge grants its full immediate value.
	return value if skill.grants_bonus_fireballs else value*0.75/passive.charge_limit(model.character_evolution_stage())

## Stop for a certain clear or an available charged-attack interruption; otherwise compare rerolls.
func decide(state: Dictionary, forecasts: Array) -> Dictionary:
	options = forecasts; memo.clear(); terminal.clear()
	boost = state.tarot_modifiers.get("dice_boost",0)
	curse = state.relics.any(func(r): return r.id == "cursed_die")
	fixed_six = state.dice.any(func(d): return (d.spent or d.locked) and d.face == 6)
	var values: Array = state.dice.map(func(d): return int(d.face) if d.face != null else 0)
	var current: Dictionary = best(values)
	for option in options:
		if option.clears and fits(option,values): return {"action":"form","dice":option.dice}
	if not current.is_empty():
		for option in options:
			if fits(option,values) and state.enemies.any(func(e): return e.charge > 0 and e.interrupt_straight == option.faces.size() and (option.area or e.legal_target and state.enemies.filter(func(t): return t.legal_target).size() == 1)):
				return {"action":"form","dice":option.dice}
	cost = maxf(1.0,float(current.get("score",0.0))*REROLL_COST)
	var slots: Array = state.dice.filter(func(d): return not d.spent and not d.locked).map(func(d): return int(d.slot)-1)
	var depth: int = mini(HORIZON,state.rolls_left) if "reroll" in state.actions else 0
	var best_value: float = current.get("score",0.0)
	var chosen := -1
	if depth > 0:
		for slot in slots:
			var value: float = expected(values,slot,depth,slots,state.get("same_pip_rerolls",0)%2)
			if value > best_value+0.0001: best_value = value; chosen = slot
	if chosen >= 0: return {"action":"reroll","die":chosen+1}
	if not current.is_empty(): return {"action":"form","dice":current.dice}
	return {"action":"end"} if "end" in state.actions else {}

## Match a straight to its physical dice without permitting locked/spent replacements.
func fits(option: Dictionary, values: Array) -> bool:
	if curse and not fixed_six and 6 not in values: return false
	var mask := 0
	for index in option.indices: mask |= 1 << (int(values[index])-1)
	return mask == option.mask

## Cache the strongest legal current cast; one skill per turn means no dice-count penalty.
func best(values: Array) -> Dictionary:
	var key := 0
	for face in values: key = key*7+int(face)
	if terminal.has(key): return terminal[key]
	var result := {}; var score := -1.0
	for option in options:
		if option.score > score and fits(option,values): result = option; score = option.score
	terminal[key] = result
	return result

## Forecast the unchanged-face guarantee first, then apply visible High Priestess boosts.
func expected(values: Array, slot: int, depth: int, slots: Array, same_count: int = 0) -> float:
	var total := 0.0
	for outcome in RerollRules.outcomes(values[slot],same_count):
		var next: Array = values.duplicate(); next[slot] = mini(6,outcome.face+boost)
		total += value_after(next,depth-1,slots,outcome.same_count%2)*outcome.weight
	return total-cost

## Each future decision can stop immediately; no forced fishing after a good result.
func value_after(values: Array, depth: int, slots: Array, same_count: int = 0) -> float:
	var key := str(values)+":"+str(depth)+":"+str(same_count)
	if memo.has(key): return memo[key]
	var option: Dictionary = best(values)
	var value: float = option.get("score",0.0)
	if depth > 0 and not option.get("clears",false):
		for slot in slots: value = maxf(value,expected(values,slot,depth,slots,same_count))
	memo[key] = value
	return value
