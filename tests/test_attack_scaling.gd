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
	for damage in [0,1,5,10,100,1000]:
		var expected: float = 1 if damage <= 10 else 2 if damage == 100 else 3
		check(is_equal_approx(Effects.damage_scale(damage),expected),"Attack scale uses the number's log10 ratio")
		check(Effects.damage_font_size(damage) == roundi(24*expected),"Number size uses the identical scale")
	var fx = Effects.new()
	root.add_child(fx)
	fx.set_process(false)
	fx.world_transform = Transform2D(0,Vector2(40,20)).scaled(Vector2.ONE*1.2)
	var targets := [Vector2(400,200),Vector2(600,200)]
	fx.flame_cast(3,Vector2(120,300),targets,0.78,[10,1000])
	check(is_equal_approx(fx.spell.scales[0],1.0) and is_equal_approx(fx.spell.scales[1],3.0),"Area targets have separate scales instead of sharing the largest hit")
	var projected: Dictionary = fx.projected_spell(fx.spell)
	for i in range(targets.size()): check(projected.targets[i].is_equal_approx(targets[i]),"Size scaling does not shift targets")
	check(projected.from.is_equal_approx(Vector2(120,300)),"Size scaling does not shift the origin")
	fx.slash(Vector2.ZERO,false,100)
	check(is_equal_approx(fx.slashes[-1].scale,2.0) and fx.particles.size() == 10,"Impact grows while particle count stays bounded")
	check(fx.particles.all(func(p): return p.size >= 6 and p.size <= 14),"Impact sparks grow with damage")
	var model = Run.new(98)
	model.enemies = [model.make_enemy(3),model.make_enemy(2)]
	model.enemies[0].hp = 1
	var skill = model.Patterns.classify([1,2,3,4,5])
	model.pending = skill; model.phase = "player"
	model.apply_enemy_status(1,model.Status.BURNING,2)
	var hits: Array = model.preview(skill,0)
	check(hits[0].damage == 32 and hits[1].damage == 32,"Sizing receives post-Burning, post-taunt target damage before HP clamping")
	fx.flame_cast(3,Vector2.ZERO,targets,0.78,hits.map(func(hit): return hit.damage))
	check(is_equal_approx(fx.spell.scales[0],Effects.damage_scale(32)),"One-HP enemy still gets the full overkill effect size")
	fx.flame_cast(4,Vector2.ZERO,targets,1.1,[0,0])
	check(fx.spell.scales == [1.0,1.0],"Brimstone keeps its dedicated tier effect instead of scaling by remaining HP")
	var souls = Run.new(99)
	var stages: Array = []
	souls.character_leveled.connect(func(level): stages.append(level))
	souls.gain_souls(180)
	check(stages == [2,3] and souls.character_level == 3 and souls.souls == 100,"A large grant queues exactly two evolutions and retains spare souls")
	check(souls.max_hp == 225 and is_equal_approx(souls.character_damage_factor(),2.25),"Level three compounds two 1.5x upgrades")
	check(not souls.level_up() and souls.level_cost() == 0,"No fourth level is purchasable")
	check(souls.MAX_CHARACTER_LEVEL == souls.LEVEL_COSTS.size()+1,"Threshold count matches the cap")
	check(is_equal_approx((Battle.AUTO_ATTACK_TRAVEL*0.55+Battle.AUTO_ATTACK_RECOVERY)/(0.30*0.55+0.09),1.2078431373),"Automatic cadence is roughly 20 percent slower again")
	fx.queue_free()
	print("Attack scale and levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
