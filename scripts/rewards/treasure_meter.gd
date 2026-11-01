extends RefCounted
## One compact bar shares its fill endpoint, receipt targets and chest hit area across layouts.
const Chests = preload("res://scripts/rewards/chest_rules.gd")
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const GOLD := Color("ffd773")

static func bar_rect(at: Vector2, scale_factor: float) -> Rect2:
	return Rect2(at+Vector2(-138,-6)*scale_factor,Vector2(246,12)*scale_factor)

static func icon_rect(at: Vector2, scale_factor: float) -> Rect2:
	return Rect2(at+Vector2(108,-18)*scale_factor,Vector2.ONE*36*scale_factor)

## Keep a finger-sized target even though the chest itself is a small icon.
static func claim_rect(at: Vector2, scale_factor: float) -> Rect2:
	return icon_rect(at,scale_factor).grow(10*scale_factor)

static func point(at: Vector2, scale_factor: float, index: int) -> Vector2:
	var rect := bar_rect(at,scale_factor)
	return Vector2(lerpf(rect.position.x,rect.end.x,clampf(float(index+1)/Chests.REROLL_COST,0,1)),rect.get_center().y)

## Full progress lights the chest; claim eligibility remains with the battle controller.
static func paint(battle, at: Vector2, scale_factor: float) -> void:
	var progress: int = battle.treasure_pickup.displayed_progress() if is_instance_valid(battle.treasure_pickup) else battle.model.reroll_progress
	progress = clampi(progress,0,Chests.REROLL_COST)
	var full: bool = progress == Chests.REROLL_COST
	var ratio: float = float(progress)/Chests.REROLL_COST
	var bar := bar_rect(at,scale_factor)
	var icon := icon_rect(at,scale_factor)
	var pulse: float = 0.8 if battle.reduced else 0.7+0.3*sin(battle.clock_time*4.5)
	battle.draw_rect(bar.grow(3*scale_factor),Color("171d1b"))
	battle.draw_rect(bar.grow(scale_factor),GOLD if full else Color("70694d"),false,scale_factor)
	battle.draw_rect(bar,Color("292d28"))
	if progress > 0:
		var filled := Rect2(bar.position,Vector2(bar.size.x*ratio,bar.size.y))
		battle.draw_rect(filled,GOLD if full else Color("c8a34f"))
		battle.draw_rect(Rect2(filled.position,Vector2(filled.size.x,3*scale_factor)),Color("fff0b4"))
	if full:
		for layer in range(5,0,-1): Pixel.disc(battle,icon.get_center(),(17+layer*4)*scale_factor,Color(GOLD,0.055+0.035*pulse),2)
		if not battle.reduced:
			for spark in range(4):
				var phase: float = battle.clock_time*0.65+spark*TAU/4
				var p: Vector2 = icon.get_center()+Vector2(cos(phase),sin(phase))*25*scale_factor
				Pixel.line(battle,p-Vector2(3,0)*scale_factor,p+Vector2(3,0)*scale_factor,Color("fff8da"),2)
				Pixel.line(battle,p-Vector2(0,3)*scale_factor,p+Vector2(0,3)*scale_factor,Color("fff8da"),2)
	battle.draw_texture_rect(battle.chest.art.chest_closed,icon,false,Color.WHITE if full else Color(0.42,0.42,0.42,0.8))
	battle._center(Vector2(bar.get_center().x,bar.end.y+19*scale_factor),"%d / %d" % [progress,Chests.REROLL_COST],roundi(14*scale_factor),Color("fff1bb") if full else battle.MUTED)
