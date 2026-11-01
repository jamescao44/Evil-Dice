extends Node2D
## Resolve leftover dice immediately; gemstone recovery now belongs to matches and skills.
var battle
var active_die: int = -1
var launched: int = 0

func clear() -> void:
	active_die = -1
	launched = 0

func play(token: int) -> bool:
	clear()
	battle._show_events(battle.model.apply_player_step())
	return battle._valid_turn(token)
