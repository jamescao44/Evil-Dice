class_name BattleLayers
extends RefCounted
## Absolute canvas-item depths: world < combat < rewards < inspection < held < pages.
const SURROUND := -3
const WORLD := -2
const BACKDROP := -1
const COMBAT := 0
const TAROT_QUICK := 10
const DICE := 20
const STATUS := 35
const SKILL := 40
const DICE_RITUAL := 52
const RITUAL_DIE := 54
const TREASURE_PICKUP := 65
const LOOT_PICKUP := 70
const REWARD_PAGE := 80
const REWARD_FX := 90
const EVOLUTION := 95
const CHEST_PICKUP := 96
const NOTICE := 100
const RELIC_UI := 110
const DAMAGE_READOUT := 115
const TAROT_QUICK_NAME := 135
const TAROT_INVENTORY := 120
const BANNER := 120
const TAROT_FX := 121
const TAROT_PICKUP := 125
const TAROT_CHOICE := 130
const RELIC_REPLACEMENT := 140
const TAROT_DRAW := 280
const ENEMY_INSPECTION := 300
const HELD_ITEM := 400
const EFFECT_INSPECTION := 460
const INVENTORY_PAGE := 450
const MENU := 500
const MENU_SHORTCUT := MENU-1

## CanvasLayer IDs are a separate ordering system; hide these while modal pages are open.
const RIPPLE_CANVAS := 128
const DAMAGE_CANVAS := 129
const DISPLAY_CANVAS := 200
