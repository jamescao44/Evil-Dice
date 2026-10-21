extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Verify receipts, pause/reset and level-overflow counters without a second reward grant.
func scene(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.set_process(false); g.set_process_input(false)
	var p = g.soul_pickup
	p.set_process(false)
	g.model.souls = 29
	g.model.gain_souls(20)
	var state: int = g.model.reward_rng.state
	var origin: Vector2 = g.wave_chest.chest_rect().get_center()
	g.view_phase = "wave_reward"
	g.wave_chest.present_chest(g.model.WaveRewards.SOULS)
	g.wave_chest.reveal_amount(20)
	p.enqueue(origin,20,29,1)
	check(p.orbs.size() == 40 and p.pending_total == 20 and p.counter_text() == "29/30","Many soul orbs represent the exact committed amount")
	g.debug_open = true; p._process(0.5)
	check(p.orbs[0].age == 0 and not p.visible,"Menus hide and pause soul receipts")
	g.debug_open = false; p.visible = true
	p.advance(0.5)
	check(p.pending_total == 20 and p.orbs.all(func(o): return p.position_of(o).distance_to(o.rest) < 5),"Souls scatter and hover before any pickup")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://test-output/soul-orbs-"+str(portrait)+".png")
	p.advance(0.65)
	check(p.pending_total > 0 and p.pending_total < 20,"Staggered orb arrivals progressively reveal the soul count")
	p.advance(1)
	check(p.orbs.is_empty() and p.pending_total == 0 and p.counter_text() == "19/50","Counter accounts for automatic level spending and leftover souls")
	check(g.model.character_level == 2 and g.model.souls == 19 and g.model.reward_rng.state == state,"Visuals never grant twice or use reward RNG")
	g.model.gain_souls(100)
	p.enqueue(origin,100,19,2)
	p.advance(1.1)
	check(p.counter_state().level <= 3,"Animated receipts cannot reach a removed fourth level")
	p.advance(2)
	check(p.counter_text() == "69" and p.counter_state().level == 3,"Maximum-level receipt shows excess souls without a next-level threshold")
	check(g.evolution.forms.size() == 3 and g.evolution.forms[0].resource_path.ends_with("level-2.png") and g.evolution.forms[2].resource_path.ends_with("level-4.png"),"Three forms omit the ember starter and retain the final evolution")
	g.reduced = true; p.enqueue(origin,40,19,2); p.advance(3)
	check(p.orbs.is_empty(),"Reduced effects still completes every soul receipt")
	var gems = g.crystal_pickup
	gems.set_process(false); gems.enqueue_chest(origin,400)
	gems.advance(1.3)
	check(gems.gems.is_empty() and gems.pending_total == 0,"Even the largest direct chest gem burst is collected within 1.3 seconds")
	gems.enqueue(0,5); gems.advance(0.7)
	check(gems.pending_total == 5,"Enemy drops retain their ground pause")
	p.enqueue(origin,10,0,1)
	g._restart()
	check(p.pending_total == 0 and p.orbs.is_empty() and p.counter_text() == "0/30","Restart clears receipts and restores the real counter")
	g.queue_free(); await process_frame

func run() -> void:
	await scene(false)
	await scene(true)
	print("Soul pickups: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
