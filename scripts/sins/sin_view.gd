extends Node2D
## An always-processing modal owns a real scene pause; cosmetic time never touches combat RNG.
const Catalog = preload("res://scripts/sins/sin_catalog.gd")
const PlayerSprite = preload("res://scripts/player/player_sprite.gd")
const Aura = preload("res://scripts/sins/sin_aura.gd")
var battle
var queue: Array = []
var current := ""
var mode := ""
var age := 0.0
var clock_time := 0.0
var prior_pause := false
var opening := false
var flash := 0.0
var textures: Dictionary = {}
var glow: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in Catalog.ORDER: textures[id] = Catalog.icon(id)
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	var radial := GradientTexture2D.new()
	radial.gradient = gradient; radial.width = 128; radial.height = 128
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5,0.5); radial.fill_to = Vector2(1,0.5)
	glow = radial
	battle.model.sins.awakened.connect(enqueue)

## Queue simultaneous awakenings, showing each one without briefly resuming the battle.
func enqueue(id: String) -> void:
	if id in queue or current == id: return
	queue.append(id)
	_try_next()

## Debug can queue several awakenings; keep the options usable until every menu is closed.
func _try_next() -> void:
	if active() or queue.is_empty() or battle.menu_open or battle.debug_open or battle.guide: return
	_open(queue.pop_front(),true)

func active() -> bool:
	return not current.is_empty()

## Pending pages also block combat during the frame between menu close and presentation.
func blocks_battle() -> bool:
	return active() or not queue.is_empty()

## Restarting or jumping waves discards pages that belong to the previous run.
func reset() -> void:
	if active(): get_tree().paused = prior_pause
	queue.clear(); current = ""; mode = ""; age = 0; flash = 0

func _open(id: String, awakening: bool) -> void:
	if not active(): prior_pause = get_tree().paused
	current = id; opening = awakening; mode = "enter"; age = 0
	get_tree().paused = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

## All seven icons fit in one anchored row above the right edge of the HP bar.
func icon_rect(id: String) -> Rect2:
	var ids: Array = Catalog.ORDER.filter(func(key): return battle.model.sins.has(key))
	var at: int = ids.find(id)
	var hp: Rect2 = battle.player_health_rect()
	var portrait: bool = battle.fx.canvas_size.y > battle.fx.canvas_size.x
	var size: float = minf(38 if portrait else 28,hp.size.x/maxi(1,ids.size())-3)
	var right: float = hp.end.x
	return Rect2(right-(ids.size()-at)*(size+3),hp.position.y-size-12,size,size)

func hud_visible() -> bool:
	return battle.BattlefieldRender.overlays_visible(battle) and not battle.model.sins.unlocked.is_empty()

func hit(point: Vector2) -> String:
	if not hud_visible(): return ""
	for id in Catalog.ORDER:
		if battle.model.sins.has(id) and icon_rect(id).grow(3).has_point(point): return id
	return ""

## Press-to-inspect supports both taps and holds; the opening release cannot dismiss the page.
func _input(event: InputEvent) -> void:
	var pointer: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch
	if active():
		if pointer and event.pressed and mode != "leave" and age > 0.32: mode = "leave"; age = 0
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_ENTER,KEY_SPACE] and mode != "leave": mode = "leave"; age = 0
		get_viewport().set_input_as_handled()
	elif pointer and event.pressed:
		var id: String = hit(battle.get_global_transform_with_canvas().affine_inverse()*event.position)
		if not id.is_empty():
			get_viewport().set_input_as_handled()
			_open(id,false)

func _process(delta: float) -> void:
	if not is_instance_valid(battle): return
	queue = queue.filter(func(id): return battle.model.sins.has(id))
	_try_next()
	clock_time += delta
	flash = maxf(0,flash-delta*3)
	if active():
		age += delta
		if mode == "enter" and age >= 0.7: mode = "hold"
		if mode == "leave" and age >= 0.48:
			current = ""; mode = ""; flash = 1
			if not queue.is_empty():
				var saved_pause: bool = prior_pause
				_open(queue.pop_front(),true)
				prior_pause = saved_pause
			else: get_tree().paused = prior_pause
	queue_redraw()

## Scene teardown must never leave the title screen or a subsequent run paused.
func _exit_tree() -> void:
	if active() and is_inside_tree(): get_tree().paused = prior_pause

func _center(text: String, at: Vector2, size: int, tint: Color) -> void:
	var font: Font = GameText.description_font()
	var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_string_outline(font,at-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color(0.02,0.015,0.04,tint.a))
	draw_string(font,at-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,tint)

func _paragraph(text: String, y: float, width: float, size: int, tint: Color) -> float:
	var font: Font = GameText.description_font()
	var lines: PackedStringArray = GameText.lines(text,font,size,width)
	for line in lines:
		_center(line,Vector2(battle.fx.canvas_size.x*0.5,y),size,tint)
		y += size*1.5
	return y

## Each sigil has its own color, a dark aura, drifting embers and a restrained breathing halo.
func _sigil(id: String, center: Vector2, side: float, alpha: float, intensity: float = 1.0) -> void:
	var color: Color = Catalog.ITEMS[id].color
	var pulse: float = 0.95+0.05*sin(clock_time*2.2)
	draw_texture_rect(glow,Rect2(center-Vector2.ONE*side,Vector2.ONE*side*2),false,Color(color,alpha*0.38*intensity*pulse))
	draw_texture_rect(glow,Rect2(center-Vector2.ONE*side*0.64,Vector2.ONE*side*1.28),false,Color(0.015,0.006,0.03,alpha*0.86))
	for i in range(3):
		var width: float = side*(1.04+i*0.045)
		draw_texture_rect(textures[id],Rect2(center-Vector2.ONE*width*0.5,Vector2.ONE*width),false,Color(1,1,1,alpha*0.10*intensity))
	draw_texture_rect(textures[id],Rect2(center-Vector2.ONE*side*0.5,Vector2.ONE*side),false,Color(1,1,1,alpha))
	if battle.reduced or side < 50: return
	for i in range(40):
		var p: float = fposmod(clock_time*(0.12+(i%7)*0.014)+i*0.618,1)
		var angle: float = i*2.399+clock_time*(0.12 if i%2 else -0.12)
		var at: Vector2 = center+Vector2(cos(angle)*side*(0.5+p*0.42),sin(angle)*side*(0.3+p*0.4)-p*side*0.25)
		var fade: float = sin(p*PI)*alpha
		draw_circle(at,1.3+(i%3)*0.6,Color(color,fade*0.8))
		draw_line(at,at+Vector2(sin(angle)*3,-5-(i%4)*2),Color(color,fade*0.35),1.2,true)

func _draw() -> void:
	if not is_instance_valid(battle): return
	if not active():
		if not hud_visible(): return
		for id in Catalog.ORDER:
			if battle.model.sins.has(id):
				var rect: Rect2 = icon_rect(id)
				_sigil(id,rect.get_center(),rect.size.x*(1+flash*0.15),1,1.0+flash)
		return
	var viewport: Vector2 = battle.fx.canvas_size
	var phone: bool = viewport.y > viewport.x
	var center := viewport*Vector2(0.5,0.35 if phone else 0.36)
	var side: float = minf(viewport.x*0.31,260 if phone else 185)
	var progress: float = clampf(age/0.7,0,1)
	var alpha: float = smoothstep(0,0.22,age) if mode == "enter" else 1.0
	var text_alpha: float = smoothstep(0.16,0.65,age) if mode == "enter" else 1.0
	if mode == "leave":
		var leave: float = smoothstep(0,0.48,age)
		alpha = 1-leave
		text_alpha = 1-smoothstep(0,0.18,age)
		center = center.lerp(icon_rect(current).get_center(),leave)
		side = lerpf(side,icon_rect(current).size.x,leave)
	elif mode == "enter":
		center.y += (1-progress)*(1-progress)*54
		side *= 0.66+0.34*(1-pow(1-progress,3))+sin(progress*PI)*0.11
	draw_rect(Rect2(Vector2.ZERO,viewport),Color(0.014,0.008,0.025,0.92*alpha))
	var tint: Color = Catalog.ITEMS[current].color
	if mode != "leave":
		for i in range(3):
			var radius: float = side*(0.73+i*0.18)
			draw_arc(center,radius,clock_time*0.08+i,clock_time*0.08+i+PI*1.4,70,Color(tint,alpha*(0.07-i*0.015)),1,true)
	_sigil(current,center,side,1 if mode == "leave" else alpha,1.5)
	if text_alpha <= 0: return
	var title_y: float = viewport.y*(0.35 if phone else 0.36)+minf(viewport.x*0.31,260 if phone else 185)*0.75
	_center(GameText.text("SIN AWAKENED" if opening else "AWAKENED SIN"),Vector2(viewport.x*0.5,viewport.y*(0.16 if phone else 0.13)),24 if phone else 18,Color(tint,text_alpha))
	_center(GameText.text(Catalog.ITEMS[current].name),Vector2(viewport.x*0.5,title_y),52 if phone else 34,Color(tint,text_alpha))
	var y: float = title_y+(66 if phone else 40)
	y = _paragraph(GameText.text(Catalog.ITEMS[current].condition),y,viewport.x*0.78,26 if phone else 21,Color(0.72,0.70,0.77,text_alpha))
	y = _paragraph(GameText.text(Catalog.ITEMS[current].effect),y+(28 if phone else 18),viewport.x*0.80,29 if phone else 23,Color(0.96,0.93,0.98,text_alpha))
	_center(GameText.text("Tap to continue"),Vector2(viewport.x*0.5,maxf(y+54,viewport.y*0.83)),22 if phone else 17,Color(0.65,0.61,0.72,text_alpha*0.9))

## Repeating silhouette echoes stay behind the actor and inherit its exact animated pose.
func paint_aura(canvas: CanvasItem, rect: Rect2) -> void:
	var ids: Array = battle.model.sins.unlocked
	if ids.is_empty() or battle.reduced: return
	var pose: Dictionary = battle.evolution.actor_pose(rect)
	var colors: Array = ids.map(func(id): return Catalog.ITEMS[id].color)
	Aura.paint(canvas,pose.body,pose.form,pose.frame,colors,battle.clock_time)
