extends Node2D
## Outcomes are locked by Run. Motion and particles use separate cosmetic RNG.
signal opened
signal landed(index: int)
signal completed
signal upgraded(tier: int)
signal revealed(tier: int)
const Chests = preload("res://scripts/rewards/chest_rules.gd")
const ChestAudio = preload("res://scripts/audio/chest_audio.gd")
const RewardBurst = preload("res://scripts/rewards/reward_burst.gd")
var audio: Node
var battle
var tier: int = 0
var upgrade_mode: bool = false
var upgrade_misses: Array = [0,0,0]
var final_tier: int = 0
var roll_phase: String = ""
var roll_scroll: float = 0.0
var settle_from: float = 0.0
var settle_started: float = 0.0
var upgrade_age: float = 10.0
var layout_from_count: int = 1
const UPGRADE_BEAT := 0.65
const BEAT := 60.0/160.0
const ULTRA_BUILDUP := 8*BEAT
const AUTO_STOP := 2.55
const REEL_SPEED := 20.0
var reveal_age: float = -1.0
var audio_clock_enabled: bool = true # Tests can advance the visual timeline manually.
const Catalog = preload("res://scripts/rewards/reward_catalog.gd")
const Icons = preload("res://scripts/rewards/reward_icons.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Glow = preload("res://scripts/shared/item_glow.gd")
var symbols: Array = Catalog.ITEMS.duplicate(true)
var scroll_symbols: Array = [Catalog.Category.SHARD,Catalog.Category.TAROT]
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
var idle_age: float = 0
var active: bool = false
var paused: bool = false
var skip_requested: bool = false
var reduced: bool = false
var playback_speed: float = 1.0
var announced: int = 0
var did_open: bool = false
var rolling_started: bool = false
var focused: int = -1
var sequences: Array = []
var celebrations: Array = []
var landing_bursts: Array = []
var cosmetic := RandomNumberGenerator.new()

## Load reward artwork and build the cosmetic symbol pool without rolling outcomes.
func _ready() -> void:
	z_index = 80
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cosmetic.randomize()
	relic_atlas = load("res://assets/art/relic_atlas.png")
	audio = ChestAudio.new()
	add_child(audio)
	for id in Relics.ITEMS:
		var item: Dictionary = Relics.ITEMS[id]
		symbols.append({"id":"curse" if item.rarity == Relics.Rarity.CURSED else "relic", "name":item.name,"text":item.text,"color":Relics.rarity_color(id),"relic_id":id})
		relic_symbols[id] = symbols.size()-1
		if id not in Relics.DISABLED and not item.get("fusion",false): scroll_symbols.append(symbols.size()-1)
	for key in ["chest_closed", "chest_open", "ruby", "contract", "relic", "curse", "damage", "multiplier", "potion"]:
		art[key] = load("res://assets/art/rewards/" + key + ".png")
	hide()

## Present locked prizes in a closed chest and reset all reel and audio state.
func start(values: Array, canvas: Vector2, pixel_font: Font, reduce: bool = false, prizes: Array = [], chest_tier: int = -1, wave_roll: bool = false, pity_misses: Array = [0,0,0]) -> void:
	tier = clampi(chest_tier,0,3) if chest_tier >= 0 else 3 if values.size() == 5 else 2 if values.size() == 3 else 0
	upgrade_mode = wave_roll
	upgrade_misses = pity_misses.duplicate()
	final_tier = tier
	if upgrade_mode: tier = 0
	roll_phase = "closed"
	roll_scroll = 0
	settle_from = 0
	settle_started = 0
	reveal_age = -1
	upgrade_age = 10
	layout_from_count = Chests.COUNTS[tier]
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
	idle_age = 0
	announced = 0
	did_open = false
	rolling_started = false
	focused = -1
	celebrations.clear()
	landing_bursts.clear()
	sequences.clear()
	reel_steps = maxi(REEL_STEPS,scroll_symbols.size())
	for outcome in rewards:
		var sequence: Array = _scroll_sequence()
		sequences.append(sequence)
	active = not rewards.is_empty()
	visible = active
	audio.stop()
	audio.reveal_count = 0
	_sync_audio()

func closed_rect() -> Rect2:
	var portrait: bool = size.y > size.x
	var side: float = 320 if portrait else 240
	return Rect2(Vector2(size.x/2,850 if portrait else 430)-Vector2.ONE*side/2,Vector2.ONE*side)

func click(point: Vector2) -> void:
	if roll_phase == "closed":
		if closed_rect().grow(18).has_point(point): open_chest()
	else: request_stop()

## Open the clicked chest and start its reveal timeline.
func open_chest() -> bool:
	if not active or paused or roll_phase != "closed": return false
	roll_phase = "spinning"
	elapsed = 0
	if tier == 3: _begin_settle(0)
	_sync_audio()
	queue_redraw()
	return true

func _start_rolling_audio() -> void:
	# The reels are hidden during the opening; sound begins with their first motion.
	if rolling_started or elapsed < OPEN_TIME: return
	rolling_started = true
	audio.start_rolling(tier)
	_sync_audio()

## Build cosmetic reels from every obtainable item independently of prize odds.
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
	if is_instance_valid(audio): audio.stop()
	active = false
	upgrade_mode = false
	roll_phase = ""
	paused = false
	skip_requested = false
	rewards.clear()
	collected.clear()
	celebrations.clear()
	landing_bursts.clear()
	focused = -1
	hide()

func stop_time(index: int) -> float:
	if roll_phase == "closed": return INF
	if roll_phase in ["spinning","upgrading"] and upgrade_mode: return INF
	var start_time: float = settle_started if roll_phase in ["settling","complete"] else AUTO_STOP
	return start_time+stop_duration()+reel_delay(index)

func stop_duration() -> float:
	return ChestAudio.ULTRA_NOTES[0] if tier == 3 else 4*BEAT if tier == 2 else 3*BEAT

func reel_delay(index: int) -> float:
	var order: int = stop_order().find(index)
	return ChestAudio.ULTRA_NOTES[order]-ChestAudio.ULTRA_NOTES[0] if tier == 3 else order*BEAT/3

func stop_order() -> Array:
	return [3,1,0,2,4] if rewards.size() == 5 else [1,0,2] if rewards.size() == 3 else [0]

func stopping_progress() -> float:
	return clampf((elapsed-settle_started)/stop_duration(),0,1) if roll_phase == "settling" else 0.0

func travel(index: int) -> float:
	if roll_phase == "closed": return 0
	if roll_phase in ["spinning","upgrading"]: return roll_scroll
	if elapsed >= stop_time(index): return reel_steps
	# Ultra stays on its musical cues; other chests ease past the prize and settle.
	if tier == 3: return fposmod(settle_from+maxf(0,elapsed-settle_started)*REEL_SPEED,reel_steps)
	var t: float = clampf((elapsed-settle_started)/(stop_time(index)-settle_started),0,1)
	if reduced: return lerpf(settle_from,reel_steps,1-pow(1-t,2))
	if t < 0.78: return lerpf(settle_from,reel_steps+0.24,1-pow(1-t/0.78,2))
	var bounce: float = (t-0.78)/0.22
	return reel_steps+0.24*cos(bounce*PI*1.5)*pow(1-bounce,2)

func visible_reel_count() -> int:
	return Chests.COUNTS[tier] if upgrade_mode else rewards.size()

func _layout_rect(index: int, count: int) -> Rect2:
	var portrait: bool = size.y > size.x
	count = maxi(1,count)
	var gap: float = 14 if portrait else 22
	var width: float = minf(202 if portrait else 188,(size.x-64-gap*(count-1))/count)
	var extent := Vector2(width,420 if portrait else 300)
	var offset: int = [0,-1,1,-2,2][index]
	var center := Vector2(size.x/2+offset*(width+gap),890 if portrait else 430)
	return Rect2(center-extent/2,extent)

func reel_rect(index: int) -> Rect2:
	var rect: Rect2 = _layout_rect(index,visible_reel_count())
	if upgrade_mode and upgrade_age < UPGRADE_BEAT:
		var previous: Rect2 = _layout_rect(index,layout_from_count) if index < layout_from_count else rect
		if index >= layout_from_count:
			previous.position.x = -rect.size.x if rect.get_center().x < size.x/2 else size.x
		var t: float = 1.0 if reduced else smoothstep(0,UPGRADE_BEAT,upgrade_age)
		return Rect2(previous.position.lerp(rect.position,t),previous.size.lerp(rect.size,t))
	return rect

func _symbol_at(reel: int, row: int) -> int:
	if roll_phase in ["spinning","upgrading"]:
		return sequences[reel][posmod(row,reel_steps)]
	return sequences[reel][clampi(row,0,reel_steps+3)]

## Reveal an upgrade or begin stopping on the already committed prizes.
func request_stop() -> void:
	if not active or paused or roll_phase == "closed": return
	# One tap reveals one upgrade. Extra taps during its impact cannot skip tiers.
	if roll_phase == "upgrading": return
	if roll_phase == "settling":
		if tier != 3: _finish_reels()
		return
	elapsed = maxf(elapsed,SPIN_TIME)
	_start_rolling_audio()
	if not did_open:
		did_open = true
		opened.emit()
	if upgrade_mode and tier < final_tier:
		layout_from_count = visible_reel_count()
		tier += 1
		audio.set_roll_tier(tier)
		upgrade_age = 0
		roll_phase = "upgrading"
		upgraded.emit(tier)
		if tier == 3: _begin_settle(elapsed)
	else:
		_begin_settle(elapsed)
	queue_redraw()

## Start the tier-specific slowdown or Ultra musical landing sequence.
func _begin_settle(at: float) -> void:
	# Rebase the continuous cosmetic strip, then attach the committed winners.
	# This remains bounded even if the player leaves the reels spinning.
	settle_from = fposmod(roll_scroll,reel_steps)
	# Quadratic braking starts near the existing reel speed, then springs back.
	var end: int = reel_steps if tier == 3 else ceili(settle_from+stop_duration()*REEL_SPEED*0.78/2-0.24)
	for reel in range(rewards.size()):
		var sequence: Array = []
		for row in range(end+4): sequence.append(_symbol_at(reel,row))
		sequence[end] = rewards[reel]
		sequences[reel] = sequence
	reel_steps = end
	settle_started = at
	roll_phase = "settling"
	if tier == 3: audio.begin_ultra(maxf(0,elapsed-at))
	_sync_audio()

## Emit each prize landing once when its scheduled stop is reached.
func _land_reels() -> void:
	var order: Array = stop_order()
	while announced < rewards.size() and elapsed >= stop_time(order[announced]):
		var index: int = order[announced]
		focused = index
		landing_bursts.append(RewardBurst.create(reel_rect(index).get_center(),reward_color(rewards[index]),stop_time(index),cosmetic,reward_burst_scale(rewards[index])*(1.35 if size.y > size.x else 1.0)))
		if announced == 0 and tier < 3: audio.reveal(tier)
		landed.emit(index)
		announced += 1
	if announced == rewards.size() and reveal_age < 0:
		reveal_age = 0
		if tier == 3: audio.reveal(tier)
		revealed.emit(tier)

## Complete the chest reveal after all visible prize reels land.
func _finish_reels() -> void:
	elapsed = stop_time(rewards.size()-1)
	_land_reels()
	active = false
	roll_phase = "complete"
	completed.emit()
	queue_redraw()

## Find an uncollected stopped prize beneath the pointer.
func pickup_at(point: Vector2) -> int:
	if active or not visible: return -1
	for i in range(rewards.size()):
		if i not in collected and reel_rect(i).grow(7).has_point(point): return i
	return -1

func skip_rect() -> Rect2:
	return Rect2(152,130,500,88) if size.y > size.x else Rect2(944,64,304,56)

## Check whether the player may leave the remaining chest rewards.
func can_skip() -> bool:
	return visible and not active and not skip_requested and collected.size() < rewards.size()

func skip_animation() -> void:
	# All input paths honor the Ultra notes and the brief non-Ultra stop delay.
	request_stop()

## Mark the unclaimed rewards to skip so the battle flow can close the chest.
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
	var destination := Vector2(size.x/2,1440 if size.y > size.x else 680)
	return closed_rect().get_center().lerp(destination,smoothstep(0,OPEN_TIME,elapsed))

func emergence(index: int) -> float:
	return 1.0 if roll_phase != "closed" and elapsed >= OPEN_TIME else 0.0

func prize_origin(index: int) -> Vector2:
	return reel_rect(index).get_center()

func celebrate(index: int) -> void:
	if index < 0 or index >= rewards.size(): return
	focused = index
	var item: Dictionary = symbols[rewards[index]]
	var specks: Array = []
	for i in range(72): specks.append(Vector4(cosmetic.randf(),cosmetic.randf(),cosmetic.randf(),cosmetic.randf()))
	celebrations.append({"id":item.id,"at":reel_rect(index).get_center(),"color":item.color,"born":elapsed,"specks":specks})

## Advance chest reels, upgrades and reveal particles without changing outcomes.
func _process(delta: float) -> void:
	_sync_audio()
	if paused or not visible or rewards.is_empty(): return
	if roll_phase == "closed":
		idle_age += delta
		queue_redraw()
		return
	var previous_elapsed: float = elapsed
	if audio_clock_enabled and tier == 3 and roll_phase == "settling" and audio.ultra_started and audio.payout.playing and not audio.clock_failed and is_equal_approx(playback_speed,1) and DisplayServer.get_name() != "headless":
		elapsed = maxf(elapsed,settle_started+audio.ultra_position(delta))
	else:
		elapsed += delta * playback_speed
	upgrade_age += delta * playback_speed
	if reveal_age >= 0: reveal_age += maxf(0,elapsed-previous_elapsed)
	if roll_phase in ["spinning","upgrading","settling"]: _start_rolling_audio()
	if roll_phase in ["spinning","upgrading"]:
		roll_scroll += delta*playback_speed*REEL_SPEED
	if roll_phase == "upgrading" and upgrade_age >= UPGRADE_BEAT: roll_phase = "spinning"
	if not upgrade_mode and roll_phase == "spinning" and elapsed >= AUTO_STOP: _begin_settle(AUTO_STOP)
	celebrations = celebrations.filter(func(event): return elapsed-event.born < 4.2)
	landing_bursts = landing_bursts.filter(func(event): return elapsed-event.born < RewardBurst.DURATION)
	if active:
		if not did_open and elapsed >= OPEN_TIME:
			did_open = true
			opened.emit()
		_land_reels()
		if elapsed >= stop_time(rewards.size()-1)+(0.8 if tier == 3 else 0.3):
			active = false
			roll_phase = "complete"
			completed.emit()
	queue_redraw()

## Pause pre-reveal audio with the chest while allowing payouts during tarot draws.
func _sync_audio() -> void:
	if not is_instance_valid(audio): return
	var muted: bool = not is_instance_valid(battle) or battle.muted
	# Tarot selection holds the revealed chest's visuals, not its payout music.
	audio.sync(muted,paused and reveal_age < 0)


func draw_currency(canvas: CanvasItem) -> void:
	if not is_instance_valid(battle): return
	var point: Vector2 = battle._currency_point()
	var side: float = 32 if battle.fx.canvas_size.y > battle.fx.canvas_size.x else 23
	Icons.paint(canvas,art,"ruby",Rect2(point-Vector2.ONE*side/2,Vector2.ONE*side))
	var pending: int = battle.crystal_pickup.pending_total
	canvas.draw_string(battle.description_font,point+Vector2(side*0.75,8),str(maxi(0,battle.model.rubies-pending)),HORIZONTAL_ALIGNMENT_LEFT,-1,26 if side > 25 else 20,Color("ffd0de"))

func _text(at: Vector2, text: String, point_size: int, color: Color) -> void:
	text = GameText.text(text)
	var width: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
	var p := (at-Vector2(width/2,0)).round()
	draw_string(font,p+Vector2(3,3),text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,Color("111716"))
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,color)

func upgrade_hint() -> String:
	if tier >= 3: return ""
	return GameText.text("25% CHANCE TO UPGRADE")

## Paint the current chest, horizontal reels and claim controls.
func _draw() -> void:
	if rewards.is_empty() or font == null: return
	var portrait: bool = size.y > size.x
	var gold: Color = Chests.COLORS[tier]
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.07,0.06,0.95))
	draw_currency(self)
	if roll_phase == "closed":
		_draw_closed(gold,portrait)
		return
	_draw_celebrations(false)
	var center := Vector2(size.x/2,1040 if portrait else 490)
	for i in range(24):
		var a: float = i*TAU/24 + (0 if reduced else elapsed*0.05)
		Pixel.line(self,center+Vector2.from_angle(a)*65,center+Vector2.from_angle(a)*(360 if portrait else 265),Color(gold,0.08),4)
	_text(Vector2(center.x,450 if portrait else 88),Chests.NAMES[tier],42 if portrait else 32,gold)
	var hint: String = "TAP EACH GIFT TO COLLECT" if not active else "UPGRADED!" if roll_phase == "upgrading" else "ULTRA REVEAL" if roll_phase == "settling" and tier == 3 else "TAP TO SKIP" if roll_phase == "settling" else "TAP ANYWHERE TO STOP"
	_text(Vector2(center.x,516 if portrait else 138),hint,24 if portrait else 20,Color("eee0b9"))
	if upgrade_mode and active and tier < 3 and roll_phase in ["spinning","upgrading"]:
		_text(Vector2(center.x,572 if portrait else 185),upgrade_hint(),22 if portrait else 18,gold)
	if focused >= 0 and not active and focused not in collected:
		var item: Dictionary = symbols[rewards[focused]]
		var info_y: float = 1175 if portrait else 205
		var title_size: int = 28 if portrait else 22
		_text(Vector2(center.x,info_y),item.name,title_size,item.color)
		var lines := GameText.lines(item.text,font,24 if portrait else 17,size.x-100)
		for line in range(mini(3 if portrait else 1,lines.size())):
			_text(Vector2(center.x,info_y+(36 if portrait else 30)+line*(30 if portrait else 22)),lines[line],24 if portrait else 17,Color("eee0b9"))
	var box_at := chest_point()
	var chest_side: float = lerpf(closed_rect().size.x,260 if portrait else 154,smoothstep(0,OPEN_TIME,elapsed))
	var opened_for: float = elapsed-OPEN_TIME
	if opened_for > 0:
		for i in range(8):
			var spread: float = 110+i*14
			draw_colored_polygon(PackedVector2Array([box_at+Vector2(-32,-20),box_at+Vector2(32,-20),box_at+Vector2(spread,-300-i*12),box_at+Vector2(-spread,-300-i*12)]),Color(gold,0.025))
	var shake: float = 0 if reduced or elapsed > OPEN_TIME else sin(elapsed*70)*8
	var pop: float = 0 if reduced else sin(clampf(opened_for/0.55,0,1)*PI)*chest_side*0.3
	if tier == 3 and reveal_age >= 0 and reveal_age < 0.6 and not reduced: pop += sin(reveal_age/0.6*PI)*chest_side*0.28
	draw_texture_rect(art.chest_open if opened_for >= 0 else art.chest_closed,Rect2(box_at-Vector2.ONE*(chest_side+pop)/2+Vector2(shake,0),Vector2.ONE*(chest_side+pop)),false)
	if opened_for > 0 and opened_for < 0.65 and not reduced:
		Pixel.circle(self,box_at-Vector2(0,35),opened_for*450,Color(gold,(1-opened_for/0.65)*0.65),6)
	_text(box_at+Vector2(0,chest_side*0.62),GameText.format("+%d soul crystals",battle.model.chest_crystals if is_instance_valid(battle) and battle.model.chest_crystals > 0 else Chests.CRYSTALS[tier]),26 if portrait else 19,Color("ffadc4"))
	if opened_for > 0 and opened_for < 0.7 and not reduced:
		var burst: float = opened_for/0.7
		for i in range(48):
			var direction := Vector2.from_angle(i*TAU/48)
			var at: Vector2 = box_at+direction*(45+burst*(240 if portrait else 170))
			Pixel.line(self,at,at+direction*28*(1-burst),Color(gold,1-burst),4)
	if upgrade_mode and upgrade_age < UPGRADE_BEAT:
		var pulse: float = 1-upgrade_age/UPGRADE_BEAT
		if not reduced:
			Pixel.circle(self,box_at-Vector2(0,35),(1-pulse)*450,Color(gold,pulse*0.8),8)
			for i in range(24):
				var direction := Vector2.from_angle(i*TAU/24)
				var at: Vector2 = box_at+direction*(80+(1-pulse)*220)
				Pixel.line(self,at,at+direction*32*pulse,Color(gold,pulse),4)
		draw_rect(Rect2(Vector2.ZERO,size),Color(gold,pulse*(0.035 if reduced else 0.13)))
	_draw_ultra_impact(box_at,gold)
	# Reels appear at full size; additional reels slide in horizontally.
	for reel in range(visible_reel_count()):
		if reel in collected:
			_text(reel_rect(reel).get_center()+Vector2(0,8), "CLAIMED", 18 if portrait and rewards.size() == 5 else 22 if portrait else 18, gold.darkened(0.3))
			continue
		var t: float = emergence(reel)
		if t <= 0: continue
		var rect := reel_rect(reel)
		_draw_reel(reel,rect,gold)
	for burst in landing_bursts: RewardBurst.paint(self,burst,elapsed,reduced)
	_draw_celebrations(true)
	draw_skip_button(self)

func _draw_closed(color: Color, portrait: bool) -> void:
	var rect: Rect2 = closed_rect()
	var pulse: float = 0.8 if reduced else 0.8+sin(idle_age*3)*0.2
	for ring in range(8,0,-1): draw_circle(rect.get_center(),rect.size.x*(0.46+ring*0.045),Color(color,0.018*pulse))
	draw_texture_rect(art.chest_closed,rect,false)
	_text(Vector2(size.x/2,450 if portrait else 88),Chests.NAMES[tier],42 if portrait else 32,color)
	_text(Vector2(size.x/2,516 if portrait else 138),"TAP THE CHEST TO OPEN",26 if portrait else 22,Color("eee0b9"))
	if upgrade_mode: _text(rect.get_center()+Vector2(0,rect.size.y*0.75),upgrade_hint(),24 if portrait else 18,color)

## Draw neighboring symbols around the square prize-selection indicator.
func _draw_reel(reel: int, rect: Rect2, gold: Color) -> void:
	var scroll: float = travel(reel)
	# Follow the visible reel symbol, never the hidden locked prize during a spin.
	var shown: Dictionary = symbols[_symbol_at(reel,roundi(scroll))]
	var color: Color = reward_color(_symbol_at(reel,roundi(scroll)))
	var revealed: bool = elapsed >= stop_time(reel)
	draw_rect(rect.grow(3),Color("1b2420"))
	draw_rect(rect,Color("20271f"))
	var band: Rect2 = selection_rect(reel)
	draw_rect(band,Color(color,0.16 if revealed else 0.08))
	var step: float = band.size.y+8
	for row in range(floori(scroll)-1,floori(scroll)+3):
		var item_index: int = _symbol_at(reel,row)
		var side: float = rect.size.x*0.61
		var item_rect := Rect2(rect.get_center()-Vector2.ONE*side/2+Vector2(0,(row-scroll)*step),Vector2.ONE*side)
		var clipped := item_rect.intersection(rect.grow(-8))
		if not clipped.has_area(): continue
		var distance: float = absf(row-scroll)
		_paint_symbol(item_index,item_rect,rect.grow(-8),Color(1,1,1,lerpf(1,0.35,clampf(distance,0,1))))
	draw_rect(band,Color(color,0.95),false,3)
	for y in [rect.position.y,rect.end.y-16]: draw_rect(Rect2(rect.position.x,y,rect.size.x,16),Color(0.04,0.08,0.06,0.8))
	draw_rect(rect,Color("626b69"),false,2)
	if revealed and shown.has("relic_id"):
		var label: String = Relics.RARITY_NAMES[Relics.ITEMS[shown.relic_id].rarity]
		_text(Vector2(rect.get_center().x,rect.end.y-18),label,18 if size.y > size.x else 16,Color("d4d8d3"))
	var blink: float = clampf(1-(elapsed-stop_time(reel))*4,0,1) if elapsed >= stop_time(reel) else 0
	if not reduced and blink > 0: draw_rect(band,Color(color,blink*0.35))
	for direction in [-1,1]:
		var at := Vector2(rect.get_center().x+direction*(rect.size.x/2+9),rect.get_center().y)
		draw_colored_polygon(PackedVector2Array([at+Vector2(direction*9,-10),at+Vector2(-direction*5,0),at+Vector2(direction*9,10)]),Color("9ba4a0"))

func selection_rect(reel: int) -> Rect2:
	var rect: Rect2 = reel_rect(reel)
	var side: float = rect.size.x-16
	return Rect2(rect.get_center()-Vector2.ONE*side/2,Vector2.ONE*side)

func reward_color(symbol: int) -> Color:
	var item: Dictionary = symbols[symbol]
	return Relics.rarity_color(item.relic_id) if item.has("relic_id") else item.color

func reward_burst_scale(symbol: int) -> float:
	var item: Dictionary = symbols[symbol]
	if item.has("relic_id"):
		return [0.45,0.65,0.85,1.0,1.0][Relics.ITEMS[item.relic_id].rarity]
	# Tarot draws and summon shards have no rarity; use a modest celebration.
	return 0.65

func _draw_ultra_impact(origin: Vector2, gold: Color) -> void:
	if tier != 3 or roll_phase != "settling" and reveal_age < 0: return
	if reveal_age < 0:
		var progress: float = stopping_progress()
		var beat: float = fposmod(elapsed-settle_started,BEAT)/BEAT
		for i in range(8):
			var at: Vector2 = origin+Vector2.from_angle(-PI/2+i*TAU/8)*120
			draw_circle(at,5 if reduced else 5+(1-beat)*3,Color(gold,0.9 if progress*8 >= i else 0.15))
		if not reduced:
			Pixel.circle(self,origin,340-progress*220,Color(gold,progress*0.35),3)
			for i in range(12):
				var angle: float = i*TAU/12+progress*0.8
				var at: Vector2 = origin+Vector2.from_angle(angle)*(320-progress*190)
				Pixel.line(self,at,at+Vector2.from_angle(angle)*24,Color(gold,progress*0.65),3)
	elif reveal_age < 1.2:
		var fade: float = 1-reveal_age/1.2
		if not reduced:
			for i in range(3):
				var age: float = maxf(0,reveal_age-i*0.1)
				Pixel.circle(self,origin,60+age*950,Color(gold,fade*(0.7-i*0.15)),8-i*2)
			if reveal_age < 0.24: draw_rect(Rect2(Vector2.ZERO,size),Color(1,0.95,0.73,(1-reveal_age/0.24)*0.24))

func _paint_symbol(index: int, rect: Rect2, clip: Rect2 = Rect2(), tint: Color = Color.WHITE) -> void:
	var item: Dictionary = symbols[index]
	if not item.has("relic_id"):
		Icons.paint(self,art,item.icon,rect,clip,tint)
		return
	Glow.paint(self,rect.get_center(),rect.size.x*0.49,Relics.rarity_color(item.relic_id),clip,tint.a)
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
