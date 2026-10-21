extends Node2D
## Level-specific forms and a queued charge, silhouette swap and release animation.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const DURATION := 1.8
const REVEAL := 0.85
var battle
var displayed_level := 1
var target_level := 1
var queued: Array = []
var age := -1.0
var forms: Array[Texture2D] = []
var silhouettes: Array[Texture2D] = []

## Cache sprites and white silhouettes once, rather than rebuilding them during effects.
func _ready() -> void:
	z_index = 95
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The ember starter is retired; the three original Flamelings are levels 1–3.
	for i in range(battle.model.MAX_CHARACTER_LEVEL):
		var texture: Texture2D = load("res://assets/art/player/flamelings/level-%d.png" % (i+2))
		forms.append(texture)
		var mask: Image = texture.get_image()
		for y in range(mask.get_height()):
			for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
		silhouettes.append(ImageTexture.create_from_image(mask))
	battle.model.character_leveled.connect(enqueue)

## Preserve every evolution if one reward buys several levels at once.
func enqueue(level: int) -> void:
	queued.append(level)

func active() -> bool:
	return age >= 0 or not queued.is_empty()

## Reset presentation alongside the run, including an interrupted transformation.
func reset() -> void:
	queued.clear()
	age = -1
	displayed_level = battle.model.character_level
	target_level = displayed_level
	queue_redraw()

## Advance in real time; menus suspend the visual without repeating the soul transaction.
func _process(delta: float) -> void:
	if battle._menus_open() or battle.view_phase == "shop" or (is_instance_valid(battle.soul_pickup) and not battle.soul_pickup.orbs.is_empty()): return
	if age < 0 and not queued.is_empty():
		target_level = queued.pop_front()
		age = 0
		battle._sound("item/bell",0.8,-12)
	if age >= 0:
		var previous := age
		age += delta
		if previous < REVEAL and age >= REVEAL:
			displayed_level = target_level
			battle._sound("enemy/bell",1.1,-10)
		if age >= DURATION: age = -1
	queue_redraw()

## Render the current form with an eased white silhouette at the transformation peak.
func draw_actor(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
	if forms.is_empty(): return
	var index: int = clampi(displayed_level-1,0,forms.size()-1)
	canvas.draw_texture_rect(forms[index],rect,false,tint)
	if age < 0: return
	var glow: float = smoothstep(0.15,REVEAL,age)*(1-smoothstep(REVEAL,1.3,age))
	canvas.draw_texture_rect(silhouettes[index],rect,false,Color(0.8,0.97,1,glow*0.95))

## Keep the level visible in the header with no manual upgrade button.
func _draw() -> void:
	if battle._menus_open() or battle.tarot_ui.ceremony.active(): return
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var header := Vector2(258,155) if portrait else Vector2(870 if battle.view_phase in ["shop","reward"] else 600,40)
	var visible_level: int = battle.soul_pickup.counter_state().level if is_instance_valid(battle.soul_pickup) else battle.model.character_level
	Cards.text(self,battle.description_font,header,GameText.format("LV. %d",visible_level),26 if portrait else 20,Color("a5e4ef"))
	if age < 0: return
	var t: float = clampf(age/DURATION,0,1)
	var center: Vector2 = battle._player_point()
	var side: float = battle.monster_side
	var alpha: float = sin(t*PI)
	var tint := Color("a5e4ef")
	var charge: float = clampf(age/REVEAL,0,1)
	if not battle.reduced:
		# Rising ribbons gather into the body, then the reveal ring travels outward.
		for i in range(16):
			var angle: float = i*TAU/16+age*2
			var radius: float = side*(0.65-charge*0.22)
			var at: Vector2 = center+Vector2(cos(angle)*radius,sin(angle)*radius*0.30+(0.5-fposmod(age*1.2+i*0.17,1))*side)
			Pixel.disc(self,at,3+i%3,Color(tint,alpha),2)
		for i in range(6):
			var x: float = (i-2.5)*side*0.13
			draw_line(center+Vector2(x,side*0.45),center+Vector2(x,-side*(0.5+charge)),Color(tint,alpha*0.08),8)
	if age >= REVEAL:
		var release: float = (age-REVEAL)/(DURATION-REVEAL)
		Pixel.circle(self,center,side*(0.3+release),Color(tint,(1-release)*0.8),3)
		var title := GameText.format("LEVEL %d",displayed_level)
		Cards.text(self,battle.description_font,center-Vector2(0,side*0.75),title,36 if portrait else 28,Color(tint,alpha))
		Cards.text(self,battle.description_font,center-Vector2(0,side*0.55),"BASE DMG x1.5  ·  HP +50%",24 if portrait else 18,Color(tint,alpha))
