extends RefCounted
## Stable IDs, presentation, and reward eligibility. Effects live in TarotEffects.
enum EffectType { ROLL_SETTING, ROLL_TRIGGER, IMMEDIATE, NEXT_SKILL }
# Timing and repeat behavior are independent. Star affects Perfect detection,
# so it shares a category with face settings without replacing their faces.
const ROLL_FACE_SETTINGS := ["magician","lovers","justice"]
const ROLL_TRIGGERS := ["hierophant","devil"]
const NEXT_SKILL_MODIFIERS := ["strength","high_priestess"]

static func effect_type(id: String) -> EffectType:
	if id in ROLL_FACE_SETTINGS or id == "star": return EffectType.ROLL_SETTING
	if id in ROLL_TRIGGERS: return EffectType.ROLL_TRIGGER
	if id in NEXT_SKILL_MODIFIERS: return EffectType.NEXT_SKILL
	return EffectType.IMMEDIATE

const BACK = preload("res://assets/art/tarot/back.png")
const ITEMS := {
	"fool": {"name": "The Fool", "design": "Reroll every owned relic. New relics cannot match any previously owned relic.", "target": "owned_item", "art": "res://assets/art/tarot/00.png", "implemented": true},
	"magician": {"name": "The Magician", "design": "Set all three dice for the next throw. Later dice settings replace this; transformations still apply.", "target": "dice", "art": "res://assets/art/tarot/01.png", "implemented": true},
	"high_priestess": {"name": "The High Priestess", "design": "The next damaging skill gains one extra use. Excludes buffs and instant kills.", "target": "self", "art": "res://assets/art/tarot/02.png", "implemented": true},
	"empress": {"name": "The Empress", "design": "Receive two random tarot cards.", "target": "self", "art": "res://assets/art/tarot/03.png", "implemented": true},
	"emperor": {"name": "The Emperor", "design": "Receive a random item.", "target": "self", "art": "res://assets/art/tarot/04.png", "implemented": true},
	"hierophant": {"name": "The Hierophant", "design": "Gain a random revelation face for the next throw. If it appears, the roll becomes that triple.", "target": "dice", "art": "res://assets/art/tarot/05.png", "implemented": true},
	"lovers": {"name": "The Lovers", "design": "Choose all odd or all even dice for the next throw.", "target": "dice", "art": "res://assets/art/tarot/06.png", "implemented": true},
	"chariot": {"name": "The Chariot", "design": "Deal 50 base damage to all enemies.", "target": "all_enemies", "art": "res://assets/art/tarot/07.png", "implemented": true},
	"strength": {"name": "Strength", "design": "Add one extra base damage or support potency to the next skill. Repeated Strength stacks additively.", "target": "self", "art": "res://assets/art/tarot/08.png", "implemented": true},
	"hermit": {"name": "The Hermit", "design": "Become invisible for three turns; attacking breaks invisibility.", "target": "self", "art": "res://assets/art/tarot/09.png", "implemented": true},
	"wheel": {"name": "Wheel of Fortune", "design": "A 1 in 4 chance of a chest; 1 in 10 of those is rare.", "target": "self", "art": "res://assets/art/tarot/10.png", "implemented": true},
	"justice": {"name": "Justice", "design": "The next throw is guaranteed to be a triple.", "target": "dice", "art": "res://assets/art/tarot/11.png", "implemented": true},
	"hanged_man": {"name": "The Hanged Man", "design": "Choose a tarot card to exclude from future draws.", "target": "tarot_type", "art": "res://assets/art/tarot/12.png", "implemented": true},
	"death": {"name": "Death", "design": "Execute a selected enemy.", "target": "enemy", "art": "res://assets/art/tarot/13.png", "implemented": true},
	"temperance": {"name": "Temperance", "design": "Skip this turn; gain an extra throw and skill use next turn.", "target": "self", "art": "res://assets/art/tarot/14.png", "implemented": true},
	"devil": {"name": "The Devil", "design": "The next triple becomes 666.", "target": "dice", "art": "res://assets/art/tarot/15.png", "implemented": true},
	"tower": {"name": "The Tower", "design": "Apply ten random statuses, each to a random character, including the player.", "target": "random_character", "art": "res://assets/art/tarot/16.png", "implemented": true},
	"star": {"name": "The Star", "design": "The next three throws are Perfect.", "target": "self", "art": "res://assets/art/tarot/17.png", "implemented": true},
	"moon": {"name": "The Moon", "design": "Apply permanent darkness to all enemies.", "target": "all_enemies", "art": "res://assets/art/tarot/18.png", "implemented": true},
	"sun": {"name": "The Sun", "design": "Fully heal and apply one burning stack to every enemy.", "target": "all", "art": "res://assets/art/tarot/19.png", "implemented": true},
	"judgement": {"name": "Judgement", "design": "If the enemy count is a multiple of six, execute a random half.", "target": "all_enemies", "art": "res://assets/art/tarot/20.png", "implemented": true},
	"world": {"name": "The World", "design": "Receive a random legendary item.", "target": "self", "art": "res://assets/art/tarot/21.png", "implemented": true},
}

static func draw_choices(rng: RandomNumberGenerator, banned: Array = []) -> Array:
	var eligible: Array = ITEMS.keys().filter(func(id): return id not in banned)
	var pool: Array = eligible.duplicate()
	var choices: Array = []
	if pool.is_empty(): return []
	for i in range(3):
		if pool.is_empty(): pool = eligible.duplicate()
		choices.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	return choices
