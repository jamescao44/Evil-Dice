extends RefCounted
## Cosmetic sprite fragments; no physics bodies, combat RNG or damage side effects.
const Visuals = preload("res://scripts/enemies/enemy_visuals.gd")
var bodies: Dictionary = {}
var cosmetic := RandomNumberGenerator.new()

## Seed visual variation independently of combat and reward rolls.
func _init() -> void:
	cosmetic.randomize()

## Replace one corpse with its authored pieces, preserving the sprite's pixel scale.
func spawn(index: int, enemy: Dictionary, sprite: Rect2, arena: Rect2, reduced: bool) -> bool:
	if bodies.has(index): return true
	var data: Dictionary = Visuals.debris(enemy)
	if data.is_empty(): return false
	var pieces: Array = []
	var side: float = sprite.size.y
	var bounds := arena.grow(-8)
	for i in range(data.textures.size()):
		var texture: Texture2D = data.textures[i]
		var size: Vector2 = texture.get_size()*sprite.size/data.source_size
		var radius: float = size.length()*0.5
		var small: bool = maxf(size.x,size.y) <= side*0.22
		var point: Vector2 = sprite.position+data.origins[i]*sprite.size
		if small: point += Vector2(cosmetic.randf_range(-0.035,0.035),cosmetic.randf_range(-0.035,0.035))*side
		var floor_y: float = clampf(sprite.end.y+cosmetic.randf_range(-side*0.07,side*0.05)-radius,bounds.position.y+radius,bounds.end.y-radius)
		point = point.clamp(bounds.position+Vector2.ONE*radius,bounds.end-Vector2.ONE*radius)
		point.y = minf(point.y,floor_y)
		# Independent sideways kicks and lift keep small pieces irregular without a wide fan.
		var spread: float = 0.90 if small else 0.42
		var velocity := Vector2(cosmetic.randf_range(-spread,spread),-cosmetic.randf_range(1.8 if small else 2.2,5.0 if small else 3.9))*side
		if reduced: velocity *= 0.3
		pieces.append({"texture":texture,"size":size,"p":point,"v":velocity,"floor":floor_y,"radius":radius,"angle":0.0,"spin":cosmetic.randf_range(-8,8),"bounces":0,"resting":false})
	var blood: Array = _blood_splatter(sprite,bounds,reduced)
	bodies[index] = {"pieces":pieces,"blood":blood,"movers":pieces+blood,"bounds":bounds,"gravity":side*7.0,"age":0.0}
	return true

## Scatter a few dark-red pixel droplets that flatten into short-lived floor splashes.
func _blood_splatter(sprite: Rect2, bounds: Rect2, reduced: bool) -> Array:
	var drops: Array = []
	var side: float = sprite.size.y
	for i in range(6 if reduced else 24):
		var size := Vector2.ONE*cosmetic.randf_range(0.03,0.1)*side
		var radius: float = size.length()*0.5
		var floor_y: float = clampf(sprite.end.y+cosmetic.randf_range(-0.08,0.12)*side,bounds.position.y+radius,bounds.end.y-radius)
		var at: Vector2 = sprite.get_center()+Vector2(cosmetic.randf_range(-0.12,0.12),cosmetic.randf_range(-0.15,0.15))*side
		at = at.clamp(bounds.position+Vector2.ONE*radius,bounds.end-Vector2.ONE*radius)
		var velocity := Vector2(cosmetic.randf_range(-0.8,2),-cosmetic.randf_range(0.6,1.8))*side*(0.3 if reduced else 2.0)
		drops.append({"p":at,"v":velocity,"floor":floor_y,"size":size,"radius":radius,"angle":0.0,"spin":0.0,"bounces":0,"resting":false,"blood":true,"color":Color("7b2038").lerp(Color("b94754"),cosmetic.randf())})
	return drops

## Advance scatter, spin and two small bounces with bounded simulation steps.
func advance(delta: float, reduced: bool) -> void:
	var remaining: float = minf(delta,0.25)
	while remaining > 0:
		var step: float = minf(remaining,1.0/120.0)
		remaining -= step
		for body in bodies.values():
			body.age += step
			for piece in body.movers:
				if piece.resting: continue
				piece.v.y += body.gravity*step
				piece.p += piece.v*step
				if not reduced: piece.angle += piece.spin*step
				var left: float = body.bounds.position.x+piece.radius
				var right: float = body.bounds.end.x-piece.radius
				if piece.p.x < left or piece.p.x > right:
					piece.p.x = clampf(piece.p.x,left,right)
					piece.v.x *= -0.45
				if piece.p.y < body.bounds.position.y+piece.radius:
					piece.p.y = body.bounds.position.y+piece.radius
					piece.v.y = maxf(0,piece.v.y)
				if piece.p.y >= piece.floor:
					piece.p.y = piece.floor
					piece.bounces += 1
					if piece.bounces >= (1 if reduced or piece.get("blood",false) else 3):
						piece.v = Vector2.ZERO
						piece.resting = true
					else:
						piece.v = Vector2(piece.v.x*0.4,-absf(piece.v.y)*0.25)
						piece.spin *= 0.5

## Draw fragments in the dead enemy's battlefield layer, below all interface overlays.
func draw(canvas: CanvasItem, index: int, alpha: float, hurt: float = 0.0) -> void:
	if not bodies.has(index): return
	var body: Dictionary = bodies[index]
	var blood_alpha: float = alpha*(1.0-smoothstep(1.5,3.5,body.age))
	for drop in body.blood:
		var size: Vector2 = drop.size*Vector2(1.65,0.5) if drop.resting else drop.size
		canvas.draw_rect(Rect2((drop.p-size*0.5).round(),size.round()),Color(drop.color,blood_alpha))
	for piece in body.pieces:
		canvas.draw_set_transform(piece.p.round(),piece.angle)
		var tint := Color.WHITE.lerp(Color("e99b81"),hurt*0.6)
		tint.a = alpha
		canvas.draw_texture_rect(piece.texture,Rect2(-piece.size*0.5,piece.size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

## Remove settled fragments when restarting or leaving the wave.
func clear() -> void:
	bodies.clear()
