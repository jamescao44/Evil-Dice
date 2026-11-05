extends RefCounted
## Short automatic-match spectacles share combat timing without becoming manual skills.
const Pixel = preload("res://scripts/shared/pixel_paint.gd")
const Flame = preload("res://scripts/effects/flame_spell.gd")
const Embers = preload("res://scripts/effects/flame_particles.gd")
const Particles = preload("res://scripts/effects/baked_particles.gd")
const IMPACT := 0.55
const DURATIONS := {3:0.74,4:0.88}

## Pulse the matched dice once, then resolve one concentrated or squad-wide impact.
static func play(battle, group: Dictionary, token: int) -> bool:
	var skill: MultiHitSkill = group.skill
	var target: int = battle.model.roll_attack_target()
	if target < 0: return false
	for index in group.indices:
		battle.dice[index].auto_attack_active = true
		battle.dice[index].pulse_auto_attack()
	if not await battle._wait(0.16,token): return false
	var hits: Array = battle.model.preview(skill,target)
	var destinations: Array = hits.map(func(hit): return battle._enemy_impact_point(hit.target))
	var feet: Array = hits.map(func(hit): return battle._enemy_feet(hit.target))
	var seconds: float = DURATIONS[skill.dice.size()]
	battle.damage_feedback.show_attack(skill)
	battle.player_animation.begin("fireball" if skill.dice.size() == 3 else "storm")
	if not await battle._wait_player_launch(token): return false
	var buildup: float = battle.player_animation.impact_delay()
	if buildup <= 0: buildup = seconds*IMPACT/battle._roll_speed()
	seconds = buildup/IMPACT
	battle.combat_motion.attack(-1)
	var style: Dictionary = battle.fx.AttackStyle.for_form(battle.player_animation.form)
	battle.fx.match_cast(skill.dice.size(),battle._player_cast_point(),destinations,feet,seconds,hits.map(func(hit): return hit.damage),battle.player_animation.form)
	battle.player_animation.launch()
	battle._sound("player/slash",0.95 if skill.dice.size() == 3 else 0.8,-19)
	if not await battle._wait(buildup,token,false,1.0): return false
	battle.player_animation.damage()
	for hit in hits:
		var at: Vector2 = battle._enemy_impact_point(hit.target)
		var amount: int = 10 if battle.reduced else (54 if skill.dice.size() == 3 else 80)
		battle.fx.attack_burst(at,Color("ffb544"),hit.damage,maxi(2,roundi(amount*style.particles)),135,style.size)
		battle.fx.ring(at,Color("ffd180"),(60 if skill.dice.size() == 3 else 90)*style.size,battle.ARENA)
	battle._show_events(battle.model.resolve_roll_attack_step())
	battle._sound("player/crash",1.1 if skill.dice.size() == 3 else 0.85,-19)
	battle.shake = 0 if battle.reduced else (2.5 if skill.dice.size() == 3 else 3.5)*battle.ATTACK_SHAKE_SCALE*style.shake
	for index in group.indices: battle.dice[index].auto_attack_active = false
	var completed: bool = await battle._wait(seconds*(1.0-IMPACT),token,false,1.0)
	battle.player_animation.finish()
	return completed and await battle._wait_player_recovery(token)

## Render inside the normal battlefield clip, leaving UI and damage numbers unobscured.
static func paint(canvas: CanvasItem, spell: Dictionary, reduced: bool) -> void:
	var t: float = clampf(1.0-spell.life/spell.duration,0,1)
	var tint := Color("ff9e40")
	var progress: float = clampf(t/IMPACT,0,1)
	var fade: float = 1.0-smoothstep(IMPACT,1.0,t)
	var size: float = spell.style.size
	var density: float = spell.style.particles
	if spell.match_count == 3:
		var target: Vector2 = spell.targets[0]
		var scale: float = clampf(spell.scales[0],1.0,1.6)*size
		var head: Vector2 = spell.from.lerp(target,progress)-Vector2(0,sin(progress*PI)*65)
		if t < IMPACT:
			for tail in range(6 if not reduced else 2,0,-1):
				var phase: float = maxf(0,progress-tail*0.035)
				var point: Vector2 = spell.from.lerp(target,phase)-Vector2(0,sin(phase*PI)*65)
				Pixel.disc(canvas,point,24*scale*(1-tail*0.10),Color(tint,0.6-tail*0.06),4)
			Flame.ember(canvas,head,25*scale,tint,t)
			Embers.trail(canvas,spell.from,target,progress,t,65,38*scale,maxi(4,roundi((12 if reduced else 80)*density)),tint)
		else:
			var blast: float = (t-IMPACT)/(1-IMPACT)
			for petal in range(7):
				var direction := Vector2.from_angle(petal*TAU/7)
				Flame.ember(canvas,target+direction*blast*60*scale,(1-blast)*22*scale,tint,t,fade)
			Pixel.circle(canvas,target,(18+70*blast)*scale,Color("ffdd86",fade),5)
			Particles.burst(canvas,"match_burst",target,blast,scale,reduced)
		return
	# A molten seam lights beneath the squad before all pillars burst together.
	var points: Array = spell.get("feet",spell.targets).duplicate()
	points.sort_custom(func(a,b): return a.x < b.x)
	for i in range(1,points.size()):
		for layer in range(3,0,-1):
			Pixel.line(canvas,points[i-1]+Vector2(0,5),points[i]+Vector2(0,5),Color(tint,fade*(0.12 if layer > 1 else 0.8)*progress*spell.style.glow),layer*6*size)
	for i in range(points.size()):
		canvas.draw_set_transform(points[i],0,Vector2.ONE*size)
		var at := Vector2.ZERO
		var lift: float = sin(clampf((t-0.30)/0.70,0,1)*PI)
		var height: float = 135*lift
		Pixel.circle(canvas,at,22+18*progress,Color("ffbc59",fade*0.7),4)
		for column in range(-2,3):
			var tip: Vector2 = at+Vector2(column*12,-height*(1-absf(column)*0.14))
			Pixel.line(canvas,at+Vector2(column*12,0),tip,Color(tint,fade*0.18),28)
			Pixel.line(canvas,at+Vector2(column*12,0),tip,Color("ffb347",fade*0.85),12)
			Pixel.line(canvas,at+Vector2(column*12,0),tip,Color("fff0af",fade),4)
		Particles.paint(canvas,"light_fountain" if reduced or density < 1 else "fountain",t*2+i*0.07,at,Vector2.ONE,Color(1,1,1,fade*progress*sqrt(density)))
		canvas.draw_set_transform(Vector2.ZERO)
