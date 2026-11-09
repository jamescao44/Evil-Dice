extends RefCounted
## Golden guardian presentation follows the player's world position without touching combat RNG.
const ART = preload("res://assets/art/pets/golden_warrior.svg")
const Glow = preload("res://scripts/shared/item_glow.gd")
const DISPLAY_SCALE := 2.0
var opacity := 0.0
var pulse := 0.0
var clock := 0.0

func clear() -> void:
	opacity = 0
	pulse = 0
	clock = 0

## Activate on both spear throws and damage sharing, including relic copies.
func activate(id: String) -> void:
	if id == "golden_warrior": pulse = 1.0

## One visible warrior represents the owned fusion; downed guardians fade until recovery.
func advance(delta: float, model) -> void:
	clock += delta
	var ready: bool = model.relics.items.any(func(item): return item.id == "golden_warrior" and model.RelicProtection.guardian_active(item))
	opacity = move_toward(opacity,1.0 if ready else 0.0,delta*4)
	pulse = maxf(0,pulse-delta*2.5)

## Stand beside the entire relic orbit so the enlarged warrior never masks passing items.
func sprite_rect(battle) -> Rect2:
	var player: Rect2 = battle.evolution.visible_rect(battle._player_world_sprite_rect())
	var height: float = clampf(player.size.y*0.64,64,108)*DISPLAY_SCALE
	var size := Vector2(height*0.75,height)
	var feet := Vector2(battle.RelicOrbit.right_clearance(battle)+12+size.x*0.5,player.end.y+4)
	feet.x = minf(feet.x,battle.ARENA.end.x-size.x*0.5-8)
	var jump: float = 0 if battle.reduced else sin(pulse*PI)*7
	return Rect2(feet-Vector2(size.x*0.5,size.y+jump),size)

## Spears leave the hand rather than the floating core icon.
func hand(battle) -> Vector2:
	var rect := sprite_rect(battle)
	return rect.position+rect.size*Vector2(0.84,0.6)

## Small HP bar and recovery pips explain why the guardian has stopped attacking.
func paint(canvas: CanvasItem, battle) -> void:
	var owned: Array = battle.model.relics.items.filter(func(item): return item.id == "golden_warrior")
	if owned.is_empty(): return
	var item: Dictionary = owned[0]
	var rect := sprite_rect(battle)
	if opacity > 0:
		Glow.paint(canvas,rect.get_center(),rect.size.y*0.3,Color("ffc953"),Rect2(),opacity*(0.14+pulse*0.25))
		canvas.draw_texture_rect(ART,rect,false,Color(1,1,1,opacity))
		var bar := Rect2(Vector2(rect.get_center().x-20,rect.position.y-6),Vector2(40,4))
		canvas.draw_rect(bar,Color("332a27"))
		bar.size.x *= float(item.get("guardian_hp",0))/maxi(1,item.get("guardian_max_hp",1))
		canvas.draw_rect(bar,Color("ffdd83"))
	elif item.get("guardian_recovery",0) > 0:
		var at := Vector2(rect.get_center().x,rect.end.y-9)
		canvas.draw_circle(at,12,Color("4a3d2d"))
		for i in range(item.guardian_recovery): canvas.draw_circle(at+Vector2((i-(item.guardian_recovery-1)*0.5)*7,0),2,Color("e3bd68"))
