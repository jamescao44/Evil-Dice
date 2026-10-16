extends SceneTree
## Compare local drawing/layout CPU costs; these numbers are not phone frame rates.
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
class Landscape extends "res://scripts/combat/battle.gd":
	var draw_usec: int = 0
	var draw_count: int = 0
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec()-start
		draw_count += 1
class Portrait extends "res://scripts/combat/battle_portrait.gd":
	var draw_usec: int = 0
	var draw_count: int = 0
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec()-start
		draw_count += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	GameText.set_language("zh_CN",false)
	var font := GameText.description_font()
	var text := "Tap twice to throw. Drag skills to the field, or tap targeted skills to choose a foe. SAVE banks a bonus cast."
	GameText.lines(text,font,26,718) # Warm glyphs before measuring repeated layout.
	var start := Time.get_ticks_usec()
	for i in range(5000): GameText.lines(text,font,26,718)
	print("Repeated description layout (5000): %.2f ms" % ((Time.get_ticks_usec()-start)/1000.0))
	start = Time.get_ticks_usec()
	for i in range(5000):
		GameText.clear_line_cache()
		GameText.lines(text,font,26,718)
	print("Uncached description layout (5000): %.2f ms" % ((Time.get_ticks_usec()-start)/1000.0))
	for portrait in [false,true]:
		var game = Portrait.new() if portrait else Landscape.new()
		game.muted = true
		game.reduced = true
		root.add_child(game)
		game._restart(19)
		for i in range(100): game.model.tarots.add(Tarot.ITEMS.keys()[i%22])
		start = Time.get_ticks_usec()
		for i in range(1000): game.tarot_ui.carousel_order()
		print("%s carousel sorting (100 cards, 1000): %.2f ms" % ["Portrait" if portrait else "Landscape",(Time.get_ticks_usec()-start)/1000.0])
		for i in range(10): await process_frame
		game.draw_usec = 0
		game.draw_count = 0
		for i in range(120): await process_frame
		print("%s wave 19 draw: %.3f ms, %d frames" % ["Portrait" if portrait else "Landscape",game.draw_usec/1000.0/maxi(1,game.draw_count),game.draw_count])
		if "--capture" in OS.get_cmdline_user_args():
			game.clock_time = 0
			game.set_process(false)
			game.queue_redraw()
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png("res://test-output/benchmark-%s.png" % ("portrait" if portrait else "landscape"))
		game.queue_free()
		await process_frame
	quit()
