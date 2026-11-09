extends SceneTree
## Real enemy actions wait for XP receipts and every queued level celebration.
const Battle = preload("res://scripts/combat/battle.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
var checks := 0
var failures := 0

class FastBattle extends Battle:
	var finished := false
	## Skip attack presentation delays; keep the actual level-up wait under test.
	func _wait(_seconds: float, token: int = -1, _real_time: bool = false, _fixed_speed: float = -1.0, _minimum_real_seconds: float = 0.0) -> bool:
		return token == -1 or _valid_turn(token)
	func _start_round() -> void: finished = true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var g = FastBattle.new()
	root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
	g.soul_pickup.set_process(false); g.evolution.set_process(false)
	g.model.enemies = [Enemy.make(Enemy.Role.MAGE),Enemy.make(Enemy.Role.VANGUARD),Enemy.make(Enemy.Role.ARCHER)]
	g.model.phase = "enemy"; g.view_phase = "resolving"; g.finished = false
	for i in range(3): g.model.enemies[i].intent = g.model.EnemyActions.intent(g.model,i,"attack")
	return g

## Drive a phase without waiting for the test-controlled evolution animation.
func drive(g, receipt: Dictionary) -> void:
	await g._enemy_phase()
	receipt.done = true

func run() -> void:
	var g = fresh()
	g.model.gain_souls(100); g.soul_pickup.enqueue(g._player_point(),100)
	var receipt := {"done":false}
	drive(g,receipt)
	await process_frame
	check(g.model.enemies.all(func(e): return not e.acted),"Queued levels block the first enemy action")
	g.evolution._process(2)
	check(g.evolution.displayed_level == 1,"Celebrations wait until soul orbs reach the player")
	g.soul_pickup.advance(5)
	for level in range(2,6):
		g.evolution._process(0.1)
		await process_frame
		check(not g.model.enemies[0].acted,"Enemy stays idle throughout level %d animation" % level)
		g.evolution._process(g.evolution.duration())
		if level < 5:
			await process_frame
			check(not g.model.enemies[0].acted,"Additional queued levels cannot be skipped")
	await process_frame; await process_frame
	check(receipt.done and g.finished and g.model.enemies.all(func(e): return e.acted),"Combat resumes after the last evolution finishes")
	g.queue_free(); await process_frame

	g = fresh(); g.model.gain_souls(5)
	g.model.enemies[2].hp = 1
	g.model.enemies[0].intent = {"skill":"attack","type":"attack","target":2,"amount":10,"hits":1,"friendly_fire":true}
	receipt = {"done":false}; drive(g,receipt)
	await process_frame
	check(g.model.enemies[0].acted and not g.model.enemies[1].acted and g.model.enemies[2].hp == 0,"An enemy-action kill pauses before the next enemy")
	check(g.model.character_level == 2 and g.soul_pickup.pending_total == 5,"Real kill XP has queued its receipt and level-up")
	g.debug_open = true
	g.soul_pickup._process(5); g.evolution._process(5)
	check(not receipt.done and g.evolution.active(),"Opening a menu does not bypass the level-up wait")
	g.debug_open = false; g.soul_pickup.advance(5); g.evolution._process(0.1)
	await process_frame
	check(not g.model.enemies[1].acted,"Revealing the new level is not the end of its animation")
	g.evolution._process(2)
	await process_frame; await process_frame
	check(receipt.done and g.model.enemies[1].acted,"Next enemy acts once the full level animation ends")
	g.queue_free(); await process_frame

	g = fresh(); g.model.gain_souls(10)
	receipt = {"done":false}; drive(g,receipt)
	g.run_id += 1
	await process_frame; await process_frame
	check(receipt.done and not g.finished and g.model.enemies.all(func(e): return not e.acted),"Restart invalidates the waiting phase without performing stale attacks")
	g.queue_free(); await process_frame
	print("Enemy level-up sequencing: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _initialize() -> void: call_deferred("run")
