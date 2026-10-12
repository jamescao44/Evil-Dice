extends Node2D
## Outcomes are locked by Run. Motion and particles use separate cosmetic RNG.
signal ticked
signal opened
signal landed(index: int)
signal completed
const Catalog = preload("res://scripts/reward_catalog.gd")
const Icons = preload("res://scripts/reward_icons.gd")
const Pixel = preload("res://scripts/pixel_paint.gd")
const Relics = preload("res://scripts/relic_catalog.gd")
var symbols: Array = Catalog.ITEMS.duplicate(true)
var scroll_symbols: Array = [Catalog.Category.RUBY,Catalog.Category.SHARD,Catalog.Category.TAROT]
var relic_symbols: Dictionary = {}
var relic_atlas: Texture2D
const OPEN_TIME := 0.65
const SPIN_TIME := 1.55
const REEL_STEPS := 64
var reel_steps: int = REEL_STEPS
var rewards: Array = []
var collected: Array = []
var art: Dictionary = {}
var font: Font
var size := Vector2(1280, 800)
var elapsed: float = 0
var active: bool = false
var paused: bool = false
var skip_requested: bool = false
var reduced: bool = false
var playback_speed: float = 1.0
var announced: int = 0
var last_tick: int = -1
var last_tick_time: float = 0
var did_open: bool = false
var focused: int = -1
var sequences: Array = []
var celebrations: Array = []
var cosmetic := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 80
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cosmetic.randomize()
	relic_atlas = load("res://assets/art/relic_atlas.png")
	for id in Relics.ITEMS:
		var item: Dictionary = Relics.ITEMS[id]
		symbols.append({"id":"curse" if item.rarity == Relics.Rarity.CURSED else "relic", "name":item.name,"text":item.text,"color":Relics.color(id),"relic_id":id})
		relic_symbols[id] = symbols.size()-1
		if not item.get("fusion",false): scroll_symbols.append(symbols.size()-1)
	for key in ["chest_closed", "chest_open", "ruby", "contract", "relic", "curse", "damage", "multiplier", "potion"]:
		art[key] = load("res://assets/art/rewards/" + key + ".png")
	hide()

func start(values: Array, canvas: Vector2, pixel_font: Font, reduce: bool = false, prizes: Array = []) -> void:
	rewards = values.duplicate()
	for i in range(mini(prizes.size(),rewards.size())):
		if prizes[i].has("relic_id"):
			rewards[i] = relic_symbols[prizes[i].relic_id]
	collected.clear()
	skip_requested = false
	size = canvas
	font = pixel_font
	reduced = reduce
	elapsed = 0
	announced = 0
	last_tick = -1
	last_tick_time = 0
	did_open = false
	focused = -1
	celebrations.clear()
	sequences.clear()
	reel_steps = maxi(REEL_STEPS,scroll_symbols.size())
	for outcome in rewards:
		var sequence: Array = _scroll_sequence()
		sequence[reel_steps] = outcome
		sequences.append(sequence)
	active = not rewards.is_empty()
	visible = active

func _scroll_sequence() -> Array:
	# Every obtainable reward gets screen time, independent of the locked winner
	# and its drop odds. Each cosmetic bag is exhausted before any item repeats.
	var sequence: Array = []
	while sequence.size() < reel_steps+4:
		var bag: Array = scroll_symbols.duplicate()
		while not bag.is_empty() and sequence.size() < reel_steps+4:
			var index: int = cosmetic.randi_range(0,bag.size()-1)
			if not sequence.is_empty() and bag.size() > 1 and bag[index] == sequence[-1]: index = (index+1)%bag.size()
			sequence.append(bag.pop_at(index))
	return sequence

func cancel() -> void:
	active = false
	paused = false
	skip_requested = false
	rewards.clear()
	collected.clear()
	celebrations.clear()
	focused = -1
	hide()

func stop_time(index: int) -> float:
	return 6.6 + index * 0.55

func travel(index: int) -> float:
	var t: float = clampf((elapsed-SPIN_TIME)/(stop_time(index)-SPIN_TIME), 0, 1)
	return reel_steps * (1.0-pow(1.0-t, 2.3))

func reel_rect(index: int) -> Rect2:
	var portrait: bool = size.y > size.x
	var extent := Vector2(202,234) if portrait else Vector2(188,206)
	var row: int = index / 3 if portrait and rewards.size() == 5 else 0
	var columns: int = (3 if row == 0 else 2) if portrait and rewards.size() == 5 else rewards.size()
	var column: int = index % 3 if portrait and rewards.size() == 5 else index
	var center := Vector2(size.x/2 + (column-(columns-1)/2.0)*(extent.x+22), (860+row*286 if rewards.size() == 5 else 1020) if portrait else 465)
	return Rect2(center-extent/2, extent)

func pickup_at(point: Vector2) -> int:
	if active or not visible: return -1
	for i in range(rewards.size()):
		if i not in collected and reel_rect(i).grow(7).has_point(point): return i
	return -1

func skip_rect() -> Rect2:
	return Rect2(152,130,500,88) if size.y > size.x else Rect2(944,64,304,56)

func can_skip() -> bool:
	return visible and not skip_requested and collected.size() < rewards.size()

func skip_remaining() -> void:
	active = false
	skip_requested = true

func draw_skip_button(canvas: CanvasItem) -> void:
	if not can_skip(): return
	var rect: Rect2 = skip_rect()
	canvas.draw_rect(rect,Color("20271f"))
	canvas.draw_rect(rect,Color("9c9b8c"),false,2)
	var text: String = GameText.text("SKIP REMAINING")
	var point_size: int = 28 if size.y > size.x else 20
	var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
	canvas.draw_string(font,rect.get_center()+Vector2(-width/2,point_size*0.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,Color("eee0b9"))

func chest_point() -> Vector2:
	return Vector2(size.x/2, (1440 if rewards.size() == 5 else 1350) if size.y > size.x else 680)

func emergence(index: int) -> float:
	return clampf((elapsed-OPEN_TIME-index*0.09)/0.85, 0, 1)

func prize_origin(index: int) -> Vector2:
	var t: float = emergence(index)
	var origin := chest_point()-Vector2(0, 45)
	return origin.lerp(reel_rect(index).get_center(), 1-pow(1-t,2)) - Vector2(0,sin(t*PI)*65)

func celebrate(index: int) -> void:
	if index < 0 or index >= rewards.size(): return
	focused = index
	var item: Dictionary = symbols[rewards[index]]
	var specks: Array = []
	for i in range(72): specks.append(Vector4(cosmetic.randf(),cosmetic.randf(),cosmetic.randf(),cosmetic.randf()))
	celebrations.append({"id":item.id,"at":reel_rect(index).get_center(),"color":item.color,"born":elapsed,"specks":specks})

func _process(delta: float) -> void:
	if paused or not visible or rewards.is_empty(): return
	elapsed += delta * playback_speed
	celebrations = celebrations.filter(func(event): return elapsed-event.born < 4.2)
	if active:
		if not did_open and elapsed >= OPEN_TIME:
			did_open = true
			opened.emit()
		var tick: int = floori(travel(0))
		if elapsed > SPIN_TIME and elapsed < stop_time(rewards.size()-1) and tick != last_tick and elapsed-last_tick_time >= 0.055:
			last_tick = tick
			last_tick_time = elapsed
			ticked.emit()
		while announced < rewards.size() and elapsed >= stop_time(announced):
			focused = announced
			landed.emit(announced)
			announced += 1
		if elapsed >= stop_time(rewards.size()-1)+0.65:
			active = false
			completed.emit()
	queue_redraw()

func _text(at: Vector2, text: String, point_size: int, color: Color) -> void:
	text = GameText.text(text)
	var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
	var p := (at-Vector2(width/2,0)).round()
	draw_string(font,p+Vector2(3,3),text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,Color("111716"))
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,color)

func _draw() -> void:
	if rewards.is_empty() or font == null: return
	var portrait: bool = size.y > size.x
	var gold := Color("dfb866")
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.07,0.06,0.95))
	_draw_celebrations(false)
	var center := Vector2(size.x/2,1040 if portrait else 490)
	for i in range(24):
		var a: float = i*TAU/24 + (0 if reduced else elapsed*0.05)
		Pixel.line(self,center+Vector2.from_angle(a)*65,center+Vector2.from_angle(a)*(360 if portrait else 265),Color(gold,0.08),4)
	_text(Vector2(center.x,540 if portrait else 195),("SUPER RARE" if rewards.size() == 5 else "RARE TREASURE" if rewards.size() == 3 else "TREASURE"),40 if portrait else 36,gold)
	if active or collected.is_empty():
		_text(Vector2(center.x,604 if portrait else 238),"TAP EACH GIFT TO COLLECT" if not active else "FIVE GIFTS" if rewards.size() == 5 else "THREE GIFTS" if rewards.size() == 3 else "A GIFT FROM THE ABYSS",24 if portrait else 20,Color("eee0b9"))
	var box_at := chest_point()
	var chest_side: float = 216 if portrait else 152
	var opened_for: float = elapsed-OPEN_TIME
	if opened_for > 0:
		for i in range(8):
			var spread: float = 110+i*14
			draw_colored_polygon(PackedVector2Array([box_at+Vector2(-32,-20),box_at+Vector2(32,-20),box_at+Vector2(spread,-300-i*12),box_at+Vector2(-spread,-300-i*12)]),Color(gold,0.025))
	var shake: float = 0 if reduced or elapsed > OPEN_TIME else sin(elapsed*70)*8
	var pop: float = 0 if reduced else maxf(0,1-absf(opened_for)*4)*16
	draw_texture_rect(art.chest_open if opened_for >= 0 else art.chest_closed,Rect2(box_at-Vector2.ONE*(chest_side+pop)/2+Vector2(shake,0),Vector2.ONE*(chest_side+pop)),false)
	if opened_for > 0 and opened_for < 0.65 and not reduced:
		Pixel.circle(self,box_at-Vector2(0,35),opened_for*450,Color(gold,(1-opened_for/0.65)*0.65),6)
	# Reels unfurl out of the open box, accompanied by a rising trail of loot.
	for reel in range(rewards.size()):
		if reel in collected:
			_text(reel_rect(reel).get_center()+Vector2(0,8), "CLAIMED", 24 if portrait else 20, gold.darkened(0.3))
			continue
		var t: float = emergence(reel)
		if t <= 0: continue
		var rect := reel_rect(reel)
		if t < 1:
			for j in range(5):
				var trail: float = clampf(t-j*0.08,0,1)
				var at := (box_at-Vector2(0,45)).lerp(rect.get_center(),1-pow(1-trail,2))-Vector2(0,sin(trail*PI)*65)
				_paint_symbol(sequences[reel][j],Rect2(at-Vector2.ONE*20,Vector2.ONE*40),Rect2(),Color(1,1,1,(1-j/6.0)*t))
			rect = Rect2(prize_origin(reel)-rect.size*(0.22+0.78*t)/2,rect.size*(0.22+0.78*t))
		_draw_reel(reel,rect,gold)
	_draw_celebrations(true)
	draw_skip_button(self)

func _draw_reel(reel: int, rect: Rect2, gold: Color) -> void:
	draw_rect(rect.grow(7),Color("6e5738"))
	draw_rect(rect.grow(3),Color("1b2420"))
	draw_rect(rect,Color("344032"))
	var scroll: float = travel(reel)
	var step: float = rect.size.y*0.72
	for row in range(floori(scroll)-1,floori(scroll)+3):
		var item_index: int = sequences[reel][clampi(row,0,reel_steps+3)]
		var side: float = rect.size.x*0.61
		var item_rect := Rect2(rect.get_center()-Vector2.ONE*side/2+Vector2(0,(row-scroll)*step),Vector2.ONE*side)
		var clipped := item_rect.intersection(rect.grow(-8))
		if not clipped.has_area(): continue
		_paint_symbol(item_index,item_rect,rect.grow(-8))
	for y in [rect.position.y,rect.end.y-16]: draw_rect(Rect2(rect.position.x,y,rect.size.x,16),Color(0.04,0.08,0.06,0.8))
	draw_rect(rect,gold if reel == focused or active else gold.darkened(0.5),false,4 if reel == focused else 2)
	var blink: float = clampf(1-(elapsed-stop_time(reel))*4,0,1) if elapsed >= stop_time(reel) else 0
	if not reduced and blink > 0: draw_rect(rect.grow(2),Color(1,1,0.8,blink*0.35))
	for direction in [-1,1]:
		var at := Vector2(rect.get_center().x+direction*(rect.size.x/2+9),rect.get_center().y)
		draw_colored_polygon(PackedVector2Array([at+Vector2(direction*9,-10),at+Vector2(-direction*5,0),at+Vector2(direction*9,10)]),gold)

func _paint_symbol(index: int, rect: Rect2, clip: Rect2 = Rect2(), tint: Color = Color.WHITE) -> void:
	var item: Dictionary = symbols[index]
	if not item.has("relic_id"):
		Icons.paint(self,art,item.icon,rect,clip,tint)
		return
	var position: int = Relics.ITEMS.keys().find(item.relic_id)
	var source := Rect2(position*64,0,64,64)
	var visible_rect: Rect2 = rect.intersection(clip) if clip.has_area() else rect
	if not visible_rect.has_area(): return
	var uv := Rect2(source.position+(visible_rect.position-rect.position)/rect.size*source.size,visible_rect.size/rect.size*source.size)
	draw_texture_rect_region(relic_atlas,visible_rect,uv,tint)

func _draw_celebrations(foreground: bool) -> void:
	for event in celebrations:
		var age: float = elapsed-event.born
		var fade: float = minf(age*5,1)*clampf((4.2-age)/1.4,0,1)
		var color: Color = event.color
		if reduced:
			if not foreground: Pixel.circle(self,event.at,136,Color(color,fade*0.35),5)
			continue
		if event.id == "ruby" and foreground:
			for seed in event.specks:
				var t: float = age-seed.y*1.5
				if t < 0: continue
				var at := Vector2(seed.x*size.x,-50+t*(size.y*0.65+seed.z*220))
				var side: float = 24+seed.w*20
				var width: float = maxf(5,absf(cos(t*7+seed.z*TAU))*side)
				Icons.paint(self,art,"ruby",Rect2(at-Vector2(width,side)/2,Vector2(width,side)),Rect2(),Color(1,1,1,fade))
		elif event.id in ["damage","multiplier"] and not foreground:
			for layer in range(12):
				var alpha: float = fade*(1-layer/12.0)*0.12
				draw_rect(Rect2(layer*6,0,7,size.y),Color(color,alpha))
				draw_rect(Rect2(size.x-layer*6-7,0,7,size.y),Color(color,alpha))
		elif event.id in ["damage","multiplier"] and foreground:
			for i in range(event.specks.size()):
				var seed: Vector4 = event.specks[i]
				var t: float = fposmod(age*0.55+seed.y,1)
				var at := Vector2(14+sin(t*PI)*(35+seed.z*60),fposmod(seed.x*size.y-age*(70+seed.z*110),size.y))
				if i%2: at.x = size.x-at.x
				Pixel.line(self,at+Vector2(0,25),at,Color(color,fade*(1-t)*0.35),4)
				draw_rect(Rect2(at.round(),Vector2.ONE*(4+floorf(seed.w*3)*2)),Color(color.lightened(t),fade*(1-t)))
				if i%6 == 0:
					Pixel.line(self,at-Vector2(9,0),at+Vector2(9,0),Color(color.lightened(0.5),fade*(1-t)),2)
					Pixel.line(self,at-Vector2(0,9),at+Vector2(0,9),Color(color.lightened(0.5),fade*(1-t)),2)
		elif event.id == "curse" and not foreground:
			var pulse: float = 0.65+sin(age*3)*0.15
			for layer in range(24):
				var inset: float = layer*5
				draw_rect(Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2),Color(Color("973d83"),fade*pulse*(1-layer/24.0)*0.42),false,6)
			for edge in [Vector2(0,size.y*0.3),Vector2(size.x,size.y*0.72)]:
				for halo in range(8): Pixel.disc(self,edge,75+halo*14+sin(age*2)*12,Color(Color("8d356f"),fade*(8-halo)*0.004),6)
			for i in range(6): Pixel.circle(self,event.at,90+i*17+sin(age*2+i)*10,Color(Color("bd668b"),fade*0.07),10)
		elif event.id == "relic" and not foreground:
			for i in range(16):
				var a: float = i*TAU/16+age*0.12
				var radius: float = (280 if size.x > size.y else 390)*minf(1,age*4)
				var tip: Vector2 = event.at+Vector2.from_angle(a)*radius
				draw_colored_polygon(PackedVector2Array([event.at,tip+Vector2.from_angle(a+PI/2)*10,tip-Vector2.from_angle(a+PI/2)*10]),Color(Color("ffedb1"),fade*(0.3 if i%2 else 0.55)))
		elif foreground and event.id in ["relic","curse","potion","shard"]:
			for i in range(24):
				var seed: Vector4 = event.specks[i]
				var direction := Vector2.from_angle(seed.x*TAU)
				var at: Vector2 = event.at+direction*(70+age*(35+seed.y*55))
				var radius: float = 3+seed.z*4
				Pixel.line(self,at-Vector2(radius,0),at+Vector2(radius,0),Color(color,fade),2)
				Pixel.line(self,at-Vector2(0,radius),at+Vector2(0,radius),Color(color,fade),2)
