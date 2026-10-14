extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/evil-tarot-pickup-"+label+".png")
func run() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 75124
	var count: Dictionary = {}
	for id in Tarot.ITEMS: count[id] = 0
	for i in range(44000): count[Tarot.draw_one(rng)] += 1
	check(absf(count.world/44000.0-0.5/21.5) < 0.003,"World has half the ordinary draw weight")
	var offered := 0
	for i in range(10000):
		var choices: Array = Tarot.draw_choices(rng)
		check(choices.size() == 3 and choices[0] != choices[1] and choices[1] != choices[2] and choices[0] != choices[2],"Reward choices remain distinct")
		offered += int("world" in choices)
	check(offered/10000.0 > 0.06 and offered/10000.0 < 0.085,"Three-card rewards use the reduced World weight")
	check(Tarot.draw_one(rng, Tarot.ITEMS.keys()) == "","Exhausted pool grants no card")
	check("world" not in Tarot.draw_choices(rng,["world"]),"Bans still exclude World")
	for portrait in [false,true]:
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g); g.muted = true
		g.set_process(false)
		var p = g.tarot_ui.pickup; p.set_process(false)
		g.model.acquire_relic("fortune_cookie")
		check(p.pending.size() == 1 and g.model.tarots.items.size() == 1,"Cookie commits and queues its card exactly once")
		g.menu_open = true; p._process(0.5)
		check(p.cards.is_empty() and not p.visible,"Grant waits behind settings")
		g.menu_open = false; p._process(0.4)
		check(p.cards.size() == 1 and p.visible,"Grant reveals after settings close")
		var card: Dictionary = p.cards[0]
		card.age = p.LAND_TIME
		check(p.pose(card).at == g.tarot_ui.icon_rect().get_center(),"Flight lands at the inventory icon in either layout")
		p.advance(2)
		check(p.cards.is_empty() and g.model.tarots.items.size() == 1,"Animation never awards a second copy")
		g.model.grant_random_tarots(4)
		p.advance(0.4)
		check(p.cards.size() == 3 and p.pending.size() == 1,"Multiple grants reveal in compact batches without being lost")
		await capture("portrait" if portrait else "landscape")
		p.advance(2); p.advance(0.4)
		check(p.cards.size() == 1 and p.pending.is_empty(),"Remaining grant follows the first batch")
		p.reset()
		g.model.begin_tarot_reward("debug"); g.model.choose_tarot(0)
		check(p.pending.is_empty(),"Hand-picked cards do not receive a duplicate animation")
		g._restart(g.Run.Waves.COUNT); g.set_process(false)
		g.model.grant_tarot("world"); p._process(0.4)
		var clock: float = g.model.volley_clock
		g._process(0.05)
		check(g.model.volley_clock < clock and not g.tarot_ui.blocks_battle(),"Automatic grant animation leaves city combat running")
		g._restart()
		check(p.cards.is_empty() and p.pending.is_empty(),"Restart clears pending and active receipt animations")
		g.debug_open = true; g._debug_give_tarots()
		check(p.pending.size() == 22 and g.model.tarots.items.size() == 22,"Debug still gives every tarot including World")
		g.queue_free(); await process_frame
	print("Tarot pickups and weights: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
