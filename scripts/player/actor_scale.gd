extends RefCounted
## Fixed evolution proportions; advancing waves never resizes combatants.
# Early forms share Diablo 2: former wave 12. Diablo 3: former wave 5.
const PLAYER_SIZES := [224.0+64*11/19.0,224.0+64*11/19.0,224.0+64*4/19.0]
# Enemy scale steps through the former wave 1, 5 and 12 proportions at evolution.
const ENEMY_SIZES := [192.0,192.0-104*4/18.0,192.0-104*11/18.0]

static func player_size(form: int) -> float:
	return PLAYER_SIZES[clampi(form,0,PLAYER_SIZES.size()-1)]

static func enemy_size(form: int) -> float:
	return ENEMY_SIZES[clampi(form,0,ENEMY_SIZES.size()-1)]
