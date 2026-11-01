extends SceneTree
## Fixed debug tiers use real loot rules while leaving upgrades and battle progress alone.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func rules() -> void:
	var m = Run.new(51)
	m.reroll_progress = 12
	m.chest_pity.misses = [5,4,3]
	m.chest_pity.last_misses = [1,2,3]
	for tier in range(4):
		var rewards: Array = m.open_debug_chest(tier)
		check(m.opened_chest_tier == tier and rewards.size() == m.Chests.COUNTS[tier],"Exact tier uses its real number of prizes")
		check(m.chest_pity.misses == [5,4,3] and m.chest_pity.last_misses == [1,2,3],"Fixed tiers never consume or reset pity")
		check(m.reroll_progress == 12 and m.stage == 0,"Spawning preserves treasure and wave progress")
		if tier > 0:
			var id: String = m.chest_relics[m.guaranteed_slot]
			check(m.Relics.Catalog.ITEMS[id].rarity >= m.Chests.MIN_RARITY[tier],"Tier keeps its real guaranteed rarity")
		var before: int = m.reward_rng.state
		check(m.open_debug_chest(tier).is_empty() and m.reward_rng.state == before,"A pending prize set cannot be duplicated or rerolled")
		m.discard_unclaimed_rewards(); m.close_chest()
	for tier in [-2,4,999]:
		var before: int = m.reward_rng.state
		check(m.open_debug_chest(tier).is_empty() and m.reward_rng.state == before,"Invalid tiers cannot mutate rewards")
	m.chest_pity.misses = [5,5,5]
	check(m.open_debug_chest().size() == 5 and m.chest_pity.misses == [0,0,0],"Original upgradeable shortcut retains real upgrade rules")

func capture(g, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	g.menu_canvas.queue_redraw(); g.chest.queue_redraw(); g.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/debug-chests-"+name+".png")

func scene(phone: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
	root.size = Vector2i(402,874) if phone else Vector2i(1280,800)
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
	g.chest.audio_clock_enabled = false
	var stage: int = g.model.stage
	var enemies: Array = g.model.enemies.duplicate(true)
	g.model.chest_pity.misses = [5,5,5]
	g._open_debug(); g.debug_page.click(g.debug_page.tab_rect(2).get_center())
	var controls: Array = g.debug_page.buttons()
	check(controls.size() == 9,"Reward tab retains existing tools plus all four exact tiers")
	for i in range(controls.size()):
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(controls[i][0]),"Every debug button fits the screen")
		for j in range(i): check(not controls[i][0].intersects(controls[j][0]),"Reward buttons never overlap")
	await capture(g,"phone" if phone else "desktop")
	for tier in range(4):
		if not g.debug_open: g._open_debug()
		g.debug_page.click(g.debug_page.tab_rect(2).get_center())
		g._handle_click(g.debug_page.chest_option_rect(tier).get_center())
		check(not g.debug_open and g.view_phase == "reward" and g.chest.visible,"Actual tier button opens the chest page")
		check(g.chest.tier == tier and not g.chest.upgrade_mode and g.chest.roll_phase == "closed","Selected chest appears directly at the chosen tier")
		check(g.model.chest_pity.misses == [5,5,5],"UI tier spawn preserves stored upgrade guarantees")
		var before: Array = g.model.open_rewards.duplicate()
		g._debug_spawn_chest(tier)
		check(g.model.open_rewards == before,"Repeated debug call cannot overwrite an open chest")
		g._handle_click(g.chest.closed_rect().get_center())
		check(g.chest.roll_phase == ("settling" if tier == 3 else "spinning"),"Each tier uses its normal opening and audio sequence")
		g.model.discard_unclaimed_rewards(); g.chest.skip_remaining(); g.crystal_pickup.reset()
		for i in range(3): await process_frame
		check(g.view_phase == "ready" and not g.chest.visible,"Leaving returns to the original battle")
		check(g.model.stage == stage and g.model.enemies == enemies,"Debug prize flow preserves the encounter")
	g._open_debug(); g.debug_page.click(g.debug_page.tab_rect(2).get_center())
	g._handle_click(g.DEBUG_CHEST.get_center())
	check(g.chest.upgrade_mode and g.chest.tier == 0 and g.model.opened_chest_tier == 3,"Retained upgrade button still starts Normal and reveals its rolled tier")
	g.model.discard_unclaimed_rewards(); g.chest.skip_remaining(); g.crystal_pickup.reset()
	for i in range(3): await process_frame
	g.queue_free(); await process_frame

func run() -> void:
	rules(); await scene(true); await scene(false)
	print("Debug chest tiers: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
