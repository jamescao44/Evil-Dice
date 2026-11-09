extends SceneTree
## Document relic updates exercise complete casts, ordered stats and checkpoint loot pools.
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Paint = preload("res://scripts/relics/relic_paint.gd")
const Validate = preload("res://scripts/shared/content_validation.gd")
const NEW := ["basic_crystal","warrior_greatsword","intermediate_crystal","phoenix_feather","master_crystal","supreme_crystal"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Isolate battle and save state without touching the live chapter.
func fresh(ids: Array = []):
	var m = Run.new(3112026)
	m.enemies = [m.make_enemy(0),m.make_enemy(1)]
	for e in m.enemies: e.hp = 100000; e.max_hp = 100000; e.shield = 0
	for id in ids: check(m.acquire_relic(id),"Acquire "+id)
	return m

## Resolve a complete cast, including queued skills, through the production damage path.
func cast(m, faces: Array, source: String = "manual", uses: int = 1) -> Array:
	m.dice_turn.active = false
	m.pending = m.make_straight_skill(faces)
	m.pending.cast_source = source
	m.pending.base_uses = uses
	if source != "manual": m.pending.amplifier_locked = true
	m.phase = "player"
	var events: Array = []
	for guard in range(100):
		if m.phase not in ["player","executing"] or m.pending.is_empty(): break
		events.append_array(m.apply_player(m.player_target()))
	return events

func stats_checks() -> void:
	for spec in [["basic_crystal",5],["intermediate_crystal",10],["master_crystal",20],["contract",5],["oreo_sundae",7]]:
		var m = fresh([spec[0]])
		check(is_equal_approx(m.relic_base_damage(),spec[1]),"Document base bonus: "+spec[0])
	var m = fresh(["bracelet","supreme_crystal"])
	check(is_equal_approx(m.damage_multiplier(),4.4) and is_zero_approx(m.relic_base_damage()),"Bracelet +0.4 and Supreme +3 affect multiplier only")
	m = fresh(["basic_crystal","mithril_blade"])
	check(m.character_base_damage()+m.relic_base_damage() == 40 and m.damage_multiplier() == 2.5,"Mithril adds 30 base and 1.5 multiplier")
	var skill = m.make_straight_skill([1,2,3])
	check(m.raw_attack_damage(skill) == 360,"Skill coefficient follows ordered base modifiers")
	var trace: Array = m.attack_damage_steps(skill)
	check(is_equal_approx(trace.back().base_after*trace.back().after,m.raw_attack_damage(skill)),"Displayed buildup matches actual damage")
	m.relics.move(0,1)
	check(m.character_base_damage()+m.relic_base_damage() == 40,"Flat base additions remain unchanged when reordered")
	check(m.RelicEffects.Attack.apply(m,"test",10)[0].display_amount == 112,"Item attacks share the ordered base pipeline")
	m = fresh(["contract"])
	m.receive_damage(100000)
	check(m.hp == roundi(m.max_hp*0.6) and not m.relics.has("contract"),"Contract keeps its one-use revival")

func feather_checks() -> void:
	var m = fresh(["phoenix_feather"])
	var events: Array = m.begin_round()
	check(m.relic_base_damage() == 5,"Phoenix adds five base damage")
	check(events.filter(func(e): return e.type == "status").size() == 1,"Phoenix picks one enemy at full-turn start")
	check(m.enemy_status_count(0,m.Status.BURNING)+m.enemy_status_count(1,m.Status.BURNING) == 2,"Phoenix applies two stacks")
	m.begin_round(); m._grant_dice_bonus_turn()
	check(m.enemy_status_count(0,m.Status.BURNING)+m.enemy_status_count(1,m.Status.BURNING) == 2,"No duplicate on a repeated begin or bonus dice pool")
	m.phase = "round_end"; m.begin_round()
	check(m.enemy_status_count(0,m.Status.BURNING)+m.enemy_status_count(1,m.Status.BURNING) == 4,"New complete turn activates Phoenix again")
	m = fresh(["phoenix_feather","disguise_mask","ancient_tentacle"])
	m.begin_round()
	check(m.enemy_status_count(0,m.Status.BURNING)+m.enemy_status_count(1,m.Status.BURNING) == 8,"Mask and Tentacle repeat opening status four times")
	check(m.hp == m.max_hp-20,"Only Tentacle's two copied activations pay HP")
	m = fresh(["phoenix_feather","runestone"]); m.begin_round()
	check(m.enemy_status_count(0,m.Status.BURNING)+m.enemy_status_count(1,m.Status.BURNING) == 3,"Runestone augments Phoenix stacks")
	m = fresh(["phoenix_feather"]); m.enemies.clear()
	var state: int = m.rng.state
	check(m.RelicEffects.turn_started(m).is_empty() and m.rng.state == state,"No opening target means no effect or random draw")
	m = fresh(["phoenix_feather","powder_keg"])
	m.enemies.resize(1); m.enemies[0].hp = 1
	m.apply_enemy_status(0,m.Status.BURNING,8,false)
	m.begin_round()
	check(not m.outcome().is_empty() and m.phase == "finished" and m.relic_turn_closed,"Phoenix's secondary explosion settles the completed turn and wave")
	m = fresh(["phoenix_feather","powder_keg"])
	m.enemies.resize(1); m.enemies[0].modifier = "thorns"
	m.apply_enemy_status(0,m.Status.BURNING,8,false)
	var before: int = m.hp
	var opening: Array = m.begin_round()
	check(m.hp < before and opening.any(func(e): return e.target == -1 and e.type == "damage") and m.player_end_events.is_empty(),"Opening retaliation is returned immediately, never delayed to a later cast")

func sword_checks() -> void:
	for source in ["manual","missile","character_bonus","chip","echo"]:
		var m = fresh(["warrior_greatsword"])
		var hits: Array = cast(m,[3,4,5],source).filter(func(e): return e.type == "damage")
		check(hits.size() == 2 and hits.back().display_amount == 10,"One extra item attack after "+source)
	for faces in [[1,2,3,4,5],[1,2,3,4,5,6]]:
		var m = fresh(["warrior_greatsword"])
		var expected: int = m.make_straight_skill(faces).damage_ticks*2+1
		var hits: Array = cast(m,faces).filter(func(e): return e.type == "damage")
		check(hits.size() == expected and hits.back().display_amount == 10,"Pulse skill activates sword only after all damage ticks")
	var m = fresh(["warrior_greatsword","split_arrow"])
	check(cast(m,[1,2,3]).filter(func(e): return e.type == "damage").size() == 3,"Split Arrow's two hits still count as one completed cast")
	m = fresh(["warrior_greatsword"])
	check(cast(m,[1,2,3],"manual",3).filter(func(e): return e.type == "damage").size() == 4,"Three uses in one cast activate sword once")
	m = fresh(["warrior_greatsword","disguise_mask","ancient_tentacle"])
	var hits: Array = cast(m,[1,2,3]).filter(func(e): return e.type == "damage")
	check(hits.size() == 5 and hits.slice(1).all(func(e): return e.display_amount == 10),"Copied Greatsword attacks never recursively trigger themselves")
	check(m.hp == m.max_hp-20,"Two extra sword activations pay two curse costs")
	m = fresh(["warrior_greatsword","bracelet","basic_crystal"])
	hits = cast(m,[1,2,3]).filter(func(e): return e.type == "damage")
	check(hits.back().display_amount == 28,"Sword uses base bonuses and multiplier")
	m = fresh(["warrior_greatsword"])
	var activations: Array = []
	m.relic_activated.connect(func(id): activations.append(id))
	m.begin_round(); m.roll_pool(false,[1,1,3,4,5,6])
	for guard in range(20):
		if m.roll_attacks.is_empty(): break
		m.resolve_roll_attack_step()
	m.RelicEffects.Attack.apply(m,"test",10)
	check(not activations.has("warrior_greatsword"),"Automatic and item attacks do not activate Greatsword")
	m = fresh(["warrior_greatsword"]); m.enemies.resize(1); m.enemies[0].hp = 1
	hits = cast(m,[1,2,3]).filter(func(e): return e.type == "damage")
	check(hits.size() == 1,"No extra attack at corpses after the final foe dies")
	m = fresh(["warrior_greatsword","challenger_badge"])
	m.RelicFocus.select(m,1)
	hits = cast(m,[1,2,3]).filter(func(e): return e.type == "damage")
	check(not hits.is_empty() and hits.back().target == 1,"Random sword attack follows Challenger's Badge")
	m = fresh(["warrior_greatsword"])
	m.enemies = [m.make_enemy(m.EnemyCatalog.Role.COMMANDER)]
	m.enemies[0].hp = 1; m.enemies[0].shield = 0
	hits = cast(m,[1,2,3]).filter(func(e): return e.type == "damage")
	check(hits.size() == 1 and m.enemies[0].boss_phase == 2,"Sword cannot carry an attack across the depleted boss phase")

func checkpoint_checks() -> void:
	var m = fresh(["banana"])
	var before: Dictionary = Run.Campaign.capture(m)
	for seed_value in range(100):
		m.rng.seed = seed_value; m.RelicEffects.Conditions.turn_finished(m)
		if not m.relics.has("banana"): break
	check(not m.relics.can_add("banana") and m.relics.can_add("magic_banana"),"Disappearance replaces Banana in all eligible pools")
	var after: Dictionary = Run.Campaign.capture(m)
	check(Run.Campaign.restore(m,before) and m.relics.has("banana"),"Earlier checkpoint restores the owned Banana")
	check(not m.relics.can_add("magic_banana"),"Earlier checkpoint locks Magic Banana again")
	m.sell_relic(0)
	check(m.relics.can_add("banana") and not m.relics.can_add("magic_banana"),"Selling Banana leaves its original pool intact")
	check(Run.Campaign.restore(m,after) and not m.relics.can_add("banana") and m.relics.can_add("magic_banana"),"Later checkpoint retains the replacement pool")
	var path := "res://test-output/crystal-relic-discoveries.cfg"
	DirAccess.remove_absolute(path)
	m.relics.unlocks.configure(path); m.relics.unlocks.restore(["magic_banana"])
	var other = fresh(); other.relics.unlocks.configure(path)
	check(other.relics.can_add("magic_banana") and not other.relics.can_add("banana"),"Chapter replacement persists on disk")
	Run.Campaign.restore(other,before)
	var reloaded = fresh(); reloaded.relics.unlocks.configure(path)
	check(not reloaded.relics.can_add("magic_banana"),"Rewound checkpoint also replaces saved discovery state")
	m.relics.unlocks.configure(path,"chapter_2")
	check(m.relics.can_add("banana") and not m.relics.can_add("magic_banana"),"Other chapter has its own pool")
	m.relics.unlocks.unlock("magic_banana")
	var campaign = Run.Campaign.new(); campaign.start(m)
	check(m.relics.can_add("banana") and not m.relics.can_add("magic_banana"),"Restarting at level one restores its original pool")
	DirAccess.remove_absolute(path)

func catalog_checks() -> void:
	check(Validate.all_errors().is_empty(),"All content references validate")
	var m = fresh()
	for i in range(NEW.size()):
		var id: String = NEW[i]
		check(Catalog.ITEMS[id].rarity == [0,1,1,2,2,3][i],"Rarity for "+id)
		check(m.relics.can_add(id) and not Catalog.ITEMS[id].get("fusion",false),"Ordinary reward eligibility for "+id)
		check(Paint.textures.get(Paint._load_sprite(id)) != null,"Shared sprite loads for "+id)
		check(GameText.text(Catalog.ITEMS[id].name) != Catalog.ITEMS[id].name,"Chinese name for "+id)
		check(GameText.text(Catalog.ITEMS[id].text) != Catalog.ITEMS[id].text,"Chinese description for "+id)

func _initialize() -> void: call_deferred("run")

## Lethal turn-start copies must leave the actual battle UI in defeat, never ready.
func scene_checks() -> void:
	var g = preload("res://scripts/combat/battle_portrait.gd").new()
	root.add_child(g); g.muted = true; g.process_mode = Node.PROCESS_MODE_DISABLED
	g.model.acquire_relic("phoenix_feather"); g.model.acquire_relic("ancient_tentacle")
	g.model.hp = 1; g.model.phase = "round_end"
	g._start_round()
	check(g.model.outcome() == "defeat" and g.view_phase == "over","Opening copied relic cannot overwrite defeat with ready controls")
	g.queue_free(); await process_frame

func run() -> void:
	GameText.set_language("zh_CN",false)
	stats_checks(); feather_checks(); sword_checks(); checkpoint_checks(); catalog_checks()
	await scene_checks()
	print("Crystal relic update: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
