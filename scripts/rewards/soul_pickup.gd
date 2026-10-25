extends Node2D
## Cosmetic XP receipts for committed soul rewards; overlapping drops share one progress bar.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const BURST_TIME := 0.32
const FLIGHT_START := 0.62
const FLIGHT_TIME := 0.42
const BLUE := Color("72c9ff")
const GOLD := Color("ffcf59")
var battle
var orbs: Array = []
var pending_total := 0
var pulse := 0.0
var pulse_tint := BLUE
var sound_cooldown := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_as_relative = false
	z_index = 70 # Above combat, beneath inspections, reward pages and held items.
	rng.randomize()

## Clear every outstanding receipt on restart without changing the model's XP.
func reset() -> void:
	orbs.clear()
	pending_total = 0
	pulse = 0
	sound_cooldown = 0
	queue_redraw()

## Larger soul grants gradually shift from blue to gold, regardless of their source.
static func color_for_amount(amount: int) -> Color:
	return BLUE.lerp(GOLD,clampf((amount-5)/45.0,0,1))

## Start each kill receipt at the defeated actor, including legacy city troops.
func enqueue_enemy(target: int, amount: int) -> void:
	var origin: Vector2 = battle._enemy_point(target) if target >= 0 else battle._troop_point(-3-target)
	enqueue(origin,amount)

## Scatter a bounded cloud, retaining earlier drops when several enemies die together.
func enqueue(origin: Vector2, amount: int) -> void:
	if amount <= 0: return
	pending_total += amount
	var count: int = clampi(amount*2,10,48)
	var spread: float = (125 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 90)*lerpf(0.6,1,clampf(amount/40.0,0,1))
	var tint := color_for_amount(amount)
	for i in range(count):
		var offset := Vector2.from_angle(i*TAU/count+rng.randf_range(-0.2,0.2))*rng.randf_range(spread*0.35,spread)
		offset.y *= 0.65
		var rest: Vector2 = (origin+offset).clamp(battle.ARENA.position+Vector2.ONE*18,battle.ARENA.end-Vector2.ONE*18)
		orbs.append({"origin":origin,"rest":rest,"age":0.0,"delay":i*0.012,"amount":floori(float(amount)*(i+1)/count)-floori(float(amount)*i/count),"phase":rng.randf_range(0,TAU),"size":rng.randf_range(4,7),"tint":tint})
	queue_redraw()

## Subtract uncollected receipts from lifetime XP to animate overlapping grants across levels.
func counter_state() -> Dictionary:
	var level: int = battle.model.character_level
	var value: int = battle.model.souls+battle.model.LEVEL_COST_STEP*level*(level-1)/2-pending_total
	level = 1
	value = maxi(0,value)
	while level < battle.model.character_level and value >= battle.model.LEVEL_COST_STEP*level:
		value -= battle.model.LEVEL_COST_STEP*level
		level += 1
	return {"souls":value,"level":level}

## Spread outward, hover briefly, then accelerate into the player's body.
func position_of(orb: Dictionary) -> Vector2:
	var age: float = orb.age
	if age < BURST_TIME:
		var t: float = 1-pow(1-clampf(age/BURST_TIME,0,1),3)
		return orb.origin.lerp(orb.rest,t)-Vector2(0,sin(t*PI)*22 if not battle.reduced else 0)
	var t: float = clampf((age-FLIGHT_START-orb.delay)/FLIGHT_TIME,0,1)
	var bob := Vector2(0,sin(age*5+orb.phase)*4*(1-t)) if not battle.reduced else Vector2.ZERO
	return orb.rest.lerp(battle._player_point(),t*t)+bob

## Pause in menus; cosmetics never grant XP or use the reward random generator.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and battle.view_phase != "shop" and not battle.chest.active and not battle.tarot_ui.ceremony.active()
	if visible: advance(delta*clampf(battle.speed,1,2))

## Feed the XP bar and a brief player aura as each committed receipt arrives.
func advance(delta: float) -> void:
	pulse = maxf(0,pulse-delta)
	sound_cooldown = maxf(0,sound_cooldown-delta)
	var remaining: Array = []
	for orb in orbs:
		orb.age += delta
		if orb.age >= FLIGHT_START+orb.delay+FLIGHT_TIME:
			pending_total -= orb.amount
			pulse = 0.24
			pulse_tint = orb.tint
			if sound_cooldown <= 0:
				battle._sound("item/crystal_collect",1.3,-19)
				sound_cooldown = 0.075
		else: remaining.append(orb)
	orbs = remaining
	battle.queue_redraw()
	queue_redraw()

## White cores and colored comet tails converge on a soft, expanding power-up aura.
func _draw() -> void:
	for orb in orbs:
		var at := position_of(orb)
		var tint: Color = orb.tint
		if orb.age > FLIGHT_START+orb.delay and not battle.reduced:
			var direction: Vector2 = (battle._player_point()-orb.rest).normalized()
			for j in range(1,5): Pixel.disc(self,at-direction*j*7,orb.size*(1-j*0.15),Color(tint,0.22*(1-j/5.0)),2)
		for j in range(3,0,-1): Pixel.disc(self,at,orb.size+j*4,Color(tint,0.06),2)
		Pixel.disc(self,at,orb.size,tint,2)
		Pixel.disc(self,at-Vector2.ONE*2,orb.size*0.45,Color("f0fcff"),2)
	if pulse > 0:
		var alpha := pulse/0.24
		var center: Vector2 = battle._player_point()
		var radius: float = battle.monster_side*(0.24+(1-alpha)*0.16)
		Pixel.disc(self,center,radius,Color(pulse_tint,alpha*0.08),4)
		draw_arc(center,radius,0,TAU,40,Color(pulse_tint,alpha*0.65),3)
