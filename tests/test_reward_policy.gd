extends "res://tools/current_balance.gd"
## Keep every reward tier eligible and distinguish a ready Normal chest from no chest.
var checks := 0
var errors := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors += 1; push_error(label)

func _initialize() -> void:
	var timing := RandomNumberGenerator.new()
	for tier in range(4):
		var session = Session.new(231+tier)
		session.model._roll_chest(tier)
		session.chest_source = "treasure"
		var count: int = session.model.open_rewards.size()
		for index in range(count):
			var action: Dictionary = choose(session.snapshot(),timing)
			check(action.action == "take","Policy accepts tier %d prize %d" % [tier,index])
			check(session.command(action).ok,"Every prize is collected through the real CLI transaction")
		check(session.model.open_rewards.is_empty(),"All prizes settle, including all five Ultra relics")
		_cleanup(session)
	var session = Session.new(234)
	check(session.snapshot().treasure.tier == -1 and "treasure" not in session.snapshot().actions,"Incomplete meter exposes no claim action")
	session.model.reroll_progress = 20
	check(session.snapshot().treasure.tier == 0 and "treasure" in session.snapshot().actions,"Ready Normal chest exposes a claim action")
	session.model.chest_pity.misses = [5,5,5]
	check(session.command({"action":"treasure"}).ok,"CLI opens a Normal-start reroll chest")
	check(session.model.chest_start_tier == 0 and session.model.opened_chest_tier == 3,"Normal reroll chest follows the complete shared upgrade chain")
	_cleanup(session)
	print("Reward policy: %d checks, %d failures" % [checks,errors])
	quit(1 if errors else 0)
