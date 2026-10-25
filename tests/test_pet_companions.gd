extends SceneTree
## Ownership, copied/fused triggers and cosmetic movement must stay separate from combat rules.
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const Pets = preload("res://scripts/relics/pet_companions.gd")
const Sequence = preload("res://scripts/relics/relic_sequence.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
var checks := 0
var failures := 0

class OtherCharacter:
	extends "res://scripts/progression/run_rules.gd"
	## A non-Fireball fixture proves generated relic skills use the character's resolver.
	func make_straight_skill(values: Array) -> MultiHitSkill:
		return Skill.new(Skill.Kind.PAIR,2,values)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for portrait in [true,false]:
		var g = Portrait.new() if portrait else Battle.new()
		root.add_child(g); g.muted = true; g.set_process(false); g.relic_ui.set_process(false)
		g._restart(); g.view_phase = "ready"
		var m = g.model; var p = g.pet_companions
		p.rng.seed = 251025
		for id in ["pet_bat","pet_lizard","pet_slime","pet_ghost"]: m.acquire_relic(id)
		p.sync(m)
		var before: Dictionary = p.states.duplicate(true)
		m.relics.move(0,3); p.sync(m)
		check(p.states == before,"Inventory reordering does not move or respawn pets")
		m.acquire_relic("pet_dragon"); p.sync(m)
		check(m.relics.items.size() == 1 and p.states.size() == 5,"One fused ball summons all five pets")
		for id in before: check(p.states[id] == before[id],"Fusion keeps existing pet pose: "+id)
		m.acquire_relic("disguise_mask"); p.sync(m)
		check(p.states.size() == 5,"Copies do not create duplicate companion creatures")
		var copied: Array = Sequence.entries(m.relics.items).filter(func(e): return e.item.id == "pet_dragon" and e.source == "disguise_mask")
		check(copied.size() == 1,"Copied fused effects retain the dragon identity")
		Sequence.activate(m,copied[0])
		check(p.states.pet_dragon.jump == 0 and p.states.pet_bat.jump < 0,"Only the pet whose copied effect fired jumps")
		check(g.relic_ui.activations.has("pet_orb") and g.relic_ui.activations.has("disguise_mask"),"Fused ball and copy icon still glow")
		var rng_before: int = m.rng.state
		var hp_before: int = m.hp
		var inventory: Array = m.relics.items.duplicate(true)
		p.advance(0.2,m,false,Vector2.RIGHT,false)
		check(p.poses(g).any(func(x): return x.id == "pet_dragon" and x.jump > 5),"Activation visibly lifts the creature")
		p.activate("pet_dragon")
		check(p.states.pet_dragon.again,"Rapid activations queue a hop instead of pinning it to the ground")
		for i in range(300): p.advance(1.0/60,m,false,Vector2.RIGHT,false)
		check(p.states.pet_bat.offset != before.pet_bat.offset,"Pets wander without player input")
		for i in range(180): p.advance(1.0/60,m,true,Vector2(1,-0.6),false)
		check(p.states.values().all(func(x): return x.offset.x < 0 and x.moving),"All pets follow behind the player on diagonal travel")
		check(m.rng.state == rng_before and m.hp == hp_before and m.relics.items == inventory,"Movement changes neither combat randomness nor gameplay state")
		for level in [1,5,10]:
			g.evolution.displayed_level = level
			for pose in p.poses(g):
				check(g.ARENA.has_point(pose.ground) and pose.ground.y <= g.player_health_rect().position.y-10,"Companions keep clear of health bars in both layouts")
		var held: Dictionary = p.states.duplicate(true)
		p.advance(1,m,false,Vector2.RIGHT,true)
		for id in held: check(p.states[id].offset == held[id].offset,"Reduced effects keep companion positions still")
		m.sell_relic(m.relics.index_of("pet_orb")); p.sync(m)
		check(p.states.is_empty(),"Selling the ball removes all its companions")
		g._restart(); check(p.states.is_empty(),"New runs remove old companion presentation")
		root.remove_child(g); g.free()
	for id in Pets.PETS.keys()+["pet_orb"]:
		check(not Paint._load_sprite(id).is_empty(),"Food and ball icons load: "+id)
	check(not Paint.Catalog.Sets.uses_composite_art("pet_orb"),"Super Pet Ball uses one ball icon")
	var other = OtherCharacter.new(44)
	other.acquire_relic("enchanted_missile"); other.begin_round()
	check(other.pending.is_freeze() and other.pending.dice == [3,4,5] and other.pending.cast_source == "missile","Missile resolves the current character's 3-4-5 skill, not Fireball")
	other.relic_skills.queued.clear(); other.pending = other.Skill.new(); other.phase = "roll"
	other.dice_turn.values = [1,2,3,4,5,6]; other.dice_turn.rolls_made = 1; other.dice_turn.selected = [2,3,4]
	check(other.form_selected_skill().is_freeze(),"Manual formation shares the same character skill resolver")
	print("Pet companions and character relic casts: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
