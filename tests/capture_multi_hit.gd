extends SceneTree
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var game
var portrait: bool

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/multi-hit-"+label+("-portrait" if portrait else "-landscape")+".png")

func show_skill(values: Array) -> void:
	game._cancel_targeting()
	game.model.phase = "roll"
	game.result = game.model.set_test_roll(values)
	game.skill_bubble.begin(game.result)
	game.skill_bubble.age = game.skill_bubble.formation+1
	game.view_phase = "skill"
	game.status_title = "SKILL READY"

func run() -> void:
	portrait = "--portrait" in OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i(1080,1920) if portrait else Vector2i(1280,800)
	root.size = root.content_scale_size
	game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = true
	game.reduced = true
	game.model.saved_skill = game.Rules.classify([5,5,5])
	game._sync_saved_bubble()
	show_skill([1,1,4])
	await shot("single-use")
	game.model.set_skill_use_multiplier("preview_echo",2)
	show_skill([5,5,5])
	await shot("twelve-orbs")
	show_skill([1,1,4])
	game._handle_click(game._skill_center())
	game._handle_release(game._skill_center())
	game.hover_target = 0
	await shot("aimed-two-uses")
	show_skill([2,2,4])
	await shot("support-two-uses")
	game.queue_free()
	await process_frame
	quit()
