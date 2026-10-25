extends SceneTree
## Salvage transactions, shared upgrade pity and inventory selling through real model rules.
const Run = preload("res://scripts/progression/run_rules.gd")
const Catalog = preload("res://scripts/relics/relic_catalog.gd")
const Chest = preload("res://scripts/rewards/reward_chest.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
const Portrait = preload("res://scripts/combat/battle_portrait.gd")
const OWNED := ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")

## Lock test prizes without depending on random rarity outcomes.
func chest_with(m, ids: Array) -> void:
	m._roll_chest(2)
	m.open_rewards.clear(); m.chest_relics.clear()
	for id in ids:
		m.chest_relics[m.open_rewards.size()] = id
		m.open_rewards.append(m.Rewards.Category.RELIC)

func economy() -> void:
	var examples := ["heart","magic_shield","orange_stone","mithril_blade","cursed_skull"]
	for i in range(5):
		var m = Run.new(81)
		chest_with(m,[examples[i]])
		var expected: int = [10,30,80,120,120][i]
		check(m.unclaimed_relic_gems() == expected,"Discard preview follows all five rarities")
		check(m.claim_reward(0,-1,true).text_values == [expected] and m.blood_gems == expected,"Discard pays its rarity exactly once")
		check(m.claim_reward(0,-1,true).is_empty() and m.blood_gems == expected,"Double-discard is rejected")
		check(m.unclaimed_relic_gems() == 0,"Claimed slots leave the total immediately")
	var session = Session.new(31)
	session.model.acquire_relic("heart")
	check("sell" in session.snapshot().actions,"CLI advertises inventory selling")
	check(session.command({"action":"sell","slot":1}).ok and session.model.blood_gems == 10,"CLI uses the same sale transaction")
	check(not session.command({"action":"sell","slot":1}).ok and session.model.blood_gems == 10,"Repeated CLI sale cannot duplicate currency")
	var m = Run.new(82)
	m.acquire_relic("soul_vessel")
	chest_with(m,["heart","orange_stone","mithril_blade"])
	m.claim_reward(0)
	var quote: int = m.unclaimed_relic_gems()
	var before: int = m.blood_gems
	var rng_before: int = m.reward_rng.state
	check(m.discard_unclaimed_rewards() == 2 and m.blood_gems-before == quote and quote == 200,"Partial skip pays remaining relics; Soul Vessel now affects enemy souls only")
	check(m.discard_unclaimed_rewards() == 0 and m.reward_rng.state == rng_before,"Skipping twice never repeats payment or uses RNG")
	check(m.relics.has("heart") and not m.relics.has("orange_stone"),"Skip keeps the already claimed relic only")
	m = Run.new(83)
	for id in OWNED: m.acquire_relic(id)
	quote = m.replacement_gem_preview("mithril_blade",0)
	check(m.acquire_relic("mithril_blade",0) and m.blood_gems == quote and quote == 10,"Replacing an owned Common pays ten")
	before = m.blood_gems
	check(not m.acquire_relic("mithril_blade",1) and m.blood_gems == before,"Duplicate failed acquisition pays nothing")
	check(not m.acquire_relic("orange_stone",100) and m.blood_gems == before,"Invalid replacement pays nothing")
	m = Run.new(84); m.acquire_relic("lemon_soda"); m.acquire_relic("fries",0)
	check(m.blood_gems == 0 and m.relics.items[0].id == "budget_meal","Food fusion never salvages its ingredients")
	m = Run.new(85); m.acquire_relic("codex_page"); m.acquire_relic("codex_page"); m.acquire_relic("codex_page")
	quote = m.relic_sale_preview(0)
	check(quote == 30 and m.sell_relic(0) == quote and m.relics.items.is_empty(),"Selling a stacked slot pays for all three pages")
	check(m.sell_relic(0) == 0 and m.blood_gems == quote,"Selling an empty slot cannot duplicate money")
	m = Run.new(86); m.acquire_relic("soul_vessel"); m.acquire_relic("disguise_mask")
	quote = m.relic_sale_preview(0)
	check(m.sell_relic(0) == quote and m.blood_gems == quote,"Selling a currency source quotes the resulting inventory correctly")
	m = Run.new(87); m.acquire_relic("heart"); m.hp = 110
	check(m.sell_relic(0) == 10 and m.hp == 100 and m.max_hp == 100,"Selling health relic clamps current health")
	m = Run.new(88); m.acquire_relic("reaper_scythe"); m.hp = 15
	m.sell_relic(0)
	check(m.hp == 15 and m.max_hp == 100,"Selling the half-health curse does not grant free healing")
	for card_id in ["emperor","world"]:
		m = Run.new(89); m.begin_round()
		for id in OWNED: m.acquire_relic(id)
		var card: Dictionary = m.tarots.add(card_id)
		m.tarot_effects.locked_grants[card.instance_id] = "mithril_blade"
		check(m.tarot_effects.prepare(m,card.instance_id).get("choice","") == "replace","Full tarot grant is locked before decision")
		m.tarot_effects.cast(m,card.instance_id,{"discard":true})
		check(m.blood_gems == 120 and m.tarots.find_instance(card.instance_id) < 0,"Declined Emperor or World grant pays once and consumes card")
		check(m.tarot_effects.cast(m,card.instance_id,{"discard":true}).has("error") and m.blood_gems == 120,"Repeated declined card cannot pay again")

func upgrade_rules() -> void:
	var m = Run.new(77)
	for progress in range(10):
		m.reroll_progress = progress
		check(m.chest_tier() == 0 and m.open_chest().is_empty(),"No milestone below ten")
	m.reroll_progress = 10; m.chest_pity.misses = [2,3,3]
	check(m.open_chest(2).is_empty() and m.reroll_progress == 10,"Higher starting tiers cannot be requested")
	var prizes: Array = m.open_chest()
	check(m.reroll_progress == 0 and m.chest_start_tier == 1 and m.opened_chest_tier == 3,"Ten points starts Perfect with normal upgrades")
	check(m.chest_pity.misses == [2,0,0],"Only Perfect and Greed pity are consumed")
	var state: int = m.reward_rng.state
	check(m.open_chest() == prizes and m.reward_rng.state == state,"Reopening does not reroll upgrades")
	var rng := RandomNumberGenerator.new(); rng.seed = 20261024
	var counts := [0,0,0,0]
	for n in range(20000): counts[m.Chests.roll_wave_tier(rng,[0,0,0],1)] += 1
	check(counts[0] == 0 and absf(counts[1]/20000.0-0.75) < 0.015 and absf(counts[2]/20000.0-0.1875) < 0.015 and absf(counts[3]/20000.0-0.0625) < 0.015,"Starting Perfect preserves 25 percent per-step natural odds")

func capture(g, label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/salvage-%s-%s.png" % ["portrait" if g is Portrait else "landscape",label])

func layout(portrait: bool) -> void:
	root.content_scale_size = Vector2i(804,1748) if portrait else Vector2i(1280,800)
	root.size = Vector2i(402,874) if portrait else Vector2i(1280,800)
	var g = Portrait.new() if portrait else Battle.new()
	root.add_child(g); g.muted = true; g.speed = 2
	g.model.reroll_progress = 10
	await capture(g,"meter")
	g.model.chest_pity.misses = [0,3,3]
	g._reward_sequence()
	check(g.chest.tier == 1 and g.chest.final_tier == 3 and g.chest.upgrade_mode,"Real reroll presentation begins at Perfect, hiding locked upgrades")
	g.run_id += 1 # End the asynchronous fixture without collecting its prizes.
	g.model.discard_unclaimed_rewards(); g.model.close_chest(); g.chest.cancel()
	g.view_phase = "ready"; g.model.blood_gems = 0

	g.model.acquire_relic("mithril_blade")
	var page = g.inventory_page
	page.open(); page.selected = 0
	await capture(g,"sell")
	check(Rect2(Vector2.ZERO,g.fx.canvas_size).encloses(page.sell_rect()),"Sell button fits canvas")
	page.click(page.sell_rect().get_center())
	check(g.model.relics.items.is_empty() and g.model.blood_gems == 120 and page.selected == -1,"Real inventory sale returns to grid and removes one relic")
	page.close()
	for id in OWNED: g.model.acquire_relic(id)
	chest_with(g.model,["mithril_blade","orange_stone","cursed_skull"])
	g.view_phase = "reward"
	var prizes: Array = []
	for slot in range(3): prizes.append(g.model.reward_item(slot))
	g.chest.start(g.model.open_rewards,g.fx.canvas_size,g.description_font,true,prizes,2)
	g.chest.open_chest(); g.chest.request_stop(); g.chest._finish_reels()
	await capture(g,"forfeit-total")
	g.relic_ui.chest_slot = 0; page.open("chest")
	await capture(g,"incoming")
	page.selected = 0
	await capture(g,"compare-sale")
	check(not page.sell_rect().intersects(page.close_rect()),"Sale and cancel targets never overlap")
	page.click(page.sell_rect().get_center())
	check(page.can_take_incoming() and g.model.relics.items.size() == 9,"Selling while comparing leaves pending reward collectable")
	page.click(page.take_rect().get_center())
	check(g.model.relics.has("mithril_blade") and g.model.relics.items.size() == 10,"Explicit take fills the freed slot without replacing another relic")
	g.chest.cancel(); g.queue_free(); await process_frame

func run() -> void:
	economy(); upgrade_rules()
	await layout(false); await layout(true)
	print("Relic salvage and treasure: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
