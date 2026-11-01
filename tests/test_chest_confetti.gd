extends SceneTree
## Ultra celebration stays cosmetic; reward prompts track actual collection availability.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func start(g, tier: int, upgrade: bool = false, reduced: bool = false) -> void:
	g.model.close_chest()
	var values: Array = g.model._roll_chest(tier)
	var prizes: Array = range(values.size()).map(func(i): return g.model.reward_item(i))
	g.view_phase = "reward"
	g.chest.start(values,g.fx.canvas_size,g.description_font,reduced,prizes,tier,upgrade)

func capture(g, label: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture" not in OS.get_cmdline_user_args(): return
	g.chest.queue_redraw(); g.wave_chest.queue_redraw(); g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/chest-confetti-"+label+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false)
	var chest = g.chest
	chest.set_process(false)
	chest.audio_clock_enabled = false
	var layout: String = "phone" if phone else "desktop"
	start(g,3)
	check(chest.confetti.bursts.size() == 3,"Ultra appearance starts a large celebration before opening")
	chest._process(0.3)
	await capture(g,layout+"-closed")
	var before: int = chest.confetti.bursts.size()
	g._handle_click(Vector2(g.fx.canvas_size.x*0.5,g.fx.canvas_size.y*0.8))
	check(chest.roll_phase == "closed" and chest.confetti.bursts.size() == before+1,"An outside tap blooms without opening the chest")
	g._handle_click(chest.closed_rect().get_center())
	check(chest.roll_phase == "settling","Ultra still begins its unskippable musical sequence")
	chest._process(0.6)
	var elapsed: float = chest.elapsed
	var rewards: Array = chest.rewards.duplicate()
	var strips: Array = chest.sequences.duplicate(true)
	var reward_rng: int = g.model.reward_rng.state
	var filler_rng: int = chest.cosmetic.state
	var last_origin := Vector2.INF
	for i in range(6):
		g._handle_click(chest.reel_rect(0).get_center())
		check(chest.confetti.bursts.back().at != last_origin,"Repeated taps get different bloom positions")
		last_origin = chest.confetti.bursts.back().at
	check(chest.elapsed == elapsed and chest.announced == 0 and chest.active,"Taps do not skip or advance Ultra notes")
	check(chest.rewards == rewards and chest.sequences == strips and reward_rng == g.model.reward_rng.state and filler_rng == chest.cosmetic.state,"Confetti never changes rewards or cosmetic strips")
	check(not chest.reward_prompt_visible(0),"Spinning prizes have no collection arrow")
	chest._process(0.25)
	await capture(g,layout+"-blooms")
	chest.paused = true
	var count: int = chest.confetti.bursts.size()
	var clock: float = chest.confetti.clock
	chest.click(Vector2.ZERO); chest._process(1)
	check(chest.confetti.clock == clock and chest.confetti.bursts.size() == count,"Paused chest freezes and rejects particle taps")
	chest.paused = false
	chest._process(5)
	check(not chest.active and chest.reward_prompt_visible(0),"Collection arrows appear only after the reveal completes")
	check(chest.confetti.bursts.size() == 5,"Every Ultra prize creates one baked reveal bloom")
	for burst in chest.confetti.bursts:
		check(burst.role == "prize","Expired entrance confetti is replaced by prize blooms")
	var revealed_count: int = chest.confetti.bursts.size()
	chest._process(0)
	check(chest.confetti.bursts.size() == revealed_count,"Revealed prizes cannot emit twice")
	chest._process(0.25)
	await capture(g,layout+"-rewards")
	before = chest.confetti.bursts.size()
	g._handle_click(chest.reel_rect(0).get_center())
	check(chest.collected.has(0) and not chest.reward_prompt_visible(0),"Collecting removes that reward's arrow")
	check(chest.confetti.bursts.size() > before,"Reward taps still celebrate without blocking collection")
	g.relic_ui.pickup.clear()
	for i in range(40): chest.click(Vector2.ZERO)
	check(chest.confetti.bursts.size() <= chest.confetti.LIMIT,"Tap spam has bounded sprite storage")
	chest.cancel()
	check(chest.confetti.bursts.is_empty() and not chest.reward_prompt_visible(0),"Closing removes all celebration state")
	await process_frame
	start(g,3,true)
	check(chest.confetti.bursts.is_empty(),"A hidden future Ultra cannot reveal itself early")
	chest.open_chest()
	for i in range(3):
		chest.request_stop()
		if i < 2:
			check(chest.confetti.bursts.is_empty(),"Lower upgrade tiers do not get Ultra confetti")
			chest._process(chest.UPGRADE_BEAT+0.01)
	check(chest.tier == 3 and chest.confetti.bursts.size() == 3,"Upgrading into Ultra celebrates exactly when it appears")
	await process_frame
	for tier in range(3):
		start(g,tier)
		chest.open_chest(); chest.request_stop()
		g._handle_click(chest.reel_rect(0).get_center())
		check(not chest.active and chest.collected.is_empty(),"Skipping a lower-tier reveal cannot also collect with the same tap")
		check(chest.reward_prompt_visible(0) and chest.confetti.bursts.size() == chest.rewards.size() and chest.confetti.bursts[0].role == "prize","Every lower-tier prize gets an arrow and a reveal bloom")
		await process_frame
	start(g,3,false,true)
	check(chest.confetti.bursts.size() == 3 and chest.confetti.bursts[0].kind == "light_cannon","Reduced effects keeps a smaller celebration")
	await process_frame
	chest.cancel(); g.model.close_chest()
	g.view_phase = "wave_reward"
	g.model.enemies.clear(); g.fx.clear(); g.crystal_pickup.reset()
	g.wave_chest.present_chest(g.model.WaveRewards.RELIC)
	await capture(g,layout+"-field-chest")
	g.queue_free(); await process_frame
	# Let the dummy audio mixer release stopped payout voices before the next fixture.
	if DisplayServer.get_name() == "headless": await create_timer(0.1).timeout

func run() -> void:
	var effect = preload("res://scripts/rewards/chest_confetti.gd").new()
	var library = effect.Library
	for kind in library.CLIPS:
		for frames in library.CLIPS[kind]:
			check(frames.size() == ceili(library.FPS*library.DURATION),"Baked variant covers its full lifetime")
			for frame in frames:
				check(Rect2(Vector2.ZERO,library.PAGES[frame[0]].get_size()).encloses(frame[1]),"Atlas frame stays inside its texture")
	effect.prize(Vector2(20,30),Vector2(1280,800),false,0.45)
	effect.prize(Vector2(20,30),Vector2(1280,800),false,1.0)
	check(effect.bursts[0].scale < effect.bursts[1].scale,"Rarer prizes get a larger bloom")
	check(effect.bursts[0].variant != effect.bursts[1].variant,"Adjacent blooms use different variants")
	effect.advance(5)
	check(effect.bursts.is_empty(),"Completed baked animations release active state")
	await scene(true); await scene(false)
	print("Chest confetti: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
