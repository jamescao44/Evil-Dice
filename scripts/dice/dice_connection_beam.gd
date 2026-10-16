extends RefCounted
## Cached filament texture and moving highlights for the dice-connection laser.
static var texture: Texture2D

## Generate the soft, noisy beam once without consuming gameplay randomness.
static func _texture() -> Texture2D:
	if texture != null: return texture
	var image := Image.create(256,48,false,Image.FORMAT_RGBA8)
	for x in range(256):
		for y in range(48):
			var across: float = (y-23.5)/23.5
			var noise: float = fposmod(sin(x*12.9898+y*78.233)*43758.5453,1.0)
			var filament: float = sin(x*0.13+y*0.75)*0.16+sin(x*0.047-y*1.1)*0.12
			var alpha: float = exp(-pow(across+filament,2)*4.0)*(0.35+noise*0.65)
			image.set_pixel(x,y,Color(1,1,1,alpha))
	texture = ImageTexture.create_from_image(image)
	return texture

## Paint a broad colored halo, textured core and flowing white energy streaks.
static func paint(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, clock: float, scale: float, reduced: bool) -> void:
	var length: float = from.distance_to(to)
	if length < 1: return
	var width: float = 24*scale
	for layer in [[2.4,0.05],[1.7,0.11],[1.0,0.24]]:
		canvas.draw_line(from,to,Color(color,layer[1]),width*layer[0],true)
	canvas.draw_set_transform(from,(to-from).angle())
	canvas.draw_texture_rect(_texture(),Rect2(0,-width/2,length,width),false,Color(color.lightened(0.2),0.95))
	canvas.draw_line(Vector2.ZERO,Vector2(length,0),Color(color.lightened(0.75),0.85),4*scale,true)
	for index in range(ceili(length/(36*scale))):
		var x: float = fposmod(index*36*scale+(0 if reduced else clock*110*scale),length)
		var y: float = sin(index*2.4+(0 if reduced else clock*4))*width*0.24
		canvas.draw_line(Vector2(x,y),Vector2(minf(length,x+12*scale),y),Color(1,1,1,0.75),2*scale,true)
	canvas.draw_set_transform(Vector2.ZERO)
