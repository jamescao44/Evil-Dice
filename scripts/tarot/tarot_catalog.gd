extends RefCounted
## Stable IDs, presentation, and reward eligibility. Effects live in TarotEffects.
enum EffectType { ROLL_SETTING, ROLL_TRIGGER, IMMEDIATE, NEXT_SKILL }
# Timing and repeat behavior are independent. Star affects Perfect detection,
# so it shares a category with face settings without replacing their faces.
const DISABLED: Array = []
const ROLL_FACE_SETTINGS := ["lovers","devil"]
const ROLL_TRIGGERS: Array = []
const NEXT_SKILL_MODIFIERS := ["strength"]
const Weighted = preload("res://scripts/shared/weighted_choice.gd")

static func effect_type(id: String) -> EffectType:
	if id in ROLL_FACE_SETTINGS or id == "star": return EffectType.ROLL_SETTING
	if id in ROLL_TRIGGERS: return EffectType.ROLL_TRIGGER
	if id in NEXT_SKILL_MODIFIERS: return EffectType.NEXT_SKILL
	return EffectType.IMMEDIATE

const BACK = preload("res://assets/art/tarot/back.png")
const ITEMS := {
	"fool": {"name": "The Fool", "design": "Reroll every owned relic. New relics cannot match any previously owned relic.", "target": "owned_item", "art": "res://assets/art/tarot/00.png", "implemented": true},
	"magician": {"name": "The Magician", "design": "Change one unused rolled die to a different face. Cancel without consuming the card.", "target": "dice", "art": "res://assets/art/tarot/01.png", "implemented": true},
	"high_priestess": {"name": "The High Priestess", "design": "Add 1 to unused dice now and all rolls this turn, up to 6. Repeated uses add another 1.", "target": "self", "art": "res://assets/art/tarot/02.png", "implemented": true},
	"empress": {"name": "The Empress", "design": "Receive two random tarot cards.", "target": "self", "art": "res://assets/art/tarot/03.png", "implemented": true},
	"emperor": {"name": "The Emperor", "design": "Receive a random eligible relic. Every eligible relic has an equal chance.", "target": "self", "art": "res://assets/art/tarot/04.png", "implemented": true},
	"hierophant": {"name": "The Hierophant", "design": "Remove all harmful statuses from the player.", "target": "self", "art": "res://assets/art/tarot/05.png", "implemented": true},
	"lovers": {"name": "The Lovers", "design": "The next eligible roll guarantees a straight of at least four dice.", "target": "dice", "art": "res://assets/art/tarot/06.png", "implemented": true},
	"chariot": {"name": "The Chariot", "design": "Gain 50 shield points.", "target": "self", "art": "res://assets/art/tarot/07.png", "implemented": true},
	"strength": {"name": "Strength", "design": "Add one extra base damage or support potency to the next skill. Repeated Strength stacks additively.", "target": "self", "art": "res://assets/art/tarot/08.png", "implemented": true},
	"hermit": {"name": "The Hermit", "design": "Restore all dice spent this turn so they can be used again immediately.", "target": "self", "art": "res://assets/art/tarot/09.png", "implemented": true},
	"wheel": {"name": "Wheel of Fortune", "design": "A 1 in 4 chance of a chest; 1 in 10 of those is rare.", "target": "self", "art": "res://assets/art/tarot/10.png", "implemented": true},
	"justice": {"name": "Justice", "design": "Cancel any formed skill, restore spent dice, and reroll all six dice for free.", "target": "dice", "art": "res://assets/art/tarot/11.png", "implemented": true},
	"hanged_man": {"name": "The Hanged Man", "design": "Choose a tarot card to exclude from future draws.", "target": "tarot_type", "art": "res://assets/art/tarot/12.png", "implemented": true},
	"death": {"name": "Death", "design": "Execute a selected enemy.", "target": "enemy", "art": "res://assets/art/tarot/13.png", "implemented": true},
	"temperance": {"name": "Temperance", "design": "End this turn and carry unused rolls into the next turn.", "target": "self", "art": "res://assets/art/tarot/14.png", "implemented": true},
	"devil": {"name": "The Devil", "design": "The next throw includes at least three sixes; repeated uses guarantee one more six.", "target": "dice", "art": "res://assets/art/tarot/15.png", "implemented": true},
	"tower": {"name": "The Tower", "design": "Break every enemy shield. Deal 50 fixed damage to all enemies and 30 to yourself.", "target": "all", "art": "res://assets/art/tarot/16.png", "implemented": true},
	"star": {"name": "The Star", "design": "The next three throws are Perfect. Using this again resets the count to three.", "target": "self", "art": "res://assets/art/tarot/17.png", "implemented": true},
	"moon": {"name": "The Moon", "design": "Apply permanent darkness to all enemies.", "target": "all_enemies", "art": "res://assets/art/tarot/18.png", "implemented": true},
	"sun": {"name": "The Sun", "design": "Fully heal and apply one burning stack to every enemy.", "target": "all", "art": "res://assets/art/tarot/19.png", "implemented": true},
	"judgement": {"name": "Judgement", "design": "If currently unused dice cannot form a straight, gain 2 rerolls.", "target": "dice", "art": "res://assets/art/tarot/20.png", "implemented": true},
	"world": {"name": "The World", "design": "Receive a random legendary item.", "target": "self", "art": "res://assets/art/tarot/21.png", "implemented": true, "weight": 0.5},
}

static func pick_index(rng: RandomNumberGenerator, pool: Array) -> int:
	return Weighted.pick(rng,pool.map(func(id): return ITEMS[id].get("weight",1.0)))

static func draw_one(rng: RandomNumberGenerator, banned: Array = []) -> String:
	var pool: Array = eligible(banned)
	return "" if pool.is_empty() else pool[pick_index(rng,pool)]

static func draw_choices(rng: RandomNumberGenerator, banned: Array = []) -> Array:
	var eligible: Array = eligible(banned)
	var pool: Array = eligible.duplicate()
	var choices: Array = []
	if pool.is_empty(): return []
	for i in range(3):
		if pool.is_empty(): pool = eligible.duplicate()
		choices.append(pool.pop_at(pick_index(rng,pool)))
	return choices

## Include the temporary rules notice wherever a card's effect is inspected.
static func description(id: String) -> String:
	return "Temporarily disabled for six-dice turns." if id in DISABLED else ITEMS[id].design

## Share the active reward deck with draws and ban choices.
static func eligible(banned: Array = []) -> Array:
	return ITEMS.keys().filter(func(id): return id not in banned and id not in DISABLED)
