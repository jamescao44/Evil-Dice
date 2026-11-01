extends SceneTree
## GPU checks ensure combat pixels stay in the arena while UI particles remain visible.
const Effects = preload("res://scripts/effects/effects.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func rendered() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

## Even an opaque layer at the ultimate ripple's depth must not obscure damage text.
func damage_overlay() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fx = Effects.new(); viewport.add_child(fx); fx.set_process(false)
	fx.font = ThemeDB.fallback_font; fx.canvas_size = Vector2(256,256)
	fx.clip_battlefield(Rect2(40,40,160,160))
	var overlay := CanvasLayer.new(); overlay.layer = 128; viewport.add_child(overlay)
	var white := ColorRect.new(); white.size = Vector2(256,256); overlay.add_child(white)
	fx.damage_number(Vector2(130,120),"-123",Color.RED)
	fx._sync_damage_layer()
	await rendered(); await rendered()
	var pixels := 0
	var shot: Image = viewport.get_texture().get_image()
	for y in range(256):
		for x in range(256):
			var color: Color = shot.get_pixel(x,y)
			if color.r > 0.8 and color.g < 0.2 and color.b < 0.2: pixels += 1
	check(pixels > 50,"Damage numbers remain legible above the brightest FX layer")
	fx.hide(); await rendered(); await rendered()
	shot = viewport.get_texture().get_image()
	pixels = 0
	for y in range(256):
		for x in range(256):
			if shot.get_pixel(x,y) != Color.WHITE: pixels += 1
	check(pixels == 0,"Hiding combat FX also hides the independent text layer")
	viewport.queue_free(); await process_frame

## Stress every shared primitive at the arena edge, alongside an intentionally external UI spark.
func particles() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fx = Effects.new()
	viewport.add_child(fx); fx.set_process(false)
	fx.font = ThemeDB.fallback_font; fx.canvas_size = Vector2(256,256)
	var arena := Rect2(40,40,160,150)
	fx.clip_battlefield(arena)
	fx.flame_cast(3,Vector2(60,100),[Vector2(195,60)],1.0,[20],[Vector2(195,185)])
	fx.spell.hold_damage = true; fx.begin_flame_damage(); fx._process(0.4)
	fx.burst(Vector2(195,42),Color.ORANGE,80,500)
	fx.ring(Vector2(40,40),Color.RED,200)
	fx.activate_circle(Vector2(190,180),Color.GOLD,200)
	fx.slash(Vector2(198,40),true,10000)
	fx.damage_number(Vector2(220,24),"99999",Color.RED)
	fx.flash(Color.WHITE,0.4)
	fx.burst(Vector2(12,230),Color.GREEN,1,0,1,true)
	fx.queue_redraw(); fx.battlefield_canvas.queue_redraw()
	await rendered(); await rendered()
	var shot: Image = viewport.get_texture().get_image()
	var leaked := 0; var inside := 0; var ui := 0
	for y in range(256):
		for x in range(256):
			if shot.get_pixel(x,y).a <= 0: continue
			if arena.has_point(Vector2(x,y)): inside += 1
			elif Rect2(12,230,12,12).has_point(Vector2(x,y)): ui += 1
			else: leaked += 1
	check(inside > 500,"Combat effects actually render inside the battlefield")
	check(leaked == 0,"Spells, particles, rings, flashes and damage labels cannot leak outside the arena")
	check(ui > 0,"Dice and reward UI particles are not accidentally clipped")
	viewport.queue_free(); await process_frame

## The screen-copy shader must leave the HUD pixel-identical in both layouts.
func ripple(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	await rendered()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.screen_ripple.clear()
	await rendered()
	var before: Image = root.get_texture().get_image()
	g.screen_ripple.trigger(g.ARENA.get_center())
	g.screen_ripple.age = 0.35; g.screen_ripple._update_surface()
	await rendered(); await rendered()
	var after: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(after.get_size())/g.fx.canvas_size
	var arena := Rect2(g.ARENA.position*scale,g.ARENA.size*scale)
	var leaked := 0; var inside := 0
	# The independent FPS label at the bottom is intentionally live.
	for y in range(0,after.get_height()-40,2):
		for x in range(0,after.get_width(),2):
			if before.get_pixel(x,y) == after.get_pixel(x,y): continue
			if arena.grow(1).has_point(Vector2(x,y)): inside += 1
			else: leaked += 1
	check(inside > 200,"Ultimate ripple still visibly distorts the battlefield")
	check(leaked == 0,"Ultimate ripple leaves every HUD pixel outside the battlefield unchanged")
	g.queue_free(); await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Combat FX bounds requires a rendering display"); quit(1); return
	await particles(); await damage_overlay(); await ripple(false); await ripple(true)
	print("Combat FX bounds: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
