extends SceneTree
const Effects = preload("res://scripts/effects/effects.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

## Check ballistic movement, separation, reduced motion and real combat event routing.
func run() -> void:
	var fx = Effects.new()
	fx.cosmetic.seed = 42
	fx.damage_number(Vector2(400,300),"120",Color.RED,48,0)
	fx.damage_number(Vector2(400,300),"120",Color.RED,48,0)
	var first: Dictionary = fx.floats[0]
	var second: Dictionary = fx.floats[1]
	check(first.velocity.x*second.velocity.x < 0,"Repeated hits fan to opposite sides")
	var start: Vector2 = first.p
	fx._process(0.2)
	check(first.p.y < start.y and absf(first.p.x-start.x) > 20,"Damage rises and moves sideways")
	check(first.p.distance_to(second.p) > 40,"Overlapping hits separate visibly")
	fx._process(0.6)
	check(first.velocity.y > 0,"Gravity turns the upward throw into a downward arc")
	fx._process(0.61)
	check(fx.floats.is_empty(),"Arc popups expire normally")
	fx.damage_number(Vector2.ZERO,"",Color.RED)
	check(fx.floats.is_empty(),"Instant kills still omit damage numbers")
	fx.reduced = true
	fx.damage_number(Vector2(400,300),"5",Color.RED)
	check(absf(fx.floats[0].velocity.x) <= 63,"Reduced effects use a gentler spread")
	fx.free()
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
		g.fx.clear()
		var rng_state: int = g.model.rng.state
		g._show_events([g.Rules.damage_event(0,25,25),g.Rules.damage_event(-1,15,15),g.Rules.event(0,5,"burn","BURN"),g.Rules.event(0,3,"shield_hit","SHIELD")])
		check(g.fx.floats.filter(func(f): return f.has("velocity")).size() == 4,"Enemy, player, Burning and shield damage all use arcs")
		check(g.model.rng.state == rng_state,"Number trajectories never consume gameplay randomness")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			g.fx.clear()
			g.fx.cosmetic.seed = 17
			for i in range(7):
				g._show_events([g.Rules.damage_event(0,120+i,120+i),g.Rules.damage_event(-1,12+i,12+i)])
				g.fx._process(0.1)
			g.queue_redraw(); g.fx.queue_redraw()
			await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/evil-dice-damage-arcs-%s.png" % ["portrait" if phone else "landscape"])
		g.queue_free(); await process_frame
	print("Damage number arcs: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
