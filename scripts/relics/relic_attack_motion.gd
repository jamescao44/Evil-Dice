extends RefCounted
## Enchanted weapons lift, strike and recoil home; magic items launch curved projectiles.
## Only presentation waits here: combat decisions and random targeting remain in the model.
const Orbit = preload("res://scripts/relics/relic_orbit.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const LIFT := 0.22
const STRIKE := 0.16
const RETURN := 0.25
var battle
var flights: Array = []
var cosmetic := RandomNumberGenerator.new()

## Forget queued effects on restart without executing damage or reward callbacks.
func clear() -> void:
	flights.clear()

## Resolve copied/fused effects back to the actual satellite that owns their artwork.
func _origin(receipt: Dictionary, poses: Array) -> Dictionary:
	for pose in poses:
		if pose.slot == receipt.origin: return pose
	for pose in poses:
		if pose.item.id == receipt.source: return pose
	for pose in poses:
		if Catalog.Sets.is_fused(pose.item.id) and receipt.source in Catalog.Sets.ingredients(pose.item): return pose
	return {}

## Capture living targets before synchronous damage, so the animated impact owns their fall.
func begin(receipt: Dictionary) -> void:
	var pose: Dictionary = _origin(receipt,Orbit.poses(battle))
	if pose.is_empty(): return
	var states: Dictionary = {}
	var points: Array[Vector2] = []
	for target in receipt.targets:
		if target >= 0:
			var enemy: Dictionary = battle.model.enemies[target]
			states[target] = {"source":enemy,"hp":enemy.hp,"shield":enemy.shield,"maximum":enemy.max_hp,"phase":enemy.get("boss_phase",0)}
			points.append(battle._enemy_world_point(target))
		elif target == -2: points.append(battle.battlefield_view.transform.affine_inverse()*battle.CITY_POINT)
	if points.is_empty(): return
	var center := Vector2.ZERO
	for point in points: center += point
	center /= points.size()
	var radius: float = pose.radius
	var motion: Dictionary = Catalog.ITEMS[receipt.source].get("attack_motion",{})
	var kind: String = motion.get("kind","orb")
	var source_at: Vector2 = _ranged_origin(receipt.source,pose.at) if kind != "jab" else pose.at
	var lift: Vector2 = pose.at+Vector2(cosmetic.randf_range(-18,10),-radius*cosmetic.randf_range(2.7,3.6))
	lift = lift.clamp(battle.ARENA.position+Vector2.ONE*radius*1.5,battle.ARENA.end-Vector2.ONE*radius*1.5)
	if kind != "jab": lift = source_at
	var delay := 0.0
	# Repeated copies share one physical icon and take turns, never duplicate its orbit sprite.
	for prior in flights:
		if is_same(prior.owner,pose.item): delay = maxf(delay,prior.duration-prior.age)
	var rate: float = maxf(0.1,receipt.speed)*(1.5 if battle.reduced else 1.0)
	flights.append({"receipt":receipt,"item":pose.item.duplicate(true),"owner":pose.item,"slot":pose.slot,"radius":radius,
		"start":source_at,"lift":lift,"center":center,"points":points,"states":states,
		"age":-delay,"impact":(LIFT+STRIKE)/rate,"duration":(LIFT+STRIKE+RETURN)/rate,"rate":rate,
		"kind":kind,"tip":deg_to_rad(motion.get("tip_degrees",-45.0)),
		"curl":cosmetic.randf_range(-1,1),"events":[],"callbacks":[],"hit":false})

## Queue only events carrying this attack's receipt; unrelated skill damage stays immediate.
func defer_event(event: Dictionary) -> bool:
	if not event.has("relic_flight"): return false
	for flight in flights:
		if not flight.hit and is_same(flight.receipt,event.relic_flight):
			var copy: Dictionary = event.duplicate()
			copy.erase("relic_flight")
			flight.events.append(copy)
			return true
	return false

## Delay boss feedback until the same impact as its HP loss.
func defer_callback(target: int, callback: Callable) -> bool:
	for i in range(flights.size()-1,-1,-1):
		if not flights[i].hit and flights[i].states.has(target):
			flights[i].callbacks.append(callback)
			return true
	return false

## Find the earliest pending HP snapshot, ignoring actors replaced by a new encounter.
func state_for(target: int) -> Dictionary:
	for flight in flights:
		if flight.hit or not flight.states.has(target): continue
		var state: Dictionary = flight.states[target]
		if target < battle.model.enemies.size() and is_same(state.source,battle.model.enemies[target]): return state
	return {}

## Supply the same held health values to bars, trails and enemy labels.
func health_states() -> Dictionary:
	var states: Dictionary = {}
	for index in range(battle.model.enemies.size()):
		var state: Dictionary = state_for(index)
		if not state.is_empty(): states[index] = state
	return states

func holds(target: int) -> bool:
	return not state_for(target).is_empty()

func pending() -> bool:
	return flights.any(func(f): return not f.hit)

## Source icons disappear only while airborne, including their return arc.
func owns(slot: int) -> bool:
	if slot < 0 or slot >= battle.model.relics.items.size(): return false
	return flights.any(func(f): return f.kind == "jab" and is_same(f.owner,battle.model.relics.items[slot]) and f.age >= 0)

## Ranged icons spring above their orbit, hold large while firing, then settle smoothly.
func ranged_pop(item: Dictionary) -> float:
	var strength := 0.0
	for flight in flights:
		if flight.kind == "jab" or flight.age < 0 or not is_same(flight.owner,item): continue
		var t: float = flight.age*flight.rate
		var pop: float = 1.0
		if t < LIFT:
			var p: float = clampf(t/LIFT,0,1)-1.0
			pop = 1.0+2.7*p*p*p+1.7*p*p
		elif t < LIFT+STRIKE:
			pop += sin((t-LIFT)/STRIKE*PI)*0.08
		else: pop = 1.0-smoothstep(0,RETURN,t-LIFT-STRIKE)
		strength = maxf(strength,pop)
	return strength

## Pets and the Witch cast from their creature sprites; bows cast from their orbit icons.
func _ranged_origin(source: String, fallback: Vector2) -> Vector2:
	if source == "golden_warrior": return battle.warrior_companion.hand(battle)
	if source == "witch_ghost":
		battle.witch_companion.prepare_art()
		var rect: Rect2 = battle.witch_companion.sprite_rect(battle)
		return rect.position+rect.size*Vector2(0.7,0.48)
	for pet in battle.pet_companions.poses(battle):
		if pet.id == source: return pet.at+Vector2(pet.size*0.22,-pet.size*0.55)
	return fallback

## Advance on the paused battle clock, landing damage and death feedback together.
func advance(delta: float) -> void:
	for flight in flights.duplicate():
		if flight.age < 0 and flight.age+maxf(0,delta) >= 0 and flight.kind == "jab":
			var displacement: Vector2 = _home(flight)-flight.start
			flight.start += displacement
			flight.lift += displacement
		var preparing: bool = flight.kind != "jab" and flight.age*flight.rate < LIFT
		flight.age += maxf(0,delta)
		if preparing: flight.lift = _ranged_origin(flight.receipt.source,_home(flight))
		if not flight.hit and flight.age >= flight.impact:
			flight.hit = true
			for point in flight.points:
				var at: Vector2 = battle.battlefield_view.transform*point
				var tint: Color = Catalog.rarity_color(flight.receipt.source).lightened(0.25)
				if flight.kind == "witch":
					tint = Color("bba3ff")
					battle.fx.activate_circle(at,Color("c3b3ff"),flight.radius*2.2,0.32)
					battle.fx.burst(at,Color("d9faff"),18 if not battle.reduced else 6,145)
				battle.fx.burst(at,tint,5 if battle.reduced else 12,100)
				battle.fx.ring(at,tint,flight.radius*1.8,battle.ARENA)
			battle._show_events(flight.events)
			for callback in flight.callbacks: callback.call()
			flight.events.clear()
			flight.callbacks.clear()
	flights = flights.filter(func(f): return f.age < f.duration)

## Return to a moving satellite, so the final frame cannot jump back to its old orbit.
func _home(flight: Dictionary) -> Vector2:
	for pose in Orbit.poses(battle):
		if is_same(pose.item,flight.owner): return pose.at
	return flight.start

static func _curve(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control,t).lerp(control.lerp(b,t),t)

## Anticipation, accelerated jab, overshoot and spring-back avoid straight point-to-point motion.
func pose_at(flight: Dictionary, age: float) -> Dictionary:
	if flight.kind != "jab": return {"at":flight.lift,"angle":0.0,"scale":1.0}
	var t: float = clampf(age*flight.rate,0,LIFT+STRIKE+RETURN)
	var direction: Vector2 = (flight.center-flight.lift).normalized()
	var aim: float = direction.angle()-flight.tip
	var at: Vector2
	var angle: float
	var scale := 1.0
	var hit_point: Vector2 = flight.center-direction*flight.radius*0.6
	var attack_end: Vector2 = hit_point+direction*flight.radius*0.8
	if t < LIFT:
		var p: float = t/LIFT
		var ease: float = 1.0-pow(1.0-p,3)
		at = _curve(flight.start,flight.start+Vector2(-flight.radius*(1+flight.curl),-flight.radius*3),flight.lift,ease)
		angle = lerp_angle(-0.25,aim-0.55,smoothstep(0,1,p))
		scale = 1.0+sin(p*PI)*0.25
	elif t < LIFT+STRIKE:
		var p: float = (t-LIFT)/STRIKE
		at = _curve(flight.lift,flight.lift.lerp(attack_end,0.4)+Vector2(0,-flight.radius*1.1),attack_end,pow(p,2.1))
		angle = lerp_angle(aim-0.55,aim+0.18,p)
		scale = 1.15
	else:
		var p: float = (t-LIFT-STRIKE)/RETURN
		at = _curve(attack_end,attack_end+Vector2(-flight.radius*1.8,-flight.radius*2.4),_home(flight),smoothstep(0,1,p))
		angle = lerp_angle(aim+0.18,0,smoothstep(0,1,p))+sin(p*TAU)*0.18*(1-p)
		scale = 1.0+0.15*(1-p)+sin(p*TAU)*0.1*(1-p)
	return {"at":at,"angle":angle,"scale":scale}

## A bowed orb accelerates out of the hovering weapon, with a bright core and colored tail.
static func orb_point(flight: Dictionary, target: Vector2, progress: float) -> Vector2:
	var from: Vector2 = flight.lift+(target-flight.lift).normalized()*flight.radius*0.6
	return _curve(from,from.lerp(target,0.5)+Vector2(0,-flight.radius*(1.4+absf(flight.curl))),target,pow(clampf(progress,0,1),1.45))

## Draw above battlefield actors, inside their existing clip and below all combat HUD labels.
func paint(canvas: CanvasItem) -> void:
	for flight in flights:
		if flight.age < 0: continue
		var pose: Dictionary = pose_at(flight,flight.age)
		var tint: Color = Catalog.rarity_color(flight.receipt.source)
		if flight.kind == "witch": tint = Color("b49aff")
		if not battle.reduced and flight.kind == "jab":
			for i in range(7,0,-1):
				var tail: Vector2 = pose_at(flight,maxf(0,flight.age-i*0.012)).at
				var next: Vector2 = pose_at(flight,maxf(0,flight.age-(i-1)*0.012)).at
				canvas.draw_line(tail,next,Color(tint,(1-i/8.0)*0.4),maxf(1,flight.radius*(1-i/8.0)*0.22),true)
		var t: float = flight.age*flight.rate
		if flight.kind != "jab" and t < LIFT:
			var charge: float = clampf(t/LIFT,0,1)
			canvas.draw_circle(flight.lift,flight.radius*(0.4+charge*0.5),Color(tint,charge*0.25))
			canvas.draw_circle(flight.lift,flight.radius*charge*0.24,Color("fffbed"))
			if flight.kind == "witch": _witch_sigil(canvas,flight.lift,flight.radius*(1.0+charge*0.5),charge,t*8)
		if flight.kind != "jab" and t >= LIFT and t < LIFT+STRIKE:
			var progress: float = (t-LIFT)/STRIKE
			for point in flight.points:
				var at: Vector2 = orb_point(flight,point,progress)
				var tail: Vector2 = orb_point(flight,point,maxf(0,progress-0.22))
				canvas.draw_line(tail,at,Color(tint,0.25),flight.radius*0.65,true)
				canvas.draw_line(tail,at,Color(tint,0.9),flight.radius*0.24,true)
				canvas.draw_circle(at,flight.radius*0.7,Color(tint,0.12))
				if flight.kind == "spear":
					var aim: Vector2 = (point-flight.lift).normalized()
					canvas.draw_line(at-aim*flight.radius*2,at+aim*flight.radius,Color("ffdb73"),3,true)
					var tip: Vector2 = at+aim*flight.radius
					canvas.draw_colored_polygon(PackedVector2Array([tip+aim*10,tip-aim*4+aim.orthogonal()*4,tip-aim*4-aim.orthogonal()*4]),Color("fff2b5"))
				else: canvas.draw_circle(at,flight.radius*0.37,tint)
				canvas.draw_circle(at,flight.radius*0.2,Color("fffbed"))
				if flight.kind == "witch": _witch_bolt(canvas,flight,point,progress,tint)
		if flight.kind != "jab": continue
		canvas.draw_set_transform(pose.at,pose.angle,Vector2.ONE*pose.scale)
		Paint.silhouette_glow(canvas,flight.item.id,Vector2.ZERO,flight.radius,tint,flight.item,1.0)
		Paint.paint(canvas,flight.item.id,Vector2.ZERO,flight.radius,false,flight.item)
		canvas.draw_set_transform(Vector2.ZERO)

## The Witch weaves two spectral ribbons around a bright, crescent-shaped spell core.
func _witch_bolt(canvas: CanvasItem, flight: Dictionary, target: Vector2, progress: float, tint: Color) -> void:
	var at: Vector2 = orb_point(flight,target,progress)
	var normal: Vector2 = (target-flight.lift).normalized().orthogonal()
	for strand in range(2):
		var points := PackedVector2Array()
		for i in range(14):
			var p: float = maxf(0,progress-(13-i)*0.032)
			points.append(orb_point(flight,target,p)+normal*sin(p*TAU*2+strand*PI)*flight.radius*0.55)
		canvas.draw_polyline(points,Color(tint if strand == 0 else Color("c4f9ff"),0.85),3,true)
	canvas.draw_circle(at,flight.radius*1.25,Color(tint,0.13))
	canvas.draw_arc(at,flight.radius*0.8,progress*TAU,progress*TAU+PI*1.6,20,Color("e4e0ff"),4,true)
	for mote in range(4):
		var offset: Vector2 = Vector2.from_angle(progress*TAU*2+mote*TAU/4)*flight.radius*0.95
		canvas.draw_circle(at+offset,2.5,Color("e5fbff"))

## A rotating double triangle gives the spectral cast a recognizable spell signature.
static func _witch_sigil(canvas: CanvasItem, at: Vector2, radius: float, alpha: float, angle: float) -> void:
	canvas.draw_arc(at,radius,0,TAU,32,Color(0.72,0.59,1,alpha*0.7),2,true)
	for layer in range(2):
		var points := PackedVector2Array()
		for i in range(4): points.append(at+Vector2.from_angle(angle+layer*PI+i*TAU/3)*radius)
		canvas.draw_polyline(points,Color(0.83,0.92,1,alpha*0.85),2,true)
