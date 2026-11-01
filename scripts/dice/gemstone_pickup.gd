extends Node2D
## Cosmetic gemstone drops: bounce from the defeated enemy, then fly into the backpack.
const Paint = preload("res://scripts/dice/gemstone_paint.gd")
const DURATION := 1.55
var battle
var drops: Array = []
var cosmetic := RandomNumberGenerator.new()
var sound_cooldown := 0.0

func _ready() -> void:
	z_index = BattleLayers.LOOT_PICKUP
	cosmetic.randomize()

## The model has already granted ownership; closing an overlay can never lose the drop.
func enqueue(gem: Dictionary, target: int) -> void:
	if target == -1: return
	var origin: Vector2 = battle._enemy_point(target) if target >= 0 else battle._troop_point(-3-target)
	var feet: Vector2 = battle._enemy_feet(target) if target >= 0 else origin
	var rest: Vector2 = (feet+Vector2(cosmetic.randf_range(-48,48),0)).clamp(battle.ARENA.position+Vector2(24,30),battle.ARENA.end-Vector2(24,30))
	drops.append({"gem":gem.duplicate(),"origin":origin,"rest":rest,"age":0.0,"seed":cosmetic.randf()*TAU})

func reset() -> void:
	drops.clear()
	sound_cooldown = 0
	queue_redraw()

## Pause receipts beneath modals and coalesce simultaneous pickup sounds.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and not battle.chest.active and not battle.tarot_ui.ceremony.active() and battle.view_phase not in ["shop","transition"]
	if not visible: return
	sound_cooldown = maxf(0,sound_cooldown-delta)
	for drop in drops:
		drop.age += delta*clampf(battle.speed,1,2)
		if drop.age >= DURATION and sound_cooldown <= 0:
			battle._sound("item/crystal_collect",1.05,-18)
			sound_cooldown = 0.12
	drops = drops.filter(func(drop): return drop.age < DURATION)
	queue_redraw()

func _draw() -> void:
	for drop in drops:
		var t: float = clampf(drop.age/0.42,0,1)
		var flight: float = clampf((drop.age-1.0)/(DURATION-1.0),0,1)
		var at: Vector2 = drop.origin.lerp(drop.rest,t)
		if not battle.reduced: at.y -= sin(t*PI)*52
		if t >= 1 and flight == 0 and not battle.reduced: at.y -= absf(sin((drop.age-0.42)*8))*6
		at = at.lerp(battle.inventory_page.button_rect().get_center(),flight*flight)
		var radius: float = lerpf(24,12,flight)
		Paint.paint(self,at,drop.gem,radius)
		for i in range(3 if battle.reduced else 6):
			var angle: float = drop.seed+i*TAU/6+drop.age
			var p: Vector2 = at+Vector2.from_angle(angle)*(radius+8)
			var alpha: float = (0.35+0.4*absf(sin(drop.age*4+i)))*(1-flight)
			draw_rect(Rect2(p,Vector2.ONE*3),Color(Paint.Gems.Catalog.color(drop.gem.id).lightened(0.5),alpha))
