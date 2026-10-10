extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var game
var portrait: bool

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://test-output/skill-"+name+("-portrait" if portrait else "-landscape")+".png")

func run() -> void:
	portrait = "--portrait" in OS.get_cmdline_user_args()
	if not portrait:
		root.content_scale_size = Vector2i(1280,800)
		root.size = Vector2i(1280,800)
	game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = true
	game.model.stage = 6
	game.model.power = 9.0
	game.model._load_wave()
	game.visual_stage = 6
	game.monster_side = game.HORROR_SIZES[6]
	game._start_round()
	game.model.set_status_counts({2:4,3:3,33:2,6:1})
	game.model.perfect_progress = 9
	game.result = game.model.set_test_roll([5,5,3])
	game.status_color = game.TEAL
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	game.view_phase = "skill"
	await shot("held")
	game.model.saved_skill = game.Rules.classify([5,5,5])
	game._sync_saved_bubble()
	await shot("bank-filled")
	game._handle_click(game._saved_slot_center())
	game._handle_motion(game.ARENA.get_center())
	await shot("saved-selected")
	game.saved_bubble.lock_cast_position(game.saved_bubble.display_center())
	game._cancel_targeting()
	game.view_phase = "resolving"
	game.casting_source = "saved"
	game.saved_bubble.consume_use()
	await shot("saved-cast")
	game.saved_bubble.dissolve()
	game.saved_bubble.dissolve_age = 0.2
	await shot("saved-dissolve")
	game.casting_source = ""
	game.saved_bubble.clear()
	game._sync_saved_bubble()
	game.view_phase = "skill"
	game.result = game.Rules.classify([3,3,4])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	game._handle_click(game._skill_center())
	game._handle_motion(game.ARENA.get_center())
	await shot("support-selected")
	game._cancel_targeting()
	game.result = game.Rules.classify([2,2,4])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	await shot("regen-held")
	game._cancel_targeting()
	game.result = game.Rules.classify([5,5,3])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	game.set_process_input(false)
	game.skill_bubble.consume_use()
	game.skill_bubble.cast_age = 0.15
	game.skill_bubble.pops[0].age = 0.15
	await shot("charge-pop")
	game.skill_bubble.age = (game.skill_bubble.converge+game.skill_bubble.RISE+0.1)/game.skill_bubble.entrance_speed
	await shot("center-reveal")
	game.result = game.Rules.classify([5,5,5])
	game.status_color = game.PURPLE
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	game.view_phase = "resolving"
	game.casting_source = "current"
	game.skill_bubble.lock_cast_position(game._enemy_point(4))
	game._begin_cast_cinematic(game.Rules.Kind.SPECIAL)
	await shot("cast-pause")
	game.cinematic_remaining = game.cinematic_duration-game.cinematic_pause-0.08
	await shot("cast-slow")
	game.cinematic_remaining = 0
	game.casting_source = ""
	game.result = game.Rules.classify([1,1,6])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	game.view_phase = "targeting"
	game.hover_target = 4
	await shot("damage-selected")
	game.result = game.Rules.classify([1,1,1])
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 4
	game.view_phase = "targeting"
	game.hover_target = 4
	game.skill_dragging = true
	game.skill_pointer = game._enemy_point(4)
	await shot("drag")
	game._cancel_targeting()
	game.result = game.Rules.classify([6,6,6])
	game.status_color = game.GOLD
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = 2
	game._begin_cinematic(true)
	game.fx.flashes.clear()
	await shot("omen")
	for stage in [1, 4, 8]:
		game._clear_skill()
		game.model.stage = stage
		game.model._load_wave()
		game.visual_stage = stage
		game.monster_side = game.HORROR_SIZES[stage]
		game.view_phase = "ready"
		await shot("enemy-bars-%d" % stage)
	game._clear_skill()
	game.model.pending = MultiHitSkill.new()
	game.view_phase = "ready"
	await shot("milestones")
	game.model._load_wave()
	game._start_round()
	game._start_charge()
	game.throw_meter.elapsed = game.ThrowMeter.PERIOD*0.225
	game.charge_stamp = Time.get_ticks_usec()
	await shot("short-meter")
	for tier in range(1,4):
		game._restart()
		game.model.stage = 9
		game.model._load_wave()
		game.model.city_hp = 0
		game.model.perfect_progress = tier*3
		game.visual_stage = 9
		game.monster_side = game.HORROR_SIZES[9]
		game._check_over()
		game.auto_claim_remaining = 2.0
		await shot("auto-claim-"+game.CHEST_NAMES[tier].to_lower())
	game.queue_free()
	await process_frame
	quit()
