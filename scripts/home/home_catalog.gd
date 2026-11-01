extends RefCounted
## Collection entries are shared by the carousel, picker, details and battle loadout.
const ANCIENTS := [{
	"id": "horror", "name": "The Horror", "epithet": "The uninvited",
	"art": "flameling", "style": "Conjures forbidden arcane.",
	"lore": "The damned of Rivia tell of a hunger beneath the drowned chapel. They stopped saying its name. It kept answering.",
	"traits": "DEVOUR / FREEZE / OVERWHELM",
	"skill_set": "horror",
}]
const DICES := [{
	"id": "bone", "name": "Bone Dice", "rarity": "BASIC", "face": 5,
	"description": "Six six-sided dice, carved from bones whose owner is best left unasked. A familiar weight. An unfamiliar whisper.",
	"effect": "Matches attack on the first throw. Reroll individual dice up to four times, then cast one straight skill to end your turn.",
}]
