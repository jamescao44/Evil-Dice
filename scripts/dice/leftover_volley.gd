extends Node2D
## Direct die-pip projectiles; combat still owns damage, targets and turn completion.
const Orb = preload("res://scripts/combat/skill_orb_paint.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
var battle
var flight: Dictionary = {}
var active_die: int = -1
var launched: int = 0

func _ready() -> void:
	z_index = 80

## A restart clears the projectile immediately; its turn token cancels old work.
func clear() -> void:
	flight.clear()
	active_die = -1
	launched = 0
	queue_redraw()

## Launch from each printed pip in sequence, accelerating longer volleys gently.
func play(token: int) -> bool:
	clear()
	var indices: Array = battle.model.skill_dice_indices.duplicate()
	var budget: MultiHitSkill = battle.model.pending.duplicate()
	var count: int = battle.model.skill_use_count(budget)
	for hit in range(count):
		if not battle._valid_turn(token): return false
		var roll: MultiHitSkill = battle.model.pending.duplicate()
		var source: Vector2i = battle.model.Patterns.cleanup_source(budget,hit)
		active_die = indices[source.x]
		var die = battle.dice[active_die]
		var origin: Vector2 = battle.to_local(die.to_global(die.pip_offsets(budget.dice[source.x])[source.y]+Vector2(0,-2)))
		var target: int = battle.model.player_target()
		battle.attack_target = target
		var destination: Vector2 = battle.CITY_POINT if battle.model.is_city() else battle._enemy_impact_point(target)
		battle.damage_feedback.sync_value(battle.model.cast_damage_multiplier(roll))
		battle.damage_feedback.sync_hit(battle.model.attack_base(roll),battle.model.unmitigated_damage(roll))
		flight = {"from":origin,"to":destination,"age":0.0,"duration":0.19/minf(1.8,1.0+hit*0.05)}
		launched += 1
		if source.y == 0: battle._sound("dice/drop_001",1.25+source.x*0.08,-22)
		while flight.age < flight.duration:
			await get_tree().process_frame
			if not battle._valid_turn(token): return false
			if battle._menus_open(): continue
			flight.age += get_process_delta_time()*battle._roll_speed()*battle._world_time_scale()
			queue_redraw()
		flight.clear()
		battle.fx.burst(destination,battle.GOLD,4 if battle.reduced else 7,80)
		battle._sound("player/hit",1.35+(hit%4)*0.08,-24)
		battle._show_events(battle.model.apply_player_step(target))
		battle._sync_corpses()
		if battle.model.phase != "executing": break
	active_die = -1
	queue_redraw()
	return battle._valid_turn(token)

## Keep projectiles below menus and hide them while a modal covers combat.
func _process(_delta: float) -> void:
	visible = not battle._menus_open()

## A short curved trail makes the shining pip read as a traveling orb.
func _draw() -> void:
	if flight.is_empty(): return
	var t: float = clampf(flight.age/flight.duration,0,1)
	var at: Vector2 = _flight_point(t)
	var radius: float = 9 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 7
	Pixel.disc(self,flight.from,radius*(1-t),Color(battle.GOLD,0.6*(1-t)),2)
	if not battle.reduced:
		for tail in range(3,0,-1):
			var p: Vector2 = _flight_point(maxf(0,t-tail*0.07))
			Pixel.disc(self,p,radius*(1-tail*0.20),Color(battle.GOLD,0.32-tail*0.06),2)
	Orb.paint(self,at,radius,battle.GOLD,true)

func _flight_point(t: float) -> Vector2:
	var point: Vector2 = flight.from.lerp(flight.to,t)
	if not battle.reduced: point.x += sin(t*PI)*32
	return point
