extends Node2D
## After-chest summary and optional paid tarot draw. Reward reels own upgrades.
const Chests = preload("res://scripts/rewards/chest_rules.gd")
const Cards = preload("res://scripts/tarot/tarot_paint.gd")
const Icons = preload("res://scripts/rewards/reward_icons.gd")
var battle
var phase: String = ""
var tier: int = 0
var clock: float = 0.0

func _ready() -> void:
	z_index = 80
	hide()

func cancel() -> void:
	phase = ""
	hide()

func after_chest(chest_tier: int = 0) -> void:
	tier = chest_tier
	phase = "after"
	clock = 0
	show()

func portrait() -> bool:
	return battle.fx.canvas_size.y > battle.fx.canvas_size.x

func action_rect() -> Rect2:
	return Rect2(142,1460,520,96) if portrait() else Rect2(480,692,320,64)

func tarot_rect() -> Rect2:
	return Rect2(190,930,424,480) if portrait() else Rect2(480,390,320,270)

func tarot_card_size() -> Vector2:
	return Vector2(180,278) if portrait() else Vector2(100,155)

func _draw_tarot_deck() -> void:
	var mid: float = battle.fx.canvas_size.x/2
	var enabled: bool = battle.model.can_buy_wave_tarot()
	var bought: bool = battle.model.wave_tarot_bought
	var at := Vector2(mid,1160 if portrait() else 516)
	var color := Color("eee0d6") if enabled else Color("85858b")
	_text(Vector2(mid,980 if portrait() else 414),"TAROT DRAW PURCHASED" if bought else "Draw Tarot",32 if portrait() else 22,color,tarot_rect().size.x)
	for i in range(3,-1,-1):
		Cards.card(self,"",at+Vector2(i*7,-i*5),tarot_card_size(),0,1,0.5 if enabled and i == 0 else 0,1.0 if enabled else 0.45)
	var price_at := Vector2(mid,1360 if portrait() else 630)
	var icon_side: float = 48 if portrait() else 30
	var point_size: int = 40 if portrait() else 27
	var label: String = str(Chests.TAROT_PRICE)
	var width: float = battle.description_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
	var left: float = mid-(width+12+icon_side)/2
	Icons.paint(self,battle.chest.art,"ruby",Rect2(Vector2(left,price_at.y-icon_side/2),Vector2.ONE*icon_side),Rect2(),Color.WHITE if enabled else Color(0.5,0.5,0.5))
	_text(Vector2(left+icon_side+12+width/2,price_at.y+point_size*0.35),label,point_size,color)

func click(at: Vector2) -> bool:
	if not visible: return false
	if phase == "after":
		if tarot_rect().has_point(at) and battle.model.can_buy_wave_tarot(): battle.tarot_ui.begin_reward("wave")
		elif action_rect().has_point(at): battle.model.finish_wave_reward()
	return true

func _process(delta: float) -> void:
	if not visible or battle._menus_open() or battle.tarot_ui.ceremony.active(): return
	clock += delta
	queue_redraw()

func _text(at: Vector2, label: String, point_size: int, color: Color, width: float = 720) -> void:
	var font: Font = battle.description_font
	label = GameText.text(label)
	while point_size > 14 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x > width: point_size -= 1
	var length: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x
	draw_string_outline(font,at-Vector2(length/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,3,Color("101418"))
	draw_string(font,at-Vector2(length/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,color)

func _button(rect: Rect2, label: String, enabled: bool = true) -> void:
	var color: Color = Chests.COLORS[tier] if enabled else Color("64646b")
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.8)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	draw_style_box(style,rect)
	_text(rect.get_center()+Vector2(0,10),label,30 if portrait() else 23,color,rect.size.x-32)

func _draw() -> void:
	if not visible: return
	var canvas: Vector2 = battle.fx.canvas_size
	var mid: float = canvas.x/2
	var color: Color = Chests.COLORS[tier]
	draw_rect(Rect2(Vector2.ZERO,canvas),Color("0c121b"))
	var center := Vector2(mid,700 if portrait() else 265)
	for i in range(18):
		var a: float = i*TAU/18+(0 if battle.reduced else clock*0.035)
		var reach: float = 550 if portrait() else 420
		draw_colored_polygon(PackedVector2Array([center,center+Vector2.from_angle(a)*reach,center+Vector2.from_angle(a+0.07)*reach]),Color(color,0.035))
	battle.chest.draw_currency(self)
	_text(Vector2(mid,280 if portrait() else 96),GameText.format("WAVE %d CLEARED",battle.model.stage+1),38 if portrait() else 30,Color("ffd773"))
	_text(Vector2(mid,360 if portrait() else 145),Chests.NAMES[tier],36 if portrait() else 28,color)
	var side: float = 240 if portrait() else 124
	for layer in range(8): draw_circle(center,side*(0.5+layer*0.09),Color(color,0.025))
	draw_texture_rect(battle.chest.art.chest_open,Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side),false,color)
	_text(center+Vector2(0,side*0.66),GameText.format("%d rewards + %d blood gems",[Chests.COUNTS[tier],Chests.CRYSTALS[tier]]),24 if portrait() else 18,color)
	_draw_tarot_deck()
	_button(action_rect(),"CONTINUE")
