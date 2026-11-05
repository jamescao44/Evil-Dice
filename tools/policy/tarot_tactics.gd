extends RefCounted
## Acquisition alone justifies reward cards; combat cards need a visible tactical opportunity.
const Catalog = preload("res://scripts/tarot/tarot_catalog.gd")
const Status = preload("res://scripts/status/status_effect.gd")

## Never spend combat cards on a shop/receipt screen just because their effects are legal.
static func tactical_context(state: Dictionary, id: String) -> bool:
	return Catalog.immediate_reward(id) or (state.phase in ["roll","player","frozen"] and state.get("outcome","").is_empty() and not state.enemies.is_empty())

## Buff only the chosen upcoming attack, retaining Strength when its damage is unnecessary.
static func strength(state: Dictionary, skill: Dictionary) -> bool:
	if not tactical_context(state,"strength") or skill.is_empty() or state.tarot_modifiers.strength > 0: return false
	for hit in skill.get("damage",[]):
		for enemy in state.enemies:
			if enemy.slot != hit.target or (not skill.area and not enemy.legal_target): continue
			var damage: float = hit.get("total",hit.get("total_per_use",0)*skill.get("uses",1))
			if enemy.hp+enemy.shield > damage: return true
	return false

## Heal a substantial deficit or avert a visible lethal attack; darkness blocks healing.
static func sun(state: Dictionary) -> bool:
	if not tactical_context(state,"sun") or state.player.statuses.any(func(s): return s.id == Status.DARKNESS): return false
	var missing: float = state.player.max_hp-state.player.hp
	if missing <= 0: return false
	var incoming := 0.0
	for enemy in state.enemies:
		if enemy.intent.get("type","") == "attack" and not enemy.statuses.any(func(s): return s.id in Status.ENEMY_ACTION_LOCKS):
			incoming += enemy.intent.get("amount",0)*enemy.intent.get("hits",1)
	return missing >= state.player.max_hp*0.45 or incoming >= state.player.hp+state.player.get("shield",0)
