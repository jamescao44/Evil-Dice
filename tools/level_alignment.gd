extends "res://tools/current_balance.gd"
## Fixed-level CLI encounters isolate level gaps; natural campaign runs live in pressure_balance.
const LINEUPS := {
	"frontline":[[Enemy.Role.VANGUARD,false],[Enemy.Role.MAGE,false]],
	"swift":[[Enemy.Role.ARCHER,false],[Enemy.Role.ASSASSIN,false]],
	"elite":[[Enemy.Role.VANGUARD,true],[Enemy.Role.MAGE,false]],
	"cannon":[[Enemy.Role.MAGIC_CANNON,false],[Enemy.Role.MAGE,false]],
}

## A small damage build has no healing, status immunity, complete sets or legendary effects.
func probe(level: int, gap: int, lineup: String, equipped: bool, seed_value: int) -> Dictionary:
	var session = Session.new(seed_value)
	var model = session.model
	model.gain_souls(5*level*(level-1))
	if equipped:
		for id in ["bracelet","mithril_blade"]: model.acquire_relic(id)
	model.hp = model.max_hp
	model.enemies.clear()
	for entry in LINEUPS[lineup]: model.enemies.append(Enemy.make(entry[0],maxi(1,level+gap),entry[1],model.rng))
	model.phase = "new"; model.round_number = 0; model.begin_round(); session._settle()
	var start_hp: int = model.max_hp
	var timing := RandomNumberGenerator.new(); timing.seed = seed_value+19001
	var min_hp := 1.0
	var count := 0
	while model.outcome().is_empty() and count < 600:
		var command: Dictionary = choose(prepare_choice(session,session.snapshot()),timing,false)
		if command.is_empty(): failures.append({"level":level,"gap":gap,"lineup":lineup}); break
		var response: Dictionary = session.command(command)
		if not response.ok: failures.append({"command":command,"error":response.error}); break
		min_hp = minf(min_hp,float(model.hp)/model.max_hp)
		count += 1
	var result := {"player_level":level,"enemy_level":maxi(1,level+gap),"gap":gap,"lineup":lineup,"equipped":equipped,"seed":seed_value,"outcome":model.outcome(),"hp_loss":float(session.stats.damage_taken)/start_hp,"min_hp_ratio":min_hp,"stats":session.stats.duplicate(),"commands":count,"telemetry":session.metrics.report()}
	_cleanup(session)
	return result

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0]
	var limit: int = int(args[1]) if args.size() > 1 else 8
	var probes: Array = []
	for level in [1,5,10,15]:
		for gap in [0,2,4,6]:
			for lineup in LINEUPS:
				for equipped in [false,true]:
					for seed_value in SEEDS.slice(0,limit): probes.append(probe(level,gap,lineup,equipped,seed_value+61000))
		print("Measured player level ",level)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"perfect_rate":perfect_rate,"probes":probes,"failures":failures},"\t"))
	print("Level alignment: ",probes.size()," encounters; failures=",failures.size())
	quit(1 if not failures.is_empty() else 0)
