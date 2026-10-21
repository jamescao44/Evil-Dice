extends Node2D
## Soul-chest receipts animate an already committed grant without mutating rewards.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const BURST_TIME := 0.32
const FLIGHT_START := 0.62
const FLIGHT_TIME := 0.42
const TINT := Color("9de9ff")
var battle
var orbs: Array = []
var pending_total := 0
var initial_souls := 0
var initial_level := 1
var total := 0
var pulse := 0.0
var sound_cooldown := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_as_relative = false
	z_index = 96
	rng.randomize()

## Clear pending visuals and displayed balance when a run restarts.
func reset() -> void:
	orbs.clear()
	pending_total = 0
	total = 0
	pulse = 0
	sound_cooldown = 0
	queue_redraw()

## Scatter a generous, bounded cloud; several particles can symbolize one soul.
func enqueue(origin: Vector2, amount: int, before_souls: int, before_level: int) -> void:
	if amount <= 0: return
	reset()
	initial_souls = before_souls
	initial_level = before_level
	total = amount
	pending_total = amount
	var count: int = clampi(amount*2,20,48)
	var spread: float = 125 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 90
	for i in range(count):
		var offset := Vector2.from_angle(i*TAU/count+rng.randf_range(-0.2,0.2))*rng.randf_range(spread*0.35,spread)
		offset.y *= 0.65
		var rest: Vector2 = (origin+offset).clamp(battle.ARENA.position+Vector2.ONE*18,battle.ARENA.end-Vector2.ONE*18)
		orbs.append({"origin":origin,"rest":rest,"age":0.0,"delay":i*0.012,"amount":floori(float(amount)*(i+1)/count)-floori(float(amount)*i/count),"phase":rng.randf_range(0,TAU),"size":rng.randf_range(5,9)})
	queue_redraw()

## Mirror automatic level spending as receipts arrive, without spending souls twice.
func counter_state() -> Dictionary:
	var value: int = battle.model.souls
	var level: int = battle.model.character_level
	if not orbs.is_empty():
		value = initial_souls+total-pending_total
		level = initial_level
		while level < battle.model.MAX_CHARACTER_LEVEL and value >= battle.model.LEVEL_COSTS[level-1]:
			value -= battle.model.LEVEL_COSTS[level-1]
			level += 1
	return {"souls":value,"level":level}

## Keep the numeric receipt and its level threshold synchronized.
func counter_text() -> String:
	var state := counter_state()
	return str(state.souls)+"/"+str(battle.model.LEVEL_COSTS[state.level-1]) if state.level < battle.model.MAX_CHARACTER_LEVEL else str(state.souls)

## Spread outward, hover briefly, then accelerate into the Souls counter.
func position_of(orb: Dictionary) -> Vector2:
	var age: float = orb.age
	if age < BURST_TIME:
		var t: float = 1-pow(1-clampf(age/BURST_TIME,0,1),3)
		return orb.origin.lerp(orb.rest,t)-Vector2(0,sin(t*PI)*22 if not battle.reduced else 0)
	var t: float = clampf((age-FLIGHT_START-orb.delay)/FLIGHT_TIME,0,1)
	var bob := Vector2(0,sin(age*5+orb.phase)*4*(1-t)) if not battle.reduced else Vector2.ZERO
	return orb.rest.lerp(battle._soul_currency_point(),t*t)+bob

## Pause menus and keep receipts independent of world slow motion.
func _process(delta: float) -> void:
	visible = not battle._menus_open()
	if visible: advance(delta*clampf(battle.speed,1,2))

## Consume only cosmetic receipts; the model's grant was committed before enqueue.
func advance(delta: float) -> void:
	pulse = maxf(0,pulse-delta)
	sound_cooldown = maxf(0,sound_cooldown-delta)
	var remaining: Array = []
	for orb in orbs:
		orb.age += delta
		if orb.age >= FLIGHT_START+orb.delay+FLIGHT_TIME:
			pending_total -= orb.amount
			pulse = 0.2
			if sound_cooldown <= 0:
				battle._sound("item/crystal_collect",1.3,-19)
				sound_cooldown = 0.075
		else: remaining.append(orb)
	orbs = remaining
	battle.queue_redraw()
	queue_redraw()

## White cores, blue halos and short comet tails identify souls separately from gems.
func _draw() -> void:
	for orb in orbs:
		var at := position_of(orb)
		if orb.age > FLIGHT_START+orb.delay and not battle.reduced:
			var direction: Vector2 = (battle._soul_currency_point()-orb.rest).normalized()
			for j in range(1,5): Pixel.disc(self,at-direction*j*7,orb.size*(1-j*0.15),Color(TINT,0.22*(1-j/5.0)),2)
		for j in range(3,0,-1): Pixel.disc(self,at,orb.size+j*4,Color(TINT,0.06),2)
		Pixel.disc(self,at,orb.size,TINT,2)
		Pixel.disc(self,at-Vector2.ONE*2,orb.size*0.45,Color("f0fcff"),2)
	if pulse > 0: draw_arc(battle._soul_currency_point(),16+(1-pulse/0.2)*18,0,TAU,28,Color(TINT,pulse/0.2),3)
