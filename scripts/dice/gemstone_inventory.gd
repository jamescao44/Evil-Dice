extends RefCounted
## Six sockets and a compact gem bag; combat uses snapshots, never live equipment.
const Catalog = preload("res://scripts/dice/gemstone_catalog.gd")
const DiceTurn = preload("res://scripts/dice/dice_turn.gd")
const SOCKETS := DiceTurn.COUNT
var bag: Dictionary = {}
var order: Array = []
var sockets: Array = _empty_sockets()
var revision: int = 0
# Presentation metadata follows individual copies without changing combat snapshots or saves.
var unseen_bag: Array = []
var unseen_sockets: Array = range(SOCKETS).map(func(_i): return false)

func is_new(location: Dictionary) -> bool:
	var flags: Array = unseen_sockets if location.has("socket") else unseen_bag
	var index: int = int(location.get("socket",location.get("bag",-1)))
	return index >= 0 and index < flags.size() and flags[index]

## Keep navigation notices separate from the copies that still need inspection.
func has_new() -> bool:
	return true in unseen_bag or true in unseen_sockets

## Touching one copy acknowledges it without changing identical gems elsewhere.
func acknowledge(location: Dictionary) -> void:
	var flags: Array = unseen_sockets if location.has("socket") else unseen_bag
	var index: int = int(location.get("socket",location.get("bag",-1)))
	if index >= 0 and index < flags.size(): flags[index] = false

## Clear cosmetic metadata independently of gemstone ownership.
func acknowledge_new() -> void:
	unseen_bag.fill(false)
	unseen_sockets.fill(false)

## Stable keys keep duplicates stacked without imposing another inventory limit.
static func key(id: String, level: int) -> String:
	return "%s:%d" % [id,level]

static func valid_gem(gem: Dictionary) -> bool:
	return Catalog.valid(gem)

## Allocate a distinct dictionary for every physical die and every inventory instance.
static func _empty_sockets() -> Array:
	return range(SOCKETS).map(func(_index): return {})

func count(id: String, level: int = 1) -> int:
	return int(bag.get(key(id,level),0))

## Grant spare gems without changing any equipped die.
func add(id: String, level: int = 1, amount: int = 1, newly_found: bool = false) -> bool:
	if not valid_gem({"id":id,"level":level}) or amount <= 0: return false
	bag[key(id,level)] = count(id,level)+amount
	for i in range(amount):
		order.append(key(id,level))
		unseen_bag.append(newly_found)
	revision += 1
	return true

func _remove(id: String, level: int) -> bool:
	return _remove_at(order.find(key(id,level)))

func _remove_at(index: int) -> bool:
	if index < 0 or index >= order.size(): return false
	var gem: Dictionary = bag_gem(index)
	var unseen: bool = unseen_bag.pop_at(index)
	order.remove_at(index)
	var id: String = gem.id
	var level: int = gem.level
	var name: String = key(id,level)
	bag[name] = count(id,level)-1
	if bag[name] <= 0: bag.erase(name)
	return unseen

func bag_gem(index: int) -> Dictionary:
	if index < 0 or index >= order.size(): return {}
	var parts: PackedStringArray = str(order[index]).split(":")
	return {"id":parts[0],"level":int(parts[1])}

func _insert(index: int, gem: Dictionary, newly_found: bool = false) -> void:
	add(gem.id,gem.level,1,newly_found)
	order.pop_back()
	unseen_bag.pop_back()
	unseen_bag.insert(clampi(index,0,order.size()),newly_found)
	order.insert(clampi(index,0,order.size()),key(gem.id,gem.level))

## A drag merges matching tiers; otherwise it reorders the bag or swaps dice sockets.
func transfer(source: Dictionary, destination: Dictionary) -> bool:
	if source == destination: return false
	var from_socket: bool = source.has("socket")
	var to_socket: bool = destination.has("socket")
	var start: int = int(source.get("socket",source.get("bag",-1)))
	var end: int = int(destination.get("socket",destination.get("bag",-1)))
	if start < 0 or start >= (SOCKETS if from_socket else order.size()): return false
	if end < 0 or end >= (SOCKETS if to_socket else order.size()+1): return false
	var a: Dictionary = sockets[start] if from_socket else bag_gem(start)
	var b: Dictionary = sockets[end] if to_socket else bag_gem(end)
	if a.is_empty(): return false
	var new_a: bool = is_new(source)
	var new_b: bool = is_new(destination)
	var combine: bool = a == b and Catalog.can_merge(a)
	if from_socket and to_socket:
		sockets[start] = {} if combine else b
		sockets[end] = {"id":a.id,"level":int(a.level)+1} if combine else a
		unseen_sockets[start] = false if combine else new_b
		unseen_sockets[end] = new_a or (combine and new_b)
	elif not from_socket and not to_socket:
		if combine:
			_remove_at(maxi(start,end)); _remove_at(mini(start,end))
			_insert(end-(1 if start < end else 0),{"id":a.id,"level":int(a.level)+1},new_a or new_b)
		else:
			var value: Variant = order.pop_at(start)
			unseen_bag.insert(mini(end,order.size()),unseen_bag.pop_at(start))
			order.insert(mini(end,order.size()),value)
	elif from_socket:
		sockets[start] = {} if combine else b
		unseen_sockets[start] = false if combine else new_b
		if not b.is_empty(): _remove_at(end)
		_insert(end,{"id":a.id,"level":int(a.level)+1} if combine else a,new_a or (combine and new_b))
	else:
		_remove_at(start)
		sockets[end] = {"id":a.id,"level":int(a.level)+1} if combine else a
		unseen_sockets[end] = new_a or (combine and new_b)
		if not combine and not b.is_empty(): _insert(start,b,new_b)
	revision += 1
	return true

## Swapping returns the old gemstone to the bag, even on a spent or rolling die.
func equip(index: int, id: String, level: int = 1, bag_index: int = -1) -> bool:
	if index < 0 or index >= SOCKETS or count(id,level) <= 0: return false
	var source: int = order.find(key(id,level)) if bag_index < 0 else bag_index
	if bag_gem(source) != {"id":id,"level":level}: return false
	var previous: Dictionary = sockets[index]
	var previous_new: bool = unseen_sockets[index]
	unseen_sockets[index] = _remove_at(source)
	sockets[index] = {"id":id,"level":level}
	if not previous.is_empty(): add(previous.id,previous.level,1,previous_new)
	revision += 1
	return true

## Removing a gemstone changes future actions; committed dice remain spent.
func unequip(index: int) -> bool:
	if index < 0 or index >= SOCKETS or sockets[index].is_empty(): return false
	var gem: Dictionary = sockets[index]
	sockets[index] = {}
	add(gem.id,gem.level,1,unseen_sockets[index])
	unseen_sockets[index] = false
	return true

## Prefer spare copies before touching another socket when looking for a merge partner.
func merge_partner(gem: Dictionary, socket: int = -1) -> int:
	if not Catalog.can_merge(gem): return -3
	if socket >= 0:
		if socket >= SOCKETS or sockets[socket] != gem: return -3
	elif count(gem.id,gem.level) == 0: return -3
	if count(gem.id,gem.level) >= (1 if socket >= 0 else 2): return -1
	for i in range(SOCKETS):
		if i != socket and sockets[i] == gem: return i
	return -3

## Merge two identical gems atomically and retain the selected gem's bag/socket location.
func merge(gem: Dictionary, socket: int = -1, bag_index: int = -1) -> bool:
	var partner: int = merge_partner(gem,socket)
	if partner == -3: return false
	var source: int = order.find(key(gem.id,gem.level)) if bag_index < 0 else bag_index
	if socket < 0 and bag_gem(source) != gem: return false
	var upgraded := {"id":gem.id,"level":int(gem.level)+1}
	var newly_found: bool
	if partner == -1:
		var partner_index: int = order.find(key(gem.id,gem.level))
		if socket < 0 and partner_index == source: partner_index = order.find(key(gem.id,gem.level),source+1)
		newly_found = _remove_at(partner_index)
		if socket < 0 and partner_index < source: source -= 1
	else:
		newly_found = unseen_sockets[partner]
		sockets[partner] = {}
		unseen_sockets[partner] = false
	if socket >= 0:
		sockets[socket] = upgraded
		unseen_sockets[socket] = unseen_sockets[socket] or newly_found
	else:
		var source_new: bool = _remove_at(source)
		add(upgraded.id,upgraded.level,1,source_new or newly_found)
	revision += 1
	return true

## Copy only the participating physical dice; generated skills receive no socket effects.
func snapshot(indices: Array) -> Array:
	var result: Array = []
	for index in indices:
		result.append(sockets[index].duplicate() if index >= 0 and index < SOCKETS else {})
	return result

func save() -> Dictionary:
	return {"bag":bag.duplicate(),"order":order.duplicate(),"sockets":sockets.duplicate(true)}

## Accept old checkpoints without gems and ignore malformed or unknown gem entries.
func restore(data: Dictionary) -> void:
	bag.clear()
	order.clear()
	unseen_bag.clear()
	unseen_sockets.fill(false)
	sockets = _empty_sockets()
	var stored_bag: Variant = data.get("bag",{})
	if stored_bag is Dictionary:
		for id in Catalog.ids():
			for level in range(1,Catalog.max_level(id)+1):
				var amount: Variant = stored_bag.get(key(id,level),0)
				if amount is int and amount > 0: add(id,level,amount)
	var stored_order: Variant = data.get("order",[])
	if stored_order is Array and stored_order.size() == order.size():
		var valid_order: bool = true
		for name in bag:
			if stored_order.count(name) != bag[name]: valid_order = false; break
		if valid_order: order = stored_order.duplicate()
	var stored_sockets: Variant = data.get("sockets",[])
	if stored_sockets is Array:
		for i in range(mini(SOCKETS,stored_sockets.size())):
			if stored_sockets[i] is Dictionary and valid_gem(stored_sockets[i]): sockets[i] = {"id":stored_sockets[i].id,"level":stored_sockets[i].level}
	revision += 1
