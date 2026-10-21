extends RefCounted
## Reward category selection, separate from relic rarity and cosmetic reels.
const Weighted = preload("res://scripts/shared/weighted_choice.gd")
enum Category { RUBY, RELIC, CURSE, DAMAGE, MULTIPLIER, POTION, SHARD, TAROT }
# Preserve stable category IDs. Removed categories cannot drop, even with custom weights.
# CURSE stays as a presentation ID only;
# cursed relics are selected by the shared relic rarity roll.
const RETIRED_CATEGORIES := [Category.RUBY, Category.DAMAGE, Category.MULTIPLIER, Category.POTION, Category.SHARD, Category.TAROT]
const DEFAULT_WEIGHTS := [0.0,100.0,0.0,0.0,0.0,0.0,0.0,0.0]
# Retired rows keep old numeric references readable; selection and claiming reject them.
const ITEMS := [
	{"id":"ruby", "name":"Blood Gems", "text":"+100 blood gems", "icon":"ruby", "color":Color("fa6086")},
	{"id":"relic", "name":"Relic", "text":"A random relic", "icon":"relic", "color":Color("c5a4de")},
	{"id":"curse", "name":"Cursed Relic", "text":"A random cursed relic", "icon":"curse", "color":Color("e99b81")},
	{"id":"damage", "name":"Sharpened Hunger", "text":"+7.5 base damage", "icon":"damage", "color":Color("e99b81")},
	{"id":"multiplier", "name":"Unbound Power", "text":"+0.5 damage multiplier", "icon":"multiplier", "color":Color("aed085")},
	{"id":"potion", "name":"Crimson Draught", "text":"potion / placeholder", "icon":"potion", "color":Color("e99b81")},
	{"id":"shard", "name":"Summon Shard", "text":"+1 summon shard", "icon":"shard", "color":Color("9dcedb")},
	{"id":"tarot", "name":"Draw Tarot", "text":"Draw three cards. Keep one.", "icon":"tarot", "color":Color("c5a4de")},
]

static func draw_category(rng: RandomNumberGenerator, weights: Array = DEFAULT_WEIGHTS) -> int:
	var categories: Array = weights.duplicate()
	while categories.size() < ITEMS.size(): categories.append(0.0)
	# Older/debug weight arrays must not bypass relic rarity via the curse ID.
	categories[Category.RELIC] = maxf(0,categories[Category.RELIC])+maxf(0,categories[Category.CURSE])
	categories[Category.CURSE] = 0.0
	for retired in RETIRED_CATEGORIES: categories[retired] = 0.0
	var category: int = Weighted.pick(rng,categories)
	return Weighted.pick(rng,DEFAULT_WEIGHTS) if category < 0 else category
