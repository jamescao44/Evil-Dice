extends SceneTree
## Check automatic relic casts and inspect the new items in both live layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func capture(g, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	g.queue_redraw(); g.inventory_page.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/new-relics-"+label+".png")

func inspect_layout(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2; g.set_process_input(false)
	var label: String = "portrait" if phone else "landscape"
	g.model.relics.clear()
	for id in ["glass_marble","steel_marble","gold_marble","magic_slingshot","royal_seal","echo_bell","alternating_gears","powder_keg","overflow_prism","magician_hat","piggy_bank","bookmark"]: g.model.acquire_relic(id)
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1)]
	for e in g.model.enemies: e.hp = 100000; e.max_hp = 100000
	g.model.phase = "round_end"
	g._start_round()
	var end: int = Time.get_ticks_msec()+15000
	while (g.model.phase != "roll" or g.view_phase != "ready") and Time.get_ticks_msec() < end: await process_frame
	check(g.model.phase == "roll" and g.view_phase == "ready",label+": automatic missile completes and restores rolling controls")
	check(g.model.dice_turn.rolls_left == 3 and g.model.character_passive.charge == 1,label+": missile spends no dice and counts as a skill")
	g.inventory_page.open()
	await capture(g,label+"-inventory")
	for i in range(g.model.relics.items.size()):
		check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(g.inventory_page.slot_rect(i)),label+": item slot stays on screen")
	g.inventory_page.selected = 0
	await capture(g,label+"-fusion")
	g.inventory_page.close()
	g.model.relics.clear(); g.model.acquire_relic("echo_bell"); g.model.relics.items[0]["casts"] = 2
	g.model.character_passive.charge = 0
	g.model.pending = g.model.Patterns.classify([3,4,5]); g.model.phase = "player"
	g._show_pending_skill(false)
	g._resolve_player(0)
	end = Time.get_ticks_msec()+15000
	while (g.model.phase != "roll" or g.view_phase != "ready") and Time.get_ticks_msec() < end: await process_frame
	check(g.model.phase == "roll" and g.view_phase == "ready",label+": echo animates automatically without leaving an unclickable pending skill")
	check(g.model.character_passive.charge == 1 and g.model.relics.items[0].casts == 0,label+": echo cannot recharge itself or the character")
	g.model.relics.clear()
	g.model.character_passive.charge = 2
	g.model.pending = g.model.Patterns.classify([1,2,3]); g.model.phase = "player"
	g._show_pending_skill(false)
	g._resolve_player(0)
	var casts: Dictionary = {}
	var all_single := true
	end = Time.get_ticks_msec()+15000
	while (g.model.phase != "roll" or g.view_phase != "ready") and Time.get_ticks_msec() < end:
		if g.model.phase == "executing":
			casts[g.model.pending.get_instance_id()] = g.model.pending.cast_source
			all_single = all_single and g.model.pending.use_count() == 1 and not g.skill_bubble.roll.has_use_orbs()
		await process_frame
	check(casts.size() == 3 and casts.values().count("character_bonus") == 2,label+": three separate cast animations run automatically")
	check(all_single,label+": original and bonus bubbles never acquire multi-hit orbs")
	check(g.model.phase == "roll" and g.view_phase == "ready" and g.model.character_passive.charge == 0,label+": bonus skills return control without recharging themselves")
	g.queue_free(); await process_frame

func _initialize() -> void: call_deferred("run")
func run() -> void:
	for phone in [false,true]: await inspect_layout(phone)
	print("New relic scenes: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
