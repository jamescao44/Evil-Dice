extends RefCounted
## Cosmetic rarity presentation shared by shop offers and revealed chest prizes.
## Cached seals and a small fixed set of motes keep the effect independent of particle counts.
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Glow = preload("res://scripts/shared/item_glow.gd")
const ORBIT = preload("res://assets/art/fx/relic_rarity/orbit.svg")
const SIGIL = preload("res://assets/art/fx/relic_rarity/sigil.svg")
const SUN = preload("res://assets/art/fx/relic_rarity/sunburst.svg")
const CURSE = preload("res://assets/art/fx/relic_rarity/curse.svg")
const MOTES := [2,3,4,6,5]
const BOB := [0.025,0.045,0.06,0.055,0.035]

## Preserve artwork identity; time, emphasis and landing age never touch gameplay state.
static func paint(canvas: CanvasItem, id: String, at: Vector2, radius: float, time: float, reduced: bool = false, emphasis: float = 0.0, landing_age: float = -1.0, item: Dictionary = {}) -> void:
	var rarity: int = Catalog.ITEMS[id].rarity
	var color: Color = Catalog.rarity_color(id)
	var seed: float = float(posmod(id.hash(),997))/997.0*TAU
	var t: float = 0.0 if reduced else time
	var phase: float = t*1.8+seed
	var arrival: float = 0.0 if reduced or landing_age < 0 else sin(clampf(landing_age/0.7,0,1)*PI)*exp(-landing_age*2.2)
	var r: float = radius*(1.0+emphasis*0.055+arrival*[0.12,0.18,0.24,0.3,0.2][rarity])
	var center: Vector2 = at+Vector2(0,0 if reduced else sin(phase)*radius*BOB[rarity])
	if rarity == Catalog.Rarity.CURSED: center.x += sin(maxf(0,landing_age)*42)*arrival*r*0.08
	var pulse: float = 0.85+0.15*sin(phase*0.7)
	_aura(canvas,center,r,rarity,color,t,seed+arrival*[0.0,0.15,0.65,0.25,-0.6][rarity],pulse,emphasis)
	_motes(canvas,center,r,rarity,color,t,seed,false,reduced)
	if arrival > 0:
		var ring: float = r*(0.95+clampf(landing_age/0.7,0,1)*0.7)
		canvas.draw_arc(center,ring,0,TAU,48,Color(color,arrival*1.3),maxf(1.5,r*0.045),true)
		Glow.paint(canvas,center,r*0.9,color,Rect2(),arrival*0.65)
	var tilt: float = 0 if reduced else sin(phase*0.65)*[0.0,0.025,0.045,0.02,0.025][rarity]
	canvas.draw_set_transform(center,tilt)
	Paint.paint(canvas,id,Vector2.ZERO,r,false,item)
	canvas.draw_set_transform(Vector2.ZERO)
	_motes(canvas,center,r,rarity,color,t,seed,true,reduced)

## Distinct silhouettes identify rarity even before the colored text is read.
static func _aura(canvas: CanvasItem, at: Vector2, r: float, rarity: int, color: Color, t: float, seed: float, pulse: float, emphasis: float) -> void:
	Glow.paint(canvas,at,r*(0.76 if rarity == 0 else 0.96),color,Rect2(),(0.48 if rarity == 0 else 0.72)*pulse+emphasis*0.15)
	match rarity:
		Catalog.Rarity.COMMON:
			canvas.draw_arc(at+Vector2(0,r*0.8),r*0.65,0.15,PI-0.15,20,Color(color,0.24),1.5,true)
		Catalog.Rarity.RARE:
			_seal(canvas,ORBIT,at,r*1.52,t*0.4+seed,Vector2(1,0.62),Color(color,0.7))
		Catalog.Rarity.EPIC:
			_seal(canvas,SIGIL,at,r*1.48,-t*0.23+seed,Vector2.ONE,Color(color,0.66))
			_seal(canvas,ORBIT,at,r*1.18,t*0.38,Vector2.ONE,Color(color.lightened(0.35),0.34))
		Catalog.Rarity.LEGENDARY:
			_seal(canvas,SUN,at,r*1.5,t*0.16+seed,Vector2.ONE,Color("ffefb8",pulse))
			_seal(canvas,ORBIT,at,r*1.28,-t*0.18,Vector2.ONE,Color("fff1ba",0.65))
			for i in range(3):
				var crown := at+Vector2((i-1)*0.42,-1.16-0.14*(1-absi(i-1)))*r
				_diamond(canvas,crown,r*0.07,Color("fff2c2",0.8))
		Catalog.Rarity.CURSED:
			canvas.draw_circle(at,r*1.05,Color("160b22",0.65))
			_seal(canvas,CURSE,at,r*1.48,-t*0.28+seed,Vector2.ONE,Color("ff5367",0.68+0.15*sin(t*2.1)))
			_seal(canvas,ORBIT,at,r*1.22,t*0.3,Vector2.ONE,Color("b855df",0.36))
			Glow.paint(canvas,at+Vector2(0,r*0.25),r*0.6,Color("ff354f"),Rect2(),0.38*pulse)

## Rotate cached textures, resetting the canvas transform before other UI is drawn.
static func _seal(canvas: CanvasItem, texture: Texture2D, at: Vector2, r: float, angle: float, squash: Vector2, color: Color) -> void:
	canvas.draw_set_transform(at,angle,squash)
	canvas.draw_texture_rect(texture,Rect2(-Vector2.ONE*r,Vector2.ONE*r*2),false,color)
	canvas.draw_set_transform(Vector2.ZERO)

## Fixed deterministic accents orbit, rise or glint without emitters or gameplay RNG.
static func _motes(canvas: CanvasItem, at: Vector2, r: float, rarity: int, color: Color, t: float, seed: float, front: bool, reduced: bool) -> void:
	var count: int = mini(2,MOTES[rarity]) if reduced else MOTES[rarity]
	for i in range(count):
		var phase: float = seed+i*TAU/count
		var cycle: float = fposmod(t*(0.33 if rarity == 4 else 0.24)+i/float(count)+seed/TAU,1.0)
		var point: Vector2
		var strength: float = 0.8 if reduced else sin(cycle*PI)
		if rarity == Catalog.Rarity.CURSED:
			point = Vector2(sin(phase)*r*(0.8+0.15*sin(cycle*TAU)),r*(0.85-cycle*2.2))
		elif rarity == Catalog.Rarity.EPIC:
			point = Vector2(cos(phase)*r*1.12,r*(0.75-cycle*2.0))
		else:
			var angle: float = phase+t*(0.65 if rarity == 1 else 0.24)
			point = Vector2(cos(angle),sin(angle)*(0.62 if rarity == 1 else 0.9))*r*(1.23 if rarity > 0 else 0.98)
		if (point.y >= 0) != front: continue
		var location: Vector2 = at+point
		var half: float = r*(0.055 if rarity < 2 else 0.075)*strength
		if half < 0.4: continue
		var tint: Color = Color("ff5b6c") if rarity == 4 else color.lightened(0.5)
		if rarity == Catalog.Rarity.RARE:
			Glow.paint(canvas,location,half*2.1,color,Rect2(),strength*0.7)
			canvas.draw_circle(location,half,Color.WHITE)
		elif rarity == Catalog.Rarity.CURSED:
			canvas.draw_colored_polygon(PackedVector2Array([location+Vector2(-half,half),location+Vector2(half,0),location+Vector2(half*0.4,-half*3)]),Color(tint,strength))
		else:
			_diamond(canvas,location,half*1.7,Color(tint,strength))
			if rarity == Catalog.Rarity.LEGENDARY:
				canvas.draw_line(location-Vector2(half*2.4,0),location+Vector2(half*2.4,0),Color("fffbe3",strength),1.2,true)

static func _diamond(canvas: CanvasItem, at: Vector2, half: float, color: Color) -> void:
	if half < 0.4: return
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-half),at+Vector2(half*0.45,0),at+Vector2(0,half),at-Vector2(half*0.45,0)]),color)
