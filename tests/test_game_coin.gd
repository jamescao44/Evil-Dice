extends SceneTree
## Game Coin pays its catalog amount once per cleared wave, with ordered copies.
const Run = preload("res://scripts/progression/run_rules.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	for ids in [["coin"],["coin","disguise_mask"],["coin","soul_vessel"]]:
		var m = Run.new(811)
		for id in ids: check(m.acquire_relic(id),"Acquire coin test equipment")
		m.wave_kind = m.WaveRewards.RELIC
		for enemy in m.enemies: enemy.hp = 0
		var expected: int = 134 if "disguise_mask" in ids else 67
		check(m.begin_wave_reward() and m.blood_gems == expected,"Wave completion pays 67 per activated Coin")
		m.begin_wave_reward()
		check(m.blood_gems == expected,"Reopening the same reward cannot duplicate Coin payout")
	GameText.initialize()
	for language in ["en","zh_CN"]:
		GameText.set_language(language,false)
		check(GameText.text(Run.Relics.Catalog.ITEMS.coin.text).contains("67"),"Both language descriptions show 67")
	print("Game Coin: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
