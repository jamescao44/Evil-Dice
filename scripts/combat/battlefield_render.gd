extends RefCounted
## Battlefield depth and reinforcement presentation, separate from combat decisions.
const ARRIVAL_DURATION := 0.65

## Stable ground-depth ordering keeps new spawns from jumping in front of nearer actors.
static func actor_order(battle) -> Array:
	var entries: Array = [{"id":-1,"feet":battle._player_world_feet()}]
	for index in range(battle.model.enemies.size()):
		if battle.model.enemies[index].get("dismissed",false): continue
		entries.append({"id":index,"feet":battle._enemy_world_feet(index)})
	entries.sort_custom(func(a,b):
		if not is_equal_approx(a.feet.y,b.feet.y): return a.feet.y < b.feet.y
		if not is_equal_approx(a.feet.x,b.feet.x): return a.feet.x < b.feet.x
		return a.id < b.id)
	return entries.map(func(entry): return entry.id)

## Stamp only newcomers, including phase-transition spawns; later batches cannot replay entry.
static func register_arrivals(battle) -> void:
	for enemy in battle.model.enemies:
		if enemy.get("reinforcement",false) and not enemy.has("arrival_started"):
			enemy.arrival_started = battle.clock_time

## Each sprite and its labels share that unit's own entry clock.
static func arrival_progress(battle, index: int) -> float:
	var enemy: Dictionary = battle.model.enemies[index]
	if not enemy.get("reinforcement",false): return 1.0
	var age: float = battle.clock_time-enemy.get("arrival_started",battle.clock_time-ARRIVAL_DURATION)
	return smoothstep(0,ARRIVAL_DURATION,age)

## Reserve labels for settled reinforcements so sliding bars cannot cross another enemy's HUD.
static func labels_visible(battle, index: int) -> bool:
	return battle._enemy_presented_alive(index) and arrival_progress(battle,index) >= 1.0 and battle.ARENA.grow(-6).encloses(battle._enemy_health_rect(index))

## Let lethal HP trails finish without retaining dead units' intent or status icons.
static func health_visible(battle, index: int) -> bool:
	return not battle.model.enemies[index].get("dismissed",false) and (battle._enemy_presented_alive(index) or battle.health_trails.lingering(index)) and arrival_progress(battle,index) >= 1.0 and battle.ARENA.grow(-6).encloses(battle._enemy_health_rect(index))

## Screen-space combat overlays never sit on shop, chest or inspection pages.
static func overlays_visible(battle) -> bool:
	return not battle._menus_open() and battle.inspecting_enemy < 0 and battle.view_phase not in ["shop","reward","over"]

## Keep each player's orbit grouped around that actor, with its counter above world sprites.
static func paint(battle, canvas: CanvasItem) -> void:
	for index in actor_order(battle):
		if index < 0: battle._draw_player_actor(canvas)
		else: battle._draw_human(index,canvas)
	battle.relic_attacks.paint(canvas)
	battle._draw_character_skill_counter(canvas)
