extends Node2D
## Short level-up celebrations and stronger transformations at five-level milestones.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const DURATION := 1.8
const REVEAL := 0.85
const FORM_COUNT := 3
const LEVEL_DURATION := 0.85
const LEVEL_REVEAL := 0.08
var battle
var displayed_level := 1
var target_level := 1
var queued: Array = []
var age := -1.0
var forms: Array[Texture2D] = []
var silhouettes: Array[Texture2D] = []
var visible_bounds: Array[Rect2] = []

## Cache sprites and white silhouettes once, rather than rebuilding them during effects.
func _ready() -> void:
	z_index = 95
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Existing forms cover levels 1–4, 5–9 and 10+; later milestones retain the final art.
	for i in range(FORM_COUNT):
		var texture: Texture2D = load("res://assets/art/player/flamelings/level-%d.png" % (i+2))
		forms.append(texture)
		var mask: Image = texture.get_image()
		var used: Rect2 = Rect2(mask.get_used_rect())
		visible_bounds.append(Rect2(used.position/Vector2(mask.get_size()),used.size/Vector2(mask.get_size())))
		for y in range(mask.get_height()):
			for x in range(mask.get_width()): mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
		silhouettes.append(ImageTexture.create_from_image(mask))
	battle.model.character_leveled.connect(enqueue)

## Preserve every level celebration if one reward crosses several thresholds.
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

## Map uncapped character levels to the available evolution artwork.
func form_index(level: int) -> int:
	return clampi(floori(level/float(battle.model.EVOLUTION_INTERVAL)),0,FORM_COUNT-1)

func is_evolution() -> bool:
	return target_level % battle.model.EVOLUTION_INTERVAL == 0

func reveal_time() -> float:
	return REVEAL if is_evolution() else LEVEL_REVEAL

func duration() -> float:
	return DURATION if is_evolution() else LEVEL_DURATION

## Celebrate once XP reaches the bar; menus and shops defer only the visual.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and battle.view_phase != "shop" and not battle.chest.active and not battle.tarot_ui.ceremony.active()
	if not visible: return
	if age < 0 and not queued.is_empty():
		if is_instance_valid(battle.soul_pickup) and battle.soul_pickup.counter_state().level < queued[0]: return
		target_level = queued.pop_front()
		age = 0
		battle._sound("item/bell",0.8 if is_evolution() else 1.2,-12)
	if age >= 0:
		var previous := age
		age += delta
		if previous < reveal_time() and age >= reveal_time():
			displayed_level = target_level
			if is_evolution(): battle._sound("enemy/bell",1.1,-10)
		if age >= duration(): age = -1
	queue_redraw()

## Render the current form with an eased white silhouette at the transformation peak.
func draw_actor(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
	if forms.is_empty(): return
	var index: int = form_index(displayed_level)
	canvas.draw_texture_rect(forms[index],rect,false,tint)
	if age < 0: return
	var glow: float = smoothstep(0.15,REVEAL,age)*(1-smoothstep(REVEAL,1.3,age)) if is_evolution() else sin(clampf(age/LEVEL_DURATION,0,1)*PI)*0.32
	canvas.draw_texture_rect(silhouettes[index],rect,false,Color(0.8,0.97,1,glow*0.95))

## Exclude transparent sprite padding when placing character-attached UI.
func visible_rect(rect: Rect2) -> Rect2:
	if visible_bounds.is_empty(): return rect
	var bounds: Rect2 = visible_bounds[form_index(displayed_level)]
	return Rect2(rect.position+bounds.position*rect.size,bounds.size*rect.size)

## Lift a level label above the player; milestone evolutions add a silhouette swap.
func _draw() -> void:
	if not visible: return
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	if age < 0: return
	var t: float = clampf(age/duration(),0,1)
	var center: Vector2 = battle._player_point()
	var side: float = battle.monster_side
	var alpha: float = sin(t*PI)
	var tint := Color("ffcf59") if is_evolution() else Color("a5e4ef")
	var charge: float = clampf(age/reveal_time(),0,1)
	if not battle.reduced:
		# Rising ribbons gather into the body, then the reveal ring travels outward.
		var count: int = 16 if is_evolution() else 8
		for i in range(count):
			var angle: float = i*TAU/count+age*2
			var radius: float = side*(0.65-charge*0.22)
			var at: Vector2 = center+Vector2(cos(angle)*radius,sin(angle)*radius*0.30+(0.5-fposmod(age*1.2+i*0.17,1))*side)
			Pixel.disc(self,at,3+i%3,Color(tint,alpha),2)
		for i in range(6 if is_evolution() else 0):
			var x: float = (i-2.5)*side*0.13
			draw_line(center+Vector2(x,side*0.45),center+Vector2(x,-side*(0.5+charge)),Color(tint,alpha*0.08),8)
	if age >= reveal_time():
		var release: float = (age-reveal_time())/(duration()-reveal_time())
		Pixel.circle(self,center,side*(0.3+release),Color(tint,(1-release)*0.8),3)
		var title := GameText.format("LEVEL %d",displayed_level)
		if is_evolution(): title = GameText.text("EVOLUTION")+" · "+GameText.format("LV. %d",displayed_level)
		var rise: float = release*42
		var font_size: int = 36 if portrait else 28
		var half_width: float = battle.description_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2
		var label_at: Vector2 = center-Vector2(0,side*0.65+rise)
		label_at.x = clampf(label_at.x,battle.ARENA.position.x+half_width+16,battle.ARENA.end.x-half_width-16)
		Cards.text(self,battle.description_font,label_at,title,font_size,Color(tint,alpha))
