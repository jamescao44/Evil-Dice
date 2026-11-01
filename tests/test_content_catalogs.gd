extends SceneTree
## Verify catalog references and independent instance state for future content additions.
const Validate = preload("res://scripts/shared/content_validation.gd")
const Gems = preload("res://scripts/dice/gemstone_inventory.gd")
const GemEffects = preload("res://scripts/dice/gemstone_effects.gd")
const Enemies = preload("res://scripts/enemies/enemy_catalog.gd")
const Moves = preload("res://scripts/enemies/enemy_skill_catalog.gd")
const Visuals = preload("res://scripts/enemies/enemy_visuals.gd")
const Relics = preload("res://scripts/relics/relic_inventory.gd")
const Instance = preload("res://scripts/relics/relic_instance.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Broken future definitions fail validation before they reach a reward or battle scene.
func definitions() -> void:
	var errors: Array = Validate.all_errors()
	check(errors.is_empty(),"Content references: "+str(errors))
	var gems := Gems.Catalog.ITEMS.duplicate(true)
	gems.burning.attack_hooks = ["misspelled"]
	check(not Validate.gems(gems).is_empty(),"Unknown gem hooks are rejected")
	var enemies := Enemies.ITEMS.duplicate(true)
	enemies[Enemies.Role.VANGUARD].skills = [["missing_skill",5]]
	check(not Validate.enemies(enemies).is_empty(),"Unknown enemy actions are rejected")
	for invalid_damage in [-1.0,INF,NAN,"twenty"]:
		enemies = Enemies.ITEMS.duplicate(true)
		enemies[Enemies.Role.MAGE].damage_percent = invalid_damage
		check(not Validate.enemies(enemies).is_empty(),"Enemy damage must be finite and nonnegative even with fractional bases")
	var relics := Relics.Catalog.ITEMS.duplicate(true)
	relics.bracelet.stats = {"base_damgae":5}
	check(not Validate.relics(relics).is_empty(),"Misspelled passive stats are rejected")
	relics = Relics.Catalog.ITEMS.duplicate(true)
	relics.magic_sword.turn_charge.period = 0
	check(not Validate.relics(relics).is_empty(),"Invalid periodic triggers are rejected")
	relics = Relics.Catalog.ITEMS.duplicate(true)
	relics.bracelet.sprite = "missing-asset.png"
	check(not Validate.relics(relics).is_empty(),"Missing item art is rejected")
	check(not Relics.Sets.collection_complete([],"unknown_set"),"An unknown set is never considered complete")
	for role in Enemies.Role.values():
		check(Enemies.ITEMS.has(role),"Stable role has a definition")
		for elite in [false,true]:
			var unit := Enemies.make(role,1,elite)
			check(Visuals.asset_paths().has(Visuals.art_key(unit)),"Both enemy variants register their artwork")
	for id in Relics.Catalog.ITEMS:
		if Relics.Sets.uses_composite_art(id): continue
		check(load(Relics.Catalog.sprite_path(id)) is Texture2D,"Reward and inventory asset resolves: "+id)

## Repeated objects own their counters, sockets, snapshots and optional nested state.
func isolation() -> void:
	var one := Gems.new()
	var two := Gems.new()
	one.add("burning",1,2); one.equip(0,"burning")
	var snapshot := one.snapshot([0])
	one.merge(one.sockets[0],0)
	check(snapshot[0].level == 1 and one.sockets[0].level == 2,"Merging does not rewrite an ongoing cast")
	check(two.sockets.all(func(gem): return gem.is_empty()) and two.bag.is_empty(),"Independent inventories do not share sockets or gems")
	var saved := one.save()
	two.restore(saved); saved.sockets[0].level = 3
	check(one.sockets[0].level == 2 and two.sockets[0].level == 2,"Restoring and editing serialized data do not alias equipment")
	for id in Gems.Catalog.ids():
		for level in range(1,Gems.Catalog.max_level(id)+1):
			var gem := {"id":id,"level":level}
			check(Gems.valid_gem(gem),"Every declared tier can be equipped")
			check(Gems.Catalog.can_merge(gem) == (level < Gems.Catalog.max_level(id)),"Merge limits come from that gem's tiers")
	check(is_equal_approx(GemEffects.status_chance({"id":"corrosive","level":3},true),0.15),"Corrosive uses the automatic proc rate")
	check(GemEffects.recovery([{"id":"healing","level":1}],[1],150,"heal") == 2,"Half-point healing rounds once after aggregation")
	var a := Instance.create("fixture",{"nested":{"charges":2},"ingredients":["fries"]})
	var b := Instance.create("fixture",a)
	b.nested.charges = 9; b.ingredients.append("hamburger")
	check(a.nested.charges == 2 and a.ingredients == ["fries"],"Relic instances never share nested custom state")
	var vanguard := Enemies.make(Enemies.Role.VANGUARD)
	var other := Enemies.make(Enemies.Role.VANGUARD)
	vanguard.intent.skill = "rest"
	check(other.intent.is_empty(),"Enemies of the same type have independent intents")
	var move := Moves.make("fire",20)
	move.stacks = 99
	check(Moves.make("fire",20).stacks == 1,"One selected enemy move cannot mutate its template")
	var first := Relics.new(); var second := Relics.new()
	first.add("magic_sword"); second.add("magic_sword")
	first.items[0].charges = 4
	check(second.items[0].charges == 0,"Separate copies of a relic retain independent charges")

func _initialize() -> void:
	definitions(); isolation()
	print("Content catalogs: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
