extends SceneTree
## Validate committed elemental outcomes and their actual damage/status application.
const Rules = preload("res://scripts/combat/battle_rules.gd")
const Enemy = preload("res://scripts/enemies/enemy_catalog.gd")
const Actions = preload("res://scripts/enemies/enemy_actions.gd")
const Status = Rules.Status
const EXPECTED := {Status.FROZEN:1,Status.BURNING:3,Status.STUNNED:1,Status.DARKNESS:2,Status.CORROSION:2}
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	check(Enemy.ITEMS[Enemy.Role.HIGH_PRIEST].skills.has(["elemental",3]),"Elemental attack keeps weight three")
	for elite in [false,true]:
		var m = Rules.new(681)
		m.enemies = [Enemy.make(Enemy.Role.HIGH_PRIEST,1,elite)]
		m.enemies[0].erase("modifier")
		var seen := {}
		for i in range(250):
			for status in m.statuses.values(): status.count = 0
			m.hp = 10000; m.max_hp = 10000; m.shield = 0
			var move: Dictionary = Actions.intent(m,0,"elemental")
			check(move.status in EXPECTED and move.stacks == EXPECTED[move.status],"Intent carries exact authored stack count")
			check(move.amount == m.enemies[0].damage and move.hits == 1,"Elemental damage equals one normal attack")
			seen[move.status] = true
			m.phase = "enemy"; m.enemies[0].intent = move; m.enemies[0].acted = false; m.enemies[0].action_hit = 0
			m.enemy_act(0)
			check(m.hp == 10000-move.amount and m.status_count(move.status) == EXPECTED[move.status],"One attack applies normal damage then its locked status")
		check(seen.size() == 5 and Status.PLAGUE not in seen,"All five allowed statuses appear, never plague")
		for status in m.statuses.values(): status.count = 0
		m.apply_affliction(Status.FROZEN,1)
		for i in range(100): check(Actions.intent(m,0,"elemental").status != Status.FROZEN,"An already-frozen player cannot be assigned freeze")
	print("Elemental attack: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
