extends RefCounted
## Level-entry checkpoints; active fights are never serialized or silently resumed.
const VERSION := 1
const WAVES_PER_LEVEL := 10
const LEVEL_COUNT := 3
const RUN_FIELDS := ["character_level","souls","base_max_hp","blood_gems","blood_gem_remainder","enemy_soul_remainder","summon_shards","reroll_progress","perfect_total","reward_base_damage","reward_damage_multiplier","first_shop_offered","battles_since_shop","route_history","reward_history","reward_weights"]
var checkpoint: Dictionary = {}
var save_path: String = ""
var cleared_level: int = 0
var _last_completion: String = ""

## Disk persistence is opt-in, so headless sessions and standalone scenes stay isolated.
func configure(path: String) -> void:
	save_path = path
	checkpoint = {}
	cleared_level = 0
	_last_completion = ""
	if path.is_empty() or not FileAccess.file_exists(path): return
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return
	var data: Variant = file.get_var(false)
	if not data is Dictionary or data.get("version",0) != VERSION: return
	var stored: Variant = data.get("checkpoint",{})
	if stored is Dictionary and (stored.is_empty() or valid(stored)):
		checkpoint = stored.duplicate(true)
		cleared_level = clampi(int(data.get("cleared_level",0)),0,LEVEL_COUNT)

## Checkpoints contain only validated value data, never executable object instances.
static func valid(data: Dictionary) -> bool:
	if data.get("stage",-1) not in [WAVES_PER_LEVEL,2*WAVES_PER_LEVEL] or not data.get("run",null) is Dictionary or not data.get("relics",null) is Array or not data.get("tarots",null) is Array: return false
	if not data.get("rng",null) is int or not data.get("reward_rng",null) is int: return false
	return data.run.get("character_level",0) is int and data.run.get("character_level",0) > 0 and data.run.get("base_max_hp",0) is int and data.run.get("base_max_hp",0) > 0

## Capture the permanent build after all completed-level prizes have been resolved.
static func capture(model) -> Dictionary:
	var run: Dictionary = {}
	for key in RUN_FIELDS: run[key] = model.get(key)
	return {"stage":model.level_number()*WAVES_PER_LEVEL,"run":run.duplicate(true),"relics":model.relics.items.duplicate(true),"tarots":model.tarots.items.filter(func(card): return not card.get("projection",false)).duplicate(true),"next_tarot":model.tarots.next_instance,"banned_tarots":model.tarot_effects.banned.duplicate(),"rng":model.rng.state,"reward_rng":model.reward_rng.state}

## Restore ownership directly; loading must not replay acquisition gifts or fusion effects.
static func restore(model, data: Dictionary) -> bool:
	if not valid(data): return false
	model.reset_run()
	for key in RUN_FIELDS:
		if data.run.has(key): model.set(key,data.run[key].duplicate(true) if data.run[key] is Array or data.run[key] is Dictionary else data.run[key])
	model.relics.items = data.relics.duplicate(true)
	model.tarots.items = data.tarots.duplicate(true)
	model.tarots.next_instance = int(data.get("next_tarot",1))
	model.tarot_effects.banned = data.get("banned_tarots",[]).duplicate()
	model.rng.state = data.rng
	model.reward_rng.state = data.reward_rng
	model.stage = data.stage
	var eligible: Array = model.WaveRewards.BATTLE_TYPES.duplicate()
	if model.route_history.size() >= 2 and model.route_history[-1] == model.route_history[-2]: eligible.erase(model.route_history[-1])
	model.wave_kind = eligible[model.reward_rng.randi_range(0,eligible.size()-1)]
	model.route_history.append(model.wave_kind)
	model.hp = model.max_hp
	model._load_wave()
	return true

## Deduplicate callbacks for this run, not future runs that finish the same level.
func complete(model) -> bool:
	if not model.level_rewards_complete(): return false
	var level: int = model.level_number()
	var completion := "%d:%d:%d" % [model.get_instance_id(),model.run_generation,level]
	if _last_completion == completion: return true
	if level < LEVEL_COUNT: checkpoint = capture(model)
	else: checkpoint.clear()
	cleared_level = level
	_last_completion = completion
	_save()
	return true

## Start retries from the entry build; completing all levels starts a fresh chapter.
func start(model) -> void:
	if not checkpoint.is_empty() and restore(model,checkpoint): return
	model.reset_run()
	if cleared_level == LEVEL_COUNT:
		cleared_level = 0
		_save()

func next_level() -> int:
	return int(checkpoint.stage)/WAVES_PER_LEVEL+1 if not checkpoint.is_empty() else 1

## Replace the save atomically so closing the app cannot leave half a checkpoint.
func _save() -> void:
	if save_path.is_empty(): return
	var temporary: String = save_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		push_warning("Could not write level checkpoint.")
		return
	file.store_var({"version":VERSION,"cleared_level":cleared_level,"checkpoint":checkpoint})
	file.close()
	var error: Error = DirAccess.rename_absolute(temporary,save_path)
	if error != OK: push_warning("Could not save level checkpoint: "+error_string(error))
