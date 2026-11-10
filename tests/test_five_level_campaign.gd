extends SceneTree
## Added levels preserve seeded boss choices, shared progression and the slower economy.
const Run = preload("res://scripts/progression/run_rules.gd")
const Waves = Run.Waves
const Enemy = Run.EnemyCatalog
const Stock = Run.ShopStock
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

## Every possible random finale is a real two-phase boss with the authored level.
func roster_checks() -> void:
	check(Run.PLAYABLE_WAVES == 48 and Waves.SQUADS.size() == 48 and Run.Campaign.LEVEL_COUNT == 6,"Six complete eight-wave levels")
	check(Run.WAVE_NAMES.size() == Waves.COUNT and Waves.CITY_STAGE == 48,"Names, debug bounds and dormant city stay aligned")
	for stage in range(24,Run.PLAYABLE_WAVES):
		check(Waves.is_boss_stage(stage) == ((stage+1)%8 == 0),"Only the eighth battle is a boss")
		check(Waves.has_shop_after(stage) == (stage%8+1 in [3,6]),"New levels retain both fixed shop stops")
		check(Waves.display_stage(stage) == 11,"Extended campaign retains the capped scenery")
	for stage in [31,39,47]:
		var counts := {}
		for seed_value in range(600):
			var first := RandomNumberGenerator.new(); first.seed = seed_value
			var second := RandomNumberGenerator.new(); second.seed = seed_value
			var enemies: Array = Waves.create(stage,first)
			var boss: Dictionary = enemies[0]
			check(enemies == Waves.create(stage,second),"Seeded replay locks role, stats and RNG")
			check(enemies.size() == 1 and boss.boss and boss.boss_phase == 1 and boss.role in Waves.RANDOM_BOSSES,"Random finale contains exactly one eligible boss")
			check(boss.level == (26 if stage == 31 else 32) and Enemy.phase_health(boss,2) > 0,"Random bosses retain level-scaled second phases")
			if boss.role == Enemy.Role.COMMANDER: check(boss.reinforcement_level == 1,"Random Commander keeps LV.1 guards")
			counts[boss.role] = counts.get(boss.role,0)+1
			var state: int = first.state
			check(Waves.map_marker(stage).art == "crown" and first.state == state,"Map previews cannot reroll or reveal the undecided boss")
		check(counts.size() == 3 and counts.values().all(func(n): return absf(n/600.0-1.0/3.0) < 0.06),"Boss choices are approximately uniform across seeds")
	for stage in [-1,0,7,9,39,47,48,"24"]:
		check(not Run.Campaign.valid({"stage":stage}),"Invalid checkpoint boundaries remain rejected")

## Ordinary waves follow chapter pressure; fixed boss budgets stay outside this pass.
func progression_checks() -> void:
	var m = Run.new(1)
	var previous := 1
	for stage in range(Run.PLAYABLE_WAVES):
		if stage%8 == 0: previous = 1
		var expected: int = Waves.reference_enemy_level(stage,m.character_level,previous)
		var xp := 0.0
		for entry in Waves.SQUADS[stage].units:
			check(entry.level == expected,"Sequential XP produces the intended fixed wave level")
			var roles: Array = entry.get("random_roles",[entry.role])
			var per_entry := 0.0
			for role in roles:
				per_entry += Enemy.soul_reward(Enemy.make(role,entry.level,entry.get("elite",false)))
				if role == Enemy.Role.COMMANDER: per_entry += 2*Enemy.soul_reward(Enemy.make(Enemy.Role.PALADIN,entry.reinforcement_level))
			xp += roundi(per_entry/roles.size())
		previous = expected
		m.gain_souls(int(xp))
	check(m.character_level == 29 and m.souls == 220,"Mean kill-only XP reaches the expected final level")

## Shared payout logic halves chest gems without changing route gems or salvage values.
func economy_checks() -> void:
	check(Run.Chests.CRYSTALS == [15,25,35,50],"All four relic-chest payouts are halved")
	for tier in range(4):
		var m = Run.new(812+tier)
		m.open_debug_chest(tier)
		var total := 0
		for reveal in range(tier+1): total += m.release_chest_crystals(reveal)
		check(total == [15,25,35,50][tier] and m.blood_gems == total,"Upgrade reveals pay only their incremental share")
		check(m.release_chest_crystals() == 0,"Repeated reveal never grants gems twice")
	var starting := [58.0,30.0,10.0,1.0,1.0]
	check(Stock.rarity_weights(3) == starting,"First shop keeps its initial rarity distribution")
	for wave in [4,6,11,19,27,35,38,40]:
		var rates: Array = Stock.rarity_weights(wave)
		check(is_equal_approx(rates.reduce(func(sum,value): return sum+value,0.0),100.0),"Slower rarity weights remain normalized")
		for i in range(5): check(is_equal_approx(rates[i],20+(starting[i]-20)*pow(0.98,wave-3)),"Shop rarity closes only 2 percent of the gap per wave")
	check(Stock.REFRESH_PRICE == 50,"Merchandise surcharge does not change refresh entry cost")
	var shop = Stock.new()
	for seed_value in range(100):
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		var baseline := RandomNumberGenerator.new(); baseline.seed = seed_value
		for limits in Stock.PRICE_RANGES+[Stock.TAROT_PRICE,Stock.BOTTLE_PRICE]:
			check(shop._price(rng,limits) == baseline.randi_range(limits.x,limits.y)+100,"All paid merchandise rises by exactly 100 with identical price rolls")

func _initialize() -> void:
	roster_checks(); progression_checks(); economy_checks()
	print("Chapter campaign: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
