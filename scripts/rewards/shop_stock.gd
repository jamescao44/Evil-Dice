extends RefCounted
## Run-local shop stock and atomic purchases; presentation never rolls rewards.
const Relics = preload("res://scripts/relics/relic_catalog.gd")
const Tarot = preload("res://scripts/tarot/tarot_catalog.gd")
const RarityTable = preload("res://scripts/relics/relic_drop_table.gd")
const FIRST_SHOP_WAVE := 4
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
var divination_used: bool = false
var refresh_price: int = REFRESH_PRICE
var debug_unlimited: bool = false

## Discard shop visits and stock when a run restarts.
func reset() -> void:
	offers.clear()
	wave = -1
	number = 0
	active = false
	guaranteed_slot = -1
	divination_used = false
	refresh_price = REFRESH_PRICE
	debug_unlimited = false

## Create a temporary debug visit with normal merchandise and unlimited spending.
func open_debug(run) -> void:
	reset()
	wave = run.stage+1
	active = true
	debug_unlimited = true
	_restock(run)

## Share affordability between transaction rules and every price indicator.
func can_afford(run, amount: int) -> bool:
	return (active and debug_unlimited) or run.blood_gems >= amount

## A visit is due only after an unfinished chosen shop wave.
func due(run) -> bool:
	return run.wave_kind == run.WaveRewards.SHOP and wave != run.stage+1

## Open once per shop wave without creating enemies.
func open(run) -> bool:
	if active or not due(run) or not run.wave_reward_resolved or not run.open_rewards.is_empty() or not run.tarot_source.is_empty(): return false
	wave = run.stage+1
	number += 1
	active = true
	divination_used = false
	refresh_price = REFRESH_PRICE
	_restock(run)
	return true

## Reserve one free three-card choice per visit before its cosmetic ceremony starts.
func begin_divination(run) -> Array:
	if not active or divination_used or not run.tarot_source.is_empty(): return []
	var choices: Array = Tarot.draw_choices(run.reward_rng,run.tarot_effects.banned)
	if choices.size() != 3: return []
	divination_used = true
	return choices

## Merchandise retains its base prices independently of the escalating refresh fee.
func price_multiplier() -> float:
	return 1.0

## Roll an inclusive fixed price in Blood Gems.
func _price(rng: RandomNumberGenerator, limits: Vector2i) -> int:
	return roundi(rng.randi_range(limits.x,limits.y)*price_multiplier())

## Start at the first possible shop, then approach equal rarity odds on later waves.
static func rarity_weights(wave_number: int) -> Array:
	return RarityTable.weights_for_wave(maxi(1,wave_number-FIRST_SHOP_WAVE+1))

## Reserve the guaranteed item from the six-slot budget so Rare does not stay overweight.
static func random_slot_weights(wave_number: int, guaranteed_rarity: int = Relics.Rarity.RARE) -> Array:
	var weights: Array = rarity_weights(wave_number).map(func(weight): return weight*RELIC_COUNT)
	weights[guaranteed_rarity] = maxf(0,weights[guaranteed_rarity]-100.0)
	return weights.map(func(weight): return weight/(RELIC_COUNT-1))

## Reserve the guaranteed rarity first so ordinary slots cannot exhaust its pool.
func _restock(run) -> void:
	offers.clear()
	var ids: Array = []
	var rarity: int = Relics.Rarity.RARE
	var weights: Array = rarity_weights(run.stage+1)
	var exact: Array = [0.0,0.0,0.0,0.0,0.0]
	exact[rarity] = 1.0
	var guaranteed: String = run.relics.draw_one(run.reward_rng,[],exact)
	# If every item of that rarity is owned, prefer an eligible higher rarity.
	if guaranteed.is_empty(): guaranteed = run.relics.draw_one(run.reward_rng,[],weights,rarity)
	guaranteed_slot = run.reward_rng.randi_range(0,RELIC_COUNT-1)
	if not guaranteed.is_empty():
		ids.append(guaranteed)
		weights = random_slot_weights(run.stage+1,Relics.ITEMS[guaranteed].rarity)
	for slot in range(RELIC_COUNT):
		var id: String = guaranteed if slot == guaranteed_slot else run.relics.draw_one(run.reward_rng,ids,weights)
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
	if offer.sold or offer.id.is_empty() or not can_afford(run,offer.price): return false
	return offer.kind in ["tarot","soul_bottle"] or run.relics.can_add(offer.id)

## Indicate when a purchase requires choosing an owned relic to replace.
func needs_replacement(run, slot: int) -> bool:
	if not can_buy(run,slot) or offers[slot].kind != "relic": return false
	return run.relics.items.size() >= Relics.MAX_SLOTS and run.relics.needs_slot(offers[slot].id)

## Commit one paid grant; failed replacements and repeat taps cost nothing.
func buy(run, slot: int, replace_index: int = -1) -> Dictionary:
	if not can_buy(run,slot): return {}
	var offer: Dictionary = offers[slot]
	if needs_replacement(run,slot) and (replace_index < 0 or replace_index >= run.relics.items.size()): return {}
	if offer.kind == "relic":
		if not run.acquire_relic(offer.id,replace_index): return {}
	elif offer.kind == "tarot":
		if run.grant_tarot(offer.id).is_empty(): return {}
	if not debug_unlimited: run.blood_gems -= offer.price
	offer.sold = true
	if offer.kind == "soul_bottle": run.gain_souls(offer.souls)
	return offer.duplicate()

## Replace every listing, including the bottle's sealed contents, in one paid refresh.
func refresh(run) -> bool:
	if not active or not can_afford(run,refresh_price): return false
	if not debug_unlimited: run.blood_gems -= refresh_price
	refresh_price += mini(refresh_price,0x7FFFFFFFFFFFFFFF-refresh_price)
	_restock(run)
	return true

## Leaving is free and closes this visit permanently.
func close() -> void:
	active = false
	debug_unlimited = false
