extends SceneTree
const Run = preload("res://scripts/run_rules.gd")
const Odds = preload("res://scripts/dice_odds.gd")
const Effects = preload("res://scripts/relic_effects.gd")
const Catalog = preload("res://scripts/relic_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual-expected) < 0.000000001,label+" (%s / %s)" % [actual,expected])

func _initialize() -> void:
	var odds = Odds.new()
	var triples: Array = [1,1,1,1,1,0.7]
	var pairs: Array = [1,1,1,1,1,1]
	var faces: Array = [1,1,1,1,1,1]
	var normal := {"normal":1.0,"pair":0.0,"triple":0.0}
	var pair := {"normal":0.0,"pair":1.0,"triple":0.0}
	var triple := {"normal":0.0,"pair":0.0,"triple":1.0}
	near(odds.six_probability(normal,triples,pairs,faces),0.5,"Distinct rolls contain six half the time")
	near(odds.six_probability(pair,triples,pairs,faces),1.0/3,"Pair odds include paired and spare sixes")
	near(odds.six_probability(triple,triples,pairs,faces),0.7/5.7,"Conditional odds retain 64-bit precision")
	triples[5] = 5
	near(odds.six_probability(triple,triples,pairs,faces),0.5,"In-place weight changes invalidate cached odds")
	var zero: Array = [0,0,0,0,0,0]
	near(odds.six_probability(normal,zero,zero,zero),0.5,"Exhausted distinct weights fall back to uniform remaining faces")
	near(odds.six_probability(pair,zero,zero,zero),1.0/3,"Exhausted pair weights match deterministic spare fallback")
	near(odds.six_probability(triple,zero,zero,zero),1.0/6,"Exhausted triple weights fall back to uniform")
	near(odds.six_probability(normal,zero,zero,[0.1,0.2,0,0,0,0]),0.25,"Partially exhausted decimal weights do not invent a residual weight")
	near(odds.six_probability(normal,zero,zero,[-1,-2,-3,-4,-5,1]),1.0,"Negative weights are excluded, matching the roller")
	near(odds.six_probability(normal,[1,1,1,1,1,0],[1,1,1,1,1,0],[1,1,1,1,1,0]),0,"Changed weights cannot reuse stale six probabilities")
	for id in Effects.STATS: check(Catalog.ITEMS.has(id),"Passive relic definition has catalog metadata: "+id)
	for id in Catalog.STONES: check(Effects.STONES.has(id),"Every fusion component has shared effect rules: "+id)
	var invalid = Run.new(104)
	invalid.begin_round()
	for id in ["lucky_die","cursed_die","cursed_watch"]: invalid.acquire_relic(id)
	var before_invalid: int = invalid.rng.state
	for values in [[],[6],[6,6],[0,1,2],[1,2,7],[1,2,"six"]]:
		check(invalid.set_test_roll(values).is_empty() and invalid.phase == "roll" and invalid.rng.state == before_invalid,"Invalid debug input cannot mutate relics or consume randomness")
	var model = Run.new(98)
	model.load_debug_wave(9)
	model.begin_round()
	model.acquire_relic("magic_sword")
	model.relics.items[0].charges = 1
	model.acquire_relic("codex_page")
	model.acquire_relic("cursed_skull")
	model.acquire_relic("cursed_bow")
	model.acquire_relic("twin_scythes")
	var random_state: int = model.rng.state
	for values in [[1,2,6],[1,1,2],[4,4,6],[5,5,1],[4,4,4],[5,5,5]]:
		var skill = model.classify(values)
		var before: Array = model.enemies.duplicate(true)
		for i in range(10):
			check(not model.damage_caption(skill,i).is_empty(),"Targeted preview remains available")
			var hits: Array = model.preview(skill,i)
			check(hits[0].damage == model.attack_damage(skill,hits[0].target),"Preview and combat share the numeric damage path")
		check(model.enemies == before and model.rng.state == random_state and model.relics.items[0].charges == 1,"Preview never mutates enemies, charges or combat randomness")
	print("Extension points: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
