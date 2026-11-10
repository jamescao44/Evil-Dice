extends RefCounted
## Awakening rules and presentation strings are data, independent of character or relic behavior.
const ORDER := ["gluttony","lust","wrath","sloth","envy","greed","pride"]
const ENVY_FACTOR := 2.25
const ITEMS := {
	"gluttony":{"name":"Gluttony","color":Color("ff913c"),"type":"food","threshold":10,"condition":"Own 10 Food stacks at once.","effect":"Consume all Food, including future acquisitions. Each consumed Food stack grants +10 base damage and +1 multiplier, replacing its original effects."},
	"lust":{"name":"Lust","color":Color("ff69ba"),"type":"biotic","threshold":10,"condition":"Own 10 Biotic stacks at once.","effect":"Healing and lifesteal are doubled. Whenever HP is lost, strike all enemies for base damage plus 100 × the fraction of HP lost."},
	"wrath":{"name":"Wrath","color":Color("ff494f"),"type":"weapon","threshold":10,"condition":"Own 10 Weapon stacks at once.","effect":"After each initial throw, every Weapon relic attacks a random enemy for 2× base damage."},
	"sloth":{"name":"Sloth","color":Color("74c6ff"),"condition":"Clear a whole level without rerolling.","effect":"Automatic attack damage ×3."},
	"envy":{"name":"Envy","color":Color("78f4a2"),"condition":"Use 12 tarot cards in this chapter.","effect":"All skill damage ×2.25."},
	"greed":{"name":"Greed","color":Color("ffce57"),"type":"treasure","threshold":10,"condition":"Own 10 Treasure stacks at once.","effect":"Every 20 Blood Gems currently held grants +1 base damage."},
	"pride":{"name":"Pride","color":Color("b998ff"),"condition":"Own 3 completed sets at once.","effect":"Gain base damage equal to your remaining HP percentage × the greater of 100 or your base damage."},
}

static func icon(id: String) -> Texture2D:
	return load("res://assets/art/sins/"+id+".svg")
