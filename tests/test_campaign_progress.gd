extends SceneTree
## Verify eight-wave boundaries, persisted entry builds, retry isolation and real home controls.
const Run = preload("res://scripts/progression/run_rules.gd")
const Session = preload("res://scripts/testing/playtest_session.gd")
const Home = preload("res://scripts/home/home.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Clear only fixture enemies; reward claims still use their actual transactions.
func finish_level(m, stage: int = 7) -> void:
	m.stage = stage; m.enemies.clear(); m.pending = m.Skill.new(); m.phase = "finished"; m.wave_kind = "relic"
	m.wave_chest_stage = -1; m.wave_reward_resolved = true
	m.begin_wave_reward(); m.open_wave_chest(); m.discard_unclaimed_rewards(); m.close_chest(); m.finish_wave_reward()

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

## Both partial and ready treasure survive every level checkpoint, including a restart.
func check_treasure_continuation() -> void:
	for level in range(1,Run.Campaign.LEVEL_COUNT):
		for progress in [7,Run.Chests.REROLL_COST]:
			var m = Run.new(740+level)
			m.reroll_progress = progress
			finish_level(m,level*Run.Campaign.WAVES_PER_LEVEL-1)
			var pity: Array = m.chest_pity.misses.duplicate()
			var reward_state: int = m.reward_rng.state
			var campaign = Run.Campaign.new()
			var path := "user://test-treasure-continuation-%s.dat" % Time.get_ticks_usec()
			campaign.configure(path)
			check(m.level_rewards_complete() and campaign.complete(m),"Unopened treasure does not block next level")
			check(m.reroll_progress == progress and m.open_rewards.is_empty(),"Completing a level does not roll or consume treasure")
			check(m.chest_pity.misses == pity and m.reward_rng.state == reward_state,"Saving unopened treasure does not spend pity or reward RNG")
			var reopened = Run.Campaign.new(); reopened.configure(path)
			reopened.start(m)
			check(m.stage == level*Run.Campaign.WAVES_PER_LEVEL and m.reroll_progress == progress,"Saved treasure survives relaunch at every level boundary")
			if progress == Run.Chests.REROLL_COST:
				check(not m.open_chest(Run.Chests.REROLL_TIER).is_empty() and m.reroll_progress == 0,"Carried ready treasure opens when explicitly claimed")
				m.discard_unclaimed_rewards(); m.close_chest()
				check(m.open_chest(Run.Chests.REROLL_TIER).is_empty(),"Carried treasure can only be spent once")
			DirAccess.remove_absolute(path)
	for progress in [7,Run.Chests.REROLL_COST]:
		var session = Session.new(912)
		session.model.reroll_progress = progress
		finish_level(session.model)
		session._settle()
		check(session.snapshot().phase == "level_complete" and session.model.open_rewards.is_empty(),"CLI settlement never auto-opens victory treasure")
		check(session.command({"action":"start"}).ok and session.model.reroll_progress == progress,"CLI carries treasure into the next level")
		session.close()

func run() -> void:
	check_treasure_continuation()
	var m = Run.new(451)
	for stage in range(Run.PLAYABLE_WAVES):
		m.stage = stage; m.enemies.clear(); m.phase = "finished"
		check(m.outcome() == ("victory" if (stage+1)%Run.Campaign.WAVES_PER_LEVEL == 0 else "wave_clear"),"Only every eighth wave completes a level")
		check(m.level_number() == (stage/8+1) and m.level_wave() == stage%8+1,"Level display preserves internal wave identity")
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
	check(m.level_rewards_complete() and campaign.complete(m),"Field rewards settle without requiring reroll treasure claims")
	var saved: Dictionary = campaign.checkpoint.duplicate(true)
	m.hp = 1
	check(campaign.complete(m) and campaign.checkpoint == saved,"Duplicate success callbacks cannot replace saved build")
	var legacy: Dictionary = saved.duplicate(true); legacy.stage = 10
	var legacy_path: String = path+"-legacy"
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_var({"version":1,"checkpoint":legacy,"cleared_level":1}); legacy_file.close()
	var migrated = Run.Campaign.new(); migrated.configure(legacy_path)
	check(migrated.checkpoint.stage == 8 and migrated.checkpoint.relics == saved.relics and migrated.checkpoint.tarots == saved.tarots,"Legacy ten-wave checkpoint retains owned relics and tarots at the new boundary")
	DirAccess.remove_absolute(legacy_path)
	var reopened = Run.Campaign.new(); reopened.configure(path)
	check(reopened.next_level() == 2 and reopened.checkpoint == saved,"Checkpoint survives file reload")
	var second = Run.new(9); reopened.start(second)
	check(second.stage == 8 and second.phase == "new" and second.hp == second.max_hp,"Next level starts at its first wave fully healed")
	check(second.reroll_progress == 10,"Partial reroll treasure survives saving and next-level restoration")
	check(second.character_level == saved.run.character_level and second.souls == saved.run.souls and second.blood_gems == saved.run.blood_gems,"Level XP and currency carry exactly")
	check(second.relics.items == saved.relics and second.relics.items[1].charges == 2,"Order, fused food, stored charges and savings survive")
	check(second.tarots.items == saved.tarots and second.tarots.next_instance == saved.next_tarot,"Tarot copies and IDs survive without replaying pickup gifts")
	check(second.tarot_effects.banned == ["fool"] and second.perfect_combo == 0 and second.shield == 0,"Permanent bans survive; combat effects reset")
	second.sell_relic(0); second.gain_souls(999); second.hp = 0
	reopened.start(second)
	check(second.stage == 8 and second.relics.items == saved.relics and second.character_level == saved.run.character_level,"Level-two defeat retries the entry build, not wave one or a farmed build")
	check(campaign.checkpoint == saved,"Restored nested inventories never mutate the original save")
	check_replayed_level(saved)
	var restart_save = Run.Campaign.new(); restart_save.configure(path)
	restart_save.restart()
	var fresh_save = Run.Campaign.new(); fresh_save.configure(path)
	check(fresh_save.next_level() == 1 and fresh_save.cleared_level == 0 and fresh_save.checkpoint.is_empty(),"Restart erases the checkpoint across app relaunches")
	var fresh = Run.new(901)
	fresh.chest_pity.misses = [1,2,3]
	fresh_save.start(fresh)
	check(fresh.stage == 0 and fresh.character_level == 1 and fresh.blood_gems == 0 and fresh.souls == 0,"Restart begins level one with starting stats and currencies")
	check(fresh.relics.items.is_empty() and fresh.tarots.items.is_empty() and fresh.gemstones.bag.is_empty(),"Restart carries no relics, tarots or gemstones")
	check(fresh.chest_pity.misses == [1,2,3],"Restart leaves persistent chest pity intact")
	finish_level(second,15); check(reopened.complete(second) and reopened.next_level() == 3,"Level two unlocks level three")
	reopened.start(second)
	check(second.stage == 16 and second.hp == second.max_hp,"Third level restores its entry build")
	var third_build = second.relics.items.duplicate(true)
	second.hp = 0; reopened.start(second)
	check(second.stage == 16 and second.relics.items == third_build,"Third-level defeat retries its entry build")
	for completed in range(3,Run.Campaign.LEVEL_COUNT):
		var build: Array = second.relics.items.duplicate(true)
		var cards: Array = second.tarots.items.duplicate(true)
		finish_level(second,completed*8-1)
		check(reopened.complete(second) and reopened.next_level() == completed+1,"New level unlocks after the preceding boss reward")
		var reloaded = Run.Campaign.new(); reloaded.configure(path)
		check(reloaded.next_level() == completed+1 and Run.Campaign.valid(reloaded.checkpoint),"New level checkpoint survives app restart")
		reloaded.start(second)
		check(second.stage == completed*8 and second.relics.items == build and second.tarots.items == cards,"New levels retain the exact inventory and tarots")
		second.hp = 0; reloaded.start(second)
		check(second.stage == completed*8 and second.hp == second.max_hp,"New level defeat retries its own entry build")
	finish_level(second,Run.PLAYABLE_WAVES-1); check(reopened.complete(second) and reopened.next_level() == 1,"Chapter completion clears the next-level checkpoint")
	reopened.start(second); check(second.stage == 0 and second.character_level == 1 and second.relics.items.is_empty(),"Start after all chapter levels begins a fresh chapter")
	DirAccess.remove_absolute(path)
	var session = Session.new(12)
	finish_level(session.model); session._settle()
	check(session.snapshot().phase == "level_complete" and "start" in session.snapshot().actions,"CLI pauses for Start after the first level")
	check(session.command({"action":"start"}).ok and session.model.stage == 8,"CLI and GUI share the continuation restore")
	for signal_info in session.model.get_signal_list():
		for connection in session.model.get_signal_connection_list(signal_info.name): session.model.disconnect(signal_info.name,connection.callable)
	for phone in [false,true]:
		var home = Home.new(); home.portrait = phone; home.campaign_path = ""; home.muted = true
		root.add_child(home); await process_frame
		home.campaign.checkpoint = saved.duplicate(true); home.campaign.cleared_level = 1
		await capture(home,"home-level2-"+str(phone))
		home.start_battle(); await process_frame
		home.battle.model.chest_pity.save_path = ""
		check(home.battle.model.stage == 8 and home.battle.view_phase == "entering" and home.battle.evolution.entrance.active(),"Home Start opens level two with its entrance in both layouts")
		check(home.battle.visual_stage == 8,"Restored battlefield has the correct world and character size")
		home.battle.evolution.reset()
		home.battle.model.reroll_progress = Run.Chests.REROLL_COST
		finish_level(home.battle.model,15)
		home.battle._check_over()
		await process_frame
		check(home.battle.view_phase == "over" and not home.battle.chest.visible and home.battle.model.open_rewards.is_empty(),"Victory UI stays open without auto-opening treasure")
		check(home.campaign.checkpoint.run.reroll_progress == Run.Chests.REROLL_COST,"Victory checkpoint preserves a ready chest")
		check(not home.battle._can_claim_chest(),"Victory overlay cannot consume the saved treasure through hidden controls")
		home.battle._handle_click(home.battle.REPLAY_RECT.get_center())
		await process_frame
		check(home.battle.model.stage == 16 and home.battle.treasure_pickup.displayed_progress() == Run.Chests.REROLL_COST,"Next Level restores the full treasure meter in both layouts")
		home.battle.evolution.reset(); home.battle.view_phase = "ready"
		check(home.battle._can_claim_chest(),"Carried treasure is manually claimable after the next entrance")
		home.campaign.checkpoint = saved.duplicate(true); home.campaign.cleared_level = 1
		home.battle.model.hp = 0; home.battle._check_over()
		await capture(home.battle,"retry-level2-"+str(phone))
		home.battle._restart(); await process_frame
		check(home.battle.model.stage == 8 and home.battle.model.hp == home.battle.model.max_hp,"Retry button restores the level entry")
		finish_level(home.battle.model)
		home.battle.view_phase = "over"
		await capture(home.battle,"level1-complete-"+str(phone))
		home._return_home(); await process_frame
		home.campaign.checkpoint = saved.duplicate(true); home.campaign.cleared_level = 1
		check(not home.play_rect().intersects(home.restart_rect()) and Rect2(Vector2.ZERO,home.canvas_size()).encloses(home.restart_rect()),"Restart is a distinct on-screen touch target")
		for locale in GameText.LANGUAGES:
			GameText.set_language(locale,false)
			check(home.pixel_font.get_string_size(GameText.text("FROM LEVEL 1"),HORIZONTAL_ALIGNMENT_LEFT,-1,22 if phone else 18).x < home.restart_rect().size.x-16,"Restart label fits in "+locale)
			await capture(home,"home-restart-"+str(phone)+"-"+locale)
		home._press(home.restart_rect().get_center()); home._release(home.restart_rect().get_center())
		await process_frame
		check(home.battle.model.stage == 0 and home.battle.model.character_level == 1 and home.battle.model.relics.items.is_empty() and home.battle.model.tarots.items.is_empty(),"Home restart tap starts a fresh level one instead of continuing")
		check(home.campaign.next_level() == 1 and home.campaign.checkpoint.is_empty(),"Home restart resets the shared continuation owner")
		home._return_home(); home.queue_free(); await process_frame
	print("Campaign levels: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
