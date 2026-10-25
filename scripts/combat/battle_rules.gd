extends RefCounted
const RelicRollRules = preload("res://scripts/relics/relic_roll_rules.gd")
## Deterministic battle model. Rendering and cosmetic randomness never alter it.
signal relic_activated(id: String)
signal relic_effect_activated(id: String)
signal boss_changed(index: int, event_type: String)
signal damage_redirected(source: int, target: int, damage: int, loss: int)
const BossRules = preload("res://scripts/enemies/boss_rules.gd")
var boss_cast_contacts: Dictionary = {}
const Weighted = preload("res://scripts/shared/weighted_choice.gd")

const Skill = preload("res://scripts/combat/multi_hit_skill.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Relics = preload("res://scripts/relics/relic_inventory.gd")
const RelicEffects = preload("res://scripts/relics/relic_effects.gd")
const RelicSkills = preload("res://scripts/relics/relic_skill_rules.gd")
const RelicCombat = preload("res://scripts/relics/relic_combat_triggers.gd")
var relic_skills = RelicSkills.new()
const RelicRecovery = preload("res://scripts/relics/relic_recovery.gd")
var relic_recovery = RelicRecovery.new()
var player_end_events: Array = []
const AreaAttack = preload("res://scripts/combat/area_attack.gd")
const TarotEffects = preload("res://scripts/tarot/tarot_effects.gd")
var tarot_effects = TarotEffects.new()
const FlamelingsPassive = preload("res://scripts/combat/flamelings_passive.gd")
var character_passive = FlamelingsPassive.new()
const CharacterSkills = preload("res://scripts/combat/flamelings_skills.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const SAVED_SKILLS_ENABLED := false
const DiceTurn = preload("res://scripts/dice/dice_turn.gd")
var dice_turn = DiceTurn.new()
var skill_dice_indices: Array = []
const DiceOdds = preload("res://scripts/dice/dice_odds.gd")
const EnemyCatalog = preload("res://scripts/enemies/enemy_catalog.gd")
const EnemyActions = preload("res://scripts/enemies/enemy_actions.gd")
const Kind = Skill.Kind
const NORMAL_NAME = "Tentacle Swipe"
const PAIR_NAMES = ["Rending Blow", "Abyssal Frost", "Eldritch Might", "Sweeping Ruin", "Tentacle Flurry", "Beyond Harm"]
const PAIR_TEXT = ["1.5x regular attack + 1.5x spare die.", "Apply 1 Frozen stack to every enemy. No attack.", "+0.5 damage multiplier for the next spare-die attacks.", "Hit all: 2/3 regular attack + 1.5x spare die each.", "3 automatic random hits, each regular attack + 1.5x spare die.", "Invincible for spare-die enemy phases / roll intervals."]
const SPECIAL_NAMES = ["Death Sentence", "Abyssal Renewal", "Eldritch Ascension", "Worldbreaker", "Sixfold Ruin", "Annihilation"]
const SPECIAL_TEXT = ["Instantly kill your chosen foe, ignoring shield.", "Restore all missing health. No attack.", "+2.0 damage multiplier for the next 3 attacks.", "Hit every foe for 2x regular attack power.", "6 automatic random hits, each regular attack power.", "Destroy the squad. Heal 12 HP."]
const CITY_SPECIAL_TEXT = ["Hit the city for 5x regular attack power.", "Restore all missing health. No attack.", "+2.0 damage multiplier for the next 3 attacks.", "2x city attack; clear all troops.", "6 automatic city hits; each clears one troop.", "2000 base damage x DMG multiplier; clear troops; heal 12."]
const REGULAR_ATTACK_POWER = 15.0
const DAMAGE_PER_PIP = 1.5
const MAX_HP = 100
const SHIELD_CAP = 20
const DAMAGE_MULTIPLIER = 1.0
const NON_PERFECT_TRIPLE_CAP = 0.25
const NON_PERFECT_PAIR_CAP = 0.70

var rng = RandomNumberGenerator.new()
var dice_odds = DiceOdds.new()
var hp: int = MAX_HP
var base_max_hp: int = MAX_HP
var max_hp: int:
	get:
		var value: float = RelicEffects.max_health(relics.items,base_max_hp)
		return maxi(1, floori(value + 0.000001))
	set(value): base_max_hp = value
var relics = Relics.new()
var perfect_relic_ready: bool = false
var roll_relic_actions: Array = []
var roll_chip_casts: Array = []
var roll_attacks: Array = []
var active_relic_procs: Array = []
var relic_activation_speed: float = 1.0
var relic_turn_closed: bool = false
var turn_end_events: Array = []
var lifesteal_budgets: Dictionary = {}
var lifesteal_used: int = 0:
	set(value):
		lifesteal_used = value
		if value == 0: lifesteal_budgets.clear()
var power: float = 1.0
var reward_base_damage: float = 0.0
var reward_damage_multiplier: float = 0.0
var perfect_combo: int = 0
var shield: int = 0
var statuses: Dictionary = {}
var burn_ticks_remaining: int = 0
var ice_hits_remaining: int = 0
var enemies: Array = []
var round_number: int = 0
var bonus_turn_count: int = 0
var pending: MultiHitSkill = Skill.new()
var saved_skill: MultiHitSkill = Skill.new()
var bonus_resume: Dictionary = {}
var buff_ticks: Dictionary = {}
# Future buffs/relics can add or remove named use multipliers without changing skills.
var skill_use_modifiers: Dictionary = {}
var phase: String = "new"
var category_weights: Array = [1.0, 1.0, 1.0] # normal, pair, triple; relic hooks
var pair_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var triple_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 0.7]
var face_weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

func _init(seed_value: int = -1) -> void:
	dice_turn.selection_rules = relics
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	reset()

func reset() -> void:
	relic_recovery = RelicRecovery.new()
	player_end_events.clear()
	relic_skills = RelicSkills.new()
	character_passive = FlamelingsPassive.new()
	tarot_effects = TarotEffects.new()
	dice_turn = DiceTurn.new()
	dice_turn.selection_rules = relics
	skill_dice_indices.clear()
	relics.clear()
	perfect_relic_ready = false
	roll_relic_actions.clear()
	roll_chip_casts.clear()
	roll_attacks.clear()
	active_relic_procs.clear()
	relic_activation_speed = 1.0
	relic_turn_closed = false
	turn_end_events.clear()
	hp = MAX_HP
	max_hp = MAX_HP
	power = 1.0
	reward_base_damage = 0
	reward_damage_multiplier = 0
	perfect_combo = 0
	shield = 0
	set_status_counts({2: 0, 3: 0, 6: 0, 33: 0})
	burn_ticks_remaining = 0
	ice_hits_remaining = 0
	enemies = [make_enemy(0), make_enemy(1), make_enemy(2)]
	for e in enemies:
		e["intent"] = {}
		e["canceled"] = false
		e["acted"] = false
	round_number = 0
	bonus_turn_count = 0
	pending = Skill.new()
	saved_skill = Skill.new()
	bonus_resume = {}
	buff_ticks.clear()
	skill_use_modifiers.clear()
	phase = "new"
	category_weights = [1.0, 1.0, 1.0]
	pair_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	triple_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 0.7]
	face_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

static func make_enemy(role: int, level: int = 1, elite: bool = false) -> Dictionary:
	return EnemyCatalog.make(role,level,elite)

func set_status_counts(counts: Dictionary) -> void:
	statuses.clear()
	for id in Status.IDS:
		statuses[id] = Status.new(id)
		statuses[id].count = 0 if id == Status.PLAGUE else int(counts.get(id, 0))

func status_count(id: int) -> int:
	return statuses[id].count if statuses.has(id) else 0

func is_city() -> bool:
	return false

func relic_drop_weights() -> Array:
	return Relics.Drops.weights_for_wave(1)

func status_counts(ids: Array = Status.IDS) -> Dictionary:
	var counts: Dictionary = {}
	for id in ids: counts[id] = status_count(id)
	return counts

func is_frozen() -> bool:
	return status_count(Status.FROZEN) > 0

func is_stunned() -> bool:
	return status_count(Status.STUNNED) > 0

## Apply an eligible player status with relic immunities and stack limits.
func apply_affliction(id: int, amount: int) -> Array:
	if hp <= 0 or (status_count(Status.IMMUNITY) > 0 and status_count(Status.CORROSION) == 0): return []
	if id not in Status.PLAYER_HARMFUL: return []
	var protector: String = RelicEffects.immunity_source(relics.items,id)
	if not protector.is_empty():
		relic_activated.emit(protector)
		return []
	var before: int = status_count(id)
	statuses[id].apply(amount)
	if id == Status.BURNING:
		amount = status_count(id) - before
		if amount <= 0: return []
	var applied := event(-1, amount, "status", status_label(id, amount))
	applied.status = id
	return [applied]

## Convert three dice faces into a reusable skill object.
static func classify(dice: Array) -> MultiHitSkill:
	if dice.size() != 3: return Skill.new()
	var counts: Dictionary = {}
	for value in dice:
		if not value is int or value < 1 or value > 6: return Skill.new()
		counts[value] = counts.get(value, 0) + 1
	for face in counts:
		if counts[face] == 3:
			return Skill.new(Kind.ULTIMATE if face == 6 else Kind.SPECIAL, face, dice, 6 if face == 5 else 1)
	for face in counts:
		if counts[face] == 2:
			return Skill.new(Kind.PAIR, face, dice, 3 if face == 5 else 1)
	return Skill.new(Kind.NORMAL, 0, dice)

static func throw_rates(throw_power: float, perfect: bool = false, fever: bool = false) -> Dictionary:
	if perfect:
		if fever: return {"normal": 0.0, "pair": 0.0, "triple": 1.0}
		return {"normal": 0.0, "pair": 0.5, "triple": 0.5}
	var weight: float = pow(clampf(throw_power, 0, 1), 2)
	var triple: float = minf(NON_PERFECT_TRIPLE_CAP, lerpf(1.0 / 36.0, 0.5, weight))
	var match_rate: float = lerpf(4.0 / 9.0, 1.0, weight)
	var pair: float = match_rate - triple
	if fever:
		pair *= 1.5
		triple *= 1.5
		var total: float = pair + triple
		# Preserve the boosted category ratio when their combined chance exceeds 100%.
		if total > 1.0:
			pair /= total
			triple /= total
	# Apply the pair ceiling after fever normalization; overflow becomes singles.
	pair = minf(pair, NON_PERFECT_PAIR_CAP)
	return {"normal": maxf(0, 1.0 - pair - triple), "pair": pair, "triple": triple}

## Combine throw power and relic modifiers into the current dice-category odds.
func roll_rates(throw_power: float, perfect: bool = false, fever: bool = false) -> Dictionary:
	var base: Dictionary = throw_rates(throw_power, perfect, fever)
	var values: Array = [base.normal, base.pair, base.triple]
	var total: float = 0
	for i in range(3):
		values[i] *= maxf(0, category_weights[i])
		total += values[i]
	if total <= 0: return RelicEffects.category_rates(relics.items,base,perfect and fever)
	var triple: float = values[2] / total
	if perfect:
		triple = minf(triple, 1.0 if fever else 0.5)
		return RelicEffects.category_rates(relics.items,{"normal":0.0, "pair":1.0-triple, "triple":triple},fever)
	triple = minf(triple, NON_PERFECT_TRIPLE_CAP * (1.5 if fever else 1.0))
	var pair: float = minf(values[1] / total, NON_PERFECT_PAIR_CAP)
	return RelicEffects.category_rates(relics.items,{"normal":maxf(0, 1.0-pair-triple), "pair":pair, "triple":triple})

func _weighted_face(weights: Array) -> int:
	var index: int = Weighted.pick(rng, weights)
	return index + 1 if index >= 0 else rng.randi_range(1, 6)

func _match_values(triple: bool) -> Array:
	var face: int = _weighted_face(triple_weights if triple else pair_weights)
	var values: Array = [face, face, face]
	if not triple:
		var spare_weights: Array = face_weights.duplicate()
		spare_weights[face-1] = 0.0
		var other: int = Weighted.pick(rng, spare_weights)
		if other < 0: other = (face % 6)
		values[rng.randi_range(0, 2)] = other + 1
	return values

## Roll unused dice only after the previous summoned skill has been resolved.
func roll_pool(perfect: bool = false, forced: Array = [], free: bool = false) -> Array:
	if phase != "roll" or not pending.is_empty() or not outcome().is_empty(): return []
	perfect = perfect or forces_perfect()
	var changed: Array = dice_turn.roll(rng, perfect, forced, free)
	if changed.is_empty(): return []
	RelicRollRules.apply(self,changed)
	tarot_effects.modify_pool(self,changed)
	var cursed_sixes: bool = RelicRollRules.apply_curse(self)
	tarot_effects.star_throws = maxi(0,tarot_effects.star_throws-1)
	record_perfect(perfect,free)
	roll_attacks = Patterns.automatic_groups(dice_turn.values,range(DiceTurn.COUNT) if cursed_sixes else changed)
	for group in roll_attacks: group.skill.begin_cast(RelicEffects.use_modifiers(relics.items,group.skill,{}))
	if not roll_attacks.is_empty(): phase = "roll_attacks"
	statuses[Status.STUNNED].consume()
	return range(DiceTurn.COUNT) if cursed_sixes else changed

## Lock a valid combination and suspend the remaining dice until it resolves.
func form_selected_skill() -> MultiHitSkill:
	if phase != "roll" or not pending.is_empty() or not outcome().is_empty(): return Skill.new()
	var indices: Array = dice_turn.selected.duplicate()
	var skill: MultiHitSkill = make_straight_skill(dice_turn.form())
	if skill.is_empty(): return skill
	skill.perfect = dice_turn.last_perfect
	skill = relic_skills.preview_upgrade(self,skill)
	pending = skill
	skill_dice_indices = indices
	phase = "player"
	return skill.duplicate(true)

## Character-owned skill mapping shared by physical dice and generated relic casts.
func make_straight_skill(values: Array) -> MultiHitSkill:
	return Patterns.classify(values)

## Return a pending skill's dice without refunding throws or touching spent groups.
func cancel_formed_skill() -> bool:
	if phase != "player" or pending.is_empty() or pending.cast_source != "manual" or not bonus_resume.is_empty() or not outcome().is_empty(): return false
	if not dice_turn.release_group(skill_dice_indices): return false
	pending = Skill.new()
	skill_dice_indices = []
	phase = "roll"
	return true

## Defer formation relic bonuses until the combination can no longer be cancelled.
func _commit_formed_skill() -> void:
	if pending.cast_source != "manual": return
	if not bonus_resume.is_empty() or not dice_turn.commit_group(skill_dice_indices): return
	roll_relic_actions.append_array(RelicEffects.formation_actions(self, pending))
	perfect_relic_ready = not roll_relic_actions.is_empty()

## End Turn is available only after throwing and resolving the summoned skill.
func can_end_dice_turn() -> bool:
	return phase == "roll" and dice_turn.active and dice_turn.has_rolled() and pending.is_empty() and outcome().is_empty()

## Build a read-only leftover healing action for the End Turn preview.
func leftover_skill() -> MultiHitSkill:
	return Patterns.cleanup(dice_turn.unused().map(func(index): return dice_turn.values[index]))

## Preview effective healing, respecting missing HP and Darkness.
func leftover_total_healing() -> int:
	if status_count(Status.DARKNESS) > 0: return 0
	return mini(max_hp-hp,modified_healing(CharacterSkills.leftover_healing(leftover_skill().sum,max_hp)))

## Compatibility for older consumers; leftovers no longer inflict damage.
func leftover_total_damage() -> int:
	return 0

## Commit leftover dice as one healing action before enemies act.
func end_dice_turn() -> bool:
	if not can_end_dice_turn(): return false
	pending = leftover_skill()
	relic_recovery.leftover_sum = pending.sum
	skill_dice_indices = dice_turn.unused()
	dice_turn.selected.clear()
	dice_turn.locked.append_array(skill_dice_indices)
	dice_turn.committed.append_array(skill_dice_indices)
	dice_turn.active = false
	if pending.is_empty(): _finish_player_action(Skill.new(Kind.NORMAL))
	else: phase = "player"
	return true

## Roll dice, apply outcome modifiers and store the pending player skill.
func roll(throw_power: float = 0.0, perfect: bool = false, fever: bool = false) -> MultiHitSkill:
	if phase != "roll": return Skill.new()
	dice_turn.active = false # Legacy three-die simulation helper; gameplay uses roll_pool.
	perfect = perfect or forces_perfect()
	var rates: Dictionary = roll_rates(throw_power, perfect, fever)
	var category: int = Weighted.pick(rng, [rates.normal, rates.pair, rates.triple])
	var values: Array = []
	if category > 0:
		values = _match_values(category == 2)
	else:
		var weights: Array = face_weights.duplicate()
		for i in range(3):
			var index: int = Weighted.pick(rng, weights)
			if index < 0:
				for j in range(6): weights[j] = 0.0 if j+1 in values else 1.0
				index = Weighted.pick(rng, weights)
			values.append(index+1)
			weights[index] = 0.0
	pending = classify(tarot_effects.modify_dice(self,RelicEffects.modify_dice(self,values,perfect,rates)))
	pending.perfect = perfect
	record_perfect(perfect)
	statuses[Status.STUNNED].consume()
	phase = "player"
	return pending.duplicate(true)

func set_test_roll(dice: Array, perfect: bool = false) -> MultiHitSkill:
	# Only called by tests or the visual debug picker; overrides power odds.
	if phase != "roll" or classify(dice).is_empty():
		return Skill.new()
	dice_turn.active = false # Direct skill fixture for combat tests.
	perfect = perfect or forces_perfect()
	var result := classify(tarot_effects.modify_dice(self,RelicEffects.modify_dice(self,dice.duplicate(),perfect,throw_rates(0,perfect))))
	if result.is_empty():
		return Skill.new()
	pending = result
	pending.perfect = perfect
	record_perfect(perfect)
	statuses[Status.STUNNED].consume()
	phase = "player"
	return pending.duplicate(true)

## Update the Perfect combo once for an accepted throw.
func record_perfect(perfect: bool, preserve_combo: bool = false) -> void:
	# Justice has no timing attempt; only a missed manual throw breaks the streak.
	preserve_combo = RelicEffects.protect_perfect(self,perfect,preserve_combo)
	if perfect: perfect_combo += RelicEffects.perfect_combo_gain(relics.items)
	elif not preserve_combo: perfect_combo = 0
	roll_chip_casts = RelicEffects.Conditions.rolled(self)
	roll_relic_actions = RelicEffects.roll_actions(self,perfect)
	perfect_relic_ready = not roll_relic_actions.is_empty()
	if perfect:
		for item in relics.items:
			if item.id not in RelicEffects.Catalog.DISABLED and RelicEffects.STONES.get(item.id,{}).get("combo_gain",0) > 0:
				relic_activated.emit(item.id)

func forces_perfect() -> bool:
	return tarot_effects.star_throws > 0

func combo_multiplier() -> float:
	return 1.0 if perfect_combo <= 0 else 1.2 + perfect_combo * 0.1

func is_enemy_alive(index: int) -> bool:
	return index >= 0 and index < enemies.size() and (enemies[index].hp > 0 or enemies[index].get("phase_transition_pending",false))

func has_living_enemies() -> bool:
	for index in range(enemies.size()):
		if is_enemy_alive(index): return true
	return false

func living() -> Array:
	var result: Array = []
	for i in range(enemies.size()):
		if is_enemy_alive(i):
			result.append(i)
	return result

func has_pending_attack_hits() -> bool:
	return phase == "executing" and pending.is_attack() and pending.uses_left() > 0

func taunting_enemies() -> Array:
	var targets: Array = living()
	return targets.filter(func(i): return EnemyCatalog.taunts(enemies[i])) if targets.size() > 1 else []

## Return living targets allowed by Paladin taunt.
func attack_targets() -> Array:
	var guards: Array = taunting_enemies()
	return guards if not guards.is_empty() else living()

func area_damage_factor(target: int, guards: Array) -> float:
	return 0.5 if not guards.is_empty() and target not in guards else 1.0

## Lock selected-target casts to their corpse; random attacks prefer living foes.
func player_attack_targets() -> Array:
	if has_pending_attack_hits() and pending.keeps_selected_target() and pending.target >= 0 and pending.target < enemies.size(): return [pending.target]
	var targets: Array = attack_targets()
	# Only an already-started cast can follow through on the defeated squad.
	if targets.is_empty() and has_pending_attack_hits(): return range(enemies.size())
	return targets

func outcome() -> String:
	if hp <= 0:
		return "defeat"
	if not has_living_enemies() and not has_pending_attack_hits():
		return "victory"
	return ""

func begin_round() -> Array:
	if not outcome().is_empty() or phase not in ["new", "round_end"]:
		return []
	RelicEffects.Conditions.begin_turn(self)
	relic_recovery.begin_turn(self)
	tarot_effects.begin_round()
	round_number += 1
	relic_turn_closed = false
	var events: Array = []
	if statuses[2].count > 0:
		var healed := heal(roundi(5*statuses[2].potency))
		buff_ticks[2] = true
		events.append(event(-1, healed, "heal", "Regrowth +%d" % healed))
	for i in living():
		enemies[i].canceled = false
		enemies[i].acted = false
		enemies[i].action_hit = 0
		enemies[i].intent = choose_intent(i)
	_prepare_player_turn()
	return events

func _prepare_player_turn() -> void:
	roll_attacks.clear()
	dice_turn.reset()
	dice_turn.rolls_left += tarot_effects.start_pool(self)
	skill_dice_indices.clear()
	if is_frozen():
		tarot_effects.extra_rolls = 0
		dice_turn.active = false
	phase = "frozen" if is_frozen() else "roll"
	ice_hits_remaining = 3 if is_frozen() else 0

func break_ice() -> Array:
	if phase != "frozen" or not is_frozen() or not outcome().is_empty() or ice_hits_remaining <= 0: return []
	ice_hits_remaining -= 1
	if ice_hits_remaining == 0: return skip_frozen_turn()
	return [event(-1, ice_hits_remaining, "ice_crack", "CRACK")]

func skip_frozen_turn() -> Array:
	if phase != "frozen" or not is_frozen() or not outcome().is_empty() or ice_hits_remaining > 0: return []
	statuses[Status.FROZEN].consume()
	_finish_player_action(Skill.new(Kind.NORMAL))
	return [event(-1, 0, "skip", "TURN SKIPPED")]

func choose_intent(index: int) -> Dictionary:
	return EnemyActions.choose(self,index)

func damage_cap(kind: int, target: int) -> int:
	var max_hp: int = enemies[target].max_hp
	return maxi(1, floori(float(max_hp) * (2.0 / 3.0 if kind == Kind.SPECIAL else 1.0 / 3.0)))

static func is_attack(result: MultiHitSkill) -> bool:
	return result.is_attack()

func set_skill_use_multiplier(source: String, multiplier: int) -> void:
	if multiplier <= 1: skill_use_modifiers.erase(source)
	else: skill_use_modifiers[source] = multiplier

func skill_use_count(skill: MultiHitSkill) -> int:
	return skill.use_count(skill_modifiers_for(skill))

func skill_modifiers_for(skill: MultiHitSkill) -> Dictionary:
	relic_skills.configure_split(self,skill)
	if skill.pattern in ["cleanup","match_auto"] or skill.cast_source in ["echo","chip"]: return {}
	if skill.cast_source == "character_bonus": return RelicEffects.use_modifiers(relics.items,skill,{}) if skill.split_attack else {}
	var modifiers: Dictionary = RelicEffects.use_modifiers(relics.items,skill,skill_use_modifiers)
	if skill.is_attack() and not is_instant_kill(skill) and tarot_effects.extra_uses > 0: modifiers["high_priestess"] = {"add":tarot_effects.extra_uses}
	return modifiers

## Freeze the skill use budget and consume next-skill modifiers at cast start.
func begin_player_cast(primary: int = -1) -> bool:
	if phase != "player" or pending.is_empty() or not outcome().is_empty(): return false
	relic_skills.configure_split(self,pending)
	if pending.is_attack():
		if pending.split_attack:
			var targets: Array = attack_targets()
			primary = targets[rng.randi_range(0,targets.size()-1)] if not targets.is_empty() else -1
		elif primary < 0: primary = player_target()
		if not is_city() and primary not in attack_targets(): return false
		pending.target = primary
	_commit_formed_skill()
	boss_cast_contacts.clear()
	pending.begin_cast(skill_modifiers_for(pending))
	if pending.cast_source not in ["echo","character_bonus","chip"]: character_passive.on_cast(pending,character_evolution_stage())
	if pending.cast_source not in ["echo","character_bonus","chip"] and pending.is_attack() and not is_instant_kill(pending): tarot_effects.extra_uses = 0
	if pending.pattern != "cleanup" and pending.cast_source not in ["echo","character_bonus","chip"]: tarot_effects.begin_skill(pending)
	if pending.is_attack(): statuses[Status.HIDDEN].count = 0
	if pending.cast_source not in ["echo","character_bonus","chip"] and is_attack(pending) and RelicEffects.begin_attack(relics.items): pending.critical = true
	relic_skills.cast_started(self,pending)
	phase = "executing"
	return true

static func hits_all(result: MultiHitSkill) -> bool:
	return result.hits_all()

func attack_multiplier() -> float:
	return 1.0 + (0.5*statuses[3].potency if statuses[3].count > 0 else 0.0) + (2.0*statuses[33].potency if statuses[33].count > 0 else 0.0)

func boon_turns(face: int) -> int:
	return (statuses[33].count if statuses[33].count > 0 else statuses[3].count) if face == 3 else int(status_count(face))

## Get the skill’s base damage with current flat relic bonuses.
func attack_base(result: MultiHitSkill) -> float:
	return attack_base_with_bonus(result,relic_base_damage()+RelicEffects.auto_damage(relics.items,result))*tarot_effects.skill_factor(result)

## Expose the current character's level-scaled base before flat relic additions.
func character_base_damage() -> float:
	return CharacterSkills.BASE_DAMAGE*character_damage_factor()

## Persistent HUD values exclude skill-only conditions and unspent next-skill effects.
func standing_damage_values() -> Vector2:
	return Vector2(character_base_damage()+relic_base_damage(),damage_multiplier(MultiHitSkill.new()))

func regular_base_damage() -> float:
	return (REGULAR_ATTACK_POWER + reward_base_damage * DAMAGE_PER_PIP)*character_damage_factor()

## Subclasses can scale character damage without multiplying flat relic bonuses.
func character_damage_factor() -> float:
	return 1.0

## Standalone battles use the starting form; runs provide their earned evolution stage.
func character_evolution_stage() -> int:
	return 0

func attack_base_with_bonus(result: MultiHitSkill, bonus: float) -> float:
	if result.pattern == "cleanup": return 0
	if result.pattern in ["straight","match_auto"]: return (character_base_damage()+bonus)*CharacterSkills.damage_factor(result)
	if result.kind == Kind.NORMAL: return (result.sum + reward_base_damage) * DAMAGE_PER_PIP * character_damage_factor() + bonus
	var amount: float = regular_base_damage() + bonus
	if result.kind == Kind.PAIR:
		if result.face == 1: amount *= 1.5
		elif result.face == 4: amount *= 2.0 / 3.0
		amount += result.spare * DAMAGE_PER_PIP
	elif result.kind == Kind.SPECIAL and result.face == 4:
		amount *= 2.0
	return amount

func regular_attack_power() -> float:
	return regular_base_damage() + relic_base_damage()

func relic_base_damage() -> float:
	return RelicEffects.base_damage(relics.items,character_base_damage())

func damage_baseline() -> float:
	return DAMAGE_MULTIPLIER * power

## Apply additive boons and ordered relics, then the independent Perfect factor and darkness.
func damage_multiplier(result: MultiHitSkill = null) -> float:
	var value: float = damage_baseline() + reward_damage_multiplier + (attack_multiplier() - 1.0)
	var skill: MultiHitSkill = pending if result == null else result
	value = RelicEffects.damage_multiplier(relics.items,value,skill,self)
	value *= combo_multiplier()
	if status_count(Status.DARKNESS) > 0: value *= 0.5
	return value

## Build the read-only base and multiplier trace for cast feedback.
func attack_damage_steps(result: MultiHitSkill) -> Array:
	relic_skills.configure_split(self,result)
	# Read-only trace of the same formula used by hits. Never consumes charges/RNG.
	if not is_attack(result) or is_instant_kill(result): return []
	var base: float = character_base_damage() if not result.pattern.is_empty() else regular_base_damage()
	var steps: Array = []
	if not is_equal_approx(character_damage_factor(),1.0):
		steps.append({"source":"level","id":"","slot":-1,"before":1.0,"after":1.0,"base_before":base/character_damage_factor(),"base_after":base,"note":""})
	var value: float = 1.0
	var bonuses: Array = [
		{"source":"baseline","amount":damage_baseline()-1.0},
		{"source":"treasure","amount":reward_damage_multiplier},
		{"source":"boon","amount":attack_multiplier()-1.0},
	]
	for bonus in bonuses:
		if is_zero_approx(bonus.amount): continue
		steps.append({"source":bonus.source,"id":"","slot":-1,"before":value,"after":value+bonus.amount,"note":""})
		value += bonus.amount
	var relic_steps: Array = RelicEffects.attack_steps(relics.items,value,result,self)
	steps.append_array(relic_steps)
	if not relic_steps.is_empty(): value = relic_steps.back().after
	var strength_factor: float = tarot_effects.skill_factor(result)
	var base_bonus: float = 0
	for step in steps:
		if step.source == "level": continue
		step.base_before = base
		var addition: float = step.get("base_bonus",0.0)+step.get("auto_bonus",0.0)
		base = (base+addition)*step.get("base_factor",1.0)
		base_bonus = base-(character_base_damage() if not result.pattern.is_empty() else regular_base_damage())
		step.base_after = base
		if not is_equal_approx(step.base_before,base):
			step.note = "+%s BASE"
			step.note_values = [str(snappedf(base-step.base_before,0.01))]
	# Multiply the accumulated level and relic base only after all ordered relics.
	var skill_base: float = attack_base_with_bonus(result,base_bonus)*result.damage_ticks*(0.5 if result.split_attack else 1.0)
	steps.append({"source":"skill","id":"","slot":-1,"before":value,"after":value,"base_before":base,"base_after":skill_base,"note":""})
	base = skill_base
	var strength_base: float = base
	for i in range(maxi(0,floori(strength_factor)-1)):
		steps.append({"source":"tarot","id":"","slot":-1,"before":value,"after":value,"base_before":base,"base_after":base+strength_base,"note":"STRENGTH"})
		base += strength_base
	# Echoes can halve an amplified skill to a fractional factor such as 0.5 or 1.5.
	if not is_equal_approx(base,strength_base*strength_factor):
		steps.append({"source":"skill","id":"","slot":-1,"before":value,"after":value,"base_before":base,"base_after":strength_base*strength_factor,"note":""})
		base = strength_base*strength_factor
	if perfect_combo > 0:
		steps.append({"source":"combo","id":"","slot":-1,"before":value,"after":value*combo_multiplier(),"base_before":base,"base_after":base,"note":""})
		value *= combo_multiplier()
	if status_count(Status.DARKNESS) > 0:
		steps.append({"source":"darkness","id":"","slot":-1,"before":value,"after":value*0.5,"base_before":base,"base_after":base,"note":""})
	steps.back()["damage_ticks"] = result.damage_ticks
	return steps

func cast_damage_multiplier(result: MultiHitSkill) -> float:
	return damage_multiplier(result)

func is_instant_kill(result: MultiHitSkill) -> bool:
	return (result.kind == Kind.ULTIMATE and result.pattern != "straight") or (result.pattern.is_empty() and result.kind == Kind.SPECIAL and result.face == 1)

## Keep fractional damage until target-specific bonuses have been applied.
func raw_attack_damage(result: MultiHitSkill) -> float:
	relic_skills.configure_split(self,result)
	if result.inherited_damage >= 0: return float(result.inherited_damage)*(0.5 if result.split_attack else 1.0)
	var critical: bool = result.critical or (result.pattern != "match_auto" and result.cast_source != "chip" and phase != "executing" and RelicEffects.has_critical(relics.items))
	var evaluated: MultiHitSkill = result.duplicate(true)
	evaluated.critical = critical
	return attack_base(result)*damage_multiplier(evaluated)*(0.5 if result.split_attack else 1.0)

## Combine base damage, multiplier and critical before target defenses.
func unmitigated_damage(result: MultiHitSkill) -> int:
	return floori(raw_attack_damage(result)+0.000001)

func _target_damage(result: MultiHitSkill, damage: int, target: int, burning: bool = false) -> int:
	if result.pattern.is_empty() and result.kind == Kind.NORMAL and is_enemy_alive(target): damage = mini(damage,damage_cap(result.kind,target))
	if CharacterSkills.doubles_on_burning(result) and (burning or enemy_status_count(target,Status.BURNING) > 0): damage = floori(raw_attack_damage(result)*2+0.000001)
	if enemy_status_count(target,Status.CORROSION) > 0: damage = floori(damage*1.5)
	return floori(damage*RelicEffects.Conditions.target_factor(self,target)+0.000001)

## Apply target caps and modifiers to the shared calculated hit.
func attack_damage(result: MultiHitSkill, target: int = -1) -> int:
	return _target_damage(result,unmitigated_damage(result),target)

## Sum one cast's damage pulses, preserving per-tick rounding and deterministic Burning bonuses.
func skill_damage_total(result: MultiHitSkill, target: int = -1, protection: float = 1.0) -> int:
	var damage: int = unmitigated_damage(result)
	var total: int = 0
	var ignites: bool = target >= 0 and not CharacterSkills.burning_after_cast(result) and CharacterSkills.burning_stacks(result,character_evolution_stage()) > 0
	for tick in range(result.damage_ticks):
		total += floori(_target_damage(result,damage,target,ignites and tick > 0)*protection)
	return total

## Held skills show the whole cast; real multi-use attacks retain their separate use count.
func damage_caption(result: MultiHitSkill, primary: int = -1) -> String:
	if not is_attack(result) or is_instant_kill(result): return ""
	var base: int = floori(attack_base(result))*result.damage_ticks
	var targets: Array = living() if hits_all(result) else [primary] if primary in attack_targets() else attack_targets()
	var guards: Array = taunting_enemies()
	if targets.is_empty(): return ""
	var low: int = skill_damage_total(result,targets[0],area_damage_factor(targets[0],guards) if hits_all(result) else 1.0)-base
	var high: int = low
	for target in targets:
		var modifier: int = skill_damage_total(result,target,area_damage_factor(target,guards) if hits_all(result) else 1.0)-base
		low = mini(low,modifier)
		high = maxi(high,modifier)
	var modifier: String = str(low) if low == high else "%d to %d" % [low,high]
	if low < 0 or low != high: modifier = "("+modifier+")"
	return "%d + %s (x%d)" % [base,modifier,skill_use_count(result)]

func player_target() -> int:
	if phase not in ["player", "executing"] or not is_attack(pending) or not outcome().is_empty(): return -1
	var candidates: Array = player_attack_targets()
	if pending.target not in candidates:
		if candidates.is_empty(): return -1
		pending.target = candidates[rng.randi_range(0, candidates.size() - 1)]
	return pending.target

func preview(result: MultiHitSkill, primary: int) -> Array:
	# Preview one impact, without drawing RNG or consuming resources.
	var hits: Array = []
	var candidates: Array = player_attack_targets()
	if not is_attack(result) or primary not in candidates: return hits
	var targets: Array = (living() if has_living_enemies() else candidates) if hits_all(result) else [primary]
	var guards: Array = taunting_enemies()
	for i in targets:
		var execute: bool = is_instant_kill(result)
		var damage: int = enemies[i].hp if execute else attack_damage(result, i)
		if not execute and hits_all(result): damage = floori(damage*area_damage_factor(i,guards))
		var hp_loss: int = 0 if enemies[i].shield > 0 and not execute and enemy_status_count(i, Status.CORROSION) == 0 else mini(enemies[i].hp, damage)
		hits.append({"target": i, "damage": damage, "ignore": execute, "hp_loss": hp_loss, "corpse_hit": not is_enemy_alive(i)})
	return hits

## Resolve healing, freeze or boon application and any refresh bonus.
func _apply_support(result: MultiHitSkill) -> Array:
	var events: Array = []
	if result.pattern == "cleanup":
		return [event(-1,heal(CharacterSkills.leftover_healing(result.sum,max_hp)),"heal","HEALING EMBERS")]
	if result.is_freeze():
		if is_city(): return [event(-2,0,"immune","IMMUNE")]
		var stacks: int = roundi(tarot_effects.skill_factor(result))
		for target in living():
			events.append_array(apply_enemy_status(target,Status.FROZEN,enemy_status_count(target,Status.FROZEN)+stacks))
		return events
	var id: int = result.face if result.kind == Kind.PAIR else Status.ASCENSION
	if result.kind == Kind.SPECIAL and result.face == 2:
		return [event(-1, heal(roundi(max_hp*result.relic_effect_scale)), "heal", "FULL HEAL")]
	if id in Status.ATTACK_BOONS and status_count(id) > 0:
		events.append_array(_boon_shockwave(result,10.0 if id == Status.MIGHT else 50.0))
	if result.kind == Kind.PAIR:
		var duration: int = maxi(1,roundi(result.spare*result.relic_effect_scale)) + (status_count(id) if id == Status.IMMUNITY else 0)
		statuses[id].apply(duration,tarot_effects.skill_factor(result))
		buff_ticks.erase(result.face)
		events.append(event(-1, 0, "buff", PAIR_NAMES[result.face - 1]))
	else:
		statuses[Status.ASCENSION].apply(maxi(1,roundi(3*result.relic_effect_scale)),tarot_effects.skill_factor(result))
		events.append(event(-1, 0, "buff", SPECIAL_NAMES[2]))
	return events

func _boon_shockwave(result: MultiHitSkill, base_damage: float) -> Array:
	var wave := Skill.new(Kind.SPECIAL,4,result.dice)
	wave.amplifier_locked = true
	var events: Array = [event(-1,int(base_damage),"boon_wave","")]
	events.append_array(AreaAttack.apply(self,base_damage,wave))
	return events

func _finish_player_action(_result: MultiHitSkill) -> void:
	if not relic_skills.queued.any(func(entry): return entry.skill.cast_source == "character_bonus"):
		BossRules.finish_attack_sequence(self)
	if relic_skills.start_next(self): return
	if not bonus_resume.is_empty():
		# A banked skill is a bonus: preserve the current roll and its turn clocks.
		var resume: Dictionary = bonus_resume
		bonus_resume = {}
		if outcome() == "wave_clear" and not resume.pending.is_empty():
			# Carry the unspent summoned skill into the next wave without casting it.
			saved_skill = resume.pending.duplicate(true)
			saved_skill.target = -1
		pending = resume.pending if outcome().is_empty() else Skill.new()
		phase = resume.phase if outcome().is_empty() else "finished"
		return
	if dice_turn.active and outcome().is_empty():
		pending = Skill.new()
		if dice_turn.locked.size() < DiceTurn.COUNT:
			phase = "roll"
			return
		if dice_turn.committed.size() == DiceTurn.COUNT:
			_grant_dice_bonus_turn()
			return
		dice_turn.active = false
	if tarot_effects.extra_rolls > 0 and outcome().is_empty():
		tarot_effects.extra_rolls -= 1
		pending = Skill.new()
		phase = "roll"
		return
	# Invulnerability remains active through every enemy action.
	buff_ticks[6] = true
	pending = Skill.new()
	phase = "enemy" if outcome().is_empty() else "finished"
	if phase == "enemy":
		player_end_events.append_array(relic_recovery.finish_player_turn(self))
		BossRules.finish_attack_sequence(self)
		if not outcome().is_empty(): phase = "finished"
	if phase == "finished": _end_buff_turn()

## Reward a fully used skill pool without advancing enemy intents or round timers.
func _grant_dice_bonus_turn() -> void:
	bonus_turn_count += 1
	_prepare_player_turn()

func _end_buff_turn() -> void:
	for face in buff_ticks: statuses[face].consume()
	buff_ticks.clear()

## Bank the rolled skill without casting its effect.
func save_pending_skill() -> bool:
	if not SAVED_SKILLS_ENABLED: return false
	if phase != "player" or pending.is_empty() or not saved_skill.is_empty() or not bonus_resume.is_empty() or not outcome().is_empty(): return false
	_commit_formed_skill()
	saved_skill = pending.duplicate(true)
	saved_skill.target = -1
	# Banking passes the turn; it does not apply or refresh the stored boon.
	_finish_player_action(Skill.new(Kind.NORMAL))
	return true

## Temporarily replace the pending roll with the saved bonus skill.
func begin_saved_cast() -> bool:
	if not SAVED_SKILLS_ENABLED: return false
	if saved_skill.is_empty() or not bonus_resume.is_empty() or phase not in ["roll", "player", "round_end"] or not outcome().is_empty(): return false
	bonus_resume = {"phase": phase, "pending": pending.duplicate(true)}
	pending = saved_skill.duplicate(true)
	saved_skill = Skill.new()
	phase = "player"
	return true

## Resolve one use of the current skill and emit its combat events.
func apply_player_step(primary: int = -1) -> Array:
	if phase not in ["player", "executing"] or pending.is_empty() or not outcome().is_empty(): return []
	if is_attack(pending):
		if primary < 0 or (phase == "executing" and (pending.keeps_selected_target() or (pending.hits_all() and primary not in player_attack_targets()))): primary = player_target()
		if primary not in player_attack_targets(): return []
		pending.target = primary
	if phase == "player":
		if not begin_player_cast(primary): return []
		if pending.split_attack: primary = pending.target
	var formation_events: Array = resolve_perfect_relic() if perfect_relic_ready else []
	if not outcome().is_empty(): return formation_events
	if is_attack(pending) and primary not in player_attack_targets():
		primary = player_target()
		pending.target = primary
	# Snapshot the displayed whole-use total before hit effects can change relics or buffs.
	if pending.is_attack(): pending.calculated_damage_total = unmitigated_damage(pending)*pending.damage_ticks
	var result: MultiHitSkill = pending.duplicate()
	var events: Array = formation_events
	if not is_attack(result): events.append_array(_apply_support(result))
	else:
		if pending.damage_ticks_spent == 0: lifesteal_used = 0
		for hit in preview(result, primary):
			if result.cast_source not in ["echo","chip"]: BossRules.skill_contact(self,hit.target)
			events.append_array(_apply_attack_hit(result,hit))
	pending.damage_ticks_spent += 1
	if pending.damage_ticks_spent >= pending.damage_ticks or not outcome().is_empty() or (pending.damage_ticks > 1 and not is_city() and not has_living_enemies()):
		if pending.damage_ticks_spent >= pending.damage_ticks and CharacterSkills.burning_after_cast(result):
			# Finish every target's final pulse before Burning can trigger any relic reactions.
			var burning: int = CharacterSkills.burning_stacks(result,character_evolution_stage())
			for target in living(): events.append_array(apply_enemy_status(target,Status.BURNING,burning,true,result.relic_effect_scale))
		if result.is_attack(): events.append_array(RelicEffects.attack_used(self))
		_complete_skill_use(result, events)
	return events

## Share defenses, death handling and on-hit relics between skills and roll attacks.
func _apply_attack_hit(result: MultiHitSkill, hit: Dictionary) -> Array:
	var events: Array = []
	if enemies[hit.target].get("phase_transition_pending",false): return events
	if hit.get("corpse_hit",false):
		var follow_through: Dictionary = damage_event(hit.target,0,hit.damage,"damage",hit.ignore)
		follow_through.corpse_hit = true
		return [follow_through]
	var previous_shield: int = enemies[hit.target].shield
	var previous_hp: int = enemies[hit.target].hp
	var shielded: bool = previous_shield > 0 and not hit.ignore and enemy_status_count(hit.target,Status.CORROSION) == 0
	RelicEffects.Conditions.target_factor(self,hit.target,true)
	var loss: int = hit_enemy(hit.target,hit.damage,hit.ignore)
	if previous_shield > 0 and not hit.ignore and enemy_status_count(hit.target,Status.CORROSION) == 0:
		var blocked: Dictionary = damage_event(hit.target,previous_shield-enemies[hit.target].shield,hit.damage,"shield_hit")
		blocked.text = "SHIELD BREAK" if enemies[hit.target].shield == 0 else "BLOCKED"
		events.append(blocked)
	else:
		events.append(damage_event(hit.target,loss,hit.damage,"damage",hit.ignore))
	# The preview snapshots pre-hit Burning; the new stacks can only affect later hits.
	var burning: int = CharacterSkills.burning_stacks(result,character_evolution_stage())
	if burning > 0 and not CharacterSkills.burning_after_cast(result):
		events.append_array(apply_enemy_status(hit.target,Status.BURNING,burning,true,result.relic_effect_scale))
	if loss > 0: events.append_array(_attack_relic_effects(hit.target,loss,result))
	events.append_array(RelicCombat.overflow(self,hit.target,hit.damage,previous_hp,shielded,hit.ignore))
	return events

## Select one random legal living target once, before its projectile launches.
func roll_attack_target() -> int:
	if roll_attacks.is_empty() or phase != "roll_attacks": return -1
	var skill: MultiHitSkill = roll_attacks[0].skill
	var targets: Array = attack_targets()
	if targets.is_empty(): return -1
	if skill.target not in targets: skill.target = targets[rng.randi_range(0,targets.size()-1)]
	return skill.target

## Resolve exactly one queued matching die, without spending dice or next-skill tarot.
func resolve_roll_attack_step() -> Array:
	if phase != "roll_attacks" or roll_attacks.is_empty(): return []
	var target: int = roll_attack_target()
	if target < 0 or not outcome().is_empty():
		roll_attacks.clear()
		phase = "finished" if not outcome().is_empty() else "roll"
		return []
	var skill: MultiHitSkill = roll_attacks[0].skill
	if skill.uses_spent == 0: lifesteal_used = 0
	RelicEffects.activate_damage_modifiers(self,skill)
	var events: Array = []
	# Six alike fires six area pulses; smaller matches retain random single targets.
	if skill.hits_all():
		for hit in preview(skill,target): events.append_array(_apply_attack_hit(skill,hit))
	else:
		events.append_array(_apply_attack_hit(skill,{"target":target,"damage":attack_damage(skill,target),"ignore":false}))
	events.append_array(RelicEffects.attack_used(self))
	skill.consume_use()
	skill.target = -1
	if skill.uses_left() == 0:
		roll_attacks.pop_front()
		for id in Status.ATTACK_BOONS: statuses[id].consume()
	if roll_attacks.is_empty(): BossRules.finish_attack_sequence(self)
	if not outcome().is_empty():
		roll_attacks.clear()
		phase = "finished"
		events.append_array(_complete_relic_turn())
	elif roll_attacks.is_empty(): phase = "roll"
	return events

func _complete_skill_use(result: MultiHitSkill, events: Array) -> void:
	if result.kind == Kind.ULTIMATE and result.pattern.is_empty(): events.append(event(-1, heal(roundi(12*tarot_effects.skill_factor(result))), "heal", "+12 HP"))
	pending.consume_use()
	# Damage pulses end with the last living foe; only true multi-hit skills follow through.
	if pending.damage_ticks > 1 and not is_city() and not has_living_enemies():
		pending.uses_spent = pending.use_count()
	if pending.random_target_per_use(): pending.target = -1
	if pending.uses_left() == 0 or not outcome().is_empty():
		# One charge covers the whole cast, including every multi-hit impact.
		# Saving, skipping and immediate item effects never pass through here.
		var bonus_follows: bool = outcome().is_empty() and (result.grants_bonus_fireballs or relic_skills.queued.any(func(entry): return entry.skill.cast_source == "character_bonus"))
		if result.is_attack() and result.cast_source not in ["echo","chip"] and not bonus_follows:
			for id in Status.ATTACK_BOONS: statuses[id].consume()
		if result.grants_bonus_fireballs:
			relic_skills.queue_character_fireballs(result)
			events.append(event(-1,0,"bonus_skill","Bonus Skill"))
		var bonuses_before: int = bonus_turn_count
		_finish_player_action(result)
		events.append_array(player_end_events)
		player_end_events.clear()
		if bonus_turn_count > bonuses_before: events.append(event(-1,bonus_turn_count,"bonus_turn","BONUS TURN"))
		if not outcome().is_empty(): events.append_array(_complete_relic_turn())

func apply_player(primary: int = -1) -> Array:
	var events: Array = []
	var bonus: bool = not bonus_resume.is_empty()
	while phase in ["player", "executing"] and not pending.is_empty() and outcome().is_empty():
		var uses_before: int = pending.uses_spent
		var ticks_before: int = pending.damage_ticks_spent
		var phase_before: String = phase
		var step: Array = apply_player_step(primary)
		# A depleted boss bar absorbs remaining impacts without emitting damage events.
		if step.is_empty() and phase == phase_before and pending.uses_spent == uses_before and pending.damage_ticks_spent == ticks_before: break
		events.append_array(step)
		if (bonus and bonus_resume.is_empty()) or phase == "player": break
		primary = -1
	return events

## Apply one hit to enemy defenses and health, returning actual damage dealt.
func hit_enemy(index: int, damage: int, ignore: bool = false) -> int:
	var e: Dictionary = enemies[index]
	if e.get("phase_transition_pending",false): return 0
	if e.hp <= 0: return 0
	var protector: int = -1 if e.get("direct_hp_loss",false) else BossRules.Fanatic.protector(self,index)
	if protector >= 0:
		var absorbed: int = hit_enemy(protector,damage,ignore)
		damage_redirected.emit(index,protector,damage,absorbed)
		return 0
	if not ignore and e.shield > 0 and enemy_status_count(index, Status.CORROSION) == 0:
		e.shield = maxi(0, e.shield-maxi(0, damage))
		if e.shield == 0 and not e.get("elite",false): apply_enemy_status(index,Status.IMMOBILIZED,1)
		return 0 # A single hit can break a shield, but never spill into HP.
	if ignore: e.shield = 0
	var actual: int = mini(e.hp, damage)
	e.hp -= actual
	if actual > 0 and e.hp <= 0 and not BossRules.handle_defeat(self,index):
		BossRules.Fanatic.master_died(self,index)
		if not e.get("summoned",false): RelicEffects.enemy_killed(self)
	return actual

## Exact HP costs bypass damage redirection while retaining ordinary phase and death rules.
func direct_enemy_hp_damage(index: int, amount: int) -> int:
	var enemy: Dictionary = enemies[index]
	var previous: bool = enemy.get("direct_hp_loss",false)
	enemy.direct_hp_loss = true
	var loss: int = hit_enemy(index,amount,true)
	if previous: enemy.direct_hp_loss = true
	else: enemy.erase("direct_hp_loss")
	return loss

## Shared recovery modifier used before caps and in read-only previews.
func modified_healing(amount: float) -> int:
	return RelicEffects.healing_amount(relics.items,amount*relic_recovery.healing_factor)

func heal(amount: int, modify: bool = true) -> int:
	if status_count(Status.DARKNESS) > 0: return 0
	if modify: amount = modified_healing(amount)
	var actual: int = maxi(0, mini(max_hp - hp, amount))
	hp += actual
	relic_recovery.overhealed(self,maxi(0,amount-actual))
	if actual > 0:
		for entry in RelicEffects.repeat_sources(relics.items,"blood_bag"): RelicEffects.Sequence.activate(self,entry)
	return actual

## Resolve the next impact of an enemy’s committed action.
func enemy_act_step(index: int) -> Array:
	if phase != "enemy" or not outcome().is_empty() or not is_enemy_alive(index) or enemies[index].acted: return []
	var events: Array = player_end_events.duplicate()
	player_end_events.clear()
	events.append_array(EnemyActions.step(self,index))
	if not outcome().is_empty(): phase = "finished"
	return events

func enemy_act(index: int) -> Array:
	# Model callers can resolve a whole action; the UI plays individual impacts.
	var events: Array = []
	while phase == "enemy" and outcome().is_empty() and is_enemy_alive(index) and not enemies[index].acted:
		events.append_array(enemy_act_step(index))
	return events

func _begin_turn_end() -> void:
	burn_ticks_remaining = status_count(Status.BURNING)
	turn_end_events = BossRules.Fanatic.end_turn(self)
	turn_end_events.append_array(_tick_enemy_statuses())
	phase = "turn_end"
	if burn_ticks_remaining == 0 and turn_end_events.is_empty():
		_finish_turn_end()
		turn_end_events.append_array(_complete_relic_turn())

func _finish_turn_end() -> void:
	statuses[Status.BURNING].decay()
	statuses[Status.DARKNESS].decay()
	statuses[Status.CORROSION].decay()
	_end_buff_turn()
	phase = "round_end" if outcome().is_empty() else "finished"

## Resolve turn-end effects incrementally after all enemies have acted.
func end_round_step() -> Array:
	# Presentation calls once per burn tick; headless simulation uses end_round().
	if phase == "enemy":
		if living().any(func(i): return not enemies[i].acted): return []
		_begin_turn_end()
	if phase != "turn_end":
		var completed: Array = turn_end_events.duplicate()
		turn_end_events.clear()
		return completed
	var events: Array = []
	events.append_array(turn_end_events)
	turn_end_events.clear()
	if burn_ticks_remaining > 0:
		burn_ticks_remaining -= 1
		if hp > 0: events.append_array(receive_damage(5, true))
	if burn_ticks_remaining == 0 or hp <= 0:
		burn_ticks_remaining = 0
		_finish_turn_end()
		events.append_array(_complete_relic_turn())
	return events

func relic_immune(id: int) -> bool:
	return RelicEffects.immune(relics.items,id)

func acquire_relic(id: String, replace_index: int = -1) -> bool:
	var old_max: int = max_hp
	if not relics.add(id, replace_index): return false
	refresh_relic_health(old_max)
	RelicEffects.acquired(self,id)
	return true

func move_relic(from: int, to: int) -> bool:
	if not relics.move(from,to): return false
	# Reordering passive health bonuses changes capacity, never grants free healing.
	hp = mini(hp,max_hp)
	return true

func grant_random_tarots(_count: int) -> Array:
	# Standalone battles have no run inventory; RunRules owns consumable rewards.
	return []

## Base battle fixtures have no card inventory; run rules provide the real grant.
func grant_tarot(_id: String, _enemy_index: int = -1, _projection: bool = false) -> Dictionary:
	return {}

func refresh_relic_health(old_max: int) -> void:
	for status in Status.HARMFUL:
		if relic_immune(status): statuses[status].count = 0
	hp = clampi(hp + maxi(0, max_hp - old_max), 0, max_hp)

## Resolve incoming damage through player statuses, defenses and survival relics.
func receive_damage(amount: int, burning: bool = false, attacker: int = -1) -> Array:
	if not burning and status_count(Status.HIDDEN) > 0: return [event(-1,0,"relic","UNTARGETABLE")]
	var corroded: bool = status_count(Status.CORROSION) > 0
	if status_count(Status.IMMUNITY) > 0 and not corroded: return [event(-1,0,"immune","INVINCIBLE")] + (RelicEffects.retaliation(self,attacker) if not burning else [])
	var incoming: float = maxf(0, amount) * (1.5 if corroded else 1.0)
	var defense: Dictionary = RelicEffects.incoming(relics.items,incoming,corroded,burning)
	for id in defense.activated: relic_activated.emit(id)
	if defense.blocked: return [event(-1,0,"relic","SHIELD BLOCK")] + RelicEffects.retaliation(self,attacker)
	incoming = defense.amount
	var loss: int = roundi(incoming)
	if not corroded and not burning:
		var blocked: int = mini(shield, loss)
		shield -= blocked
		loss -= blocked
	var hit_damage: int = loss
	loss = mini(hp, loss)
	hp -= loss
	var events: Array = [damage_event(-1,loss,hit_damage,"burn" if burning else "damage")]
	if hp <= 0: events.append_array(RelicEffects.prevent_death(self))
	if not burning: events.append_array(RelicEffects.retaliation(self,attacker))
	return events

func _complete_relic_turn() -> Array:
	if relic_turn_closed: return []
	relic_turn_closed = true
	tarot_effects.end_round()
	statuses[Status.HIDDEN].consume()
	return RelicEffects.turn_finished(self)

static func status_label(id: int, amount: int) -> String:
	return "%s +%d" % [{Status.FROZEN:"FROZEN",Status.BURNING:"BURN",Status.STUNNED:"STUN",Status.DARKNESS:"DARKNESS",Status.CORROSION:"CORROSION",Status.PLAGUE:"PLAGUE",Status.IMMOBILIZED:"IMMOBILIZED"}.get(id,"STATUS"), amount]

func enemy_cannot_act(index: int) -> bool:
	return Status.ENEMY_ACTION_LOCKS.any(func(id): return enemy_status_count(index,id) > 0)

func enemy_status_count(index: int, id: int) -> int:
	if index < 0 or index >= enemies.size(): return 0
	var effects: Dictionary = enemies[index].get("statuses", {})
	return effects[id].count if effects.has(id) else 0

## Apply eligible enemy afflictions and interrupt blocked charging actions.
func apply_enemy_status(index: int, id: int, amount: int, modify_stacks: bool = true, effect_scale: float = 1.0) -> Array:
	if not is_enemy_alive(index) or id not in Status.ENEMY_HARMFUL: return []
	if enemies[index].get("phase_transition_pending",false): return []
	if modify_stacks: amount += RelicEffects.status_bonus(self,id)
	amount = roundi(amount*effect_scale)
	var enemy: Dictionary = enemies[index]
	if not enemy.has("statuses"): enemy.statuses = {}
	if not enemy.statuses.has(id): enemy.statuses[id] = Status.new(id)
	var before: int = enemy.statuses[id].count
	enemy.statuses[id].apply(amount)
	if id in Status.ENEMY_ACTION_LOCKS and amount > 0: EnemyActions.interrupt(enemy,id)
	var added: int = enemy.statuses[id].count - before
	if added <= 0: return RelicEffects.status_applied(self,index,id) if amount > 0 else []
	if id == Status.PLAGUE:
		if not enemy.has("healthy_max_hp"): enemy.healthy_max_hp = enemy.max_hp
		enemy.max_hp = maxi(1, enemy.healthy_max_hp - enemy.statuses[id].count * 10)
		enemy.hp = mini(enemy.hp, enemy.max_hp)
	var effect: Dictionary = event(index, added, "status", status_label(id, added))
	effect.status = id
	return [effect] + RelicEffects.status_applied(self,index,id)

func _attack_relic_effects(target: int, damage: int, skill: MultiHitSkill) -> Array:
	return RelicEffects.after_hit(self,target,damage,skill)

## Resolve enemy burning, plague spread and decaying status stacks.
func _tick_enemy_statuses() -> Array:
	var events: Array = []
	# Snapshot infections so a newly infected ally cannot spread again this turn.
	var infected: Array = living().filter(func(i): return enemy_status_count(i,Status.PLAGUE) > 0)
	for i in living():
		var burning: int = enemy_status_count(i,Status.BURNING)
		if burning > 0:
			var burn_factor: float = 1.0
			for entry in RelicEffects.repeat_sources(relics.items,"vodka"):
				burn_factor *= 2.0
				RelicEffects.Sequence.activate(self,entry)
			var amount: int = roundi(burning * 5 * burn_factor * (1.5 if enemy_status_count(i,Status.CORROSION) > 0 else 1.0)*RelicEffects.Conditions.target_factor(self,i,true))
			var shield_before: int = enemies[i].shield
			var old_phase: int = enemies[i].get("boss_phase",0)
			var loss: int = hit_enemy(i,amount,true)
			if enemies[i].get("boss_phase",0) == old_phase: enemies[i].shield = shield_before
			events.append(damage_event(i,loss,amount,"burn"))
		for id in [Status.BURNING,Status.DARKNESS,Status.CORROSION]:
			if enemy_status_count(i,id) > 0: enemies[i].statuses[id].decay()
	for i in infected:
		if not is_enemy_alive(i): continue
		events.append_array(apply_enemy_status(i,Status.PLAGUE,1,false))
		var allies: Array = living().filter(func(ally): return ally != i and enemy_status_count(ally,Status.PLAGUE) == 0)
		if not allies.is_empty(): events.append_array(apply_enemy_status(allies[rng.randi_range(0,allies.size()-1)],Status.PLAGUE,1,false))
	return events

func roll_relic_animation_speed() -> float:
	return RelicEffects.Sequence.animation_speed(roll_relic_actions[0].activation) if not roll_relic_actions.is_empty() else 1.0

func resolve_roll_relic_step() -> Array:
	if roll_relic_actions.is_empty():
		perfect_relic_ready = false
		return []
	if not outcome().is_empty():
		roll_relic_actions.clear()
		perfect_relic_ready = false
		return []
	var action: Dictionary = roll_relic_actions.pop_front()
	RelicEffects.Sequence.activate(self,action.activation)
	var options: Dictionary = {}
	if RelicEffects.Sets.collection_complete(relics.items,"pets"):
		if action.id == "pet_ghost": options.multiplier_only = true
		if action.id == "pet_dragon": options.burning = 1
	var events: Array = RelicEffects.Attack.apply(self,action.id,action.amount,action.fixed,action.area,-1,options)
	perfect_relic_ready = not roll_relic_actions.is_empty()
	if not perfect_relic_ready and roll_attacks.is_empty() and phase != "executing": BossRules.finish_attack_sequence(self)
	if not outcome().is_empty():
		roll_relic_actions.clear()
		perfect_relic_ready = false
		if not is_city() and saved_skill.is_empty(): saved_skill = pending.duplicate()
		pending = Skill.new()
		phase = "finished"
		events.append_array(_complete_relic_turn())
	return events

func resolve_perfect_relic() -> Array:
	# Compatibility for model simulations; presentation resolves one proc at a time.
	if perfect_relic_ready and roll_relic_actions.is_empty(): roll_relic_actions = RelicEffects.roll_actions(self,true)
	var events: Array = []
	while not roll_relic_actions.is_empty(): events.append_array(resolve_roll_relic_step())
	return events

func _six_probability(rates: Dictionary) -> float:
	return dice_odds.six_probability(rates,triple_weights,pair_weights,face_weights)

func end_round() -> Array:
	var events: Array = []
	while phase in ["enemy", "turn_end"]:
		if phase == "enemy" and living().any(func(i): return not enemies[i].acted): break
		events.append_array(end_round_step())
	return events

static func event(target: int, amount: int, type: String, text: String) -> Dictionary:
	return {"target": target, "amount": amount, "type": type, "text": text}

## Keep actual HP loss separate from the full damage displayed on impact.
static func damage_event(target: int, actual_loss: int, hit_damage: int, type: String = "damage", instant_kill: bool = false) -> Dictionary:
	# Gameplay consumers retain actual HP/shield loss; presentation shows the hit
	# before remaining-health clamping. An execution has impact FX but no number.
	var result: Dictionary = event(target,actual_loss,type,"" if instant_kill else "-%d" % hit_damage)
	result.display_amount = hit_damage
	result.instant_kill = instant_kill
	return result

## Start roll-generated item skills only after ordinary roll attacks and procs finish.
func start_roll_chip_casts() -> bool:
	if roll_chip_casts.is_empty() or not roll_attacks.is_empty() or perfect_relic_ready or phase != "roll": return false
	relic_skills.queued.append_array(roll_chip_casts)
	roll_chip_casts.clear()
	relic_skills.resume_phase = "roll"
	return relic_skills.start_next(self)
