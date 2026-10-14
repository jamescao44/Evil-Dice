extends SceneTree
const Life = preload("res://scripts/city/city_life.gd")
const City = preload("res://scripts/city/city_paint.gd")
const Run = preload("res://scripts/progression/run_rules.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var life = Life.new(71)
	var battle = Run.new(71)
	var rng_state: int = battle.rng.state
	life.tick(0.1,1)
	check(life.people.is_empty() and life.destroyed.is_empty(), "Intact houses do not spawn frightened inhabitants")
	life.sync_destruction(2.0/3.0)
	check(not life.people.is_empty(), "City damage releases inhabitants")
	check(life.people.any(func(p): return p.noble) and life.people.any(func(p): return not p.noble), "Both nobles and civilians flee")
	for person in life.people:
		var home: Dictionary = life.houses.filter(func(h): return h.id == person.home)[0]
		check(City.house_ruined(home.id,2.0/3.0) and person.p.distance_to(home.p) < 8, "Inhabitants emerge at the house that actually became rubble")
	var crowd_size: int = life.people.size()
	for i in range(60): life.sync_destruction(2.0/3.0)
	check(life.people.size() == crowd_size, "Redrawing or checking unchanged health never respawns a house")
	for i in range(180):
		life.tick(1.0/30.0,2.0/3.0)
		check(life.people.all(func(p): return ((p.p-City.CENTER)/Life.WALK_RADIUS).length_squared() <= 1.001), "Fleeing residents stay inside the walls")
	check(life.people.filter(func(p): return p.p.distance_to(p.origin) > 10).size() >= crowd_size/2, "Residents visibly flee rather than remain stuck at their homes")
	check(battle.rng.state == rng_state and battle.hp == 100, "Cosmetic panic never touches combat RNG or health")
	life.sync_destruction(0)
	check(life.destroyed.size() == life.houses.size() and life.people.size() <= Life.MAX_PEOPLE, "Mass destruction records every house and bounds the crowd")
	for i in range(100): life.tick(0.25,0)
	check(life.people.is_empty(), "Residents eventually fade without being respawned from old ruins")
	life.clear()
	check(life.people.is_empty() and life.destroyed.is_empty() and life.clock == 0 and life.remaining == 1, "Restart clears panic and its destruction ledger")
	life.sync_destruction(2.0/3.0)
	check(life.people.size() == crowd_size, "A new run can release inhabitants from those houses again")
	print("City life: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
