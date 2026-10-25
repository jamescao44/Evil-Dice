extends SceneTree
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Orbit = preload("res://scripts/relics/relic_orbit.gd")
const Effects = preload("res://scripts/relics/relic_effects.gd")
const Attack = preload("res://scripts/relics/relic_attack.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func positions(g) -> Dictionary:
	var result := {}
	for pose in Orbit.poses(g): result[pose.item.id] = pose.at
	return result
func run() -> void:
	for portrait in [true,false]:
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g);g.muted=true;g.set_process(false);g.relic_ui.set_process(false)
		g._restart();g.view_phase="ready"
		var ui = g.relic_ui
		for id in ["fries","orange_stone","codex_page","bracelet"]: g.model.acquire_relic(id)
		g.reduced = true
		for level in [1,5,10]:
			g.evolution.displayed_level = level
			var sprite := Rect2(g._player_world_feet()-Vector2(g.monster_side*0.5,g.monster_side),Vector2.ONE*g.monster_side)
			var visible: Rect2 = g.evolution.visible_rect(sprite)
			for pose in Orbit.poses(g):
				if pose.slot in [1,3]:
					check(is_equal_approx(pose.at.y,visible.end.y-visible.size.y/3.0),"Both orbit sides sit one-third of each visible form above its feet")
		g.evolution.displayed_level = 1
		g.reduced = false
		ui.ready_clock=7.3
		var before: Dictionary = positions(g)
		ui.reset()
		check(before==positions(g) and ui.ready_clock==7.3,"Reward reset preserves orbit positions")
		ui.activate("bracelet");ui._process(0.1)
		var strength: float=ui.activation_strength("bracelet")
		check(strength>0.5,"Activation is immediately visible")
		for i in range(6): ui.activate("bracelet");ui._process(0.01)
		check(ui.activation_strength("bracelet")>=strength,"Rapid retriggers do not collapse the glow or bounce")
		ui.reset()
		check(ui.activation_strength("bracelet")>0,"Wave reward preserves just-triggered feedback")
		g.menu_open=true
		var time: float=ui.ready_clock
		var pulse: float=ui.activations.bracelet.age
		ui._process(2)
		check(ui.ready_clock==time and ui.activations.bracelet.age==pulse,"Menus pause orbit and activation together")
		g.menu_open=false
		ui._process(1)
		check(ui.activations.is_empty(),"Feedback expires when it is no longer retriggered")
		var m = g.model
		for enemy in m.enemies: enemy.hp=10000;enemy.max_hp=10000;enemy.shield=0
		m.roll_pool(false,[2,2,3,4,5,6])
		ui.activations.clear()
		m.resolve_roll_attack_step()
		for id in ["fries","codex_page","bracelet","orange_stone"]: check(ui.activations.has(id),"Automatic hit activates damage and on-hit relic: "+id)
		ui.activations.clear()
		Attack.apply(m,"worn_bow",5)
		for id in ["fries","codex_page","bracelet"]: check(ui.activations.has(id),"Base-damage proc activates contributors: "+id)
		ui.activations.clear()
		Attack.apply(m,"spiked_helmet",10,true)
		check(not ui.activations.has("bracelet") and not ui.activations.has("fries"),"Fixed damage does not flash unused damage modifiers")
		var inventory: Array=m.relics.items.duplicate(true)
		var rng_state: int=m.rng.state
		Effects.activate_damage_modifiers(m,m.Patterns.classify([1,2,3]))
		check(m.relics.items==inventory and m.rng.state==rng_state,"Feedback never reapplies effects, spends counters or draws RNG")
		g._restart();g.view_phase="ready"
		m.acquire_relic("fries");m.acquire_relic("fried_chicken")
		ui.activate("fries")
		check(ui.activations.has("budget_meal"),"Ingredient activation maps to the fused icon")
		g._restart();g.view_phase="ready"
		m.acquire_relic("contract")
		Effects.prevent_death(m)
		check(m.relics.items.is_empty() and Orbit.poses(g).size()==1,"Consumed Contract finishes its activation in orbit")
		ui._process(1)
		check(Orbit.poses(g).is_empty(),"Consumed icon disappears after its activation")
		g._restart()
		check(ui.ready_clock==0 and ui.activations.is_empty(),"New run resets both orbit and pending feedback")
		root.remove_child(g);g.free()
	print("Relic orbit feedback: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
