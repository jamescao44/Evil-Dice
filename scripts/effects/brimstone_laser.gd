extends RefCounted
## Early Brimstone uses narrow per-hit columns with no authored cap or broad aura.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const FADE_DURATION := 0.10
const TOP_PADDING := 96.0
const WIDTH_RATIO := 0.70
const TICK_INTERVAL := 0.20

## Follow each target's projected sprite width, including bosses and camera zoom.
static func width(spell: Dictionary, index: int) -> float:
	var widths: Array = spell.get("target_widths",[])
	return float(widths[index] if index < widths.size() else 128.0)*WIDTH_RATIO

## Each actual damage pulse flashes once, then vanishes before the next pulse.
static func intensity(state: Dictionary) -> float:
	if state.phase == "build": return 0.0
	return clampf((state.pulse-0.28)/0.72,0,1)

## Extend beyond the clip's upper edge so neither camera motion nor enemy height exposes a cap.
static func top(anchor: Vector2, battlefield_top: float) -> Vector2:
	return Vector2(anchor.x,minf(battlefield_top,anchor.y)-TOP_PADDING)

## Keep only a crisp gold edge, white core and a small impact spark at each enemy's feet.
static func paint(canvas: CanvasItem, spell: Dictionary, reduced: bool) -> void:
	var state: Dictionary = spell.brimstone
	var anchors: Array = spell.get("brimstone_anchors",[])
	var strength: float = intensity(state)
	for index in range(anchors.size()):
		var anchor: Vector2 = anchors[index]
		var beam_width: float = width(spell,index)
		if state.phase == "build":
			var ready: float = smoothstep(0,state.build_duration,state.age)
			canvas.draw_line(anchor-Vector2(beam_width*0.5,0),anchor+Vector2(beam_width*0.5,0),Color("ffb547",ready*0.6),2)
			continue
		if strength <= 0: continue
		var start: Vector2 = top(anchor,spell.brimstone_top)
		var thickness: float = beam_width*sqrt(strength)
		if not reduced: canvas.draw_line(start,anchor,Color("ff8b32",strength*0.15),thickness+6)
		canvas.draw_line(start,anchor,Color("ffbd54",strength*0.85),maxf(2,thickness))
		canvas.draw_line(start,anchor,Color("fff7d6",strength),maxf(1,thickness*0.38))
		Pixel.disc(canvas,anchor,beam_width*(0.3+strength*0.2),Color("ffe19d",strength*0.65),2,0.28)
		if not reduced:
			var spread: float = beam_width*(0.75-strength*0.2)
			for side in [-1,1]:
				canvas.draw_line(anchor+Vector2(side*spread*0.5,-3),anchor+Vector2(side*spread,-spread*0.8),Color("ffc864",strength*0.7),2)
