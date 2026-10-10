extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Status = preload("res://scripts/status_effect.gd")
var g
var portrait: bool

func _initialize() -> void: call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/status-"+name+("-portrait" if portrait else "-landscape")+".png")

func run() -> void:
	portrait = "--portrait" in OS.get_cmdline_user_args()
	if not portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	g = Portrait.new() if portrait else Battle.new()
	root.add_child(g)
	g.muted = true
	g.model.stage = 1
	g.visual_stage = 1
	g.monster_side = g.HORROR_SIZES[1]
	g.model.enemies = [Rules.make_enemy(0,1,true),Rules.make_enemy(1,1,true),Rules.make_enemy(2,1,true)]
	for e in g.model.enemies: e.intent = {"type":"attack","target":-1,"amount":e.damage,"attribute":e.attribute}
	await shot("elite-moves")
	g._handle_click(g._enemy_point(1))
	g._update_enemy_hold(0.3)
	await shot("move-inspection")
	g._handle_release(g._enemy_point(1))
	g.model.enemies[0].intent = {"type":"shield","target":0,"amount":6}
	g.model.enemies[1].intent = {"type":"team_heal","target":1,"amount":0}
	g.model.enemies[2].intent = {"type":"empower","target":0,"amount":0}
	await shot("support-icons")
	g.model.set_status_counts({2:4,3:3,33:2,6:0,Status.FROZEN:1,Status.BURNING:4,Status.STUNNED:1})
	g.model.phase = "frozen"
	g.model.ice_hits_remaining = 3
	g.view_phase = "frozen"
	await shot("frozen")
	for hit in range(2):
		g._handle_click(g.DICE_CENTER)
		g._handle_release(g.DICE_CENTER)
	await shot("ice-cracks")
	g.model.statuses[Status.FROZEN].count = 0
	g.model.phase = "roll"
	g.view_phase = "ready"
	g._start_charge()
	g.throw_meter.advance(0.11)
	await shot("stunned")
	g._cancel_charge()
	g.model.stage = 8
	g.visual_stage = 8
	g.monster_side = g.HORROR_SIZES[8]
	g.model.rng.seed = 928
	g.model._load_wave()
	g.model.begin_round()
	for e in g.model.enemies:
		if e.elite: e.intent = {"type":"attack","target":-1,"amount":e.damage,"attribute":e.attribute}
	g.model.statuses[6].count = 2
	g.model.statuses[Status.FROZEN].count = 1
	g.model.phase = "frozen"
	g.model.ice_hits_remaining = 3
	g.view_phase = "frozen"
	g.status_title = "FROZEN"
	await shot("crowded")
	g._restart()
	g.model.stage = 9
	g.model._load_wave()
	g.model.begin_round()
	g.visual_stage = 9
	g.monster_side = g.HORROR_SIZES[9]
	g.model.set_test_roll([6,6,4])
	g.model.apply_player()
	g.model.troops = 4
	await shot("city-immunity")
	g.queue_free()
	await process_frame
	quit()
