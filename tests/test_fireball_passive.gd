extends SceneTree
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	var m = Run.new(843)
	m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	m.begin_round()
	m.roll_pool(false,[1,2,3,4,5,6])
	m.dice_turn.selected = [0,1,2]
	m.form_selected_skill()
	m.cancel_formed_skill()
	check(m.character_passive.charge == 0,"Cancelling never charges")
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	check(m.begin_player_cast(0),"First Fireball begins")
	check(m.character_passive.charge == 1 and m.pending.use_count() == 1,"First cast fills one circle")
	m.apply_player_step(0)
	m.dice_turn.selected = [3,4,5]; m.form_selected_skill()
	check(m.begin_player_cast(0),"Second Fireball begins")
	check(m.character_passive.displayed_charge(m.pending) == 2 and m.pending.use_count() == 1,"Second cast fills two circles without triggering")
	m.apply_player_step(0)
	m.roll_pool(false,[1,2,3,4,5,6])
	m.dice_turn.selected = [0,1,2]; m.form_selected_skill()
	check(m.begin_player_cast(0),"Third Fireball begins")
	check(m.character_passive.displayed_charge(m.pending) == 3 and m.pending.use_count() == 1 and not m.pending.has_use_orbs(),"Third cast stays single-use while awarding two separate Fireballs")
	var rolled: Array = m.dice_turn.values.duplicate()
	var trigger_events: Array = m.apply_player_step(0)
	check(trigger_events.filter(func(e): return e.type == "bonus_skill").size() == 1,"Counter consumption emits one feedback event")
	check(m.pending.random_target_per_use() and m.character_passive.displayed_charge(m.pending) == 0,"Echoes randomly target after the original impact and empty the meter")
	var targets: Array = []
	for i in range(2):
		check(m.pending.cast_source == "character_bonus" and m.pending.use_count() == 1 and not m.pending.has_use_orbs(),"Every bonus is a separate single-use skill without orbs")
		var target: int = m.player_target()
		check(target in m.attack_targets(),"Echo chooses a legal living target")
		var events: Array = m.apply_player_step(target)
		check(events.any(func(e): return e.type == "damage"),"Each echo hits")
		check(not events.any(func(e): return e.type == "bonus_skill"),"Echoes do not repeat the consumption flash")
		targets.append(target)
	check(m.character_passive.charge == 0 and m.phase != "executing","Echoes cannot recursively fill the counter")
	check(m.dice_turn.values == rolled or m.bonus_turn_count == 1,"Echoes never reroll dice")
	var passive = m.FlamelingsPassive.new()
	var slash = Patterns.classify([1,2,3,4]); slash.begin_cast(); passive.on_cast(slash)
	check(passive.charge == 0 and slash.use_count() == 1,"Other straights do not charge")
	for i in range(3):
		var fire = Patterns.classify([1,2,3]); fire.begin_cast({"test":3}); passive.on_cast(fire)
		check(fire.use_count() == 3 and fire.grants_bonus_fireballs == (i == 2),"Multi-hit cast charges once without extending its use budget")
	m.character_passive.charge = 1
	m.reset_run()
	check(m.character_passive.charge == 0,"New runs clear the passive")
	inherited_damage_checks()
	modifier_checks()
	evolutions()
	print("Fireball passive: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

## Evolved abilities change actual hits and captions without recursively charging their echoes.
func evolutions() -> void:
	for level in [4,5,9,10,15]:
		for length in [3,4,5,6]:
			var m = Run.new(954)
			m.gain_souls(5*level*(level-1))
			m.enemies = [m.make_enemy(0),m.make_enemy(1)]
			for e in m.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
			m.pending = Patterns.classify(range(1,length+1)); m.phase = "player"
			var skill: MultiHitSkill = m.pending
			var expected: int = (3 if level >= 5 else 2) if length in [3,5] else 2 if length == 4 and level >= 5 else 0
			check(m.CharacterSkills.burning_stacks(skill,m.character_evolution_stage()) == expected,"Evolution upgrades only the intended fire skills")
			var unburned_damage: int = m.attack_damage(skill,0)
			m.character_passive.charge = 2
			m.begin_player_cast(0)
			check(skill.use_count() == 1 and skill.grants_bonus_fireballs == (length == 3 or level >= 10),"Final evolution accepts every straight; earlier forms accept Fireball")
			check(m.character_passive.charge_limit(m.character_evolution_stage()) == 3,"Every form retains three counters")
			var events: Array = m.apply_player_step(0)
			if length < 5:
				check(m.enemy_status_count(0,m.Status.BURNING) == expected,"Real hits apply the evolved stack count")
				check(events.filter(func(e): return e.type == "damage")[0].display_amount == unburned_damage,"New Burning applies after damage and cannot double the initial hit")
				var caption: Dictionary = m.CharacterSkills.caption(Patterns.classify(range(1,length+1)),m.character_evolution_stage())
				if expected > 0: check(caption.description.contains("%d Burning" % expected),"Skill descriptions show current Burning potency")
			if length == 3 or level >= 10:
				while not m.pending.is_empty() and m.pending.cast_source == "manual": m.apply_player_step(m.player_target())
				check(m.pending.dice == [3,4,5] and m.pending.damage_ticks == 1 and not m.pending.hits_all(),"Every bonus is a fixed single-target 3-4-5 Fireball")
				for i in range(2): m.apply_player_step(m.player_target())
				check(m.character_passive.charge == 0 and m.phase != "executing","Evolved bonus Fireballs do not charge themselves")

## Separate bonus casts retain the existing amplifier without spending fresh charges.
func modifier_checks() -> void:
	var m = Run.new(991)
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000
	m.acquire_relic("magic_sword"); m.relics.items[0].charges = 2
	m.acquire_relic("echo_bell")
	m.tarot_effects.strength = 2
	m.statuses[m.Status.MIGHT].apply(2)
	m.character_passive.charge = 2
	m.pending = Patterns.classify([1,2,3]); m.pending.base_uses = 3; m.phase = "player"
	m.apply_player(0)
	check(m.phase == "player" and m.pending.cast_source == "character_bonus","Original multi-use cast ends before bonus casts start")
	for i in range(2):
		check(m.pending.use_count() == 1 and m.pending.effect_multiplier == 3 and m.pending.critical,"Each bonus inherits Strength and critical but remains single-use")
		m.apply_player()
	check(m.relics.items[0].charges == 1 and m.tarot_effects.strength == 0,"Bonus casts cannot consume another stored critical or Strength")
	check(m.status_count(m.Status.MIGHT) == 1 and m.relics.items[1].casts == 1,"Sequence consumes one attack boon and only its manual skill counts toward Echo Bell")
	check(m.relic_skills.queued.is_empty() and m.character_passive.charge == 0,"Sequence leaves no queued skills or recursive charges")

# Bonus casts retain the whole displayed total even if modifiers subsequently change.
func inherited_damage_checks() -> void:
	for faces in [[1,2,3],[1,2,3,4,5],[1,2,3,4,5,6]]:
		var m = Run.new(843)
		m.character_level = 10
		m.enemies = [m.make_enemy(0)]
		m.enemies[0].hp = 1000000; m.enemies[0].max_hp = 1000000; m.enemies[0].shield = 0
		m.pending = Patterns.classify(faces)
		m.phase = "player"
		m.character_passive.charge = 2
		m.begin_player_cast(0)
		var expected: int = m.unmitigated_damage(m.pending)*m.pending.damage_ticks
		m.apply_player(0)
		check(m.pending.cast_source == "character_bonus", "Trigger queues bonus Fireball")
		check(m.pending.inherited_damage == expected, "Bonus inherits all damage pulses")
		var copy = m.pending.duplicate()
		check(copy.same_as(m.pending) and copy.inherited_damage == expected, "Damage snapshot survives copying")
		m.reward_base_damage += 1000
		check(m.unmitigated_damage(copy) == expected, "Bonus does not recalculate changed stats")
		m.apply_player(0)
		check(m.pending.inherited_damage == expected, "Second bonus keeps same snapshot")
