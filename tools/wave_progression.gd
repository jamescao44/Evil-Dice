extends SceneTree
## Recalculate cumulative kill-only XP after each authored wave, including Commander guards.
const Waves = preload("res://scripts/progression/wave_catalog.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Run = preload("res://scripts/progression/run_rules.gd")

## Use the live leveling rules instead of duplicating an inverse XP formula.
func level_at(total: int) -> int:
	var m = Run.new(1)
	m.gain_souls(total)
	return m.character_level

## Phase-one bosses give no second payout; only the Commander has reward-bearing guards.
func wave_souls(entries: Array) -> int:
	var total := 0
	for entry in entries:
		var roles: Array = entry.get("random_roles",[entry.role])
		var expected := 0.0
		for role in roles:
			var unit: Dictionary = Enemy.make(role,entry.level,entry.get("elite",false))
			expected += Enemy.soul_reward(unit)
			if unit.role == Enemy.Role.COMMANDER:
				expected += 2*Enemy.soul_reward(Enemy.make(Enemy.Role.PALADIN,entry.get("reinforcement_level",unit.reinforcement_level)))
		total += roundi(expected/roles.size())
	return total

## --plan follows authored reference gaps; a new level may drop below the preceding boss.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan: bool = "--plan" in args
	var rows: Array = []
	var total := 0
	var previous_level := 1
	for stage in range(Waves.SQUADS.size()):
		var entries: Array = Waves.SQUADS[stage].units.duplicate(true)
		var player_before: int = level_at(total)
		var gap: int = Waves.reference_level_gap(stage)
		if stage%Waves.WAVES_PER_LEVEL == 0: previous_level = 1
		if plan:
			for entry in entries: entry.level = Waves.reference_enemy_level(stage,player_before,previous_level)
		previous_level = entries.map(func(entry): return entry.level).max()
		var xp: int = wave_souls(entries)
		var row := {"wave":"%d-%d" % [stage/Waves.WAVES_PER_LEVEL+1,stage%Waves.WAVES_PER_LEVEL+1],"kill_souls":xp,"player_before":player_before,"target_gap":gap if not Waves.is_boss_stage(stage) else null,"pressure":Waves.LEVEL_PRESSURE[stage/Waves.WAVES_PER_LEVEL].name,"shop_after":Waves.has_shop_after(stage),"enemies":entries.map(func(u): return {"name":" / ".join(u.get("random_roles",[u.role]).map(func(role): return Enemy.ITEMS[role].name)),"elite":u.get("elite",false),"level":u.level})}
		total += xp
		row["total_souls"] = total; row["player_after"] = level_at(total)
		rows.append(row)
		print("%s enemy LV.%d; XP +%d = %d; player %d -> %d%s" % [row.wave,entries[0].level,xp,total,row.player_before,row.player_after,"; shop next" if row.shop_after else ""])
	if not args.is_empty():
		var file := FileAccess.open(args[0],FileAccess.WRITE)
		file.store_string(JSON.stringify({"planned":plan,"assumptions":"Kill-only XP; no soul chests, bottles or Soul Vessel. Six eight-wave levels; shops after local waves 3/6 grant no combat XP. Commander LV.1 guards pay once; Fanatic summons pay nothing. The final three bosses are uniform draws from the three bosses; their XP is averaged for this fixed-level planning reference. Actual player levels can vary slightly by boss. Bosses retain authored levels 9/15/21/26/32, with a level-32 placeholder in level six. Ordinary waves follow chapter pressure targets; levels only fall after a boss. No live player-level matching.","rows":rows},"\t"))
	quit()
