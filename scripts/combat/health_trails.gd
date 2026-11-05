extends RefCounted
## Presentation-only HP trails shared by player, ordinary enemies and bosses.
const HOLD_SECONDS := 0.22
const RECEDE_SECONDS := 0.55
var bars: Dictionary = {}

## Start a new run without carrying old damage into its health bars.
func reset(model) -> void:
	bars.clear()
	sync(model)

## Observe actual HP, including status damage, healing, new spawns and phase refills.
func sync(model) -> void:
	_observe(-1,model.hp,model.max_hp,model)
	for index in range(model.enemies.size()):
		var enemy: Dictionary = model.enemies[index]
		_observe(index,enemy.hp,enemy.max_hp,enemy,enemy.get("boss_phase",0))
	for target in bars.keys():
		if target >= model.enemies.size(): bars.erase(target)

## Reset replacement actors/refills; successive hits restart the hold from the visible trail.
func _observe(target: int, hp: int, maximum: int, source: Variant, phase: int = 0) -> void:
	var health: float = clampf(hp,0,maxi(1,maximum))
	var state: Dictionary = bars.get(target,{})
	if state.is_empty() or not is_same(state.source,source) or state.maximum != maximum or state.phase != phase or health > state.hp:
		bars[target] = {"hp":health,"trail":health,"from":health,"age":HOLD_SECONDS+RECEDE_SECONDS,
			"maximum":maximum,"source":source,"phase":phase}
		return
	if health < state.hp:
		state.from = maxf(state.trail,state.hp)
		state.trail = state.from
		state.age = 0.0
	state.hp = health

## Pause-aware easing reaches the new HP exactly, without changing combat values.
func advance(delta: float) -> void:
	for state in bars.values():
		if state.trail <= state.hp: continue
		state.age += maxf(0,delta)
		var progress: float = smoothstep(HOLD_SECONDS,HOLD_SECONDS+RECEDE_SECONDS,state.age)
		state.trail = lerpf(state.from,state.hp,progress)

## Return a safe fallback before the first presentation update.
func value(target: int, hp: int) -> float:
	return maxf(hp,bars[target].trail) if bars.has(target) else maxf(0,hp)

## Keep only the health bar briefly visible after a lethal hit.
func lingering(target: int) -> bool:
	return bars.has(target) and bars[target].trail > bars[target].hp
