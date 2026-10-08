extends SceneTree
const Home = preload("res://scripts/home.gd")
var home

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	home._update_preview()
	home.queue_redraw()
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/home-" + ("portrait-" if home.portrait else "landscape-") + label + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-output")
	home = Home.new()
	home.portrait = not "--landscape" in OS.get_cmdline_user_args()
	home.muted = true
	root.add_child(home)
	await create_timer(0.3).timeout
	await capture("play")
	home.page = 1
	await capture("ancients")
	home.modal = "ancients"
	await capture("picker")
	home.modal = "skills"
	for i in range(3):
		home.skill_page = i
		await capture("skills-%d" % i)
	home.modal = ""
	home.page = 0
	await capture("dices")
	home.modal = "dice"
	await capture("dice-detail")
	home.modal = ""
	home.page = 3
	await capture("summon")
	home.page = 4
	await capture("shop")
	home.queue_free()
	await process_frame
	quit()
