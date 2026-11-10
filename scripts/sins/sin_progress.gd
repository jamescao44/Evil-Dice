extends RefCounted
## Chapter-scoped rules; save data contains no presentation state or executable objects.
signal awakened(id: String)
const Catalog = preload("res://scripts/sins/sin_catalog.gd")
const Types = preload("res://scripts/relics/relic_types.gd")
var unlocked: Array = []
var tarot_uses := 0
var food_consumed := 0
var level_rerolled := false
var cleared_waves: Array = []
var checked_level := -1
var retaliation_queue: Array = []
var resolving_retaliation := false

func has(id: String) -> bool:
	return id in unlocked

## Unlock all satisfied conditions before consuming Food, preserving simultaneous set awakenings.
func check(model) -> void:
	var counts: Dictionary = Types.owned(model.relics.items,model.relics.Catalog.ITEMS)
	var satisfied: Array = []
	for id in Catalog.ORDER:
		if has(id): continue
		var rule: Dictionary = Catalog.ITEMS[id]
		var eligible: bool = counts.get(rule.get("type",""),0) >= rule.get("threshold",2147483647)
		if id == "envy": eligible = tarot_uses >= 12
		if id == "pride": eligible = Types.completed_sets(model.relics.items) >= 3
		if eligible: satisfied.append(id)
	awaken(model,satisfied)

## Earned conditions and debug shortcuts share activation, Food consumption and notifications.
func awaken(model, satisfied: Array) -> int:
	var newly: Array = []
	for id in Catalog.ORDER:
		if id in satisfied and not has(id):
			unlocked.append(id)
			newly.append(id)
	model.relics.consume_food = has("gluttony")
	if has("gluttony"): consume_food(model)
	for id in newly: awakened.emit(id)
	return newly.size()

## Consumed fused meals pay per ingredient; their old effects and acquisition gifts are removed.
func consume_food(model) -> void:
	for i in range(model.relics.items.size()-1,-1,-1):
		var count: int = Types.stacks(model.relics.items[i],model.relics.Catalog.ITEMS).get("food",0)
		if count <= 0: continue
		food_consumed += count
		model.relics.record_consumed_food(model.relics.items[i])
		model.relics.remove(i)

func tarot_used(model) -> void:
	tarot_uses += 1
	check(model)

## Free corrections still reroll dice; changing a face directly does not spoil Sloth.
func rerolled() -> void:
	level_rerolled = true

## Only all eight real cleared waves qualify; debug jumps and partial levels never do.
func enter_wave(model) -> void:
	if checked_level != model.level_number():
		if checked_level != -1: level_rerolled = false
		checked_level = model.level_number()
		cleared_waves.clear()

func wave_cleared(model) -> void:
	enter_wave(model)
	if model.stage not in cleared_waves: cleared_waves.append(model.stage)
	if model.level_wave() == model.Waves.WAVES_PER_LEVEL and cleared_waves.size() == model.Waves.WAVES_PER_LEVEL and not level_rerolled and not has("sloth"):
		awaken(model,["sloth"])

## Add chapter powers after ordered relic base changes; Pride never scales itself recursively.
func base_damage(model, relic_base: float) -> float:
	var value: float = relic_base+food_consumed*10
	if has("greed") and "blood_gems" in model: value += floori(model.blood_gems/20.0)
	if has("pride"): value += maxf(100,value)*clampf(float(model.hp)/model.max_hp,0,1)
	return value

func skill_factor(skill) -> float:
	if skill.pattern == "match_auto": return 3.0 if has("sloth") else 1.0
	if skill.is_attack() and skill.cast_source != "relic": return Catalog.ENVY_FACTOR if has("envy") else 1.0
	return 1.0

## HP losses enqueue real reactions; nested retaliations remain enabled without recursive call stacks.
func lost_hp(model, before: int, loss: int) -> void:
	if not has("lust") or loss <= 0 or before <= 0: return
	retaliation_queue.append((float(loss)/before)*100+model.character_base_damage()+model.relic_base_damage())

## The queue permits deliberate lifesteal/retaliation chains until either side has fallen.
func resolve_retaliations(model) -> Array:
	if resolving_retaliation: return []
	resolving_retaliation = true
	var events: Array = []
	while not retaliation_queue.is_empty():
		var amount: float = retaliation_queue.pop_front()
		if model.hp <= 0 or model.living().is_empty(): retaliation_queue.clear(); break
		events.append_array(model.RelicEffects.Attack.apply(model,"sin_lust",amount,true,true,-1,{"no_damage_modifiers":true}))
	resolving_retaliation = false
	return events

func save() -> Dictionary:
	return {"unlocked":unlocked.duplicate(),"tarot_uses":tarot_uses,"food_consumed":food_consumed,"level_rerolled":level_rerolled,"cleared_waves":cleared_waves.duplicate(),"checked_level":checked_level}

func restore(data: Dictionary) -> void:
	unlocked = data.get("unlocked",[]).filter(func(id): return id in Catalog.ORDER)
	tarot_uses = maxi(0,int(data.get("tarot_uses",0)))
	food_consumed = maxi(0,int(data.get("food_consumed",0)))
	level_rerolled = data.get("level_rerolled",false)
	cleared_waves = data.get("cleared_waves",[]).duplicate()
	checked_level = data.get("checked_level",-1)
	retaliation_queue.clear()
	resolving_retaliation = false
