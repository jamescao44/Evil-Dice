extends "res://tests/test_playtest_session.gd"
## Check telemetry values, intermediate HP checkpoints and seeded non-interference.
const Metrics = preload("res://scripts/testing/playtest_metrics.gd")

func measurement() -> void:
	var s = make_session(221)
	var m = s.model
	var row: Dictionary = Metrics.measure(m)
	check(row.hp == 1000 and row.max_hp == 1000 and row.fireball_per_use == 21,"Initial reference uses real 3-4-5 Fireball and fixed player health")
	m.acquire_relic("bracelet")
	m.acquire_relic("magic_sword")
	m.acquire_relic("split_arrow")
	m.tarot_effects.strength = 2
	m.perfect_combo = 3
	var before := signature(m)
	var pending = m.pending.duplicate()
	var reference = Patterns.classify([3,4,5])
	var expected: int = m.unmitigated_damage(reference)*reference.damage_ticks
	for i in range(15):
		row = Metrics.measure(m)
		check(row.fireball_per_use == expected and row.fireball_uses == m.skill_use_count(reference),"Reference shares live relic/buff/split-use formula")
	check(signature(m) == before and m.pending.base_uses == pending.base_uses and m.tarot_effects.strength == 2,"Recording leaves RNG, relics, pending skill and Strength untouched")
	var old: int = s.metrics.samples.size()
	s.snapshot(); s.snapshot(); s.command({"action":"state"})
	check(s.metrics.samples.size() == old,"Repeated inspection does not inflate the timeline")
	var copied: Dictionary = s.metrics.report()
	copied.samples.clear()
	check(not s.metrics.samples.is_empty(),"Exported reports cannot mutate recorded samples")

func health_boundaries() -> void:
	var s = make_session(54)
	var m = s.model
	m.enemies = [m.EnemyCatalog.make(m.EnemyCatalog.Role.ARCHER,1),m.EnemyCatalog.make(m.EnemyCatalog.Role.MAGE,1)]
	durable(m)
	m.roll_pool(false,[1,1,3,3,6,6]); s._settle()
	for enemy in m.enemies:
		enemy.intent = {"type":"attack","amount":100,"hits":1,"target":-1}
		enemy.acted = false
	m.hp = 1000
	var result: Dictionary = s.command({"action":"end"})
	var healths: Array = result.metrics.map(func(row): return row.hp)
	check(result.ok and 900 in healths and 800 in healths,"Both enemy actions have health checkpoints rather than only the final 800 HP")
	check(result.metrics.front().reason == "before_end" and result.metrics.back().reason == "after_end","Command metadata brackets the full resolution")
	check(result.metrics.all(func(row): return row.command == s.metrics.command_index),"All nested resolution samples belong to their command")
	var start: int = s.metrics.samples.size()
	m.gain_souls(m.level_cost())
	check(s.metrics.samples.size() > start and s.metrics.samples.back().reason == "level_up" and s.metrics.samples.back().hp == m.max_hp,"Level-up full heal is recorded immediately")
	var now: Dictionary = Metrics.measure(m)
	check(now.max_hp == 1000 and now.fireball_per_use == 23,"Level-up changes Fireball while maximum HP stays flat")

## Actual transactions cover fusion, sale, duplicate slots, stacking, replacement and failed actions.
func inventory_tracking() -> void:
	var s = make_session(522)
	var m = s.model
	m.shop.active = true; m.shop.debug_unlimited = true
	m.shop.offers = []
	for id in ["hamburger","oreo_sundae","codex_page","codex_page","bracelet","bracelet","runestone"]:
		m.shop.offers.append({"kind":"relic","id":id,"price":0,"sold":false})
	check(s.command({"action":"buy","slot":1}).ok,"Acquire ingredient through a real shop command")
	var gained: Dictionary = s.metrics.inventory_events.back()
	check(gained.source == "buy" and gained.gained[0].id == "hamburger","Acquisition records name and source")
	s.command({"action":"buy","slot":2})
	var fusion: Dictionary = s.metrics.inventory_events.back()
	check(fusion.gained.size() == 1 and fusion.gained[0].id == "oreo_sundae" and fusion.added[0].id == "budget_meal","Fusion retains the incoming ingredient and resulting meal")
	check(fusion.sold.is_empty() and fusion.replaced.is_empty() and fusion.lost.is_empty(),"Fusion consumption is not a sale or lost ingredient")
	s.command({"action":"buy","slot":3}); s.command({"action":"buy","slot":4})
	check(s.metrics.inventory_events.back().gained[0].id == "codex_page" and s.metrics.inventory_events.back().gained[0].count == 1,"Codex acquisitions count the added page rather than the whole stack")
	s.command({"action":"buy","slot":5}); s.command({"action":"buy","slot":6})
	check(s.metrics.inventory_events.back().gained[0].id == "bracelet" and s.metrics.inventory_events.back().gained[0].count == 1,"A duplicate shop relic remains a new acquisition")
	s.command({"action":"reorder","from":4,"to":3})
	# The identical Bracelets exchange places without changing the observable inventory.
	var count: int = s.metrics.inventory_events.size()
	m.relics.items[2].charges = 7
	s.metrics.capture(m,"counter_update")
	check(s.metrics.inventory_events.size() == count,"Activation counters and identical-item reorder cannot fabricate acquisitions")
	s.command({"action":"buy","slot":7,"replace":1})
	var replacement: Dictionary = s.metrics.inventory_events.back()
	check(replacement.replaced.size() == 1 and replacement.replaced[0].id == "budget_meal" and replacement.sold.is_empty(),"Replacing a meal with non-default ingredients is labelled as replacement")
	s.command({"action":"sell","slot":2})
	var sale: Dictionary = s.metrics.inventory_events.back()
	check(sale.sold.size() == 1 and sale.sold[0].id == "codex_page" and sale.sold[0].count == 2,"Selling a stacked relic records its identity and complete quantity")
	count = s.metrics.inventory_events.size()
	check(not s.command({"action":"buy","slot":999}).ok and s.metrics.inventory_events.size() == count,"Rejected transactions never produce inventory events")
	m.shop.active = false
	var card: Dictionary = m.tarots.add("fool")
	check(s.command({"action":"tarot","instance":card.instance_id}).ok,"Use Fool through the regular CLI")
	var reroll: Dictionary = s.metrics.inventory_events.back()
	check(reroll.card == "fool" and reroll.sold.is_empty() and reroll.replaced.is_empty(),"Fool rerolls are distinguished from selling or replacement")
	check(not s.metrics.commands.back().events.is_empty(),"Command events remain available for explaining defensive/card advantages")
	check(s.metrics.context.is_empty(),"Completed commands cannot label later setup changes as their own transaction")

## Distinguish skills, generated casts, repeated uses and matching groups from animation hits.
func wave_actions() -> void:
	for length in range(3,7):
		var s = make_session(743)
		durable(s.model)
		s.model.roll_pool(false,[1,2,3,4,5,6]); s._settle()
		s.command({"action":"form","dice":range(1,length+1)})
		check(s.command({"action":"cast"}).ok,"Each straight can be measured")
		var row: Dictionary = s.metrics.wave_report()[0]
		var name: String = Session.Character.NAMES[length-3]
		check(row.skills.size() == 1 and row.skills[name].casts == 1 and row.skills[name].uses == 1,"Damage ticks count as one "+name+" cast/use")
		check(row.turns_spent == 2,"The next begun turn is recorded once in a still-active wave")
	var bonus = make_session(8)
	durable(bonus.model); bonus.model.roll_pool(false,[1,2,3,4,5,6]); bonus._settle()
	bonus.model.character_passive.charge = 2
	bonus.command({"action":"form","dice":[1,2,3]}); bonus.command({"action":"cast"})
	var fireball: Dictionary = bonus.metrics.wave_report()[0].skills.Fireball
	check(fireball.casts == 3 and fireball.sources.manual == 1 and fireball.sources.character_bonus == 2,"Both bonus Fireballs are separate individual Fireball casts")
	var uses = make_session(9)
	durable(uses.model); uses.model.roll_pool(false,[1,2,3,4,5,6]); uses._settle()
	uses.model.tarot_effects.extra_uses = 2
	uses.command({"action":"form","dice":[1,2,3]}); uses.command({"action":"cast"})
	fireball = uses.metrics.wave_report()[0].skills.Fireball
	check(fireball.casts == 1 and fireball.uses == 3,"Three uses of the same cast are separate from three bonus skills")
	var auto = make_session(62)
	durable(auto.model); auto.model.roll_pool(false,[2,2,3,3,4,5]); auto._settle()
	var counts: Dictionary = auto.metrics.wave_report()[0].auto_attacks["2"]
	check(counts.groups == 2 and counts.pulses == 4,"Two matching pairs count as two groups and four shots")
	auto.command({"action":"reroll","die":1})
	check(auto.metrics.wave_report()[0].auto_attacks["2"] == counts,"A single-die reroll creates no extra matching attacks")
	for size in [5,6]:
		var s = make_session(size)
		durable(s.model)
		s.model.roll_pool(false,[2,2,2,2,2,3] if size == 5 else [2,2,2,2,2,2]); s._settle()
		var group: Dictionary = s.metrics.wave_report()[0].auto_attacks[str(size)]
		check(group.groups == 1 and group.pulses == size,"Special alike beams remain one group with individual pulses")

func _initialize() -> void:
	measurement(); health_boundaries(); inventory_tracking(); wave_actions(); combat_parity()
	for session in sessions:
		session.close()
	print("Playtest metrics: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
