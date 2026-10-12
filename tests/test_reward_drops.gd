extends SceneTree
const Drops = preload("res://scripts/relic_drop_table.gd")
const Relics = preload("res://scripts/relic_catalog.gd")
const Rewards = preload("res://scripts/reward_catalog.gd")
const Inventory = preload("res://scripts/relic_inventory.gd")
const Run = preload("res://scripts/run_rules.gd")
const Chest = preload("res://scripts/reward_chest.gd")
const SAMPLES := 20000
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frequency(actual: int, samples: int, probability: float, label: String) -> void:
	var expected: float = samples*probability
	check(absf(actual-expected) <= 6*sqrt(expected*(1-probability))+3,label)

func _initialize() -> void: call_deferred("run")

func distribution_checks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 608
	var all: Array = Relics.ITEMS.keys().filter(func(id): return not Relics.ITEMS[id].get("fusion",false))
	var one_per_tier: Array = []
	for tier in range(5): one_per_tier.append(all.filter(func(id): return Relics.ITEMS[id].rarity == tier)[0])
	for eligible in [all,one_per_tier]:
		var rarities := [0,0,0,0,0]
		var item_counts: Dictionary = {}
		for n in range(SAMPLES):
			var id: String = Drops.draw(rng,eligible)
			rarities[Relics.ITEMS[id].rarity] += 1
			item_counts[id] = item_counts.get(id,0)+1
		for tier in range(5): frequency(rarities[tier],SAMPLES,Relics.RARITY_WEIGHTS[tier]/100,"Rarity probability is independent of item count")
		for id in eligible:
			var tier: int = Relics.ITEMS[id].rarity
			var members: int = eligible.filter(func(other): return Relics.ITEMS[other].rarity == tier).size()
			frequency(item_counts.get(id,0),SAMPLES,Relics.RARITY_WEIGHTS[tier]/100/members,"Uniform selection within rarity: " + id)
	var inventory = Inventory.new()
	for id in all:
		if Relics.ITEMS[id].rarity == Relics.Rarity.LEGENDARY: inventory.add(id)
	var exhausted := [0,0,0,0,0]
	for n in range(SAMPLES): exhausted[Relics.ITEMS[inventory.draw_one(rng)].rarity] += 1
	check(exhausted[3] == 0,"All owned legendary relics are excluded")
	for tier in [0,1,2,4]: frequency(exhausted[tier],SAMPLES,Relics.RARITY_WEIGHTS[tier]/(100-Relics.RARITY_WEIGHTS[3]),"Empty rarity redistributes proportionally")
	check(inventory.draw_one(rng,all).is_empty(),"Fully excluded pools return no relic")
	check(Drops.draw(rng,["ancient_codex","prismatic_stone"]).is_empty(),"Fusion-only entries cannot enter reward rolls")

func chest_distribution_checks() -> void:
	var model = Run.new(890)
	var categories := [0,0,0,0,0,0,0,0]
	var rarities := [0,0,0,0,0]
	for n in range(SAMPLES):
		model.perfect_progress = 3
		model.open_chest()
		var gift: Dictionary = model.reward_item(0)
		if gift.id == "tarot": categories[Rewards.Category.RELIC] += 1
		elif gift.has("relic_id"):
			categories[Rewards.Category.RELIC] += 1
			rarities[Relics.ITEMS[gift.relic_id].rarity] += 1
		else: categories[model.open_rewards[0]] += 1
		model.claim_reward(0,-1,true)
		model.close_chest()
	for category in [0,1,3,4,5,6]:
		frequency(categories[category],SAMPLES,Rewards.DEFAULT_WEIGHTS[category]/4,"Chest category probability stays independent of catalog size")
	for retired in Rewards.RETIRED_CATEGORIES:
		check(categories[retired] == 0,"Removed category never drops")
		var forced: Array = [0,0,0,0,0,0,0]
		forced[retired] = 1
		for i in range(100): check(Rewards.draw_category(model.reward_rng,forced) not in Rewards.RETIRED_CATEGORIES,"Custom weights cannot restore removed rewards")
	check(rarities == [0,0,0,0,0],"A common chest substitutes its only relic slot with a tarot draw")
	for weights in [[0,1,0,0,0,0,0],[0,0,1,0,0,0,0]]:
		model.reward_weights = weights
		var counts := [0,0,0,0,0]
		for n in range(SAMPLES):
			model.perfect_progress = 6
			model.open_chest()
			counts[Relics.ITEMS[model.reward_item(1).relic_id].rarity] += 1
			model.discard_unclaimed_rewards()
			model.close_chest()
		for tier in range(5): frequency(counts[tier],SAMPLES,Relics.RARITY_WEIGHTS[tier]/100,"Legacy cursed category cannot bypass the shared rarity roll")

func presentation_checks() -> void:
	var chest = Chest.new()
	root.add_child(chest)
	chest.set_process(false)
	chest.cosmetic.seed = 331
	chest.start([Rewards.Category.RUBY,Rewards.Category.SHARD,Rewards.Category.TAROT],Vector2(1280,800),null)
	for sequence in chest.sequences:
		var rolling: Array = sequence.slice(0,chest.reel_steps)
		for category in [Rewards.Category.RUBY,Rewards.Category.SHARD,Rewards.Category.TAROT]:
			check(category in rolling,"Every reel shows currency and tarot regardless of the winning category")
		for id in Relics.ITEMS:
			check((chest.relic_symbols[id] in rolling) == not Relics.ITEMS[id].get("fusion",false),"Every directly obtainable relic appears; fusion-only relics stay out")
		for index in sequence:
			check(chest.symbols[index].id not in ["damage","multiplier","potion"] and index not in [Rewards.Category.RELIC,Rewards.Category.CURSE],"Reels show real rewards without retired items or generic relic placeholders")
	chest.cosmetic.seed = 207
	chest.start([Rewards.Category.RUBY],Vector2(1280,800),null)
	var ruby_sequence: Array = chest.sequences[0].duplicate()
	chest.cosmetic.seed = 207
	chest.start([Rewards.Category.TAROT],Vector2(1280,800),null)
	for i in range(ruby_sequence.size()):
		if i != chest.reel_steps: check(ruby_sequence[i] == chest.sequences[0][i],"Changing the reward changes only the final landing symbol, never the filler")
	var model = Run.new(889)
	model.perfect_progress = 9
	model.reward_weights = [0,1,0,0,0,0,0]
	var outcomes: Array = model.open_chest()
	var prizes: Array = []
	for slot in range(outcomes.size()): prizes.append(model.reward_item(slot))
	var locked: Array = prizes.duplicate(true)
	var reward_state: int = model.reward_rng.state
	var combat_state: int = model.rng.state
	var first_sequence: Array = []
	for reduced in [false,true]:
		chest.start(outcomes,Vector2(1280,800),null,reduced,prizes)
		if first_sequence.is_empty(): first_sequence = chest.sequences.duplicate(true)
		else: check(first_sequence != chest.sequences,"Cosmetic replay can change its filler without rerolling results")
		chest.playback_speed = 0.5 if reduced else 10
		for i in range(12): chest._process(2)
		check(not chest.active and model.claimed_slots.is_empty(),"Animation ends without granting any prize")
		for slot in range(outcomes.size()):
			var symbol: Dictionary = chest.symbols[chest.sequences[slot][chest.reel_steps]]
			check(symbol.get("relic_id","") == locked[slot].get("relic_id","") and symbol.id == locked[slot].id and model.reward_item(slot) == locked[slot],"Every reel ends on the concrete reward chosen before animation")
		check(model.reward_rng.state == reward_state and model.rng.state == combat_state,"Animation and speed consume neither reward nor combat RNG")
	check(model.open_chest() == outcomes and model.reward_rng.state == reward_state,"Reopening a pending chest cannot reroll")
	for slot in range(outcomes.size()-1,-1,-1):
		if locked[slot].id == "tarot":
			model.begin_tarot_reward("chest",slot)
			check(not model.choose_tarot(0).is_empty(),"Reverse pickup order also collects a locked tarot draw")
		else:
			check(model.claim_reward(slot).relic_id == locked[slot].relic_id,"Reverse pickup order grants the preselected relic")
	check(model.reward_rng.state == reward_state and model.rng.state == combat_state,"Collecting rewards never rolls them again")
	check(model.close_chest(),"All locked rewards are collectible")
	chest.free()

func run() -> void:
	distribution_checks()
	chest_distribution_checks()
	presentation_checks()
	print("Reward rarity and locked presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
