extends Node2D
## Shared non-interactive announcement: slide in, hold one second, sweep out.
const ENTER := 0.20
const HOLD := 1.0
const EXIT := 0.22
var battle
var age: float = -1
var message: String = "BONUS TURN"

func _ready() -> void:
	z_index = 120

func play(text: String = "BONUS TURN") -> void:
	message = text
	age = 0
	queue_redraw()

func clear() -> void:
	age = -1
	queue_redraw()

## Use real time, independent of combat speed, without changing any input state.
func _process(delta: float) -> void:
	visible = not battle._menus_open() and battle.view_phase not in ["over","reward","transition"]
	if age < 0 or not visible: return
	age += delta
	if age >= ENTER+HOLD+EXIT: age = -1
	queue_redraw()

func _draw() -> void:
	if age < 0: return
	var screen: Vector2 = battle.fx.canvas_size
	var label: String = GameText.text(message)
	var size: int = 96 if screen.y > screen.x else 84
	var width: float = battle.description_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	if width > screen.x*0.82:
		size = floori(size*screen.x*0.82/width)
		width = battle.description_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var travel: float = (screen.x+width)*0.55
	var x: float = -travel*pow(1-clampf(age/ENTER,0,1),3)
	if age > ENTER+HOLD: x = travel*pow((age-ENTER-HOLD)/EXIT,2)
	var settle: float = clampf((age-ENTER)/0.22,0,1)
	var scale_up: float = 1.0 if battle.reduced or age < ENTER else 1+sin(settle*PI)*0.06
	draw_set_transform(screen*0.5+Vector2(x,0),0,Vector2.ONE*scale_up)
	var gold: Color = Color("ffe5a0")
	var half: float = width/2+24
	# Fine rules and short speed streaks keep the large lettering crisp.
	for y in [-size*0.58,size*0.58]:
		draw_line(Vector2(-half,y),Vector2(half,y),Color(gold,0.55),2)
	if not battle.reduced:
		var speed_alpha: float = 1-clampf((age-ENTER)/0.16,0,1) if age < ENTER+HOLD else 0.7
		for i in range(3):
			draw_line(Vector2(-half-25-i*16,(i-1)*16),Vector2(-half-90-i*24,(i-1)*16),Color(gold,speed_alpha*0.4),2)
	var baseline := Vector2(-width/2,size*0.34)
	draw_string_outline(battle.description_font,baseline+Vector2(0,4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,10,Color("171b1a"))
	draw_string_outline(battle.description_font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color("8a6336"))
	draw_string(battle.description_font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,gold)
