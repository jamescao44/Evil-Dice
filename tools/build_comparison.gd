extends SceneTree
## Ten-turn controlled builds: real combat, equal level/rarity budget, shared roll and timing seeds.
const Session = preload("res://scripts/testing/playtest_session.gd")
const TARGET_HP := 100000000
const BUILDS := {
	"control": [],
	"raw": ["bracelet","magic_sword","hamburger","fried_chicken","steel_sword","contract","mithril_blade"],
	"items": ["worn_bow","magic_slingshot","magic_sword","hamburger","pet_ghost","pet_dragon","disguise_mask"],
	"status": ["bracelet","pet_lizard","vodka","magic_sword","orange_stone","powder_keg","pet_dragon"],
	"recovery": ["pet_bat","mysterious_seed","magic_bandage","bloodstone","contract","disguise_mask","book_of_dead"],
	"single_target": ["worn_dagger","light_sword","steel_marble","magic_sword","split_arrow","royal_dagger","twin_scythes"],
	"burst": ["glass_marble","magic_sword","steel_marble","light_sword","echo_bell","alternating_gears","royal_seal"],
	"one_roll_auto": ["lemon_soda","magic_slingshot","magic_sword","fried_chicken","steel_sword","pet_dragon","disguise_mask"],
}
var failures: Array = []

## Choose by visible damage per die, allowing each loadout to favor its own skill strengths.
func select_skill(state: Dictionary) -> Dictionary:
	var best := {}; var best_score := -1.0
	for skill in state.combinations:
		var total := 0.0
		for hit in skill.damage: total += hit.total_per_use*skill.uses
		if not skill.area: total /= maxi(1,skill.damage.size())
		var score: float = total/pow(skill.dice.size(),0.55)
		if score > best_score: best_score = score; best = skill
	return best

## Use inert durable targets, with one identical 30-damage incoming hit per completed turn.
func set_intents(model) -> void:
	for i in range(model.enemies.size()):
		model.enemies[i].intent = {"skill":"attack" if i == 0 else "rest","type":"attack" if i == 0 else "rest","amount":30 if i == 0 else 0,"target":-1,"hits":1,"status":-1}

func total_hp(model) -> int:
	return model.enemies.reduce(func(n,e): return n+e.hp,0)

## Stop before turn eleven; do not award loot, XP, prestacked kills or free tarot.
func probe(name: String, ids: Array, targets: int, sample: int, level: int = 20) -> Dictionary:
	var s = Session.new(sample)
	var m = s.model
	m.gain_souls(5*level*(level-1)); m.stage = 20
	m.enemies.clear()
	for i in range(targets):
		var enemy: Dictionary = m.make_enemy(0)
		enemy.hp = TARGET_HP; enemy.max_hp = TARGET_HP; enemy.shield = 0
		m.enemies.append(enemy)
	for id in ids: m.acquire_relic(id)
	m.hp = m.max_hp; m.phase = "new"; m.round_number = 0
	m.begin_round(); set_intents(m)
	s.stop_after_enemy_phases = 10
	var commands := 0; var previous_turn := -1; var roll_ordinal := 0
	var damage: Array = []; damage.resize(10); damage.fill(0)
	var burns := 0; var attacks := 0; var requested_rolls := 0
	while s.stats.enemy_phases < 10 and m.hp > 0 and commands < 2000:
		var state: Dictionary = s.snapshot()
		var turn: int = s.stats.enemy_phases
		if previous_turn != turn: previous_turn = turn; roll_ordinal = 0
		set_intents(m)
		var command: Dictionary = {}
		if "cast" in state.actions: command = {"action":"cast","target":1}
		elif name != "one_roll_auto" and "form" in state.actions:
			command = {"action":"form","dice":select_skill(state).dice}
		elif "roll" in state.actions and (not state.has_rolled or (name != "one_roll_auto" and m.dice_turn.unused().size() >= 3)):
			m.rng.seed = sample*100000+turn*1000+roll_ordinal*13+7
			var timing := RandomNumberGenerator.new(); timing.seed = sample*100000+turn*1000+roll_ordinal*13+91007
			command = {"action":"roll","perfect":timing.randf() < 0.35}
			roll_ordinal += 1; requested_rolls += 1
		elif "end" in state.actions: command = {"action":"end"}
		else:
			failures.append({"build":name,"phase":state.phase,"sample":sample}); break
		var before: int = total_hp(m)
		var result: Dictionary = s.command(command)
		damage[turn] += before-total_hp(m)
		for event in result.events:
			if event.get("target",-1) >= 0 and event.type == "burn": burns += event.amount
			if event.get("target",-1) >= 0 and event.type == "damage": attacks += 1
		if not result.ok: failures.append(result.error); break
		commands += 1
	if s.stats.enemy_phases != 10: failures.append({"build":name,"completed_turns":s.stats.enemy_phases,"seed":sample})
	var result := {"build":name,"items":ids,"targets":targets,"seed":sample,"level":level,"turns":s.stats.enemy_phases,"damage":targets*TARGET_HP-total_hp(m),"by_turn":damage,"peak_turn":damage.max(),"burn_damage":burns,"rolls":requested_rolls,"skills":s.stats.skills,"hp":m.hp,"max_hp":m.max_hp,"healing":s.stats.healing,"incoming":s.stats.damage_taken,"commands":commands,"impacts":attacks}
	for info in m.get_signal_list():
		for connection in m.get_signal_connection_list(info.name): m.disconnect(info.name,connection.callable)
	return result

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var builds: Dictionary = BUILDS.duplicate(true)
	if args.size() > 1 and args[1] == "recovery": builds = {"recovery":BUILDS.recovery}
	if args.size() > 1 and args[1] == "ablations":
		builds = {"raw_gears":BUILDS.raw.duplicate(),"items_sword":BUILDS.items.duplicate()}
		builds.raw_gears[builds.raw_gears.find("steel_sword")] = "alternating_gears"
		builds.items_sword[builds.items_sword.find("pet_ghost")] = "steel_sword"
	var results: Array = []
	for targets in [1,3]:
		for name in builds:
			for sample in range(1,41):
				var row: Dictionary = probe(name,builds[name],targets,sample)
				row.build = name
				results.append(row)
			print("Compared ",name," / targets ",targets)
	var path: String = args[0] if not args.is_empty() else "test-output/builds-20261025/builds.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"conditions":{"turns":10,"level":20,"incoming_per_turn":30,"perfect_probability":0.35,"samples":40,"rarities":"1 common, 3 rare, 2 epic, 1 legendary/cursed","notes":"No tarot, rewards, XP or precharged counters. One-roll auto uses no manual skills. Damage sums all targets; targets have no shields, taunt or resistance."},"results":results,"failures":failures},"\t"))
	print("Saved ",path,"; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
