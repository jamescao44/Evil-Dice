extends SceneTree
## Opening rolls resolve larger matches first, then queued item attacks in inventory order.
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
const Battle = preload("res://scripts/combat/battle.gd")

class ObservedBattle extends Battle:
	var attack_order: Array = []
	func _show_events(events: Array) -> void:
		var hits: Array = events.filter(func(e): return e.type == "damage" and e.target >= 0)
		if not hits.is_empty() and not hits[0].has("relic_flight") and relic_attacks.flights.is_empty():
			attack_order.append("auto")
		super._show_events(events)

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Durable opponents keep attack ordering separate from kill rewards and leveling.
func prepare(m) -> void:
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for enemy in m.enemies: enemy.hp = 100000; enemy.max_hp = 100000; enemy.shield = 0
	m.acquire_relic("worn_bow")
	m.acquire_relic("worn_spear")
	m.begin_round()

func patterns() -> void:
	for fixture in [
		[[6,6,1,1,1,1],[[4,1],[2,6]]],
		[[6,6,2,2,2,3],[[3,2],[2,6]]],
		[[2,2,6,6,4,4],[[2,6],[2,4],[2,2]]],
		[[2,2,2,5,5,5],[[3,5],[3,2]]]]:
		var values: Array = fixture[0].duplicate()
		var groups: Array = Patterns.automatic_groups(values,range(6))
		check(groups.map(func(g): return [g.indices.size(),g.skill.face]) == fixture[1],"Larger groups precede smaller groups, with higher pips breaking ties")
		check(values == fixture[0],"Ordering does not rearrange visible dice")
		for group in groups:
			check(group.indices.all(func(i): return values[i] == group.skill.face),"Each group keeps its original die positions")
	var subset: Array = Patterns.automatic_groups([6,6,1,1,1,1],[0,1,2,3])
	check(subset.map(func(g): return g.indices) == [[0,1],[2,3]],"Only participating dice determine group priority")

func model_order() -> void:
	var m = Run.new(881); prepare(m)
	m.roll_pool(false,[6,6,1,1,1,1])
	check(m.roll_relic_actions.map(func(a): return a.id) == ["worn_bow","worn_spear","worn_spear"],"Item queue preserves inventory order and repeated attacks")
	var hp: Array = m.enemies.map(func(e): return e.hp)
	var rng_state: int = m.rng.state
	check(not m.perfect_relic_ready,"Items are not ready while alike attacks are pending")
	check(m.resolve_roll_relic_step().is_empty() and m.resolve_perfect_relic().is_empty(),"Both item entry points wait for automatic attacks")
	check(m.enemies.map(func(e): return e.hp) == hp and m.rng.state == rng_state and m.roll_relic_actions.size() == 3,"Early item calls cannot consume damage, targets or queued attacks")
	var groups: Array = []
	for step in range(12):
		if m.roll_attacks.is_empty(): break
		groups.append(m.roll_attacks[0].indices.size())
		check(not m.perfect_relic_ready,"Every automatic hit retains priority over items")
		m.resolve_roll_attack_step()
	check(groups == [4,2,2] and m.perfect_relic_ready and m.phase == "roll","Four-alike eruption and both pair hits finish before items unlock")
	var items: Array = []
	m.relic_attack_started.connect(func(receipt): items.append(receipt.source))
	for step in range(12):
		if not m.perfect_relic_ready: break
		m.resolve_roll_relic_step()
	check(items == ["worn_bow","worn_spear","worn_spear"],"Item impacts retain their inventory order")
	check(m.roll_relic_actions.is_empty() and not m.perfect_relic_ready and m.phase == "roll","Queue returns control after the last item")
	m = Run.new(882); prepare(m); m.roll_pool(false,[1,2,3,4,5,6])
	check(m.roll_attacks.is_empty() and m.perfect_relic_ready,"Without matches, items are immediately ready")
	check(not m.resolve_perfect_relic().is_empty() and not m.perfect_relic_ready,"No-match opening throw still resolves all item attacks")
	m = Run.new(883); prepare(m)
	for enemy in m.enemies: enemy.hp = 1
	m.roll_pool(false,[6,6,1,1,1,1]); m.resolve_roll_attack_step()
	check(not m.outcome().is_empty() and m.phase == "finished" and m.roll_attacks.is_empty(),"An early area kill cancels the smaller match")
	check(m.roll_relic_actions.is_empty() and not m.perfect_relic_ready and m.resolve_perfect_relic().is_empty(),"Victory discards unneeded items without stale attacks")

func cli_order() -> void:
	var session = Session.new(884); prepare(session.model)
	var before_items: Array = []
	session.model.relic_attack_started.connect(func(_receipt): before_items.append([session.model.roll_attacks.size(),session.model.phase]))
	session.model.roll_pool(false,[6,6,1,1,1,1]); session._settle()
	check(before_items == [[0,"roll"],[0,"roll"],[0,"roll"]],"CLI attacks with items only after all alike groups")
	check(session.model.phase == "roll" and session.model.roll_relic_actions.is_empty(),"CLI settles back to player dice input")
	session.close()

## Exercise real character recovery and item-flight waits through the GUI coordinator.
func scene_order() -> void:
	var g = ObservedBattle.new()
	root.add_child(g); g.muted = true; g.speed = 4; g.set_process_input(false)
	g.model.relic_attack_started.connect(func(receipt): g.attack_order.append(receipt.source))
	prepare(g.model)
	g.model.roll_pool(false,[6,6,1,1,1,1]); g.view_phase = "rolling"
	for i in range(6): g.dice[i].face = g.model.dice_turn.values[i]
	check(await g._resolve_roll_triggers(g.run_id),"GUI completes opening attacks without blocking")
	check(g.attack_order == ["auto","auto","auto","worn_bow","worn_spear","worn_spear"],"GUI presents every alike impact before item attacks")
	check(not g.relic_attacks.pending() and g.model.phase == "roll","Final item flight finishes before dice controls return")
	g.queue_free(); await process_frame

func _initialize() -> void: call_deferred("run")

func run() -> void:
	patterns()
	model_order()
	cli_order()
	await scene_order()
	print("Roll attack order: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
