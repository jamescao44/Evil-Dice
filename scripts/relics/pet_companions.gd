extends RefCounted
## Cosmetic companions use their own RNG and persistent species identities, never battle state.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const PETS := {
	"pet_bat":{"sprite":"relics/pet_bat.png","size":0.9,"hover":12.0},
	"pet_lizard":{"sprite":"relics/pet_lizard.png","size":1.0,"hover":0.0},
	"pet_slime":{"sprite":"relics/pet_slime.png","size":0.9,"hover":0.0},
	"pet_ghost":{"sprite":"relics/pet_ghost.png","size":1.0,"hover":8.0},
	"pet_dragon":{"sprite":"pets/dragon.png","size":1.25,"hover":0.0},
}
const JUMP_TIME := 0.58
var states: Dictionary = {}
var rng := RandomNumberGenerator.new()
var clock: float = 0.0
var textures: Dictionary = {}
var regions: Dictionary = {}
var masks: Dictionary = {}

func _init() -> void:
	rng.randomize()

## Clear only on run/debug reset; wave travel, rewards and fusion keep every pet in place.
func clear() -> void:
	states.clear()
	clock = 0.0

## Food ownership and fused components summon the same single companion of each species.
func sync(model) -> void:
	for id in PETS:
		if not model.relics.has(id):
			states.erase(id)
			continue
		if states.has(id): continue
		var slot: int = PETS.keys().find(id)
		var home := Vector2([-0.95,-0.45,0.12,0.62,1.1][slot],[0.15,-0.5,0.65,-0.35,0.3][slot])
		states[id] = {"offset":home,"target":home,"wait":rng.randf_range(0.4,1.8),"jump":-1.0,"again":false,"glow":0.0,"age":0.0,"facing":1.0,"moving":false,"slot":slot}

## Copy relics and fused balls notify the actual pet, not all five companions at once.
func activate(id: String) -> void:
	if not states.has(id): return
	var pet: Dictionary = states[id]
	pet.glow = 1.0
	if pet.jump >= 0: pet.again = true
	else: pet.jump = 0.0

## Wander in small personal lanes, then gather behind the player's travel direction.
func advance(delta: float, model, travelling: bool, direction: Vector2, reduced: bool) -> void:
	sync(model)
	clock += delta
	for id in states:
		var pet: Dictionary = states[id]
		pet.age += delta
		pet.glow = maxf(0,pet.glow-delta*2.0)
		if pet.jump >= 0:
			pet.jump += delta
			if pet.jump >= JUMP_TIME:
				pet.jump = 0.0 if pet.again else -1.0
				pet.again = false
		var target: Vector2 = pet.target
		if travelling:
			# A staggered flock keeps five sprites legible instead of stacking in one trail.
			var trail: Vector2 = [Vector2(-0.35,-3.2),Vector2(-0.7,-0.65),Vector2(-0.55,1.05),Vector2(-1.25,-3.0),Vector2(-1.25,-0.45)][pet.slot]
			target = Vector2(trail.x*direction.x,trail.y-direction.y*0.35)
			pet.wait = 0.2+pet.slot*0.25
		elif not reduced:
			pet.wait -= delta
			if pet.wait <= 0:
				var lane: float = [-0.95,-0.45,0.12,0.62,1.1][pet.slot]
				pet.target = Vector2(clampf(lane+rng.randf_range(-0.25,0.25),-1.2,1.3),rng.randf_range(-0.9,0.75))
				target = pet.target
				pet.wait = rng.randf_range(1.4,3.2)
		var before: Vector2 = pet.offset
		if not reduced: pet.offset = before.move_toward(target,delta*(3.0 if travelling else 0.35))
		var dx: float = pet.offset.x-before.x
		pet.moving = travelling or before.distance_to(pet.offset) > 0.0001
		if absf(dx) > 0.0001: pet.facing = signf(dx)

## Resolve world positions with enough floor clearance for the fixed health bars.
func poses(battle) -> Array:
	var result: Array = []
	var sprite := Rect2(battle._player_world_feet()-Vector2(battle.monster_side*0.5,battle.monster_side),Vector2.ONE*battle.monster_side)
	var visible: Rect2 = battle.evolution.visible_rect(sprite)
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var anchor: Vector2 = battle._player_world_feet()-Vector2(0,30)
	var radius: float = clampf(visible.size.x*0.75+45,120,150)
	for id in states:
		var pet: Dictionary = states[id]
		var size: float = (48.0 if portrait else 40.0)*PETS[id].size
		var ground: Vector2 = anchor+Vector2(pet.offset.x*radius,pet.offset.y*18)
		ground.x = clampf(ground.x,battle.ARENA.position.x+size*0.55+6,battle.ARENA.end.x-size*0.55-6)
		ground.y = minf(ground.y,battle.player_health_rect().position.y-10)
		var jump: float = 0.0
		if pet.jump >= 0 and not battle.reduced: jump = sin(PI*clampf((pet.jump/JUMP_TIME-0.12)/0.88,0,1))*size*0.55
		var bob: float = 0.0 if battle.reduced else sin(clock*(10 if pet.moving else 2.6)+pet.slot)* (2.5 if pet.moving else 1.4)
		result.append({"id":id,"pet":pet,"at":ground-Vector2(0,PETS[id].hover+jump+bob),"ground":ground,"size":size,"front":pet.offset.y>=0 or pet.glow>0,"jump":jump})
	result.sort_custom(func(a,b): return a.ground.y < b.ground.y)
	return result

## Cache the original creature sprite separately from its food relic icon.
func _load_sprite(id: String) -> void:
	if textures.has(id): return
	var texture: Texture2D = load("res://assets/art/"+PETS[id].sprite)
	textures[id] = texture
	var mask: Image = texture.get_image()
	regions[id] = Rect2(mask.get_used_rect())
	mask.convert(Image.FORMAT_RGBA8)
	for y in range(mask.get_height()):
		for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
	masks[id] = ImageTexture.create_from_image(mask)

## Ground shadows, small body motion and one activation hop keep the pets readable.
func paint(canvas: CanvasItem, battle, entries: Array, front: bool) -> void:
	for pose in entries:
		if pose.front != front: continue
		var id: String = pose.id
		var pet: Dictionary = pose.pet
		_load_sprite(id)
		var alpha: float = clampf(pet.age/0.25,0,1)
		var color: Color = Catalog.rarity_color(id)
		Pixel.disc(canvas,pose.ground,pose.size*0.35,Color(0.05,0.04,0.08,alpha*0.25),3,0.2)
		var source: Rect2 = regions[id]
		var size: Vector2 = source.size*pose.size/maxf(source.size.x,source.size.y)
		var stretch := Vector2.ONE
		if not battle.reduced:
			var motion: float = sin(clock*(14 if id == "pet_bat" else 9)+pet.slot)*(0.08 if pet.moving or id == "pet_bat" else 0.025)
			stretch = Vector2(1+motion,1-motion)
			if pet.jump >= 0 and pet.jump < JUMP_TIME*0.12: stretch *= Vector2(1.12,0.85)
		canvas.draw_set_transform(pose.at,0,Vector2(pet.facing,1)*stretch)
		var rect := Rect2(Vector2(-size.x/2,-size.y),size)
		if pet.glow > 0:
			for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				canvas.draw_texture_rect_region(masks[id],Rect2(rect.position+side*2,rect.size),source,Color(color,pet.glow*alpha*0.7))
		canvas.draw_texture_rect_region(textures[id],rect,source,Color(1,1,1,alpha))
		if pet.glow > 0: canvas.draw_texture_rect_region(masks[id],rect,source,Color(1,0.95,0.76,pet.glow*alpha*0.28))
		canvas.draw_set_transform(Vector2.ZERO)
		if pet.glow > 0:
			for i in range(3):
				var sparkle: Vector2 = pose.at+Vector2((i-1)*pose.size*0.36,-pose.size*(0.8+0.15*sin(clock*4+i)))
				canvas.draw_rect(Rect2(sparkle,Vector2(3,6)),Color(color,pet.glow*alpha))
