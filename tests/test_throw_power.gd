extends SceneTree
const Driver = preload("res://tests/scene_driver.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const Meter = preload("res://scripts/throw_meter.gd")
const Battle = preload("res://scripts/battle.gd")
const Portrait = preload("res://scripts/battle_portrait.gd")
var failures := 0
var checks := 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 8000
	while game.view_phase not in ["ready", "over"] and Time.get_ticks_msec() < deadline:
		Driver.cast_pending(game)
		await process_frame
	check(Time.get_ticks_msec() < deadline, "Throw settles")

func timing_checks() -> void:
	var meter := Meter.new()
	for expected in [0.0, 0.5, 1.0, 0.5, 0.0]:
		check(is_equal_approx(meter.position_ratio(), expected), "Meter traverses both ends and center")
		meter.advance(Meter.PERIOD / 4)
	for sign_value in [-1, 1]:
		var edge: Dictionary = Meter.sample_at(0.5 + sign_value * 2.0 / Meter.WIDTH)
		check(edge.perfect and edge.position == 0.5, "Both +/-2 pixel edges qualify and snap to center")
		var outside: Dictionary = Meter.sample_at(0.5 + sign_value * 2.001 / Meter.WIDTH)
		check(not outside.perfect and outside.position != 0.5, "Unrounded position outside window neither qualifies nor snaps")
		check(Meter.sample_at(0.5 + sign_value * 1.5 / Meter.WIDTH).perfect, "New window accepts stops that missed the old window")
	check(Meter.sample_at(0.5).power == 1 and Meter.sample_at(0.0).power == 0, "Power spans zero to one")
	check(is_equal_approx(Meter.sample_at(0.1).power, Meter.sample_at(0.9).power), "Power is symmetric")
	meter.elapsed = Meter.PERIOD / 4
	var center_x: float = meter.position_ratio()
	meter.advance(0.001)
	var center_step: float = meter.position_ratio() - center_x
	meter.reset()
	meter.advance(0.001)
	check(center_step > meter.position_ratio() * 1.5, "Marker still accelerates toward the center")
	var previous_peak_step: float = PI / Meter.PERIOD * 0.001
	check(center_step < previous_peak_step * 0.8 and center_step > previous_peak_step * 0.7, "Center peak is modestly slower without changing the cycle")
	# Check real time inside the unchanged pixel window, not just curve constants.
	var available_ms: int = 0
	for ms in range(-20,21):
		meter.elapsed = Meter.PERIOD/4 + ms/1000.0
		if meter.sample().perfect: available_ms += 1
	check(available_ms >= 13 and available_ms <= 17, "Perfect has a longer timing opportunity while retaining the +/-2 pixel window")
	for fps in [15, 20, 30, 60, 120]:
		meter.reset()
		for frame in range(fps): meter.advance(1.0 / fps)
		var direct := Meter.new()
		direct.advance(1)
		check(is_equal_approx(meter.position_ratio(), direct.position_ratio()), "Meter is frame-rate independent at %d FPS" % fps)

func rate_checks() -> void:
	var modified := Rules.new(845)
	modified.category_weights = [1.0, 20.0, 80.0]
	for fever in [false,true]:
		for power in [0.0,0.4,1.0]:
			var adjusted: Dictionary = modified.roll_rates(power,false,fever)
			check(adjusted.triple <= (0.375 if fever else 0.25) and adjusted.pair <= 0.7 and is_equal_approx(adjusted.values().reduce(func(a,b): return a+b,0.0),1.0), "Weight modifiers preserve non-Perfect caps and normalization")
	modified.triple_weights = [0.0,0.0,0.0,0.0,0.0,4.0]
	for i in range(20):
		modified.phase = "roll"
		check(modified.roll(1,true,true).face == 6, "Triple-face weights are independently configurable")
	modified.reset()
	check(modified.triple_weights[5] == 0.7 and modified.category_weights == [1.0,1.0,1.0], "New runs reset weight modifiers")
	for fever in [false, true]:
		for strength in [0.0, 0.25, 0.5, 0.75, 0.9999, 1.0]:
			var rules := preload("res://scripts/run_rules.gd").new(97531)
			rules.stage = 9 if fever else 0
			var counts := [0, 0, 0]
			for i in range(12000):
				rules.phase = "roll"
				counts[mini(rules.roll(strength, false).kind, 2)] += 1
			var rates: Dictionary = Rules.throw_rates(strength, false, fever)
			for i in range(3): check(absf(counts[i] / 12000.0 - rates[["normal", "pair", "triple"][i]]) < 0.018, "Observed odds match power %.4f fever %s category %d" % [strength, fever, i])
			print("Power %.4f fever %s: normal / pair / triple %s" % [strength, fever, counts])
		var perfect_rules := preload("res://scripts/run_rules.gd").new(7913)
		perfect_rules.stage = 9 if fever else 0
		var perfect_counts := [0, 0, 0]
		var faces := [0, 0, 0, 0, 0, 0]
		for i in range(12000):
			perfect_rules.phase = "roll"
			var result: MultiHitSkill = perfect_rules.roll(1.0, true)
			perfect_counts[mini(result.kind, 2)] += 1
			if result.kind >= Rules.Kind.SPECIAL: faces[result.face - 1] += 1
		check(perfect_counts[0] == 0, "Perfect always produces a combination")
		if fever:
			check(perfect_counts[2] == 12000, "City Perfect guarantees triple on every roll")
		else:
			check(absf(perfect_counts[2] / 12000.0 - 0.5) < 0.018, "Squad Perfect keeps 50 percent triples")
		for i in range(6): check(absf(faces[i] / float(perfect_counts[2]) - (0.7 if i == 5 else 1.0) / 5.7) < 0.025, "Triple weights reduce 666 without changing category probability")
		for step in range(1001):
			var rates: Dictionary = Rules.throw_rates(step / 1000.0, false, fever)
			check(rates.triple <= (0.375 if fever else 0.25) + 0.000001, "Non-Perfect triple cap includes power 1 without a Perfect flag")
			check(rates.normal >= 0 and rates.pair >= 0 and rates.pair <= 0.70 and is_equal_approx(rates.normal + rates.pair + rates.triple, 1), "Outcome probabilities are valid at every power")
	var ordinary: Dictionary = Rules.throw_rates(0.5)
	var city: Dictionary = Rules.throw_rates(0.5, false, true)
	check(is_equal_approx(ordinary.triple, 7.0 / 48.0), "Below-cap squad odds preserve the existing curve")
	check(is_equal_approx(city.triple, ordinary.triple * 1.5) and is_equal_approx(city.pair, ordinary.pair * 1.5), "Fever boosts both categories by 1.5 before normalization")
	check(is_equal_approx(Rules.throw_rates(0.99).triple, 0.25), "High power plateaus at 25 percent in squads")
	var full: Dictionary = Rules.throw_rates(1.0, false, true)
	check(is_equal_approx(full.pair, 0.70) and is_equal_approx(full.triple, 0.25) and is_equal_approx(full.normal, 0.05), "Final double cap leaves overflow as normal results, separately from Perfect")

func scene_checks(portrait: bool) -> void:
	game = Portrait.new() if portrait else Battle.new()
	root.add_child(game)
	game.muted = true
	game.speed = 8
	game.reduced = true
	var state: int = game.model.rng.state
	game._handle_click(game.DICE_CENTER)
	check(game.view_phase == "charging" and game.model.phase == "roll" and game.model.rng.state == state, "Charge does not draw gameplay RNG or start combat")
	check(game.dice.all(func(d): return d.charging and not d.rolling), "Dice build energy while charging")
	game._handle_click(game.GUIDE_RECT.get_center())
	var elapsed: float = game.throw_meter.elapsed
	await create_timer(0.08).timeout
	check(game.throw_meter.elapsed == elapsed, "Grimoire pauses power meter")
	game._handle_click(game.GUIDE_CLOSE.get_center())
	game.throw_meter.elapsed = Meter.PERIOD / 4
	game.charge_stamp = Time.get_ticks_usec()
	game._handle_click(game.DICE_CENTER)
	check(game.throw_perfect and game.throw_power == 1 and not game.fx.perfect.is_empty(), "Perfect locks power, throws, and displays feedback")
	check(game.throw_meter.sample().position == 0.5 and game._power_flash_strength() == 1, "Perfect centers the wider indicator and flashes the meter")
	check(game.result.kind != Rules.Kind.NORMAL, "Perfect throws a combination")
	var pending: MultiHitSkill = game.model.pending.duplicate(true)
	game._handle_click(game.DICE_CENTER)
	check(game.model.pending.same_as(pending), "Third click cannot reroll committed dice")
	var locked: float = game.throw_meter.elapsed
	await process_frame
	check(game.throw_meter.elapsed == locked, "Indicator freezes on release")
	await create_timer(0.30).timeout
	check(game._power_flash_strength() == 0, "Perfect flash fades without repeating")
	await settle()
	game._restart()
	game.debug_choice = 0
	game._start_charge()
	game.throw_meter.elapsed = Meter.PERIOD / 4
	game.charge_stamp = Time.get_ticks_usec()
	game._release_charge()
	check(game.throw_perfect and game.result.kind == Rules.Kind.NORMAL, "Debug result explicitly overrides power odds")
	await settle()
	game._start_charge()
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.view_phase == "ready" and game.dice.all(func(d): return not d.charging), "Focus loss cancels charge without throwing")
	game._start_charge()
	game._restart()
	check(game.view_phase == "ready" and game.throw_meter.elapsed == 0 and game.fx.perfect.is_empty(), "Restart clears charging and Perfect feedback")
	game.model.stage = 9
	game.model._load_wave()
	game._start_round()
	game._start_charge()
	check(game._roll_speed() == 2.0, "City speed stays fixed at 2x in either layout")
	var city_clock: float = game.model.volley_clock
	await create_timer(0.12).timeout
	check(game.model.volley_clock < city_clock and game.view_phase == "charging", "City siege continues while aiming")
	game._handle_click(game.DEBUG_RECT.get_center())
	city_clock = game.model.volley_clock
	elapsed = game.throw_meter.elapsed
	await create_timer(0.08).timeout
	check(game.model.volley_clock == city_clock and game.throw_meter.elapsed == elapsed, "Debug pauses both siege and charge")
	game._handle_click(game.DEBUG_CLOSE.get_center())
	game.model.hp = 1
	game.model.volley_clock = 0.001
	await create_timer(0.08).timeout
	check(game.view_phase == "over" and game.model.pending.is_empty(), "City can defeat player during charge without an extra throw")
	game.queue_free()
	await process_frame

func run() -> void:
	timing_checks()
	rate_checks()
	await scene_checks(false)
	await scene_checks(true)
	print("Throw power: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
