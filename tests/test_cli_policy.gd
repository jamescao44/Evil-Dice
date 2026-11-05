extends SceneTree
## Planning changes must improve real choices without changing rules, counters or RNG.
const Session = preload("res://scripts/testing/playtest_session.gd")
const Planner = preload("res://tools/policy/straight_planner.gd")
const Order = preload("res://tools/policy/relic_order.gd")
const Inventory = preload("res://scripts/relics/relic_inventory.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Create visible combat fixtures without activating opening-throw damage.
func fixture(values: Array, foes: int = 4):
	var session = Session.new(771)
	var m = session.model
	m.enemies.clear()
	for i in range(foes):
		var enemy: Dictionary = Enemy.make(Enemy.Role.MAGE,1)
		enemy.hp = 600; enemy.max_hp = 600; m.enemies.append(enemy)
	m.phase = "roll"; m.dice_turn.values = values.duplicate(); m.dice_turn.rolls_made = 1; m.dice_turn.rolls_left = 4
	return session

## Evaluate forecasts twice and assert they cannot consume random state or mutate combat.
func decision(session) -> Dictionary:
	var state: Dictionary = session.snapshot()
	var before: String = JSON.stringify(state)
	var rng_state: int = session.model.rng.state
	var forecasts: Array = Planner.capture(session.model,state)
	check(forecasts == Planner.capture(session.model,state,false),"Equivalent forecast cache preserves every physical option and value")
	var planner = Planner.new()
	var result: Dictionary = planner.decide(state,forecasts)
	check(result == planner.decide(state,forecasts),"Planning is deterministic")
	check(session.model.rng.state == rng_state and JSON.stringify(session.snapshot()) == before,"Forecasts leave combat and RNG unchanged")
	return result

func _initialize() -> void:
	var session = fixture([2,3,4,2,2,6])
	var choice: Dictionary = decision(session)
	check(choice.action == "reroll" and choice.die in [1,4,5,6],"Keep the straight and seek an area upgrade against a crowd")
	check(choice.die not in [2,3],"Do not break unique 3/4 while duplicates are expendable")
	session.close()
	session = fixture([2,3,4,2,2,6],1)
	session.model.enemies[0].hp = 1
	choice = decision(session)
	check(choice.action == "form","Bank a certain kill rather than spending rerolls")
	session.close()
	session = fixture([2,3,4,2,2,6],1)
	session.model.enemies[0].charge = 1; session.model.enemies[0].interrupt_straight = 3
	choice = decision(session)
	check(choice.action == "form" and choice.dice.size() == 3,"Take an available matching interruption")
	session.close()
	session = fixture([1,2,3,4,5,6])
	session.model.dice_turn.rolls_left = 0
	choice = decision(session)
	check(choice.action == "form" and choice.dice.size() == 6,"Prefer actual area damage; no old per-die penalty")
	session.close()
	session = fixture([1,2,3,4,1,1],1)
	session.model.dice_turn.rolls_left = 0
	choice = decision(session)
	check(choice.action == "form" and choice.dice.size() == 3,"Early Fireball retains its Burning and counter-building value against one target")
	session.model.character_passive.charge = 2
	var state_with_bonus: Dictionary = session.snapshot()
	var forecasts: Array = Planner.capture(session.model,state_with_bonus)
	check(forecasts.filter(func(o): return o.faces.size() == 3).all(func(o): return o.counter_value > 0),"Ready bonus Fireballs contribute to cast valuation")
	check(session.model.character_passive.charge == 2,"Bonus preview does not spend live embers")
	session.close()
	session = fixture([1,2,3,4,5,6],1)
	session.model.enemies[0].hp = 50; session.model.character_passive.charge = 2
	choice = decision(session)
	var clearing: Array = Planner.capture(session.model,session.snapshot()).filter(func(o): return o.dice == choice.dice)
	check(not clearing.is_empty() and clearing[0].clears,"A certain immediate clear beats speculative bonus-counter value")
	session.close()
	session = fixture([1,1,3,3,5,5])
	session.model.dice_turn.rolls_left = 0
	check(decision(session).action == "end","No illegal reroll or formation at zero budget")
	check(Planner.needs_rescue_roll(session.snapshot()),"Justice/Judgement can rescue a genuinely exhausted pool")
	session.close()
	session = fixture([1,2,3,4,5,6])
	session.model.dice_turn.rolls_left = 0
	var formed: Dictionary = session.command({"action":"form","dice":[1,2,3]})
	check(formed.ok and not Planner.needs_rescue_roll(session.snapshot()),"Never waste Justice cancelling the skill just selected by the planner")
	session.close()
	session = fixture([2,3,4,2,2,6])
	session.model.dice_turn.locked = [3,4,5]; session.model.dice_turn.committed = [3,4,5]
	choice = decision(session)
	check(choice.action != "reroll" or choice.die <= 3,"Never reroll a spent or locked die")
	session.close()
	var inventory = Inventory.new()
	for id in ["pet_slime","bloodstone","heart","disguise_mask","pet_ghost","armor","fortune_cookie","hamburger","lemon_soda","fries","contract","glass_marble"]: inventory.add(id)
	var before: String = JSON.stringify(inventory.items)
	var original: float = Order.score(inventory.items,23)
	var ordered: Array = Order.optimize(inventory.items,23)
	var mask: int = ordered.find_custom(func(i): return i.id == "disguise_mask")
	check(mask > 0 and ordered[mask-1].id == "happy_meal","Failed-run Mask moves from Heart to Happy Trio")
	check(Order.score(ordered,23) > original,"Ordering improves the explicit sustained-value objective")
	check(JSON.stringify(inventory.items) == before,"Ordering never mutates live items or counters")
	check(Order.optimize(ordered,23) == ordered,"Optimization is stable at its solution")
	inventory = Inventory.new()
	for id in ["ancient_tentacle","disguise_mask","mithril_blade","fries"]: inventory.add(id)
	ordered = Order.optimize(inventory.items,20)
	check(ordered[-1].id == "ancient_tentacle","Tentacle follows the payload and Mask")
	check(ordered.find_custom(func(i): return i.id == "disguise_mask") > 0,"Mask has a valid left-hand payload")
	inventory = Inventory.new()
	for id in ["mithril_blade","fries"]: inventory.add(id)
	ordered = Order.optimize(inventory.items,20)
	check(ordered[0].id == "fries","Additive multiplier comes before multiplicative sword")
	var state := {"actions":["reorder"],"player":{"level":8,"base_damage":20},"relics":[]}
	var mover = Order.new()
	var moves := 0
	while moves < 10:
		state.relics = inventory.items.map(func(i): return {"counters":i})
		choice = mover.action(state)
		if choice.is_empty(): break
		inventory.move(choice.from-1,choice.to-1); moves += 1
	check(moves == 1 and inventory.items[0].id == "fries","Plan terminates through legal one-based reorder commands")
	print("CLI policy: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
