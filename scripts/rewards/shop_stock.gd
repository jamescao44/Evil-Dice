extends RefCounted
## Run-local shop stock and atomic purchases; presentation never rolls rewards.
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
const INTERVAL := 5
const RELIC_COUNT := 6
const TAROT_COUNT := 2
const BOTTLE_COUNT := 1
const OFFER_COUNT := RELIC_COUNT+TAROT_COUNT+BOTTLE_COUNT
const REFRESH_PRICE := 50
const PRICE_RANGES := [Vector2i(100,150),Vector2i(180,230),Vector2i(280,320),Vector2i(400,500),Vector2i(400,500)]
const TAROT_PRICE := Vector2i(100,150)
const BOTTLE_PRICE := Vector2i(100,300)
var offers: Array = []
var wave: int = -1
var number: int = 0
var active: bool = false
var guaranteed_slot: int = -1

## Discard shop visits and stock when a run restarts.
func reset() -> void:
	offers.clear()
	wave = -1
	number = 0
	active = false
	guaranteed_slot = -1

## A visit is due only after an unfinished chosen shop wave.
func due(run) -> bool:
	return run.wave_kind == run.WaveRewards.SHOP and wave != run.stage+1

## Open once per shop wave without creating enemies.
func open(run) -> bool:
	if active or not due(run) or not run.wave_reward_resolved or not run.open_rewards.is_empty() or not run.tarot_source.is_empty(): return false
	wave = run.stage+1
	number += 1
	active = true
	_restock(run)
	return true

## Keep all visits at base prices; refreshing always costs fifty blood gems.
func price_multiplier() -> float:
	return 1.0

## Roll an inclusive fixed price in Blood Gems.
func _price(rng: RandomNumberGenerator, limits: Vector2i) -> int:
	return roundi(rng.randi_range(limits.x,limits.y)*price_multiplier())

## Reserve the guaranteed rarity first so ordinary slots cannot exhaust its pool.
func _restock(run) -> void:
	offers.clear()
	var ids: Array = []
	var rarity: int = Relics.Rarity.RARE
	var exact: Array = [0.0,0.0,0.0,0.0,0.0]
	exact[rarity] = 1.0
	var guaranteed: String = run.relics.draw_one(run.reward_rng,[],exact)
	# If every item of that rarity is owned, prefer an eligible higher rarity.
	if guaranteed.is_empty(): guaranteed = run.relics.draw_one(run.reward_rng,[],Relics.RARITY_WEIGHTS,rarity)
	guaranteed_slot = run.reward_rng.randi_range(0,RELIC_COUNT-1)
	if not guaranteed.is_empty(): ids.append(guaranteed)
	for slot in range(RELIC_COUNT):
		var id: String = guaranteed if slot == guaranteed_slot else run.relics.draw_one(run.reward_rng,ids,Relics.RARITY_WEIGHTS)
		if not id.is_empty() and slot != guaranteed_slot: ids.append(id)
		offers.append({"kind":"relic","id":id,"price":0 if id.is_empty() else _price(run.reward_rng,PRICE_RANGES[Relics.ITEMS[id].rarity]),"sold":false})
	var cards: Array = []
	for slot in range(TAROT_COUNT):
		var id: String = Tarot.draw_one(run.reward_rng,run.tarot_effects.banned+cards)
		# Run exclusions can leave only one card type; owned cards may repeat.
		if id.is_empty(): id = Tarot.draw_one(run.reward_rng,run.tarot_effects.banned)
		if not id.is_empty(): cards.append(id)
		offers.append({"kind":"tarot","id":id,"price":_price(run.reward_rng,TAROT_PRICE),"sold":false})
	# Lock hidden contents alongside the price; inspecting or buying never rerolls them.
	var price := _price(run.reward_rng,BOTTLE_PRICE)
	var souls: int = run.reward_rng.randi_range(ceili(price/20.0),floori(price/10.0))
	offers.append({"kind":"soul_bottle","id":"soul_bottle","price":price,"souls":souls,"sold":false})

## Validate stock, ownership and funds without spending or rerolling anything.
func can_buy(run, slot: int) -> bool:
	if not active or slot < 0 or slot >= offers.size(): return false
	var offer: Dictionary = offers[slot]
	if offer.sold or offer.id.is_empty() or run.blood_gems < offer.price: return false
	return offer.kind in ["tarot","soul_bottle"] or run.relics.can_add(offer.id)

## Indicate when a purchase requires choosing an owned relic to replace.
func needs_replacement(run, slot: int) -> bool:
	if not can_buy(run,slot) or offers[slot].kind != "relic": return false
	return run.relics.items.size() >= Relics.MAX_SLOTS and not (offers[slot].id == "codex_page" and run.relics.has("codex_page"))

## Commit one paid grant; failed replacements and repeat taps cost nothing.
func buy(run, slot: int, replace_index: int = -1) -> Dictionary:
	if not can_buy(run,slot): return {}
	var offer: Dictionary = offers[slot]
	if needs_replacement(run,slot) and (replace_index < 0 or replace_index >= run.relics.items.size()): return {}
	if offer.kind == "relic":
		if not run.acquire_relic(offer.id,replace_index): return {}
	elif offer.kind == "tarot":
		if run.grant_tarot(offer.id).is_empty(): return {}
	run.blood_gems -= offer.price
	offer.sold = true
	if offer.kind == "soul_bottle": run.gain_souls(offer.souls)
	return offer.duplicate()

## Replace every listing, including the bottle's sealed contents, in one paid refresh.
func refresh(run) -> bool:
	if not active or run.blood_gems < REFRESH_PRICE: return false
	run.blood_gems -= REFRESH_PRICE
	_restock(run)
	return true

## Leaving is free and closes this visit permanently.
func close() -> void:
	active = false
