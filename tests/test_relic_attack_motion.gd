extends SceneTree
## Exercise production attacks, visual impact timing and both battlefield layouts.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Orbit = preload("res://scripts/relics/relic_orbit.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func clean(g, ids: Array) -> void:
	g.relic_attacks.clear()
	g.model.relics.items.clear()
	g.relic_ui.activations.clear()
	g.relic_ui.pickup.active = false
	g.model.enemies = [g.model.make_enemy(0),g.model.make_enemy(1)]
	for enemy in g.model.enemies: enemy.hp = 10000; enemy.max_hp = 10000; enemy.shield = 0
	for id in ids: g.model.acquire_relic(id)
	g.model.hp = g.model.max_hp
	g.model.phase = "player"
	g.view_phase = "resolving"
	g.fx.clear()
	g.fallen.clear()
	g.enemy_debris.clear()
	g.enemy_dust.clear()
	g.health_trails.reset(g.model)
	g.pet_companions.sync(g.model)
	g.relic_attacks.cosmetic.seed = 41

func attack(g, id: String, amount: int = 100, area: bool = false) -> Array:
	var events: Array = g.model.RelicEffects.Attack.apply(g.model,id,amount,true,area,0)
	g._show_events(events)
	return events

## Exercise the actual await loop as well as the manually stepped animation poses.
func resolve_opening(g, receipt: Dictionary) -> void:
	receipt.result = await g._resolve_roll_triggers(g.run_id)
	receipt.done = true

func run() -> void:
	for phone in [false,true]:
		root.content_scale_size = Vector2i(804,1748) if phone else Vector2i(1280,800)
		root.size = root.content_scale_size
		var g = Portrait.new() if phone else Battle.new()
		root.add_child(g)
		g.muted = true
		g.process_mode = Node.PROCESS_MODE_DISABLED
		clean(g,["worn_spear"])
		var rng_before: int = g.model.rng.state
		attack(g,"worn_spear")
		check(g.model.enemies[0].hp == 9900,"Rules still commit exactly one hit immediately")
		check(g.model.rng.state == rng_before,"Cosmetic flight never changes gameplay randomness")
		check(g.relic_attacks.flights.size() == 1 and g.relic_attacks.holds(0),"Living target is held until the hit")
		check(g.relic_attacks.owns(0),"Airborne weapon replaces its orbit icon")
		check(g.fx.floats.is_empty(),"Damage text waits for the flying weapon")
		check(g.relic_attacks.state_for(0).hp == 10000,"HP presentation retains the pre-hit health")
		var flight: Dictionary = g.relic_attacks.flights[0]
		var peak: Dictionary = g.relic_attacks.pose_at(flight,0.22)
		check(peak.at.y < flight.start.y-30,"Weapon rises clearly before attacking")
		var midway: Dictionary = g.relic_attacks.pose_at(flight,0.30)
		check(midway.at.distance_to(flight.center) > g.relic_attacks.pose_at(flight,0.37).at.distance_to(flight.center),"The jab accelerates toward its target")
		g.relic_attacks.advance(0.38)
		check(not g.relic_attacks.pending() and g.fx.floats.size() == 1,"One impact delivers one popup")
		check(not g.relic_attacks.holds(0) and g.health_trails.bars[0].hp == 9900,"Impact releases health and starts its trail")
		check(g.relic_attacks.owns(0),"Weapon remains airborne while recoiling")
		g.relic_ui.ready_clock += 0.5
		var home: Vector2 = Orbit.poses(g)[0].at
		check(g.relic_attacks.pose_at(flight,flight.duration).at.distance_to(home) < 0.01,"Return follows the moving orbit")
		g.relic_attacks.advance(0.3)
		check(g.relic_attacks.flights.is_empty() and not g.relic_attacks.owns(0),"Satellite resumes without a leftover duplicate")
		clean(g,["worn_spear","worn_bow"])
		attack(g,"worn_spear")
		flight = g.relic_attacks.flights[0]
		g.model.relics.move(0,1)
		check(g.relic_attacks.owns(1) and not g.relic_attacks.owns(0),"Reordering in inventory keeps the correct physical weapon hidden")
		var moved_pose: Dictionary = Orbit.poses(g).filter(func(p): return p.item.id == "worn_spear")[0]
		check(g.relic_attacks.pose_at(flight,flight.duration).at.distance_to(moved_pose.at) < 0.01,"Reordered weapon returns to its new slot")
		clean(g,["worn_bow"])
		attack(g,"worn_bow")
		flight = g.relic_attacks.flights[0]
		check(flight.kind == "orb" and not g.relic_attacks.owns(0),"Ranged relic stays in orbit and fires an orb")
		check(flight.lift == flight.start,"Ranged item does not jab or fly at the enemy")
		var orb_end: Vector2 = g.relic_attacks.orb_point(flight,flight.points[0],1)
		check(orb_end.distance_to(flight.points[0]) < 0.01,"Orb lands exactly on the chosen target")
		var bow_start: Dictionary = Orbit.poses(g)[0]
		g.relic_attacks.advance(0.16)
		var bow_raised: Dictionary = Orbit.poses(g)[0]
		check(bow_raised.at.y < bow_start.at.y-flight.radius*1.8,"Ranged icon pops much higher before shooting")
		check(bow_raised.cast_pop > 1 and 1+bow_raised.strength*0.14+bow_raised.cast_pop*Orbit.RANGED_POP_GROWTH > 1.8,"Ranged icon overshoots into a pronounced enlargement")
		check(bow_raised.radius == bow_start.radius,"Visual enlargement never compounds the projectile size on repeated activations")
		check(flight.lift.distance_to(bow_raised.at) < 0.01,"Charge and projectile origin follow the raised relic")
		g.relic_attacks.advance(0.14)
		check(g.relic_attacks.ranged_pop(flight.owner) >= 1,"Ranged icon stays large through the shot")
		g.relic_attacks.advance(0.22)
		check(g.relic_attacks.ranged_pop(flight.owner) < 0.5,"Ranged icon smoothly settles after firing")
		g.relic_attacks.advance(0.2)
		check(Orbit.poses(g)[0].cast_pop == 0,"Ranged icon returns to ordinary orbit size")
		clean(g,["pet_dragon"])
		attack(g,"pet_dragon")
		flight = g.relic_attacks.flights[0]
		var pet: Dictionary = g.pet_companions.poses(g)[0]
		check(flight.start.distance_to(pet.at+Vector2(pet.size*0.22,-pet.size*0.55)) < 0.01,"Pet projectiles start at the creature, not its food icon")
		clean(g,["witch_ghost"])
		attack(g,"witch_ghost")
		check(g.relic_attacks.flights[0].kind == "witch","Witch has a separate spectral spell profile")
		clean(g,["war_hammer"])
		attack(g,"war_hammer",100,true)
		check(g.relic_attacks.flights.size() == 1 and g.relic_attacks.flights[0].points.size() == 2,"Area attack uses one relic with all target impacts")
		g.relic_attacks.advance(0.4)
		check(g.fx.floats.size() == 2,"Area impact delivers one number per enemy")
		clean(g,["worn_spear","overflow_prism"])
		attack(g,"worn_spear")
		check(g.relic_attacks.flights.size() == 2,"Prism keeps its own projectile instead of borrowing the spear")
		var total_hp: int = g.model.enemies[0].hp+g.model.enemies[1].hp
		g.relic_attacks.advance(2.0)
		check(g.model.enemies[0].hp+g.model.enemies[1].hp == total_hp,"Playing nested visuals does not repeat damage")
		clean(g,["worn_spear"])
		attack(g,"worn_spear"); attack(g,"worn_spear")
		check(g.relic_attacks.flights[1].age < 0,"Repeated effects queue instead of cloning an airborne icon")
		g.relic_attacks.advance(0.4)
		check(g.relic_attacks.state_for(0).hp == 9900,"Second flight preserves intermediate HP")
		g.relic_attacks.advance(1.0)
		check(g.fx.floats.size() == 2 and g.model.enemies[0].hp == 9800,"Queued hits each land exactly once")
		clean(g,["worn_spear"])
		g.model.enemies[0].hp = 1
		attack(g,"worn_spear")
		check(g._enemy_presented_alive(0) and not g.fallen.has(0),"Lethal hit waits for the weapon before death animation")
		g.crystal_pickup.advance(0.2)
		g.soul_pickup.advance(0.2)
		check(not g.crystal_pickup.gems.is_empty() and not g.soul_pickup.orbs.is_empty(),"Held loot receipts survive updates")
		g.relic_attacks.advance(0.4)
		check(g.fallen.has(0) and not g._enemy_presented_alive(0),"Death is registered at impact")
		clean(g,["worn_spear"])
		g.reduced = true
		attack(g,"worn_spear")
		check(g.relic_attacks.flights[0].impact < 0.38,"Reduced effects use a shorter sequence")
		g.relic_attacks.clear()
		check(not g.relic_attacks.pending() and not g.relic_attacks.holds(0),"Reset discards all held presentation")
		g.reduced = false
		clean(g,["worn_spear","worn_bow"])
		g.model.roll_pool(false,[1,2,3,4,5,6])
		var resolved := {"done":false,"result":false}
		resolve_opening(g,resolved)
		for frame in range(240):
			g.relic_attacks.advance(0.05)
			await process_frame
			if resolved.done: break
		check(resolved.done and resolved.result,"Opening relic queue returns control without stranding a turn")
		check(not g.model.perfect_relic_ready and not g.relic_attacks.pending(),"Rules and impact queues both finish")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			for id in ["worn_spear","worn_bow","witch_ghost"]:
				clean(g,[id]); g.witch_companion.advance(0.5,g.model)
				attack(g,id)
				for at_time in [0.14,0.30,0.36,0.48]:
					g.relic_attacks.advance(at_time-g.relic_attacks.flights[0].age)
					g.queue_redraw(); g.arena_actors.queue_redraw(); g.fx.queue_redraw()
					await process_frame
					RenderingServer.force_draw()
					root.get_texture().get_image().save_png("/tmp/relic-%s-%s-%03d.png" % [id,"phone" if phone else "wide",roundi(at_time*100)])
		g.queue_free(); await process_frame
	print("Relic attack motion: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
