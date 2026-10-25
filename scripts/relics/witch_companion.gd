extends RefCounted
## A close spectral follower for Ghost of the Witch, separate from the five-pet collection.
const ART = preload("res://assets/art/pets/witch_ghost.png")
const GLOW := Color("b8a4ff")
var opacity: float = 0.0
var pulse: float = 0.0
var clock: float = 0.0
var region: Rect2
var mask: ImageTexture

## Remove the old run's follower without carrying its acquisition flash into a restart.
func clear() -> void:
	opacity = 0
	pulse = 0
	clock = 0

## Each real Witch attack lights the follower, including copied activations.
func activate(id: String) -> void:
	if id == "witch_ghost": pulse = 1.0

## Fade with ownership while keeping every cosmetic motion independent of gameplay RNG.
func advance(delta: float, model) -> void:
	clock += delta
	opacity = move_toward(opacity,1.0 if model.relics.has("witch_ghost") else 0.0,delta*4)
	pulse = maxf(0,pulse-delta*1.8)

## Place her just behind the player's left shoulder, below the fixed counter UI.
func sprite_rect(battle) -> Rect2:
	var player: Rect2 = battle.evolution.visible_rect(battle._player_world_sprite_rect())
	var height: float = clampf(player.size.y*0.92,76,145)
	var width: float = height*region.size.x/maxf(1,region.size.y)
	var sway: Vector2 = Vector2.ZERO if battle.reduced else Vector2(sin(clock*1.5)*2,sin(clock*2.2)*4-pulse*4)
	var feet: Vector2 = Vector2(player.get_center().x-player.size.x*0.35-width*0.35,player.end.y-12)+sway
	feet.x = maxf(battle.ARENA.position.x+width*0.5+4,feet.x)
	return Rect2(feet-Vector2(width*0.5,height),Vector2(width,height))

## Cache a pale silhouette for the translucent aura without changing the original artwork.
func prepare_art() -> void:
	if mask != null: return
	var pixels: Image = ART.get_image()
	region = Rect2(pixels.get_used_rect())
	pixels.convert(Image.FORMAT_RGBA8)
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()): pixels.set_pixel(x,y,Color(1,1,1,pixels.get_pixel(x,y).a))
	mask = ImageTexture.create_from_image(pixels)

## Render before the player so the follower never covers the character or the HUD.
func paint(canvas: CanvasItem, battle) -> void:
	if opacity <= 0: return
	prepare_art()
	var rect: Rect2 = sprite_rect(battle)
	var alpha: float = opacity*(0.62+0.16*pulse)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		for spread in [2,5]:
			canvas.draw_texture_rect_region(mask,Rect2(rect.position+direction*spread,rect.size),region,Color(GLOW,opacity*(0.08+0.08*pulse)))
	canvas.draw_texture_rect_region(ART,rect,region,Color(0.82,0.9,1,alpha))
	canvas.draw_texture_rect_region(mask,rect,region,Color(GLOW,opacity*(0.13+0.2*pulse)))
	# Three soft drifting motes keep the apparition readable even beside bright fire art.
	for i in range(3):
		var age: float = 0.5 if battle.reduced else fposmod(clock*0.35+i/3.0,1.0)
		var at: Vector2 = rect.position+Vector2(rect.size.x*(0.2+0.3*i),rect.size.y*(1-age))
		canvas.draw_rect(Rect2(at.round(),Vector2.ONE*(2+int(pulse*2))),Color(GLOW,opacity*sin(age*PI)*0.55))
