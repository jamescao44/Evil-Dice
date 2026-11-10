extends Node2D
## Short level-up celebrations and stronger transformations at five-level milestones.
const Sprite = preload("res://scripts/player/player_sprite.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const Entrance = preload("res://scripts/player/player_entrance.gd")
const REVEAL := 0.85
const FORM_COUNT := 3
# Opt individual character forms into the retained procedural advancing bounce.
const ADVANCE_BOUNCE_FORMS := {"horror":[false,false,false]}
const LEVEL_DURATION := 0.85
const LEVEL_REVEAL := 0.08
var battle
var displayed_level := 1
var target_level := 1
var queued: Array = []
var age := -1.0
var forms: Array[Texture2D] = []
var visible_bounds: Array[Rect2] = []
var entrance = Entrance.new()
var source_form := 0
var source_frame := 2
var source_rect := Rect2()
var transforming := false

## Cache sprites and white silhouettes once, rather than rebuilding them during effects.
func _ready() -> void:
	z_index = BattleLayers.EVOLUTION
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Keep previews and silhouette masks separate for all three authored forms.
	for i in range(FORM_COUNT):
		forms.append(Sprite.texture(1,i))
		visible_bounds.append(Sprite.rest_bounds(i))
		Sprite.silhouette(i)
	battle.player_animation.set_form(form_index(displayed_level))
	battle.model.defer_level_healing = true
	battle.model.character_leveled.connect(enqueue)

## Preserve every level celebration if one reward crosses several thresholds.
func enqueue(level: int) -> void:
	queued.append(level)

func active() -> bool:
	return age >= 0 or not queued.is_empty() or entrance.active()

## Reset presentation alongside the run, including an interrupted transformation.
func reset() -> void:
	queued.clear()
	age = -1
	entrance.reset()
	source_rect = Rect2()
	transforming = false
	displayed_level = battle.model.character_level
	target_level = displayed_level
	battle.player_animation.set_form(form_index(displayed_level))
	queue_redraw()

## Summon the checkpoint's current form once on entering a level, before opening effects.
func start_entrance() -> void:
	reset()
	battle.player_animation.cancel_emote()
	entrance.start(form_index(displayed_level))

## Debug updates replace pending celebrations but preserve the currently visible form.
func queue_debug_level(level: int) -> void:
	queued.clear()
	age = -1
	entrance.reset()
	source_rect = Rect2()
	transforming = false
	if level != displayed_level: queued.append(level)
	else: battle.model.complete_level_heal(level) # Reapplying the same debug level has no animation.
	queue_redraw()

## Map uncapped character levels to the available evolution artwork.
func form_index(level: int) -> int:
	return clampi(floori(level/float(battle.model.EVOLUTION_INTERVAL)),0,FORM_COUNT-1)

## Walking sprites stay grounded; future characters/forms can explicitly enable the bounce.
func advance_bounce_enabled() -> bool:
	var settings: Array = ADVANCE_BOUNCE_FORMS.get(battle.selected_ancient_id,[])
	if settings.is_empty(): return false
	return settings[clampi(form_index(displayed_level),0,settings.size()-1)]

func is_evolution() -> bool:
	return transforming

func reveal_time() -> float:
	return REVEAL if is_evolution() else LEVEL_REVEAL

func duration() -> float:
	if not is_evolution(): return LEVEL_DURATION
	var clip: Dictionary = Entrance.CLIPS[form_index(target_level)]
	return REVEAL+float(clip.last-clip.first+1)/Sprite.IDLE_FPS+Entrance.FADE

## Celebrate once XP reaches the bar; menus and shops defer only the visual.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and battle.view_phase != "shop" and not battle.chest.active and not battle.tarot_ui.ceremony.active()
	if not visible: return
	if age < 0 and not entrance.active() and not queued.is_empty():
		if is_instance_valid(battle.soul_pickup) and battle.soul_pickup.counter_state().level < queued[0]: return
		target_level = queued.pop_front()
		transforming = form_index(target_level) != form_index(displayed_level)
		if transforming: battle.player_animation.cancel_emote()
		source_form = form_index(displayed_level)
		source_frame = battle.player_animation.frame_number()
		source_rect = Rect2()
		age = 0
		battle._sound("item/bell",0.8 if is_evolution() else 1.2,-12)
	if age >= 0:
		var previous := age
		age += delta
		if previous < reveal_time() and age >= reveal_time():
			if is_evolution(): source_rect = battle._player_world_sprite_rect()
			displayed_level = target_level
			battle.player_animation.set_form(form_index(displayed_level))
			if is_evolution():
				entrance.start(form_index(displayed_level),true)
				battle._sound("enemy/bell",1.1,-10)
		if is_evolution() and age >= reveal_time(): entrance.advance(age-maxf(previous,reveal_time()))
		if age >= duration():
			battle.model.complete_level_heal(target_level)
			battle.health_trails.sync(battle.model)
			age = -1
	else:
		entrance.advance(delta)
	queue_redraw()

## Entrances and their preparation own the body until the summoning circle fades.
func blocks_emote() -> bool:
	return entrance.active() or (age >= 0 and is_evolution())

## Share the exact authored pose between the character and silhouette-based effects.
func actor_pose(rect: Rect2) -> Dictionary:
	var form: int = form_index(displayed_level)
	battle.player_animation.set_form(form)
	var frame: int = battle.player_animation.frame_number()
	var body: Rect2 = battle.player_animation.body_rect(rect,battle.reduced)
	# A white-light crossfade preserves the authored silhouette instead of stretching it.
	if age >= 0 and is_evolution() and age < REVEAL: body = rect
	var entering: bool = entrance.active()
	if entering:
		body = rect
		frame = entrance.frame_number(Sprite.idle_frame(maxf(0,entrance.age-entrance.clip_duration()),form))
	return {"form":form,"frame":frame,"body":body}

## Render the current form with an eased white silhouette at the transformation peak.
func draw_actor(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
	if forms.is_empty(): return
	var pose: Dictionary = actor_pose(rect)
	var form: int = pose.form
	var frame: int = pose.frame
	var body: Rect2 = pose.body
	var entering: bool = entrance.active()
	entrance.paint_ground(canvas,rect,battle.reduced,tint)
	Sprite.paint_actor(canvas,rect,frame,battle.clock_time,tint,battle.reduced,form,body,entrance.ring_alpha(),entrance.ring_flash())
	var glow: float = 0
	if entering: glow = entrance.white_alpha()
	elif age >= 0:
		if is_evolution() and age < REVEAL: glow = smoothstep(0.15,REVEAL-0.12,age)
		elif not is_evolution(): glow = sin(clampf(age/LEVEL_DURATION,0,1)*PI)*0.32
	if glow > 0: Sprite.paint(canvas,body,frame,Color(1,1,1,glow*tint.a),true,form)
	# A short white crossfade bridges the outgoing silhouette and the new entrance pose.
	if entering and entrance.evolved and source_rect.has_area() and entrance.age < 0.24:
		Sprite.paint(canvas,source_rect,source_frame,Color(1,1,1,(1-smoothstep(0,0.24,entrance.age))*tint.a),true,source_form)
	entrance.paint_release(canvas,rect,battle.reduced,tint)

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
