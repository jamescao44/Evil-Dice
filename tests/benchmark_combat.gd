extends SceneTree
## Run before/after model changes. Timings are diagnostic, never pass/fail limits.
const Run = preload("res://scripts/run_rules.gd")
const Status = preload("res://scripts/status_effect.gd")
const ITERATIONS := 5000

func _initialize() -> void:
	var model = Run.new(605)
	model.load_debug_wave(9)
	for id in ["codex_page","ancient_codex","bracelet","mithril_blade","magic_sword","cursed_skull","cursed_bow","reaper_scythe","prismatic_stone","runestone"]:
		model.acquire_relic(id)
	var skill = model.classify([4,4,6])
	var rates: Dictionary = model.roll_rates(0.8)
	var timings: Dictionary = {}
	var checksum: float = 0
	var start: int = Time.get_ticks_usec()
	for i in range(ITERATIONS): checksum += model._six_probability(rates)
	timings.six_chance_ms = (Time.get_ticks_usec()-start)/1000.0
	start = Time.get_ticks_usec()
	for i in range(ITERATIONS): checksum += model.damage_caption(skill).length()
	timings.damage_preview_ms = (Time.get_ticks_usec()-start)/1000.0
	for i in range(model.enemies.size()):
		model.enemies[i].hp = 1000000
		model.enemies[i].max_hp = 1000000
	start = Time.get_ticks_usec()
	for i in range(ITERATIONS): model._attack_relic_effects(i%10,10,skill)
	timings.on_hit_ms = (Time.get_ticks_usec()-start)/1000.0
	timings.checksum = checksum
	timings.iterations = ITERATIONS
	print(JSON.stringify(timings))
	quit()
