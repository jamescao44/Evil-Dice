extends SceneTree
## Verify ten-wave boundaries, persisted entry builds, retry isolation and real home controls.
const Run = preload("res://scripts/progression/run_rules.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
const Home = preload("res://scripts/home/home.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Clear only fixture enemies; reward claims still use their actual transactions.
func finish_level(m, stage: int = 9) -> void:
	m.stage = stage; m.enemies.clear(); m.pending = m.Skill.new(); m.phase = "finished"; m.wave_kind = "relic"
	m.wave_chest_stage = -1; m.wave_reward_resolved = true
	m.begin_wave_reward(); m.open_wave_chest(); m.discard_unclaimed_rewards(); m.close_chest(); m.finish_wave_reward()
	if m.auto_claim_victory_chest() > 0: m.discard_unclaimed_rewards(); m.close_chest()

func capture(view, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	view.queue_redraw(); await process_frame; RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://test-output/levels-20261025/"+name+".png")

## An earlier completed level must not replace a replay's new relics or tarot inventory.
func check_replayed_level(saved: Dictionary) -> void:
	var campaign = Run.Campaign.new()
	campaign.checkpoint = saved.duplicate(true); campaign.cleared_level = 1
	var replay = Run.new(72)
	replay.acquire_relic("witch_ghost"); replay.grant_tarot("magician"); replay.grant_tarot("strength")
	finish_level(replay)
	var items: Array = replay.relics.items.duplicate(true)
	var cards: Array = replay.tarots.items.duplicate(true)
	check(campaign.complete(replay),"Replayed level can commit its completed build")
	check(campaign.checkpoint.relics == items and campaign.checkpoint.tarots == cards,"Earlier clear cannot suppress new relic and tarot checkpoint")
	var latest: Dictionary = campaign.checkpoint.duplicate(true)
	replay.acquire_relic("armor")
	check(campaign.complete(replay) and campaign.checkpoint == latest,"Same completion remains idempotent")
	campaign.start(replay)
	check(replay.relics.items == items and replay.tarots.items == cards,"Continuation uses the latest replay build")
	replay.reset_run(); replay.acquire_relic("steel_sword"); replay.grant_tarot("world")
	finish_level(replay)
	items = replay.relics.items.duplicate(true); cards = replay.tarots.items.duplicate(true)
	check(campaign.complete(replay) and campaign.checkpoint.relics == items and campaign.checkpoint.tarots == cards,"Reusing a model for a fresh run can save the same level again")

func run() -> void:
	var m = Run.new(451)
	for stage in range(30):
		m.stage = stage; m.enemies.clear(); m.phase = "finished"
		check(m.outcome() == ("victory" if stage in [9,19,29] else "wave_clear"),"Only every tenth wave completes a level")
		check(m.level_number() == (stage/10+1) and m.level_wave() == stage%10+1,"Level display preserves internal wave identity")
	m = Run.new(451)
	for id in ["magician_hat","magic_sword","piggy_bank","fries","hamburger"]: m.acquire_relic(id)
	m.relics.items[1].charges = 2; m.relics.items[2]["savings"] = 23.4
	m.gain_souls(178); m.gain_blood_gems(444); m.grant_tarot("strength"); m.grant_tarot("world",-1,true)
	m.tarot_effects.banned = ["fool"]; m.reroll_progress = 10
	var campaign = Run.Campaign.new()
	var path: String = "user://test-campaign-%s.dat" % Time.get_ticks_usec()
	campaign.configure(path)
	check(not campaign.complete(m),"An unfinished level cannot create a checkpoint")
	finish_level(m)
	check(m.level_rewards_complete() and campaign.complete(m),"All field and reroll rewards settle before checkpoint")
	var saved: Dictionary = campaign.checkpoint.duplicate(true)
	m.hp = 1
	check(campaign.complete(m) and campaign.checkpoint == saved,"Duplicate success callbacks cannot replace saved build")
	var reopened = Run.Campaign.new(); reopened.configure(path)
	check(reopened.next_level() == 2 and reopened.checkpoint == saved,"Checkpoint survives file reload")
	var second = Run.new(9); reopened.start(second)
	check(second.stage == 10 and second.phase == "new" and second.hp == second.max_hp,"Next level starts at its first wave fully healed")
	check(second.character_level == saved.run.character_level and second.souls == saved.run.souls and second.blood_gems == saved.run.blood_gems,"Level XP and currency carry exactly")
	check(second.relics.items == saved.relics and second.relics.items[1].charges == 2,"Order, fused food, stored charges and savings survive")
	check(second.tarots.items == saved.tarots and second.tarots.next_instance == saved.next_tarot,"Tarot copies and IDs survive without replaying pickup gifts")
	check(second.tarot_effects.banned == ["fool"] and second.perfect_combo == 0 and second.shield == 0,"Permanent bans survive; combat effects reset")
	second.sell_relic(0); second.gain_souls(999); second.hp = 0
	reopened.start(second)
	check(second.stage == 10 and second.relics.items == saved.relics and second.character_level == saved.run.character_level,"Level-two defeat retries the entry build, not wave one or a farmed build")
	check(campaign.checkpoint == saved,"Restored nested inventories never mutate the original save")
	check_replayed_level(saved)
	finish_level(second,19); check(reopened.complete(second) and reopened.next_level() == 3,"Level two unlocks level three")
	reopened.start(second)
	check(second.stage == 20 and second.hp == second.max_hp,"Third level restores its entry build")
	var third_build = second.relics.items.duplicate(true)
	second.hp = 0; reopened.start(second)
	check(second.stage == 20 and second.relics.items == third_build,"Third-level defeat retries its entry build")
	finish_level(second,29); check(reopened.complete(second) and reopened.next_level() == 1,"Chapter completion clears the next-level checkpoint")
	reopened.start(second); check(second.stage == 0 and second.character_level == 1 and second.relics.items.is_empty(),"Start after all three levels begins a fresh chapter")
	DirAccess.remove_absolute(path)
	var session = Session.new(12)
	finish_level(session.model); session._settle()
	check(session.snapshot().phase == "level_complete" and "start" in session.snapshot().actions,"CLI pauses for Start after the first level")
	check(session.command({"action":"start"}).ok and session.model.stage == 10,"CLI and GUI share the continuation restore")
	for phone in [false,true]:
		var home = Home.new(); home.portrait = phone; home.campaign_path = ""; home.muted = true
		root.add_child(home); await process_frame
		home.campaign.checkpoint = saved.duplicate(true); home.campaign.cleared_level = 1
		await capture(home,"home-level2-"+str(phone))
		home.start_battle(); await process_frame
		check(home.battle.model.stage == 10 and home.battle.view_phase == "ready","Home Start opens level two in both layouts")
		check(home.battle.visual_stage == 10,"Restored battlefield has the correct world and character size")
		home.battle.model.hp = 0; home.battle._check_over()
		await capture(home.battle,"retry-level2-"+str(phone))
		home.battle._restart(); await process_frame
		check(home.battle.model.stage == 10 and home.battle.model.hp == home.battle.model.max_hp,"Retry button restores the level entry")
		finish_level(home.battle.model)
		home.battle.view_phase = "over"
		await capture(home.battle,"level1-complete-"+str(phone))
		home._return_home(); home.queue_free(); await process_frame
	print("Campaign levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
