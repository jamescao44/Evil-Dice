extends Node2D
## Leftover dice return together as healing embers; combat commits one rounded heal.
const Flame = preload("res://scripts/effects/flame_spell.gd")
var battle
var flights: Array = []
var active_die: int = -1
var launched: int = 0
var age: float = 0.0
const DURATION := 0.44

## A restart clears all embers immediately; the turn token cancels their old coroutine.
func clear() -> void:
	flights.clear()
	active_die = -1
	launched = 0
	age = 0
	queue_redraw()

## Merge every leftover into the character, then resolve healing before enemy actions.
func play(token: int) -> bool:
	clear()
	for index in battle.model.skill_dice_indices:
		var die = battle.dice[index]
		flights.append({"from":battle.to_local(die.to_global(Vector2.ZERO)),"delay":launched*0.035})
		launched += 1
	battle._sound("player/bell",1.5,-18)
	while age < DURATION+maxi(0,launched-1)*0.035:
		await get_tree().process_frame
		if not battle._valid_turn(token): return false
		if battle._menus_open(): continue
		age += get_process_delta_time()*battle._roll_speed()*battle._world_time_scale()
		queue_redraw()
	flights.clear()
	battle.fx.ring(battle._player_point(),Color("8feaaf"),70)
	battle.fx.burst(battle._player_point(),Color("8feaaf"),10 if battle.reduced else 22,90)
	battle._show_events(battle.model.apply_player_step())
	queue_redraw()
	return battle._valid_turn(token)

func _ready() -> void:
	z_index = 80

## Keep healing embers below modal interfaces.
func _process(_delta: float) -> void:
	visible = not battle._menus_open()

func _draw() -> void:
	for flight in flights:
		var t: float = clampf((age-flight.delay)/DURATION,0,1)
		if t <= 0 or t >= 1: continue
		var point: Vector2 = flight.from.lerp(battle._player_point(),t*t)
		point.x += sin(t*PI)*35
		Flame.ember(self,point,11,Color("8feaaf"),age,1.0)
