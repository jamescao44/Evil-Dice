extends SceneTree
## Exercise per-prize reveals without a campaign scene or saved progress.
const Chest = preload("res://scripts/rewards/reward_chest.gd")
const Display = preload("res://scripts/relics/relic_rarity_display.gd")
const FontFileAsset = preload("res://assets/fonts/Silkscreen-Regular.ttf")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Optional native captures show foreground ordering in both chest layouts.
func capture(chest, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	chest.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	chest.get_viewport().get_texture().get_image().save_png("res://test-output/relic-reveal-"+label+".png")

func run() -> void:
	GameText.set_language("en",false)
	for rarity in range(5):
		for reduced in [false,true]:
			var peak: Dictionary = Display.reveal_pose(rarity,Display.REVEAL_SPIN,reduced)
			var featured: bool = rarity >= 3 and not reduced
			check(is_equal_approx(peak.scale,2.6 if featured else 1.0),"Only Legendary/Cursed chest prizes get the larger spin")
			for age in [-1.0,Display.REVEAL_DURATION,5.0]:
				var rest: Dictionary = Display.reveal_pose(rarity,age,reduced)
				check(rest.scale == 1 and rest.angle == 0 and rest.lift == 0 and rest.squash == Vector2.ONE,"Shop offers and finished reveals return to neutral")
	for rarity in [3,4]:
		var strike: Dictionary = Display.reveal_pose(rarity,Display.REVEAL_SPIN+Display.REVEAL_SLAM)
		var rebound: Dictionary = Display.reveal_pose(rarity,Display.REVEAL_SPIN+Display.REVEAL_SLAM+Display.REVEAL_BOB/2)
		check(is_equal_approx(strike.scale,1) and is_zero_approx(strike.lift) and strike.impact > 0.99,"Slam returns to the prize slot at normal size")
		check(rebound.lift < strike.lift and rebound.scale == 1,"One small rebound follows the slam")
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var chest = Chest.new()
	viewport.add_child(chest); chest.set_process(false); chest.audio_clock_enabled = false
	for portrait in [false,true]:
		var canvas := Vector2(804,1748) if portrait else Vector2(1280,800)
		viewport.size = canvas
		chest.start([1,1,1],canvas,FontFileAsset,false,[{"relic_id":"pet_dragon"},{"relic_id":"reaper_scythe"},{"relic_id":"codex_page"}],2)
		chest.open_chest(); chest._begin_settle(0)
		var locked: Array = chest.rewards.duplicate()
		var rng_state: int = chest.cosmetic.state
		chest.elapsed = chest.stop_time(1)+0.01
		check(chest._featured_reveal(1) and not chest._featured_reveal(0),"Each special reveal begins on its own prize's musical stop")
		for age in [0.27,0.54,0.68,0.86,1.1]:
			chest.elapsed = chest.stop_time(0)+age
			await capture(chest,("portrait" if portrait else "landscape")+"-"+str(age))
		check(chest.rewards == locked and chest.cosmetic.state == rng_state,"Cosmetic poses never reroll or mutate the prizes")
		check(not chest._featured_reveal(0) and not chest._featured_reveal(1),"Finished reveals stop instead of repeating")
		chest.reduced = true; chest.elapsed = chest.stop_time(0)+0.1
		check(not chest._featured_reveal(0),"Reduced effects suppress spinning and enlargement")
		chest.cancel()
	chest.free()
	viewport.free()
	print("Chest relic reveal: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
