extends SceneTree
## Boss-phase spawns enter once; later minion batches cannot move settled allies.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Fanatic = preload("res://scripts/enemies/fanatical_mage.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false); g.set_process(false)
	g._restart(24); g.clock_time = 10
	g.model.hit_enemy(0,g.model.enemies[0].hp,true)
	g.model.BossRules.finish_attack_sequence(g.model)
	var demon: int = g.model.enemies.size()-1
	check(g.model.enemies[demon].role == g.model.EnemyCatalog.Role.BOUND_DEMON,"Phase two creates the Demon")
	check(g.model.enemies[demon].arrival_started == 10 and g.BattlefieldRender.arrival_progress(g,demon) == 0,"Phase spawn records its own initial entry clock")
	g.clock_time = 11; g._update_battlefield_view(1)
	var position_before: Vector2 = g._enemy_feet(demon)
	Fanatic.summon(g.model,0)
	check(g.model.enemies[demon].arrival_started == 10 and g.BattlefieldRender.arrival_progress(g,demon) == 1,"Later summons do not restart the Demon's entry")
	check(g._enemy_feet(demon).is_equal_approx(position_before),"Existing Demon remains at its settled battlefield position")
	for i in Fanatic.servants(g.model,0):
		check(g.model.enemies[i].arrival_started == 11 and g.BattlefieldRender.arrival_progress(g,i) == 0,"Only new minions slide in")
	g.clock_time = 12; Fanatic.split(g.model,0)
	check(g.model.enemies[demon].arrival_started == 10 and g._enemy_feet(demon).is_equal_approx(position_before),"Splitting minions also leaves the Demon stationary")
	for i in Fanatic.servants(g.model,0): check(g.model.enemies[i].arrival_started == 12,"Split tentacles each have a fresh arrival clock")
	g.clock_time = 13
	check(g.BattlefieldRender.labels_visible(g,demon),"Settled Demon keeps its health and intent UI")
	g._restart(8); g.clock_time = 20; g.model.hit_enemy(0,g.model.enemies[0].hp,true)
	g.model.BossRules.finish_attack_sequence(g.model)
	check(g.model.enemies.slice(1).all(func(e): return e.arrival_started == 20),"Commander guards share the same per-unit entry lifecycle")
	g.queue_free(); await process_frame

func run() -> void:
	await scene(false); await scene(true)
	print("Reinforcement arrival: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
