extends SceneTree
## Boss charge preservation and phase handoffs use real incremental combat resolution.
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(wave: int):
	var m = Run.new(20261024)
	m.load_debug_wave(wave)
	m.base_max_hp = 10000; m.hp = 10000
	return m

## Resolve exactly one selected boss action, without hiding its post-action state.
func act(m) -> Array:
	var e: Dictionary = m.enemies[0]
	e.acted = false; e.action_hit = 0; e.intent = m.choose_intent(0)
	m.phase = "enemy"
	return m.enemy_act(0)

## The last charge remains visible, but cannot finish the turn before its attack.
func immediate_release(wave: int, second_phase: bool) -> void:
	var m = fresh(wave)
	if second_phase: m.hit_enemy(0,99999,true)
	var e: Dictionary = m.enemies[0]
	var data: Dictionary = m.EnemyCatalog.ITEMS[e.role]
	e.charging = true; e.charge = data.charge_turns-1; e.break_marks = 1
	e.acted = false; e.intent = m.choose_intent(0); m.phase = "enemy"
	var before: int = m.hp
	var events: Array = m.enemy_act_step(0)
	check(events.size() == 1 and events[0].type == "charge" and e.charge == data.charge_turns,"Final charge fills before the heavy impact")
	check(not e.acted and e.intent.skill == data.release and m.hp == before,"Same action queues the heavy without prematurely dealing damage")
	m.end_round_step()
	check(m.phase == "enemy" and e.charge == data.charge_turns,"Turn cannot end between the final charge and its heavy")
	events = m.enemy_act_step(0)
	check(events.filter(func(x): return x.target == -1 and x.type == "damage").size() == 1 and m.hp < before,"One heavy impact immediately follows the last charge")
	check(e.acted and not e.charging and e.charge == 0 and e.break_marks == data.break_casts,"Release completes the action and resets marks")
	before = m.hp
	check(m.enemy_act_step(0).is_empty() and m.hp == before,"A completed release cannot attack twice")

## Death cannot consume a card or skip either boss phase, even through Prophecy.
func death_immunity(wave: int, second_phase: bool) -> void:
	var m = fresh(wave)
	if second_phase: m.hit_enemy(0,99999,true)
	m.begin_round()
	var e: Dictionary = m.enemies[0]
	var before: Dictionary = e.duplicate(true)
	var gems: int = m.blood_gems
	var card: Dictionary = m.grant_tarot("death")
	check(0 not in m.tarot_effects.targets(m,"death"),"Boss is excluded from Death target indicators")
	check(m.tarot_effects.prepare(m,card.instance_id,{"target":0}).get("error","") == "Death cannot affect bosses.","Death preparation rejects bosses")
	check(m.tarot_effects.cast(m,card.instance_id,{"target":0}).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"Invalid boss cast leaves Death in inventory")
	check(m.tarot_effects._execute(m,0).is_empty(),"Execution helper also protects bosses")
	m.tarot_effects.pending_repeat = {"id":"death","instance_id":-1}
	check(m.tarot_effects.cast(m,-1,{"target":0}).has("error"),"Ancient Prophecy cannot bypass boss immunity")
	check(e.hp == before.hp and e.shield == before.shield and e.boss_phase == before.boss_phase and m.blood_gems == gems,"Rejected Death has no damage, phase or reward side effects")
	m.tarot_effects.dismiss_repeat()
	if wave == 10 and second_phase:
		check(m.tarot_effects.targets(m,"death") == [1,2],"Death can still target the Commander's Paladin reinforcements")
		var result: Dictionary = m.tarot_effects.cast(m,card.instance_id,{"target":1})
		check(not result.has("error") and m.enemies[1].hp == 0 and e.hp == before.hp,"Death executes a guard without harming the boss")

## Exercise application, skipped action, thaw and a release that was already ready.
func freeze_charge(wave: int, second_phase: bool) -> void:
	var m = fresh(wave)
	if second_phase: m.hit_enemy(0,99999,true)
	var e: Dictionary = m.enemies[0]
	var last_charge: int = m.EnemyCatalog.ITEMS[e.role].charge_turns-1
	e.charging = true; e.charge = last_charge; e.break_marks = 2
	m.apply_enemy_status(0,m.Status.FROZEN,1,false)
	check(e.charging and e.charge == last_charge and e.break_marks == 2,"Freeze application keeps charge and partially broken marks")
	var before: int = m.hp
	var events: Array = act(m)
	check(events.any(func(x): return x.type == "skip" and x.text == "FROZEN") and m.hp == before,"Frozen boss skips its action")
	check(e.charging and e.charge == last_charge and e.break_marks == 2,"Frozen skip does not reset charge or marks")
	act(m)
	check(not e.charging and e.charge == 0 and m.hp < before,"Thawed boss fills its last charge and attacks in that same action")
	e.charging = true; e.charge = m.EnemyCatalog.ITEMS[e.role].charge_turns
	var release: String = m.choose_intent(0).skill
	m.apply_enemy_status(0,m.Status.FROZEN,1,false); act(m)
	check(e.charging and m.choose_intent(0).skill == release,"Freeze delays an already prepared heavy without replacing it")
	act(m)
	check(not e.charging and e.charge == 0 and m.hp < before,"Thawed boss releases its heavy normally")

## Extra uses and passive Fireballs cannot reach the next health bar in the same cast.
func skill_sequence(wave: int, faces: Array, uses: int, bonus: bool) -> void:
	var m = fresh(wave)
	var e: Dictionary = m.enemies[0]
	e.hp = 1
	if bonus: m.character_passive.charge = 2
	m.pending = Patterns.classify(faces); m.pending.base_uses = uses; m.phase = "player"
	var gems: int = m.blood_gems
	m.apply_player_step(0)
	check(e.boss_phase == 1 and e.hp == 0 and e.get("phase_transition_pending",false),"Lethal opening impact queues the new bar")
	check(m.is_enemy_alive(0) and m.outcome().is_empty() and m.blood_gems == gems,"Pending phase is not a death or victory")
	check(m.enemies.size() == 1 and m.status_count(m.Status.DARKNESS) == 0,"Phase perks wait for the entire cast")
	check(m.hit_enemy(0,99999,true) == 0 and m.apply_enemy_status(0,m.Status.PLAGUE,3).is_empty(),"Pending phase ignores further direct damage and statuses")
	m.apply_player()
	while m.phase == "player" and m.pending.cast_source != "manual": m.apply_player()
	check(e.boss_phase == 2 and e.hp == e.max_hp and not e.get("phase_transition_pending",false),"Whole cast finishes before a fresh full second bar")
	check(m.phase != "executing" and m.blood_gems == gems,"Zero-damage remaining impacts cannot stall or reward the cast")
	if wave == 10:
		check(m.enemies.size() == 3 and m.enemies.slice(1).all(func(x): return x.hp == x.max_hp and x.acted),"Reinforcements enter unharmed after all bonus attacks")
	else:
		check(m.status_count(m.Status.DARKNESS) == 2 and m.enemy_status_count(0,m.Status.DARKNESS) == 2,"Shared curse starts only after the cast")
	var new_hp: int = e.hp
	m.hit_enemy(0,7,true)
	check(e.hp == new_hp-7,"Later actions can damage the new phase")

## Every group from one roll resolves before a depleted boss switches phase.
func roll_sequence(wave: int, faces: Array, with_relic: bool = false) -> void:
	var m = fresh(wave)
	var e: Dictionary = m.enemies[0]
	e.hp = 1
	if with_relic: m.acquire_relic("magic_slingshot")
	m.begin_round(); m.roll_pool(false,faces)
	var gems: int = m.blood_gems
	if with_relic: m.resolve_perfect_relic()
	else: m.resolve_roll_attack_step()
	check(e.boss_phase == 1 and e.hp == 0 and m.is_enemy_alive(0),"Opening automatic hit holds the first phase")
	var guard := 0
	while not m.roll_attacks.is_empty() and guard < 30:
		guard += 1
		m.resolve_roll_attack_step()
	check(guard < 30 and m.phase == "roll" and m.outcome().is_empty(),"Automatic queue returns control without finishing the wave")
	check(e.boss_phase == 2 and e.hp == e.max_hp and m.blood_gems == gems,"Neither six-alike pulses nor another match group damages phase two")
	check(m.dice_turn.rolls_left == 2 and m.dice_turn.unused().size() == 6,"Phase handoff preserves the current dice and rerolls")

func _initialize() -> void:
	for wave in [10,20]:
		for second in [false,true]:
			immediate_release(wave,second)
			death_immunity(wave,second)
			freeze_charge(wave,second)
		skill_sequence(wave,[1,2,3,4,5],1,false)
		skill_sequence(wave,[1,2,3,4,5,6],1,false)
		skill_sequence(wave,[3,4,5],3,true)
		roll_sequence(wave,[6,6,6,6,6,6])
		roll_sequence(wave,[1,1,1,2,2,2])
		roll_sequence(wave,[1,1,1,2,3,4],true)
	var m = fresh(20)
	m.hit_enemy(0,99999,true)
	var e: Dictionary = m.enemies[0]
	e.forced_charge = true
	m.apply_enemy_status(0,m.Status.FROZEN,1,false); act(m)
	check(e.forced_charge and m.choose_intent(0).skill == "charge","Freeze retains the charge commitment after Corrosive Heal")
	# Tower uses the same boss/death path even though its damage ignores defenses.
	m = fresh(20); m.begin_round(); m.enemies[0].hp = 20
	var gems: int = m.blood_gems
	var card: Dictionary = m.grant_tarot("tower")
	m.tarot_effects.cast(m,card.instance_id,{})
	check(m.enemies[0].boss_phase == 2 and m.blood_gems == gems and m.outcome().is_empty(),"Tower cannot bypass a boss's second health bar")
	print("Boss sequences: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
