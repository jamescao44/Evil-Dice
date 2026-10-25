extends SceneTree
## Relic document changes exercise real damage, copied effects and temporary-card lifetimes.
const Run = preload("res://scripts/progression/run_rules.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh():
	var m = Run.new(241024)
	m.enemies = [m.make_enemy(0)]
	m.enemies[0].hp = 100000; m.enemies[0].max_hp = 100000
	return m

## A fixed deck makes lifetime assertions independent of which random card appeared.
func only_strength(m) -> void:
	m.tarot_effects.banned = m.Tarot.ITEMS.keys().filter(func(id): return id != "strength")

func damage_checks() -> void:
	for id in ["magic_sword","magic_slingshot","royal_dagger","contract","runestone","orange_stone","blue_stone","purple_stone","yellow_stone","green_stone","black_stone"]:
		var m = fresh(); m.begin_round(); m.acquire_relic(id)
		var bonus: float = 10 if id == "magic_sword" else 5
		var skill = m.Patterns.classify([1,2,3])
		check(m.standing_damage_values().x == 5+bonus,"Standing damage includes the new bonus: "+id)
		check(is_equal_approx(m.attack_base(skill),(5+bonus)*3.6),"Flat relic damage enters before the Fireball coefficient: "+id)
		check(m.attack_damage_steps(skill).any(func(step): return step.get("id","") == id and step.base_bonus == bonus),"Damage animation includes the granting relic: "+id)
	var m = fresh(); m.acquire_relic("magic_sword"); m.acquire_relic("disguise_mask"); m.acquire_relic("ancient_tentacle")
	check(m.relic_base_damage() == 40,"Mask and Tentacle repeat flat bonuses through the usual order")
	m = fresh()
	for id in m.RelicEffects.Catalog.STONES: m.acquire_relic(id)
	check(m.relics.has("prismatic_stone") and m.relics.items.size() == 1 and m.relic_base_damage() == 60,"Stone fusion keeps its documented sixty-point total")
	m = fresh(); m.acquire_relic("contract"); m.hp = 1
	m.receive_damage(1000)
	check(m.hp == 60 and not m.relics.has("contract") and m.relic_base_damage() == 0,"Contract's flat bonus disappears when it saves the player")
	for id in ["pet_ghost","pet_dragon"]:
		m = fresh(); m.acquire_relic(id); m.begin_round(); m.roll_pool(false,[1,2,3,4,5,6])
		var events: Array = m.resolve_perfect_relic().filter(func(e): return e.type == "damage")
		check(events.size() == (2 if id == "pet_dragon" else 1) and events.all(func(e): return e.display_amount == (15 if id == "pet_dragon" else 20)),"Pet uses the revised balance value: "+id)

func projection_checks() -> void:
	var m = fresh(); only_strength(m); m.acquire_relic("crystal_ball")
	var saved: Dictionary = m.grant_tarot("strength")
	var control = fresh(); control.begin_round()
	var state: int = control.rng.state
	m.begin_round()
	check(m.RelicEffects.Catalog.ITEMS.crystal_ball.rarity == 3 and m.relic_base_damage() == 0,"Crystal Ball is legendary without a flat damage bonus")
	check(m.tarots.items.size() == 2 and m.tarots.items[1].get("projection",false) and m.rng.state == state,"Turn start grants a marked temporary instance without combat RNG")
	m.begin_round(); m._grant_dice_bonus_turn()
	check(m.tarots.items.size() == 2,"Repeated begin and dice bonus pools cannot generate more projections")
	m._complete_relic_turn()
	check(m.tarots.items.size() == 1 and m.tarots.find_instance(saved.instance_id) >= 0,"Expiry preserves a permanent duplicate of the same card")
	m.phase = "round_end"; m.begin_round()
	var projection: Dictionary = m.tarots.items.back()
	m.acquire_relic("ancient_prophecy")
	check(not m.tarot_effects.cast(m,projection.instance_id).has("error"),"A projection can be used normally")
	var echo: int = m.tarot_effects.pending_repeat.instance_id
	check(not m.tarot_effects.cast(m,echo).has("error") and m.tarot_effects.strength == 2,"Projection effects support the normal Prophecy repeat")
	m._complete_relic_turn()
	check(m.tarots.items.size() == 1,"Used projections cannot expire a different owned instance")
	m.phase = "round_end"; m.begin_round(); m.enemies[0].hp = 0; m.begin_wave_reward()
	check(m.tarots.items.size() == 1,"Immediate wave clears remove unused projections before rewards")
	m = fresh(); only_strength(m)
	for id in ["crystal_ball","disguise_mask","ancient_tentacle"]: m.acquire_relic(id)
	m.begin_round()
	check(m.tarots.items.size() == 4 and m.tarots.items.all(func(card): return card.get("projection",false)),"Explicit copy relics produce temporary copies, not permanent cards")
	m._complete_relic_turn(); check(m.tarots.items.is_empty(),"Every copied projection expires at turn end")
	m.phase = "round_end"; m.begin_round(); m._load_wave()
	check(m.tarots.items.is_empty(),"Wave changes cannot carry unused projections into shops")

## Expiry cannot leave a stale inspected/dragged card or an orphaned pickup animation.
func scene_checks(phone: bool) -> void:
	var g = Portrait.new() if phone else Battle.new()
	root.add_child(g); g.muted = true; g.set_process_input(false)
	g.model.tarots.clear(); g.tarot_ui.pickup.reset()
	var permanent: Dictionary = g.model.grant_tarot("strength")
	var projection: Dictionary = g.model.grant_tarot("strength",-1,true)
	g.tarot_ui.opened = true; g.tarot_ui.expansion = 1; g.tarot_ui.inspected = 1
	g.tarot_ui.scroll = 1; g.tarot_ui.scroll_target = 1
	g.tarot_ui.float_levels[projection.instance_id] = 1.0
	check(g.tarot_ui.inspection_description(projection).contains(GameText.text("Projection: expires at turn end.")),"Inspection identifies the temporary card")
	for id in g.model.Tarot.ITEMS:
		var item := {"id":id,"projection":true}
		var rect: Rect2 = g.tarot_ui.inspection_rect(item)
		check(rect.position.y > 0 and rect.end.y < g.DICE_CENTER.y,"All projection descriptions stay on screen")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame; RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/projection-"+("portrait" if phone else "landscape")+".png")
	g.model.expire_tarot_projections()
	check(g.model.tarots.items.size() == 1 and g.model.tarots.items[0].instance_id == permanent.instance_id,"UI expiry keeps permanent cards")
	check(g.tarot_ui.inspected == -1 and g.tarot_ui.gesture.is_empty() and g.tarot_ui.scroll_target == 0,"Expiry clears stale inspection and carousel selection")
	check(g.tarot_ui.pickup.pending.all(func(item): return item.instance_id != projection.instance_id) and g.tarot_ui.pickup.cards.all(func(card): return card.item.instance_id != projection.instance_id),"Expired receipts cannot later fly into inventory")
	g.queue_free(); await process_frame

func _initialize() -> void: call_deferred("run")
func run() -> void:
	damage_checks(); projection_checks()
	for phone in [false,true]: await scene_checks(phone)
	print("Relic document updates: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
