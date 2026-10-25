extends SceneTree
const Effects = preload("res://scripts/effects/effects.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Cover logarithmic sizing, per-target modifiers, overkill, instant kills and level caps.
func _initialize() -> void:
	for stage in [0,10,20]:
		var reference: int = [20,100,300][stage/10]
		check(Effects.damage_scale(reference,stage) == 1.0,"Level reference starts at regular size")
		check(is_equal_approx(Effects.damage_scale(reference*10,stage),1.25),"Tenfold damage grows effects only 25 percent")
		check(Effects.damage_scale(1000000000,stage) == 1.4,"Impact size has a hard ceiling")
		check(Effects.damage_font_size(1000000000,stage) == 38,"Damage numbers have an independent readable ceiling")
	check(Effects.damage_scale(1000,20) < Effects.damage_scale(1000,0),"The next level normalizes the same absolute damage")
	var fx = Effects.new()
	root.add_child(fx)
	fx.set_process(false)
	fx.world_transform = Transform2D(0,Vector2(40,20)).scaled(Vector2.ONE*1.2)
	var targets := [Vector2(400,200),Vector2(600,200)]
	fx.flame_cast(3,Vector2(120,300),targets,0.78,[20,200])
	check(is_equal_approx(fx.spell.scales[0],1.0) and is_equal_approx(fx.spell.scales[1],1.25),"Area targets have separate scales instead of sharing the largest hit")
	var projected: Dictionary = fx.projected_spell(fx.spell)
	for i in range(targets.size()): check(projected.targets[i].is_equal_approx(targets[i]),"Size scaling does not shift targets")
	check(projected.from.is_equal_approx(Vector2(120,300)),"Size scaling does not shift the origin")
	fx.slash(Vector2.ZERO,false,200)
	check(is_equal_approx(fx.slashes[-1].scale,1.25) and fx.particles.size() == 10,"Impact grows while particle count stays bounded")
	check(fx.particles.all(func(p): return p.size >= 3.75 and p.size <= 8.75),"Impact sparks grow with damage")
	var model = Run.new(98)
	model.enemies = [model.make_enemy(3),model.make_enemy(2)]
	model.enemies[0].hp = 1
	var skill = model.Patterns.classify([1,2,3,4,5])
	model.pending = skill; model.phase = "player"
	model.apply_enemy_status(1,model.Status.BURNING,2)
	var hits: Array = model.preview(skill,0)
	check(hits[0].damage == 7 and hits[1].damage == 7,"Sizing receives post-Burning, post-taunt target damage before HP clamping")
	fx.flame_cast(3,Vector2.ZERO,targets,0.78,hits.map(func(hit): return hit.damage))
	check(is_equal_approx(fx.spell.scales[0],Effects.damage_scale(7)),"One-HP enemy still gets the full overkill effect size")
	fx.flame_cast(4,Vector2.ZERO,targets,1.1,[0,0])
	check(fx.spell.scales == [1.0,1.0],"Brimstone keeps its dedicated tier effect instead of scaling by remaining HP")
	var souls = Run.new(99)
	var stages: Array = []
	souls.character_leveled.connect(func(level): stages.append(level))
	souls.gain_souls(180)
	check(stages == [2,3,4,5,6] and souls.character_level == 6 and souls.souls == 30,"Large grants preserve every level and surplus XP")
	check(souls.max_hp == 161 and is_equal_approx(souls.character_damage_factor(),1.61051),"Five levels compound 1.1x upgrades")
	check(not souls.level_up() and souls.level_cost() == 60,"The next level waits for its sixty XP threshold")
	check(is_equal_approx((Battle.AUTO_ATTACK_TRAVEL*0.55+Battle.AUTO_ATTACK_RECOVERY)/(0.30*0.55+0.09),1.2078431373),"Automatic cadence is roughly 20 percent slower again")
	fx.queue_free()
	print("Attack scale and levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
