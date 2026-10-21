extends Node2D
## Cosmetic receipts for committed kill rewards. No gameplay RNG or reward mutations.
const Icons = preload("res://scripts/rewards/reward_icons.gd")
const BURST_END := 0.38
const FLIGHT_START := 0.78
const FLIGHT_TIME := 0.48
const TINT := Color("ff8fad")
var battle
var chest_mode: bool = false
var gems: Array = []
var pending_total: int = 0
var pulse: float = 0.0
var drop_cooldown: float = 0.0
var collect_cooldown: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_as_relative = false
	z_index = 70 # Over combat; below treasure, inspection, held items and menus.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()

func reset() -> void:
	gems.clear()
	chest_mode = false
	pending_total = 0
	pulse = 0
	drop_cooldown = 0
	collect_cooldown = 0
	queue_redraw()

func enqueue(target: int, amount: int) -> void:
	if amount <= 0: return
	var feet: Vector2 = battle._enemy_feet(target) if target >= 0 else battle._troop_point(-3-target)
	var origin: Vector2 = feet-Vector2(0,battle._enemy_side()*0.4)
	var count: int = mini(amount,3 if amount < 8 else 4 if amount < 15 else 5)
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var spread: float = 100 if portrait else 72
	var scatter_angle: float = rng.randf_range(0,TAU)
	for i in range(count):
		var offset: Vector2 = Vector2.from_angle(scatter_angle+i*TAU/count+rng.randf_range(-0.2,0.2))*spread*rng.randf_range(0.7,1.15)
		offset.y *= 0.55
		var ground: Vector2 = feet+offset
		ground = ground.clamp(battle.ARENA.position+Vector2(18,18),battle.ARENA.end-Vector2(18,18))
		var share: int = floori(float(amount)*(i+1)/count)-floori(float(amount)*i/count)
		gems.append({"origin":origin,"impact":feet.lerp(ground,0.72),"ground":ground,"age":0.0,"delay":i*0.075,"amount":share,"spin":rng.randf_range(-0.7,0.7),"height":rng.randf_range(38,66),"side":30.0 if portrait else 23.0})
	pending_total += amount
	if drop_cooldown <= 0 and not paused():
		battle._sound("enemy/crystal_drop",rng.randf_range(0.94,1.06),-17)
		drop_cooldown = 0.09
	queue_redraw()

func enqueue_chest(origin: Vector2, amount: int) -> void:
	if amount <= 0: return
	chest_mode = true
	z_index = 96
	var count: int = mini(amount,18+floori(amount/5.0))
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var spread: float = 320 if portrait else 290
	for i in range(count):
		var ground := origin+Vector2(rng.randf_range(-spread,spread),rng.randf_range(-35,90 if portrait else 42))
		ground = ground.clamp(Vector2(30,30),battle.fx.canvas_size-Vector2(30,30))
		var share: int = floori(float(amount)*(i+1)/count)-floori(float(amount)*i/count)
		gems.append({"origin":origin-Vector2(0,35),"impact":origin.lerp(ground,0.72),"ground":ground,"age":0.0,"delay":i*0.008,"speed":1.6,"amount":share,"spin":rng.randf_range(-0.9,0.9),"height":rng.randf_range(110,240) if portrait else rng.randf_range(65,140),"side":rng.randf_range(25,40) if portrait else rng.randf_range(19,30)})
	pending_total += amount
	battle._sound("enemy/crystal_drop",0.85,-8)
	queue_redraw()

func paused() -> bool:
	return battle._menus_open() or battle.inspecting_enemy >= 0 or battle.tarot_ui.inspected >= 0 or battle.tarot_ui.ceremony.active() or battle.relic_ui.chest_slot >= 0 or (not chest_mode and battle.view_phase in ["reward","wave_reward"])

func pose(gem: Dictionary) -> Dictionary:
	var age: float = gem.age
	var at: Vector2
	var rotation: float = 0
	var shadow: Vector2 = gem.ground
	var flight: float = clampf((age-FLIGHT_START-gem.delay)/FLIGHT_TIME,0,1)
	if age < BURST_END:
		var t: float = clampf(age/BURST_END,0,1)
		at = gem.origin.lerp(gem.impact,t)
		if not battle.reduced:
			at.y -= sin(PI*t)*gem.height
			rotation = gem.spin*sin(PI*t)
	elif flight <= 0:
		at = gem.ground
		# Two shrinking hops keep their outward momentum before settling.
		var bounce_age: float = age-BURST_END
		var t: float = clampf(bounce_age/0.18 if bounce_age < 0.18 else (bounce_age-0.18)/0.12,0,1)
		var drift: float = lerpf(0,0.75,t) if bounce_age < 0.18 else lerpf(0.75,1,t)
		shadow = gem.impact.lerp(gem.ground,drift)
		at = shadow
		if not battle.reduced:
			var hop: float = sin(PI*t)
			at.y -= hop*gem.height*(0.32 if bounce_age < 0.18 else 0.12)
			rotation = gem.spin*hop*(0.5 if bounce_age < 0.18 else 0.2)
	else:
		var eased: float = flight*flight
		at = gem.ground.lerp(battle._currency_point(),eased)
		if not battle.reduced: at += Vector2(sin(PI*flight)*gem.spin*38,-sin(PI*flight)*20)
	return {"at":at,"shadow":shadow,"rotation":rotation,"flight":flight,"side":gem.side*lerpf(1,0.58,flight),"grounded":age >= BURST_END and flight <= 0}

func advance(delta: float) -> void:
	pulse = maxf(0,pulse-delta)
	drop_cooldown = maxf(0,drop_cooldown-delta)
	collect_cooldown = maxf(0,collect_cooldown-delta)
	var remaining: Array = []
	for gem in gems:
		gem.age += delta*gem.get("speed",1.0)
		if gem.age >= FLIGHT_START+gem.delay+FLIGHT_TIME:
			pending_total -= gem.amount
			pulse = 0.24
			if collect_cooldown <= 0:
				battle._sound("item/crystal_collect",1.05+gem.delay*0.65,-12)
				collect_cooldown = 0.065
		else: remaining.append(gem)
	gems = remaining
	if gems.is_empty(): chest_mode = false
	battle.queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	z_index = 96 if chest_mode else 70
	visible = not paused()
	if visible: advance(delta*clampf(battle.speed,1,2))

func _sparkle(at: Vector2, size: float, alpha: float) -> void:
	draw_line(at-Vector2(size,0),at+Vector2(size,0),Color("fff2e5",alpha),2)
	draw_line(at-Vector2(0,size),at+Vector2(0,size),Color("fff2e5",alpha),2)

func _draw() -> void:
	for gem in gems:
		var p: Dictionary = pose(gem)
		if p.grounded:
			draw_set_transform(p.shadow+Vector2(0,8),0,Vector2(1,0.3))
			draw_circle(Vector2.ZERO,gem.side*0.42,Color(0.03,0.02,0.04,0.45))
			draw_set_transform(Vector2.ZERO)
		if p.flight > 0 and not battle.reduced:
			var direction: Vector2 = (battle._currency_point()-gem.ground).normalized()
			for i in range(1,5):
				draw_circle(p.at-direction*i*7,3.5-i*0.5,Color(TINT,0.32*(1-i/5.0)))
		for ring in range(4,0,-1): draw_circle(p.at,p.side*(0.42+ring*0.15),Color(1,1,1,0.03))
		draw_set_transform(p.at,p.rotation)
		Icons.paint(self,battle.chest.art,"ruby",Rect2(-Vector2.ONE*p.side/2,Vector2.ONE*p.side))
		draw_set_transform(Vector2.ZERO)
		var twinkle: float = 0.55+0.45*sin(gem.age*13+gem.delay*18)
		_sparkle(p.at+Vector2(-p.side*0.22,-p.side*0.29),3.5,twinkle)
	if pulse > 0:
		var t: float = 1-pulse/0.24
		draw_arc(battle._currency_point(),16+t*15,0,TAU,32,Color(TINT,1-t),2)
		for i in range(4): _sparkle(battle._currency_point()+Vector2.from_angle(i*TAU/4+0.3)*(19+t*13),3*(1-t),1-t)
