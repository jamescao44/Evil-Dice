extends "res://tools/balance_probe.gd"
## Current visible-state CLI policy: gems, natural random targeting and the revised tarot rules.
var allow_tarots := true

## Equip spare gems and upgrade matching sockets without changing already-committed actions.
func gem_action(state: Dictionary) -> Dictionary:
	var gems: Dictionary = state.gemstones
	for i in range(gems.bag.size()):
		var gem: Dictionary = gems.bag[i]
		for slot in range(6):
			if gems.sockets[slot] == gem and gem.level < 3:
				return {"action":"gem_move","from":{"bag":i+1},"to":{"socket":slot+1}}
	for i in range(gems.bag.size()):
		for slot in range(6):
			if gems.sockets[slot].is_empty(): return {"action":"gem_move","from":{"bag":i+1},"to":{"socket":slot+1}}
	for i in range(gems.bag.size()):
		for j in range(i+1,gems.bag.size()):
			if gems.bag[i] == gems.bag[j] and gems.bag[i].level < 3:
				return {"action":"gem_move","from":{"bag":i+1},"to":{"bag":j+1}}
	for i in range(gems.bag.size()):
		for slot in range(6):
			if gems.sockets[slot].id == gems.bag[i].id and gems.sockets[slot].level < gems.bag[i].level:
				return {"action":"gem_move","from":{"bag":i+1},"to":{"socket":slot+1}}
	return {}

## Find a one-face edit that makes a longer straight using only publicly visible unused dice.
func magician_choice(state: Dictionary) -> Dictionary:
	var unused: Array = state.dice.filter(func(d): return not d.spent and not d.locked)
	var current: int = 0
	for skill in state.combinations: current = maxi(current,skill.faces.size())
	var best := {}; var best_length: int = current
	for die in unused:
		for face in range(1,7):
			if face == die.face: continue
			var values: Array = unused.map(func(d): return face if d.slot == die.slot else d.face)
			for length in range(6,current,-1):
				if length < 3: continue
				for first in range(1,8-length):
					if range(first,first+length).all(func(v): return v in values) and length > best_length:
						best_length = length; best = {"die":die.slot,"face":face}
	return best

## Use cards for concrete opportunities; no forced dice, secret rewards, or future knowledge.
func tarot_action(state: Dictionary) -> Dictionary:
	if not allow_tarots or "tarot" not in state.actions: return {}
	for card in state.tarots:
		if not card.blocked_reason.is_empty(): continue
		var use := false
		match card.id:
			"empress","emperor","world","wheel": use = true
			"sun": use = state.player.hp < state.player.max_hp*0.55
			"hierophant": use = state.player.statuses.any(func(s): return s.id in [100,101,102,103,104])
			"moon": use = state.enemies.any(func(e): return not e.statuses.any(func(s): return s.id == 103))
			"chariot": use = state.player.shield < Vitals.from_combat(30) and state.enemies.any(func(e): return e.intent.get("type","") == "attack" or e.charge >= 2)
			"strength": use = state.combinations.any(func(s): return s.faces.size() >= 4) and state.tarot_modifiers.strength == 0
			"star": use = "roll" in state.actions and state.tarot_modifiers.perfect_throws == 0
			"lovers": use = "roll" in state.actions and state.combinations.is_empty() and not state.tarot_modifiers.lovers
			"devil": use = "roll" in state.actions and state.combinations.is_empty() and state.tarot_modifiers.devil == 0 and not state.tarot_modifiers.lovers
			"hermit": use = state.dice.filter(func(d): return d.spent).size() >= 3 and state.combinations.is_empty()
			"justice","judgement": use = state.combinations.is_empty() and state.has_rolled and state.rolls_left == 0
			"death":
				var foes: Array = state.enemies.filter(func(e): return e.boss_phase == 0 and e.name != "Bound Demon" and e.legal_target)
				foes.sort_custom(func(a,b): return a.hp > b.hp)
				if not foes.is_empty() and foes[0].hp > 300: return {"action":"tarot","instance":card.instance,"target":foes[0].slot}
			"magician":
				if not state.has_rolled: continue
				var edit: Dictionary = magician_choice(state)
				if not edit.is_empty(): return {"action":"tarot","instance":card.instance,"die":edit.die,"face":edit.face}
			"tower": use = state.player.hp > Vitals.from_combat(60) and state.enemies.filter(func(e): return e.shield >= 50).size() >= 2
		if use: return {"action":"tarot","instance":card.instance}
	return {}

## Prefer a matching interruption when a cannon's charged shot is imminent.
func best_skill(state: Dictionary) -> Dictionary:
	for enemy in state.enemies:
		if enemy.get("interrupt_straight",0) > 0 and enemy.charge >= 1:
			for skill in state.combinations:
				if skill.faces.size() == enemy.interrupt_straight: return {"dice":skill.dice,"target":enemy.slot}
	return super.best_skill(state)

func choose(state: Dictionary, timing: RandomNumberGenerator, use_tarots: bool = true, passive_only: bool = false) -> Dictionary:
	if not state.has("choice") and not state.has("tarot_choices"):
		var gem: Dictionary = gem_action(state)
		if not gem.is_empty(): return gem
	if state.phase == "shop" and state.has("free_gift"):
		var slot: int = replacement(state.free_gift.id,state)
		return {"action":"discard_gift"} if slot < 0 else {"action":"gift","replace":slot}
	var result: Dictionary = super.choose(state,timing,use_tarots and allow_tarots,passive_only)
	# The graphical character casts at random; do not grant the CLI extra target control.
	if result.get("action","") == "cast": result.erase("target")
	return result

## Paired seeds isolate the policy choice to use cards, with fresh in-memory saves/pity.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "test-output/current-balance.json"
	if args.size() > 1 and args[1] == "probes":
		var probes: Array = []
		for wave in ([int(args[2])] if args.size() > 2 else [7,8,12,15,16,19,23,24]):
			for build in ["typical","meal_core","meal_synergy"]:
				for seed_value in SEEDS: probes.append(encounter(wave,build,seed_value))
			print("Controlled wave ",wave)
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"probes":probes,"failures":failures},"\t"))
		print("Saved ",probes.size()," probes; failures=",failures.size())
		quit(1 if not failures.is_empty() else 0)
		return
	var runs: Array = []
	var offset: int = int(args[2]) if args.size() > 2 and args[1] == "runs" else 0
	for seed_value in SEEDS:
		seed_value += offset
		for enabled in [false,true]:
			allow_tarots = enabled
			var result: Dictionary = full_run(seed_value)
			result.tarots_enabled = enabled
			runs.append(result)
			print("Seed %d tarot=%s: %s wave %d, casts %d, cards %d" % [seed_value,enabled,result.outcome,result.wave,result.stats.skills,result.stats.tarots])
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"runs":runs,"failures":failures},"\t"))
	print("Saved ",output,"; failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
