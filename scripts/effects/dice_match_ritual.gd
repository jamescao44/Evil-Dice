extends Node2D
## Rare matching rolls borrow the actual dice, play one ritual, then restore their layout.
const Paint = preload("res://scripts/effects/dice_match_ritual_paint.gd")
const GATHER_TIME := 0.45
const RISE_TIME := 0.35
const TRAVEL_TIME := 0.65
const CHARGE_TIME := 0.42
const SHOT_TIME := 0.34
const RETURN_TIME := 0.52
const SIX_HOLD_TIME := 1.0
const FORMATION_SCALE := 0.7
const GATHER_DICE_SCALE := 0.5*FORMATION_SCALE
const CAST_DICE_SCALE := 0.32*FORMATION_SCALE
const ORBIT_SPEED := 0.8
var battle
var active := false
var phase := ""
var progress := 0.0
var age := 0.0
var serial := 0
var indices: Array = []
var snapshots: Array = []
var count := 0
var center := Vector2.ZERO
var radius := 0.0
var gather_center := Vector2.ZERO
var raised_center := Vector2.ZERO
var cast_center := Vector2.ZERO
var gather_radius := 0.0
var cast_radius := 0.0
var rotation_angle := 0.0
var points: Array = []
var beam_targets: Array = []
var previous_targets: Array = []
var beam_strength := 0.0
var shot_age := 0.0
var shots_fired := 0
var aura := 0.0
var particles: Array = []
var sparks_clock := 0.0
var cosmetic := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 52
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cosmetic.randomize()

## Let battle tinting keep the borrowed dice bright without changing input eligibility.
func owns(index: int) -> bool:
	return active and index in indices

## Restore all borrowed transform/layer state, also on restart, exit or cancellation.
func clear() -> void:
	serial += 1
	for saved in snapshots:
		if not is_instance_valid(saved.die): continue
		saved.die.position = saved.position
		saved.die.scale = saved.scale
		saved.die.rotation = saved.rotation
		saved.die.z_index = saved.z
		saved.die.clear_auto_attack()
	active = false
	phase = ""
	indices.clear(); snapshots.clear(); points.clear()
	beam_targets.clear(); previous_targets.clear(); particles.clear()
	beam_strength = 0
	aura = 0
	queue_redraw()

## Keep the ring beside the character and within the battlefield in either layout.
func destination() -> Vector2:
	var player: Vector2 = battle._player_point()
	var extent: float = cast_radius+30*FORMATION_SCALE
	var right: float = battle._player_sprite_rect().end.x
	return Vector2(clampf(right+extent+12,battle.ARENA.position.x+extent+12,battle.ARENA.end.x-extent-12),clampf(player.y-cast_radius*0.15,battle.ARENA.position.y+extent+12,battle.ARENA.end.y-extent-12))

## One group resolves at a time; cosmetic RNG never changes rolls, targets or rewards.
func play(group: Dictionary, token: int) -> bool:
	clear()
	var stamp: int = serial
	active = true
	indices = group.indices.duplicate()
	count = indices.size()
	shots_fired = 0; age = 0; rotation_angle = 0; sparks_clock = 0
	var phone: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	gather_radius = (120 if phone else 86)*FORMATION_SCALE
	cast_radius = (88 if phone else 66)*FORMATION_SCALE
	gather_center = battle.DICE_CENTER-Vector2(0,battle.DICE_RADIUS*0.2)
	raised_center = gather_center-Vector2(0,battle.DICE_RADIUS*0.7)
	cast_center = destination()
	for index in indices:
		var die = battle.dice[index]
		if die.motion_tween and die.motion_tween.is_running(): die.motion_tween.kill()
		snapshots.append({"die":die,"position":die.position,"scale":die.scale,"rotation":die.rotation,"z":die.z_index})
		die.z_index = 54
		die.auto_attack_active = true
		die.auto_attack_pulse = 0
	battle._sound("player/bell",0.85 if count == 6 else 1.1,-13)
	if not await _animate("gather",GATHER_TIME,token,stamp): return false
	if not await _animate("rise",RISE_TIME,token,stamp): return false
	if not await _animate("travel",TRAVEL_TIME,token,stamp): return false
	battle._sound("player/rumble",0.75 if count == 6 else 1.1,-15)
	if not await _animate("charge",CHARGE_TIME,token,stamp): return false
	var skill: MultiHitSkill = group.skill
	for shot in range(count):
		if battle.model.roll_attacks.is_empty() or battle.model.roll_attacks[0].skill != skill or not battle.model.has_living_enemies(): break
		var target: int = battle.model.roll_attack_target()
		if target < 0: break
		previous_targets = beam_targets.duplicate()
		beam_targets.clear()
		var hits: Array = battle.model.preview(skill,target)
		for hit in hits: beam_targets.append(battle._enemy_impact_point(hit.target))
		shot_age = 0
		beam_strength = 1.0
		battle.damage_feedback.show_attack(skill)
		battle.combat_motion.attack(-1)
		battle._sound("player/slash",0.65 if count == 6 else 1.05+shot*0.055,-13)
		if not await _animate("fire",SHOT_TIME*0.4,token,stamp): return false
		# Commit one pulse at the laser's bright core; later pulses re-evaluate living foes.
		for hit in hits:
			var at: Vector2 = battle._enemy_impact_point(hit.target)
			burst(at,14 if count == 6 else 9,190)
			battle.fx.attack_burst(at,tint(),hit.damage,8 if battle.reduced else 18,170)
		shots_fired += 1
		battle._show_events(battle.model.resolve_roll_attack_step())
		battle.shake = 0 if battle.reduced else (4.5 if count == 6 else 2.5)*battle.ATTACK_SHAKE_SCALE
		battle._sound("player/crash" if count == 6 else "player/hit",0.85+shot*0.025,-18)
		if not await _animate("fire",SHOT_TIME*0.6,token,stamp): return false
		if not battle.model.has_living_enemies(): break
	beam_strength = 0
	# Six alike lingers for one real second, independent of 1x/2x speed and kill slowmo.
	if count == 6 and not await _animate("hold",SIX_HOLD_TIME,token,stamp,true): return false
	if not await _animate("return",RETURN_TIME,token,stamp): return false
	clear()
	return battle._valid_turn(token)

## Advance movement in gameplay time, freeze cleanly under menus, and reject stale casts.
func _animate(next_phase: String, seconds: float, token: int, stamp: int, real_time: bool = false) -> bool:
	phase = next_phase
	progress = 0
	_pose()
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		if serial != stamp: return false
		if not battle._valid_turn(token): clear(); return false
		if battle._menus_open(): continue
		elapsed += get_process_delta_time()*(1.0 if real_time else battle._roll_speed()*battle._world_time_scale())
		progress = clampf(elapsed/seconds,0,1)
		_pose()
	return true

## Interpolate real dice through the polygon, aerial rise, casting ring and return arc.
func _pose() -> void:
	var t: float = smoothstep(0,1,progress)
	center = gather_center
	radius = gather_radius
	var shrink: float = GATHER_DICE_SCALE
	aura = 1.0
	match phase:
		"gather":
			aura = t
			shrink = lerpf(1,GATHER_DICE_SCALE,t)
		"rise": center = gather_center.lerp(raised_center,t)
		"travel":
			center = raised_center.lerp(cast_center,t)-Vector2(0,sin(t*PI)*55)
			radius = lerpf(gather_radius,cast_radius,t)
			shrink = lerpf(GATHER_DICE_SCALE,CAST_DICE_SCALE,t)
		"charge","fire","hold","return":
			center = cast_center
			radius = cast_radius
			shrink = CAST_DICE_SCALE
			if phase == "return": aura = 1-t
	points.clear()
	for i in range(count):
		var saved: Dictionary = snapshots[i]
		var direction := Vector2.from_angle(-PI/2+i*TAU/count+rotation_angle)
		var point: Vector2 = center+direction*radius
		if phase == "gather": point = saved.position.lerp(point,t)-Vector2(0,sin(t*PI)*18)
		elif phase == "return": point = point.lerp(saved.position,t)-Vector2(0,sin(t*PI)*60)
		var size: Vector2 = saved.scale*shrink
		if phase == "return": size = (saved.scale*CAST_DICE_SCALE).lerp(saved.scale,t)
		if not battle.reduced and phase in ["charge","fire","hold"]:
			point += direction*sin(age*TAU*1.1)*2
			size *= 1+sin(age*TAU*1.4)*0.025
		saved.die.position = point
		saved.die.scale = size
		saved.die.rotation = 0 if battle.reduced else sin(age*3+i*TAU/count)*0.04*aura
		points.append(point)
	queue_redraw()

func tint() -> Color:
	return Color("ffd66b") if count == 6 else Color("ff8456")

## Bounded local sparks avoid flooding the general battlefield particle pool.
func burst(at: Vector2, amount: int, force: float) -> void:
	if battle.reduced: amount = mini(amount,3)
	for i in range(amount):
		if particles.size() >= 160: break
		var life: float = cosmetic.randf_range(0.25,0.65)
		particles.append({"p":at,"v":Vector2.from_angle(cosmetic.randf()*TAU)*cosmetic.randf_range(force*0.3,force),"life":life,"max":life,"size":cosmetic.randf_range(2,5)})

## Animate only cosmetic embers here; all damage is committed by the ritual coroutine.
func _process(delta: float) -> void:
	visible = active and not battle._menus_open()
	if not active or battle._menus_open(): return
	var step: float = delta*battle._roll_speed()*battle._world_time_scale()
	age += step
	shot_age += step
	# Orbit the entire linked formation once assembled; keep faces upright and menus frozen.
	if phase != "gather" and not battle.reduced:
		rotation_angle += step*ORBIT_SPEED
		_pose()
	for p in particles:
		p.life -= step
		p.p += p.v*step
		p.v *= maxf(0,1-step*1.7)
	particles = particles.filter(func(p): return p.life > 0)
	sparks_clock -= step
	if sparks_clock <= 0 and not points.is_empty() and phase != "return":
		sparks_clock = 0.14 if battle.reduced else 0.035
		burst(points[cosmetic.randi_range(0,points.size()-1)],1 if battle.reduced else 3,45)
	queue_redraw()

func _draw() -> void:
	if active: Paint.draw(self)
