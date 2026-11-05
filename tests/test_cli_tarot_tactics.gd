extends "res://tools/current_balance.gd"
## Check acquisition shortcuts and real CLI decisions without running an entire campaign.
var checks := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1; push_error(label)

func _initialize() -> void:
	var session = Session.new(1223)
	var model = session.model
	model.tarots.items.clear()
	model.tarots.add("strength"); model.tarots.add("sun"); model.tarots.add("empress")
	model.hp = 400
	model.shop.open_debug(model)
	var state: Dictionary = session.snapshot()
	check(tarot_action(state).is_empty(),"Respect the CLI's available actions while browsing stock")
	# Owned-card surfaces can expose tarot here; the context must still admit only rewards.
	state.actions.append("tarot")
	var result: Dictionary = tarot_action(state)
	check(result.get("instance",0) == model.tarots.items[2].instance_id,"Only reward cards are spent immediately while shopping")
	for id in model.Tarot.ITEMS:
		check(TarotTactics.tactical_context(state,id) == model.Tarot.immediate_reward(id),"Shop policy reserves non-reward card: "+id)
	model.tarots.items.resize(1)
	model.shop.close(); model.phase = "roll"
	model.dice_turn.values = [2,3,4,2,2,6]; model.dice_turn.rolls_made = 1; model.dice_turn.rolls_left = 4
	model.enemies = [Enemy.make(Enemy.Role.MAGE,1),Enemy.make(Enemy.Role.MAGE,1)]
	for enemy in model.enemies: enemy.hp = 1000; enemy.max_hp = 1000
	state = prepare_choice(session,session.snapshot())
	check(state.policy_decision.action == "reroll" and tarot_action(state).is_empty(),"Hold Strength while the planner is still improving the dice")
	model.dice_turn.rolls_left = 0
	state = prepare_choice(session,session.snapshot())
	check(state.policy_decision.action == "form" and tarot_action(state).get("instance",0) == model.tarots.items[0].instance_id,"Strength supports the chosen attack against surviving enemies")
	for enemy in model.enemies: enemy.hp = 1
	state = prepare_choice(session,session.snapshot())
	check(tarot_action(state).is_empty(),"Save Strength when the chosen skill already kills its targets")
	model.tarots.items.clear(); var sun: Dictionary = model.tarots.add("sun")
	model.hp = 400
	check(tarot_action(session.snapshot()).get("instance",0) == sun.instance_id,"Use Sun for a substantial real health deficit")
	model.statuses[103].apply(1)
	check(tarot_action(session.snapshot()).is_empty(),"Save Sun while Darkness prevents healing")
	model.statuses[103].count = 0; model.hp = 900
	for enemy in model.enemies: enemy.intent = {"type":"rest"}
	check(tarot_action(session.snapshot()).is_empty(),"Do not waste Sun on minor chip damage")
	model.hp = 600; model.enemies[0].intent = {"type":"attack","amount":650,"hits":1}
	check(tarot_action(session.snapshot()).get("instance",0) == sun.instance_id,"Sun can avert a visible lethal attack even above the ordinary heal threshold")
	model.shield = 100
	check(tarot_action(session.snapshot()).is_empty(),"Existing shielding is included in the lethal-threat check")
	model.phase = "wave_reward"
	check(not TarotTactics.sun(session.snapshot()),"No automatic combat-card spending on receipt screens")
	session.close()
	print("CLI tactical tarots: %d checks, %d failures" % [checks,failed])
	quit(1 if failed else 0)
