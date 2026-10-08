extends RefCounted
## Cosmetic siege inhabitants. Never consumes combat RNG or changes damage.
const City = preload("res://scripts/city_paint.gd")
const MAX_PEOPLE := 96
const WALK_RADIUS := Vector2(294, 96)
var houses: Array = City.house_layout()
var people: Array = []
var destroyed: Dictionary = {}
var clock: float = 0
var remaining: float = 1
var cosmetic := RandomNumberGenerator.new()

func _init(seed_value: int = -1) -> void:
	if seed_value < 0: cosmetic.randomize()
	else: cosmetic.seed = seed_value

func clear() -> void:
	people.clear()
	destroyed.clear()
	clock = 0
	remaining = 1

func sync_destruction(health_fraction: float) -> void:
	remaining = minf(remaining, clampf(health_fraction, 0, 1))
	for house in houses:
		if destroyed.has(house.id) or not City.house_ruined(house.id, remaining): continue
		destroyed[house.id] = true
		# Mark every ruin once, even when the crowd is at capacity.
		for resident in range(2 if house.id % 3 == 0 else 1):
			if people.size() >= MAX_PEOPLE: break
			var noble: bool = house.id % 5 == 0 and resident == 0
			var spawn: Vector2 = _confine(house.p + Vector2(resident*4-2, 3))
			var person := {
				"p": spawn, "home": house.id, "origin": spawn,
				"art": "aristocrat" if noble else "civilian" if house.id % 2 else "civilian_gray",
				"noble": noble, "age": 0.0, "life": cosmetic.randf_range(12,20),
				"speed": cosmetic.randf_range(20,34), "phase": cosmetic.randf_range(0,TAU),
				"turn": 0.0, "goal": spawn, "facing": 1.0,
			}
			people.append(person)

func tick(delta: float, health_fraction: float) -> void:
	sync_destruction(health_fraction)
	# A window stall must not teleport the crowd through buildings or walls.
	var elapsed: float = minf(delta, 0.25)
	while elapsed > 0:
		var step: float = minf(elapsed, 0.05)
		_step(step)
		elapsed -= step

func _step(delta: float) -> void:
	clock += delta
	for person in people:
		person.age += delta
		person.turn -= delta
		if person.turn <= 0 or person.p.distance_squared_to(person.goal) < 16:
			person.goal = _destination(person.p)
			person.turn = cosmetic.randf_range(0.65,1.7)
		var direction: Vector2 = person.p.direction_to(person.goal)
		var move: Vector2 = direction * person.speed * delta
		var candidate: Vector2 = person.p + move
		if _walkable(candidate): person.p = candidate
		elif _walkable(person.p + Vector2(move.x,0)): person.p.x += move.x
		elif _walkable(person.p + Vector2(0,move.y)): person.p.y += move.y
		else: person.turn = 0
		if absf(direction.x) > 0.1: person.facing = signf(direction.x)
	people = people.filter(func(person): return person.age < person.life)

func _destination(from: Vector2) -> Vector2:
	for attempt in range(24):
		var candidate := _confine(from + Vector2.from_angle(cosmetic.randf_range(0,TAU)) * cosmetic.randf_range(28,110) * Vector2(1,0.55))
		if _walkable(candidate): return candidate
	return from

func _confine(point: Vector2) -> Vector2:
	var offset: Vector2 = (point - City.CENTER) / WALK_RADIUS
	return City.CENTER + offset.limit_length(0.98) * WALK_RADIUS

func _walkable(point: Vector2) -> bool:
	if ((point - City.CENTER) / WALK_RADIUS).length_squared() > 1: return false
	if Rect2(771,210,123,97).has_point(point) and remaining > 0.12: return false
	for house in houses:
		if destroyed.has(house.id): continue
		if Rect2(house.p - Vector2(12,4),Vector2(26,8)).has_point(point): return false
	return true
