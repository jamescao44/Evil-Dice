extends SceneTree
## Regression coverage for all current tarot rules against the six-die turn model.
const Run = preload("res://scripts/progression/run_rules.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Relics = preload("res://scripts/relics/relic_catalog.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh():
	var m = Run.new(604)
	m.enemies = [m.make_enemy(0),m.make_enemy(1),m.make_enemy(2)]
	for e in m.enemies: e.hp = 10000; e.max_hp = 10000; e.shield = 0
	m.begin_round()
	return m
func use(m, id: String, choice: Dictionary = {}) -> Dictionary:
	var card: Dictionary = m.tarots.add(id)
	var result: Dictionary = m.tarot_effects.cast(m,card.instance_id,choice)
	check(not result.has("error"),"Cast %s: %s" % [id,result.get("error","")])
	check(m.tarots.find_instance(card.instance_id) == -1,"Consume exactly the cast instance: "+id)
	return result
func roll(m, values: Array = [1,2,3,4,5,6], free: bool = false) -> void:
	check(not m.roll_pool(false,values,free).is_empty(),"Accept valid throw")
	m.resolve_perfect_relic()
	while not m.roll_attacks.is_empty(): m.resolve_roll_attack_step()
func finish(m) -> void:
	if m.phase == "enemy":
		for i in m.living():
			m.enemies[i].intent = {"type":"attack","target":-1,"amount":0}
			m.enemy_act(i)
	m.end_round()
func spend(m, indices: Array) -> void:
	for i in indices: m.dice_turn.select(i)
	check(not m.form_selected_skill().is_empty(),"Summon valid straight")
	m.apply_player(0)
func _initialize() -> void:
	check(Catalog.eligible().size() == 22 and Catalog.DISABLED.is_empty(),"All 22 cards enabled")
	check(Catalog.ITEMS.world.weight == 0.5,"World retains half weight")
	var m = fresh()
	var card: Dictionary = m.tarots.add("magician")
	check(m.tarot_effects.prepare(m,card.instance_id).has("error"),"Magician requires a throw")
	roll(m); m.dice_turn.selected = [0,1]
	check(m.tarot_effects.cast(m,card.instance_id,{"die":0,"face":1}).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"Unchanged face never consumes Magician")
	var hp: Array = m.enemies.map(func(e): return e.hp)
	var budget: int = m.dice_turn.rolls_left
	check(not m.tarot_effects.cast(m,card.instance_id,{"die":0,"face":6}).has("error"),"Magician edits a rolled unused die")
	check(m.dice_turn.values == [6,2,3,4,5,6] and m.dice_turn.selected.is_empty(),"Magician changes only the chosen die and clears stale selections")
	check(m.roll_attacks.is_empty() and m.enemies.map(func(e): return e.hp) == hp and m.dice_turn.rolls_left == budget,"Changing dice causes no new auto attack or budget cost")
	spend(m,[1,2,3])
	card = m.tarots.add("magician")
	check(m.tarot_effects.cast(m,card.instance_id,{"die":1,"face":6}).has("error"),"Spent die cannot be edited")
	m = fresh(); roll(m); spend(m,[0,1,2]); hp = m.enemies.map(func(e): return e.hp)
	use(m,"high_priestess"); use(m,"high_priestess")
	check(m.dice_turn.values == [1,2,3,6,6,6] and m.tarot_effects.dice_boost == 2,"Priestess stacks on unused dice and caps at six")
	check(m.enemies.map(func(e): return e.hp) == hp and m.roll_attacks.is_empty(),"Priestess does not retrigger matches")
	roll(m,[1,2,3]); check(m.dice_turn.values == [1,2,3,3,4,5],"Future throws receive the turn boost; locked faces stay unchanged")
	m._prepare_player_turn(); check(m.tarot_effects.dice_boost == 0,"New pool expires Priestess")
	roll(m); spend(m,[0,1,2]); var restored: Array = m.dice_turn.values.duplicate()
	use(m,"hermit")
	check(m.dice_turn.unused().size() == 6 and m.dice_turn.values == restored and m.dice_turn.rolls_left == 2,"Hermit restores spent faces without throwing or refunding rolls")
	check(m.roll_attacks.is_empty(),"Restoring dice does not attack")
	spend(m,[0,1,2]); check(m.dice_turn.committed.size() == 3,"Restored dice can immediately form another skill")
	m = fresh(); use(m,"lovers"); roll(m,[1,1,1,1,1,1])
	check(range(1,4).any(func(first): return range(first,first+4).all(func(face): return face in m.dice_turn.values)),"Lovers guarantees a four-or-longer straight")
	check(not m.tarot_effects.lovers,"Lovers consumed on accepted roll")
	m = fresh(); roll(m); spend(m,[0,1,2]); card = m.tarots.add("lovers")
	check(m.tarot_effects.cast(m,card.instance_id).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"Lovers requires four unused dice")
	for count in range(1,5):
		m = fresh()
		for i in range(count): use(m,"devil")
		roll(m,[1,1,1,1,1,1])
		check(m.dice_turn.values.count(6) == count+2 and m.tarot_effects.devil == 0,"Each Devil after the first adds one guaranteed six")
	for newer in ["lovers","devil"]:
		m = fresh(); use(m,"devil" if newer == "lovers" else "lovers"); use(m,newer)
		check((m.tarot_effects.devil == 3 and not m.tarot_effects.lovers) if newer == "devil" else (m.tarot_effects.lovers and m.tarot_effects.devil == 0),"Latest guaranteed roll rule wins")
	m = fresh(); use(m,"star")
	for i in range(4):
		roll(m,[1,2,3,4,5,6],true)
		check(m.dice_turn.last_perfect == (i < 3),"Star affects exactly three actual rolls")
	check(m.dice_turn.rolls_left == 3 and m.dice_turn.has_rolled(),"Free throws still record rolled state")
	use(m,"star"); m.tarot_effects.star_throws = 1; use(m,"star")
	check(m.tarot_effects.star_throws == 3,"Repeated Star refreshes three")
	m = fresh(); roll(m,[1,1,2,4,4,6]); use(m,"judgement")
	check(m.dice_turn.rolls_left == 4 and m.can_end_dice_turn(),"Judgement adds two rolls without losing rolled state")
	use(m,"justice"); budget = m.dice_turn.rolls_left
	roll(m,[1,2,3,4,5,6],true)
	check(m.dice_turn.rolls_left == budget,"Justice uses the free-roll pathway")
	card = m.tarots.add("judgement")
	check(m.tarot_effects.cast(m,card.instance_id).has("error"),"Judgement rejects playable unused straights")
	m = fresh(); roll(m,[1,2,3,4,4,6]); spend(m,[0,1,2]); use(m,"judgement")
	check(m.dice_turn.rolls_left == 4,"Judgement checks unused dice, not original straight")
	m = fresh(); m.hp = 20; roll(m); use(m,"temperance")
	check(m.tarot_effects.carried_rolls == 2 and m.dice_turn.rolls_left == 0,"Temperance transfers exactly the remaining budget")
	check(m.end_dice_turn(),"Temperance can finish the pool")
	m.apply_player(); check(m.hp == 41,"Temperance still heals leftover pips")
	finish(m); check(m.reroll_progress == 0,"Transferred rolls are not banked on the old turn")
	m.begin_round(); check(m.dice_turn.rolls_left == 5,"Next turn receives carried rolls")
	roll(m); m.end_dice_turn(); m.apply_player(); finish(m)
	check(m.reroll_progress == 4,"Unused carried rolls bank once at next turn end")
	m = fresh(); roll(m); use(m,"temperance"); m.stage += 1; m._prepare_player_turn()
	check(m.dice_turn.rolls_left == 3 and m.tarot_effects.carried_rolls == 0,"Carry never crosses waves")
	m = fresh(); m.apply_affliction(Status.FROZEN,1); m.apply_affliction(Status.BURNING,3); m.apply_affliction(Status.DARKNESS,2); m.statuses[Status.MIGHT].apply(3)
	m._prepare_player_turn(); use(m,"hierophant")
	check(m.phase == "roll" and m.dice_turn.active and m.ice_hits_remaining == 0,"Hierophant cures a frozen turn without skipping it")
	check(Status.HARMFUL.all(func(s): return m.status_count(s) == 0) and m.status_count(Status.MIGHT) == 3,"Cleanse removes harmful statuses while preserving buffs")
	m = fresh(); use(m,"chariot"); use(m,"chariot"); check(m.shield == 100,"Chariot adds exactly fifty shield per use")
	m = fresh(); m.shield = 500; m.statuses[Status.IMMUNITY].apply(2); m.acquire_relic("armor"); m.acquire_relic("bracelet"); m.perfect_combo = 10
	m.enemies[0] = m.make_enemy(3); m.enemies[0].hp = 10000; m.enemies[0].shield = 500
	m.enemies[1].elite = true; m.enemies[1].shield = 200
	use(m,"tower")
	check(m.enemies.all(func(e): return e.hp == 9950 and e.shield == 0),"Tower ignores shields, taunt, and damage multipliers")
	check(m.hp == 70 and m.shield == 500 and m.status_count(Status.IMMUNITY) == 2,"Tower takes exact self HP through defenses")
	check(m.enemy_status_count(0,Status.IMMOBILIZED) == 1 and m.enemy_status_count(1,Status.IMMOBILIZED) == 0,"Tower shield break stops normals but not elites")
	m = fresh(); m.enemies[0].hp = 10; use(m,"tower"); check(m.enemies[0].hp == 0,"Tower clamps overkill health")
	m = fresh(); use(m,"moon")
	for i in range(6): m._tick_enemy_statuses()
	check(m.enemies.all(func(e): return e.statuses[Status.DARKNESS].count == 1 and e.statuses[Status.DARKNESS].permanent),"Moon darkness persists")
	m.hp = 1; use(m,"sun"); check(m.hp == m.max_hp and m.living().all(func(i): return m.enemy_status_count(i,Status.BURNING) == 1),"Sun heals and burns")
	use(m,"death",{"target":0}); check(m.enemies[0].hp == 0,"Death executes selected target")
	m = fresh(); roll(m)
	for i in range(3): use(m,"strength")
	for i in range(3): m.dice_turn.select(i)
	m.form_selected_skill()
	check(is_equal_approx(m.attack_base(m.pending),72.0),"Three Strength add three extra Fireball bases")
	m.begin_player_cast(); check(m.tarot_effects.strength == 0 and m.pending.effect_multiplier == 4,"Strength locks and consumes once")
	m = fresh(); use(m,"hanged_man",{"ban":"sun"})
	for i in range(100): check("sun" not in Catalog.draw_choices(m.reward_rng,m.tarot_effects.banned),"Banned card absent")
	for id in Catalog.ITEMS:
		if id != "fool": m.tarot_effects.banned.append(id)
	use(m,"empress"); check(m.tarots.items.size() == 2 and m.tarots.items.all(func(c): return c.id == "fool"),"Empress respects bans and allows duplicates")
	m = fresh(); use(m,"world")
	check(Relics.ITEMS[m.relics.items[0].id].rarity == 3 and not Relics.ITEMS[m.relics.items[0].id].get("fusion",false),"World excludes fusion legends")
	for id in Relics.ITEMS:
		if Relics.ITEMS[id].rarity == 3 and not Relics.ITEMS[id].get("fusion",false): m.acquire_relic(id)
	card = m.tarots.add("world")
	check(m.tarot_effects.cast(m,card.instance_id).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"Exhausted World keeps card")
	m = fresh()
	for id in ["heart","bracelet","armor","coin","magic_shield","magic_sword","runestone","lucky_die","bloodstone","twin_scythes"]: m.acquire_relic(id)
	card = m.tarots.add("emperor")
	var setup: Dictionary = m.tarot_effects.prepare(m,card.instance_id)
	var state: int = m.reward_rng.state
	check(setup.get("choice","") == "replace" and m.tarot_effects.prepare(m,card.instance_id) == setup and state == m.reward_rng.state,"Full-inventory offer is locked across cancellation")
	check(m.tarot_effects.cast(m,card.instance_id).has("error") and m.tarots.find_instance(card.instance_id) >= 0,"Cancel keeps Emperor")
	check(not m.tarot_effects.cast(m,card.instance_id,{"replace":4}).has("error") and m.relics.items[4].id == setup.relic,"Confirmed replacement consumes Emperor")
	var owned: Array = m.relics.items.map(func(item): return item.id)
	use(m,"fool"); check(m.relics.items.size() == 10 and m.relics.items.all(func(item): return item.id not in owned),"Fool excludes all former relics")
	m = fresh(); var counts: Dictionary = {}
	for i in range(5000):
		card = m.tarots.add("emperor")
		m.tarot_effects.prepare(m,card.instance_id)
		var id: String = m.tarot_effects.locked_grants[card.instance_id]
		counts[id] = counts.get(id,0)+1
		m.tarot_effects.locked_grants.erase(card.instance_id); m.tarots.remove_instance(card.instance_id)
	check(counts.keys().all(func(id): return id not in Relics.DISABLED and not Relics.ITEMS[id].get("fusion",false)),"Emperor eligibility excludes disabled/fusion items")
	check(counts.values().min() > 70 and counts.values().max() < 190,"Emperor is uniform by item rather than rarity")
	m = fresh(); var wins := 0; var rares := 0
	for i in range(4000):
		card = m.tarots.add("wheel"); m.tarot_effects.cast(m,card.instance_id)
		if not m.tarot_effects.bonus_chests.is_empty():
			wins += 1
			if m.tarot_effects.bonus_chests[0] == 2: rares += 1
			m.tarot_effects.bonus_chests.clear()
	check(wins > 850 and wins < 1150 and rares > 65 and rares < 140,"Wheel keeps 25% chest and conditional 10% upgrade")
	print("Tarot effects: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
