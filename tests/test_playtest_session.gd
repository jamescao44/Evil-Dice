extends SceneTree
## Validate the agent adapter against shared rules, real transaction boundaries and replay determinism.
const Session = preload("res://scripts/testing/playtest_session.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Patterns = preload("res://scripts/dice/dice_patterns.gd")
const Status = preload("res://scripts/status/status_effect.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Keep enemies alive while testing sequencing rather than reward transitions.
func durable(m) -> void:
	for enemy in m.enemies: enemy.hp = 10000; enemy.max_hp = 10000; enemy.shield = 0

## Resolve roll procs in the same order as Battle._resolve_roll_triggers().
func roll_procs(m) -> void:
	while m.perfect_relic_ready: m.resolve_roll_relic_step()
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()

## Compare gameplay state and both RNG streams without presentation-specific objects.
func signature(m) -> String:
	var data := {"hp":m.hp,"max_hp":m.max_hp,"level":m.character_level,"xp":m.souls,"gems":m.blood_gems,"phase":m.phase,"round":m.round_number,"bonus":m.bonus_turn_count,"progress":m.reroll_progress,
		"dice":m.dice_turn.values,"locked":m.dice_turn.locked,"spent":m.dice_turn.committed,"rolls":m.dice_turn.rolls_left,"rng":str(m.rng.state),"reward_rng":str(m.reward_rng.state),"relics":m.relics.items,"tarots":m.tarots.items,
		"enemies":[],"statuses":[]}
	for enemy in m.enemies:
		var copy: Dictionary = enemy.duplicate()
		copy.statuses = []
		for id in enemy.get("statuses",{}): copy.statuses.append([id,enemy.statuses[id].count,enemy.statuses[id].permanent])
		data.enemies.append(copy)
	for id in m.statuses: data.statuses.append([id,m.statuses[id].count,m.statuses[id].potency])
	return JSON.stringify(data)

func combat_parity() -> void:
	for seed in range(20):
		var s = Session.new(seed)
		var m = Run.new(seed); m.begin_round()
		durable(s.model); durable(m)
		for id in ["worn_bow","orange_stone","pet_bat"]: s.model.acquire_relic(id); m.acquire_relic(id)
		for roll in range(3):
			var result: Dictionary = s.command({"action":"roll","perfect":roll == 1})
			m.roll_pool(roll == 1); roll_procs(m)
			check(result.ok and signature(s.model) == signature(m),"Natural roll, procs, matches and RNG match the real rules")
		var before := signature(s.model)
		for i in range(5): s.snapshot()
		check(before == signature(s.model),"Inspection never rolls RNG or changes gameplay")
		check(not s.command({"action":"form","dice":[1,1,9]}).ok and signature(s.model) == before,"Invalid form is atomic")
		check(not s.command({"action":"roll","perfect":"yes"}).ok,"Malformed timing result rejected")
		s.model.hp = 60; m.hp = 60
		var result: Dictionary = s.command({"action":"end"})
		m.end_dice_turn(); m.apply_player()
		for i in m.living(): m.enemy_act(i)
		m.end_round(); m.begin_round()
		check(result.ok and signature(s.model) == signature(m),"Leftover heal, enemy moves, burn ticks and next round match GUI order")
	for length in range(3,7):
		var s = Session.new(8)
		var m = Run.new(8); m.begin_round()
		durable(s.model); durable(m)
		for run in [s.model,m]: run.roll_pool(false,[1,2,3,4,5,6]); run.character_passive.charge = 2
		var selected: Array = range(1,length+1)
		check(s.command({"action":"form","dice":selected}).ok,"Form each straight tier")
		for i in range(length): m.dice_turn.select(i)
		m.form_selected_skill()
		check(signature(s.model) == signature(m),"Formation locks exactly the selected dice")
		check(s.command({"action":"cancel"}).ok,"Cancel formed skill")
		m.cancel_formed_skill()
		check(signature(s.model) == signature(m),"Cancellation returns dice without refunding rolls")
		s.command({"action":"form","dice":selected})
		for i in range(length): m.dice_turn.select(i)
		m.form_selected_skill()
		var result: Dictionary = s.command({"action":"cast","target":1})
		m.apply_player(0)
		while m.phase == "player" and m.pending.cast_source != "manual": m.apply_player()
		check(result.ok and signature(s.model) == signature(m),"Damage pulses, Fireball echoes and six-die bonus preserve model parity")
		if length == 3: check(result.events.filter(func(e): return e.type == "damage").size() == 3,"Third Fireball includes two passive echoes")
		if length >= 5: check(result.events.filter(func(e): return e.type == "damage").size() == (5 if length == 5 else 10),"Damage pulses resolve without extra skill casts")

func tarot_choices() -> void:
	var s = Session.new(14); durable(s.model)
	s.model.roll_pool(false,[1,2,3,4,5,5]); s._settle()
	var card: Dictionary = s.model.tarots.add("magician")
	check(s.command({"action":"tarot","instance":card.instance_id}).state.choice.type == "magician","Magician pauses for die/face selection")
	check(not s.command({"action":"roll"}).ok,"Pending card choice blocks combat input")
	check(s.command({"action":"cancel"}).ok and s.model.tarots.items.size() == 1,"Magician cancellation preserves card")
	s.command({"action":"tarot","instance":card.instance_id})
	check(not s.command({"action":"choose","die":6,"face":5}).ok,"Same-face Magician does not consume the card")
	var hp: int = s.model.enemies[0].hp
	check(s.command({"action":"choose","die":6,"face":6}).ok and s.model.enemies[0].hp == hp,"Magician changes unused die without auto-attacking again")
	s.command({"action":"form","dice":[1,2,3,4,5,6]})
	card = s.model.tarots.add("justice")
	check(s.command({"action":"tarot","instance":card.instance_id}).ok and s.model.pending.is_empty() and s.model.dice_turn.locked.is_empty(),"Justice cancels formed skill and freely rerolls all dice")
	check(s.model.dice_turn.rolls_left == 2,"Justice does not charge a reroll")
	card = s.model.tarots.add("temperance")
	check(s.command({"action":"tarot","instance":card.instance_id}).ok and s.model.dice_turn.rolls_left == 5,"Temperance ends turn and redeems two banked rolls next turn")
	s.model.apply_affliction(Status.FROZEN,1); s.model._prepare_player_turn()
	for i in range(2): check(s.command({"action":"ice"}).state.phase == "frozen","First two ice taps retain the frozen decision")
	check(s.command({"action":"ice"}).state.phase == "roll","Third ice tap resolves enemies and the skipped turn")
	for id in Session.Tarot.ITEMS:
		var t = Session.new(5); durable(t.model)
		t.model.roll_pool(false,[1,1,3,3,6,6]); t._settle()
		t.model.acquire_relic("bracelet")
		if id == "hermit": t.model.dice_turn.locked = [0]; t.model.dice_turn.committed = [0]
		var owned: Dictionary = t.model.tarots.add(id)
		var request := {"action":"tarot","instance":owned.instance_id}
		if id == "death": request.target = 1
		if id == "magician": request.die = 1; request.face = 2
		if id == "hanged_man": request.ban = "fool"
		check(t.command(request).ok,"Every current tarot is reachable through its real rules: "+id)
	var repeated = Session.new(5); durable(repeated.model)
	repeated.model.acquire_relic("ancient_prophecy")
	card = repeated.model.tarots.add("strength")
	check(repeated.command({"action":"tarot","instance":card.instance_id}).ok and repeated.model.tarot_effects.strength == 2,"Prophecy repeats immediate modifiers exactly twice")
	repeated.model.roll_pool(false,[1,2,3,4,5,6])
	card = repeated.model.tarots.add("magician")
	repeated.command({"action":"tarot","instance":card.instance_id,"die":1,"face":2})
	check(repeated.choice.instance_id < 0,"Repeated choice remains explicit instead of silently reusing the first answer")
	check(repeated.command({"action":"cancel"}).ok and repeated.choice.is_empty(),"Repeated card choice can be declined")
	var full = Session.new(5)
	for id in ["bracelet","heart","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]: full.model.acquire_relic(id)
	card = full.model.tarots.add("emperor")
	check(full.command({"action":"tarot","instance":card.instance_id}).state.choice.type == "replace","Full inventory exposes the actual incoming relic")
	check(full.model.tarots.items.is_empty(),"Emperor consumes immediately when offering a relic")
	check(not full.command({"action":"choose","replace":99}).ok and not full.choice.is_empty(),"Bad replacement retains the pending decision")
	check(full.command({"action":"cancel"}).ok and full.model.relics.items.size() == 10,"Cancel discards the incoming relic without replacing an owned one")
	card = full.model.tarots.add("world")
	check(not full.command({"action":"tarot","instance":card.instance_id,"replace":99}).ok and not full.choice.is_empty(),"Direct invalid replacement preserves a recoverable consumed-card choice")
	check(full.command({"action":"choose","replace":1}).ok and full.model.relics.items.size() == 10,"A valid replacement completes the pending World transaction")
	check(full.command({"action":"reorder","from":10,"to":1}).ok,"Agent can change left-to-right relic priority")

func rewards_and_shop() -> void:
	var s = Session.new(44)
	s.model.wave_kind = s.model.WaveRewards.RELIC
	for enemy in s.model.enemies: enemy.hp = 0
	s._settle()
	check(s.snapshot().phase == "closed_chest" and not s.snapshot().has("rewards") and not s.snapshot().has("chest_tier"),"Closed chest hides locked outcomes until opened")
	check(not s.command({"action":"take","slot":1}).ok,"Cannot collect unopened rewards")
	check(s.command({"action":"open"}).state.phase == "rewards","Opening reveals real committed prizes")
	var ids: Array = s.snapshot().rewards.map(func(item): return item.id)
	for i in range(3): check(s.command({"action":"state"}).state.rewards.map(func(item): return item.id) == ids,"Inspection never rerolls rewards")
	check(s.command({"action":"take","slot":1}).ok,"Take an offered relic")
	if not s.model.open_rewards.is_empty(): s.command({"action":"skip"})
	check(s.snapshot().phase == "routes","Complete rewards before choosing a route")
	check(not s.command({"action":"route","slot":3}).ok,"Reject unoffered route")
	check(s.command({"action":"route","slot":1}).ok and s.model.stage == 1,"Route advances exactly one wave")
	var full = Session.new(8)
	for id in ["bracelet","heart","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]: full.model.acquire_relic(id)
	full.model.reroll_progress = 10
	full.model.chest_pity.misses = [0,4,4]
	check(full.command({"action":"treasure"}).state.rewards.size() == 5,"An upgraded reroll chest exposes five separately claimable prizes")
	check(not full.command({"action":"take","slot":1}).ok,"A full chest inventory requires a replacement decision")
	check(full.command({"action":"take","slot":1,"replace":4}).ok,"Chest replacement preserves ten-slot capacity")
	check(full.command({"action":"skip"}).ok and full.model.relics.items.size() == 10 and full.model.open_rewards.is_empty(),"Partial pickup then skip closes the chest without losing owned items")
	# Controlled shop fixture exercises the production stock/economy without exposing cheat commands.
	var shop = Session.new(19)
	shop.model.stage = 3; shop.model.wave_kind = shop.model.WaveRewards.SHOP; shop.model._load_wave(); shop.model.blood_gems = 1000
	shop._settle()
	var state: Dictionary = shop.snapshot()
	check(state.phase == "shop" and state.shop.size() == 9,"Shop includes six relics, two tarots and one bottle")
	check(not state.shop[8].has("souls") and not JSON.stringify(state.shop[8]).contains("\"souls\":"),"Bottle amount remains sealed")
	var price: int = state.shop[0].price
	check(shop.command({"action":"buy","slot":1}).ok and shop.model.blood_gems == 1000-price,"Atomic shop purchase charges the displayed price")
	check(not shop.command({"action":"buy","slot":1}).ok and shop.model.blood_gems == 1000-price,"Sold stock cannot charge twice")
	check(shop.command({"action":"divination"}).state.tarot_choices.size() == 3,"Keeper draw reveals three choices")
	check(not shop.command({"action":"leave"}).ok,"Finish free draw before leaving")
	check(shop.command({"action":"choose","slot":2}).ok and shop.model.tarots.items.size() == 1,"Keep precisely the chosen card")
	check(not shop.command({"action":"divination"}).ok,"Keeper draw is once per visit")
	check(shop.command({"action":"refresh"}).ok,"Refresh regenerates all stock at the shared price")
	check(shop.command({"action":"leave"}).state.phase == "routes","Leaving shop offers next routes without a battle")
	check(shop.command({"action":"route","slot":1}).state.wave == 5,"Shop consumes one wave")
	var burn = Session.new(5); burn.model.enemies[0].hp = 1
	burn.model.apply_enemy_status(0,Status.BURNING,1,false)
	burn.model.apply_affliction(Status.BURNING,2)
	burn.model.phase = "enemy"
	for enemy in burn.model.enemies: enemy.acted = true
	burn.model._begin_turn_end(); burn._settle()
	check(burn.model.hp == 90 and burn.snapshot().phase == "closed_chest","Player burn fully resolves even when enemy burn clears the wave")

## Exercise long natural games for deadlocks and identical seed/decision replay, not balance claims.
func natural_runs() -> void:
	for seed in [9,29,82]:
		var a = Session.new(seed)
		var b = Session.new(seed)
		var ended := false
		for step in range(3000):
			var state: Dictionary = a.snapshot()
			var request: Dictionary = {}
			match state.phase:
				"level_complete": request = {"action":"start"}
				"closed_chest": request = {"action":"open"}
				"rewards":
					var slot: Dictionary = state.rewards.filter(func(i): return not i.claimed).front()
					request = {"action":"take","slot":slot.slot,"replace":1 if state.relics.size() >= 10 else 0}
				"routes": request = {"action":"route","slot":1}
				"shop": request = {"action":"leave"}
				"frozen": request = {"action":"ice"}
				"player": request = {"action":"cast","target":state.enemies.filter(func(e): return e.legal_target).front().slot}
				"roll":
					if not state.combinations.is_empty(): request = {"action":"form","dice":state.combinations[0].dice}
					elif "roll" in state.actions: request = {"action":"roll"}
					else: request = {"action":"end"}
			if request.is_empty():
				ended = not state.outcome.is_empty()
				break
			var left: Dictionary = a.command(request)
			var right: Dictionary = b.command(request)
			check(left.ok,"Natural run action accepted at "+state.phase)
			check(JSON.stringify(left) == JSON.stringify(right),"Same seed and choices reproduce every state and event")
			if not left.ok: break
		check(ended,"Natural run reaches defeat or final victory without deadlock")
	print("Natural runs are integration smoke tests, not human balance evidence.")

func _initialize() -> void:
	combat_parity()
	tarot_choices()
	rewards_and_shop()
	natural_runs()
	print("Playtest session: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
