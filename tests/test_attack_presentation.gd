extends SceneTree
## Check form-specific spectacle without changing skill damage or authored actor cues.
const Effects = preload("res://scripts/effects/effects.gd")
const Actor = preload("res://scripts/player/player_animation.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Body motion settles cleanly without altering actor cues or the ring's resting bounds.
func firing_motion() -> void:
	for form in range(3):
		for clip in ["fireball","ultimate"]:
			var actor = Actor.new(); actor.set_form(form)
			var rest: Rect2 = Actor.Sprite.grounded_rect(Rect2(80,80,240,240),form)
			actor.begin(clip); actor.advance(1.2)
			check(actor.firing_rect(rest) == rest,"Preparation does not start release squash early")
			actor.launch(); actor.advance(0.1)
			var squashed: Rect2 = actor.firing_rect(rest)
			check(squashed.size.x > rest.size.x and squashed.size.y < rest.size.y,"Firing visibly widens and compresses the body")
			check(is_equal_approx(squashed.get_center().x,rest.get_center().x),"Release bounce never drifts sideways")
			var feet_y: float = Actor.Sprite.rest_bounds(form).end.y
			check(squashed.position.y+squashed.size.y*feet_y < rest.position.y+rest.size.y*feet_y,"Squash also lifts the visible feet slightly")
			check(actor.firing_rect(rest,true) == rest,"Reduced effects leave the body undistorted")
			actor.advance(0.2)
			check(actor.firing_rect(rest).size.y > rest.size.y,"Body rebounds before settling")
			actor.advance(0.2)
			check(actor.firing_rect(rest) == rest,"Release returns exactly to its resting geometry")
			if clip == "ultimate":
				var frame: int = actor.frame_number()
				actor.damage(); actor.advance(0.1)
				check(actor.firing_rect(rest) != rest,"Sustained attacks pulse again when their damage starts")
				check(actor.frame_number() == frame+1,"Firing motion preserves the authored frame cadence")
			actor.play_emote()
			check(actor.firing_rect(rest) == rest,"Tapped emotes override firing distortion")
			actor.reset()
			check(actor.firing_rect(rest) == rest,"Restart removes residual firing motion")

func _initialize() -> void:
	firing_motion()
	var fx = Effects.new()
	var actor = Actor.new()
	var previous_size := 0.0
	var previous_bob := 0.0
	var targets := [Vector2(300,200),Vector2(550,250)]
	var feet := [Vector2(300,280),Vector2(550,330)]
	for form in range(3):
		actor.reset(); actor.set_form(form)
		check(actor.projectile_bob(240) == 0,"Idle leaves the character at rest")
		actor.begin("fireball"); actor.advance(0.325)
		var bob: float = absf(actor.projectile_bob(240))
		check(bob > previous_bob if form < 2 else bob == 0,"Early casts bob gently with more lift in form two")
		previous_bob = bob
		check(actor.projectile_bob(240,true) == 0,"Reduced effects suppress casting lift")
		actor.play_emote(); check(actor.projectile_bob(240) == 0,"Emotes override casting lift")
		actor.reset(); actor.begin("fireball"); actor.advance(1)
		check(actor.projectile_bob(240) == 0,"Casting lift settles fully")
		fx.flame_cast(1,Vector2(100,250),targets,0.5,[100,100],feet,[],form)
		check(fx.spell.scales[0] > previous_size,"Same damage produces progressively larger effects across forms")
		previous_size = fx.spell.scales[0]
		for tier in [3,4]:
			var ticks: int = 5 if tier == 3 else 10
			fx.flame_cast(tier,Vector2(100,250),targets,1,[100,100],feet,[],form,ticks,[100.0,200.0])
			var state: Dictionary = fx.flame_state()
			check(state.loop_frames == [1,2,4][form]*(6 if tier == 3 else 8),"Form-specific loops traverse complete authored cycles")
			check(fx.flame_tick_time(1,ticks) >= 0.1-0.00001,"Reduced repetition preserves readable damage spacing")
			check(is_equal_approx(fx.flame_tick_time(ticks-1,ticks),state.loop_duration),"Last tick coincides with the end of the loop")
			fx.spell.hold_damage = true
			fx.begin_flame_damage(); fx._process(0.1)
			if tier == 4 and form < 2:
				check(is_equal_approx(fx.flame_tick_time(1,ticks),0.2),"Early Brimstone now spaces damage pulses 200ms apart")
				check(state.emitters.is_empty(),"Early Brimstone has no broad particle fountain")
				check(Effects.Brimstone.Laser.intensity(state) == 0,"Quick laser disappears between damage pulses")
				fx.pulse_flame_damage()
				check(Effects.Brimstone.Laser.intensity(state) == 1,"Each damage pulse re-flashes the laser")
			else: check(state.emitters.all(func(e): return not e.packets.is_empty()),"Storm and final Brimstone retain their particle emitters")
			if tier == 4:
				fx.world_transform = Transform2D(0,Vector2(20,30)).scaled(Vector2.ONE*1.1)
				var projected: Dictionary = fx.projected_spell(fx.spell)
				if form < 2:
					check(projected.brimstone_anchors.size() == targets.size(),"Early Brimstone creates one beam per enemy")
					for i in range(2): check(is_equal_approx(Effects.Brimstone.Laser.width(projected,i),[100.0,200.0][i]*1.1*0.7),"Beam follows 70 percent of each enemy width through camera zoom")
					for i in range(targets.size()): check(projected.brimstone_anchors[i].is_equal_approx(fx.world_transform*fx.spell.world_feet[i]+Vector2(0,8)),"Individual beams stay grounded through camera movement")
					for anchor in projected.brimstone_anchors: check(Effects.Brimstone.Laser.top(anchor,projected.brimstone_top).y < fx.battlefield_rect.position.y,"Laser extends beyond the battlefield top without a visible cap")
				else: check(not projected.has("brimstone_anchors"),"Final Brimstone retains one formation-wide beam")
			fx.world_transform = Transform2D.IDENTITY
			fx.finish_flame_damage(); fx._process(0.11 if tier == 4 and form < 2 else 2)
			check(not fx.attack_visuals_active(),"All form-specific effects and particle tails fully expire")
	fx.free()
	print("Evolution presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
