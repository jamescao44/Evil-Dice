extends RefCounted
## Data from the Mandarin design document, including tarot-related relics.
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, CURSED }
const Sets = preload("res://scripts/relics/relic_sets.gd")
const Status = preload("res://scripts/status/status_effect.gd")
const MAX_SLOTS := 10
const SALVAGE_VALUES := [10,30,80,120,120]
const RARITY_WEIGHTS := [58.0, 30.0, 10.0, 1.0, 1.0]
const RARITY_NAMES := ["COMMON", "RARE", "EPIC", "LEGENDARY", "CURSED"]
const COLORS := [Color.WHITE, Color("72bbfe"), Color("c060ff"), Color("f9cb9c"), Color("dd7e6b")]
const STONES := Sets.MAGIC_STONES
const CURSED_DICE := {"cursed_die":6,"cursed_die_5":5,"cursed_die_4":4,"cursed_die_3":3,"cursed_die_2":2,"cursed_die_1":1}
const DISABLED := ["cursed_watch", "cursed_die_5", "cursed_die_4", "cursed_die_3", "cursed_die_2", "cursed_die_1"]
const ITEMS := {
	"rusty_round_shield": {"name":"Rusty Round Shield","rarity":1,"icon":"rusty_round_shield","sprite":"rusty_round_shield.svg","text":"After the first HP loss each turn, gain 10% max HP as shield until the enemy phase ends.","reactive_shield":0.1},
	"enchanted_core": {"name":"Enchanted Core","rarity":2,"icon":"enchanted_core","sprite":"enchanted_core.svg","text":"Appears after collecting the four Warrior relics. Fuses them into a Golden Warrior.","requires_set_parts":true},
	"golden_warrior": {"name":"Golden Warrior","rarity":3,"icon":"golden_warrior","sprite":"enchanted_core.svg","fusion":true,"icon_aura":Color("ffdf72"),"text":"Summon a warrior with 30% of your max HP. Initial throws fire two spears for 1x base damage each; Perfect fires three. Shares half of incoming attack damage and counters for 1x base damage. Returns three turns after falling.","attack_motion":{"kind":"spear"},"roll_attack":{"base_scale":1.0,"count":2},"guardian":{"health_ratio":0.3,"share":0.5,"counter_scale":1.0,"recovery_turns":3,"perfect_hits":3}},
	"diamond_crown": {"name":"Diamond Crown","rarity":2,"icon":"diamond_crown","text":"Area damage +20%, including item attacks.","sprite":"diamond_crown.svg","stats":{"area_factor":1.2}},
	"resonance_stone": {"name":"Resonance Stone","rarity":2,"icon":"resonance_stone","text":"Damage multiplier +1 per two collected Magic Stones. Fusion preserves the bonus.","sprite":"resonance_stone.svg"},
	"iron_chain": {"name":"Iron Chain","rarity":0,"icon":"iron_chain","text":"Protect an active Perfect combo from two misses, then disappear. Perfectionism is used first.","sprite":"iron_chain.svg","counter":"charges","initial_state":{"charges":2}},
	"trident": {"attack_motion":{"kind":"jab","tip_degrees":-90.0},"name":"Trident","rarity":3,"icon":"trident","text":"After the initial throw, attack random enemies three times for 2x base damage each.","sprite":"trident.svg","roll_attack":{"base_scale":2.0,"count":3}},
	"war_hammer": {"attack_motion":{"kind":"jab","tip_degrees":-90.0},"name":"War Hammer","rarity":1,"icon":"war_hammer","text":"After the initial throw, deal 0.5x base damage to all enemies.","sprite":"war_hammer.svg","roll_attack":{"base_scale":0.5,"area":true}},
	"worn_spear": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Rusty Spear","rarity":0,"icon":"worn_spear","text":"After the initial throw, attack random enemies twice for 0.5x base damage each.","sprite":"worn_spear.svg","roll_attack":{"base_scale":0.5,"count":2}},
	"teishoku": {"name":"Teishoku Set","rarity":3,"icon":"teishoku","text":"Fuse five Teishoku ingredients, retaining their effects. Base damage +20.","sprite":"teishoku.svg","fusion":true},
	"tempura": {"name":"Shrimp Tempura","rarity":2,"icon":"tempura","text":"Damage multiplier x1.5.","sprite":"tempura.svg","stats":{"damage_factor":1.5}},
	"pickles": {"name":"Pickles","rarity":1,"icon":"pickles","text":"Base damage +5.","sprite":"pickles.svg","stats":{"base_damage":5.0}},
	"salad": {"name":"Salad","rarity":0,"icon":"salad","text":"Damage multiplier +0.4.","sprite":"salad.svg","stats":{"damage_add":0.4}},
	"miso_soup": {"name":"Miso Soup","rarity":0,"icon":"miso_soup","text":"Damage multiplier +0.4.","sprite":"miso_soup.svg","stats":{"damage_add":0.4}},
	"rice": {"name":"Rice","rarity":0,"icon":"rice","text":"Base damage +5.","sprite":"rice.svg","stats":{"base_damage":5.0}},
	"basic_crystal": {"name":"Basic Crystal", "rarity":0, "icon":"basic_crystal", "text":"Base damage +5.", "stats":{"base_damage":5.0}, "sprite":"basic_crystal.svg"},
	"warrior_greatsword": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Warrior Greatsword","rarity":1,"icon":"warrior_greatsword","text":"After each skill cast, attack a random enemy for 2x base damage.","after_skill_attack":{"base_scale":2.0},"sprite":"warrior_greatsword.svg"},
	"intermediate_crystal": {"name":"Intermediate Crystal", "rarity":1, "icon":"intermediate_crystal", "text":"Base damage +10.", "stats":{"base_damage":10.0}, "sprite":"intermediate_crystal.svg"},
	"master_crystal": {"name":"Master Crystal", "rarity":2, "icon":"master_crystal", "text":"Base damage +20.", "stats":{"base_damage":20.0}, "sprite":"master_crystal.svg"},
	"supreme_crystal": {"name":"Supreme Crystal", "rarity":3, "icon":"supreme_crystal", "text":"Damage multiplier +3.", "stats":{"damage_add":3.0}, "sprite":"supreme_crystal.svg"},
	"phoenix_feather": {"name":"Phoenix Feather", "rarity":2, "icon":"phoenix_feather", "text":"Base damage +5. At turn start, apply 2 Burning to a random enemy.", "stats":{"base_damage":5.0}, "turn_start_status":{"status":Status.BURNING,"stacks":2}, "sprite":"phoenix_feather.svg"},
	"hour_hand": {"name":"Hour Hand", "rarity":0, "icon":"hour_hand", "text":"Every 3 completed turns, this relic gains +0.1 damage multiplier.", "turn_growth":{"period":3,"amount":0.1}, "sprite":"hour_hand.svg"},
	"minute_hand": {"name":"Minute Hand", "rarity":1, "icon":"minute_hand", "text":"Every 2 completed turns, this relic gains +0.1 damage multiplier.", "turn_growth":{"period":2,"amount":0.1}, "sprite":"minute_hand.svg"},
	"second_hand": {"name":"Second Hand", "rarity":2, "icon":"second_hand", "text":"Every completed turn, this relic gains +0.1 damage multiplier.", "turn_growth":{"period":1,"amount":0.1}, "sprite":"second_hand.svg"},
	"handless_clock": {"name":"Handless Clock", "rarity":0, "icon":"handless_clock", "text":"A clock waiting for its hands.", "sprite":"handless_clock.svg"},
	"demon_clock": {"name":"Demon Clock", "rarity":3, "icon":"demon_clock", "text":"Combines all Clock effects and their growth. Damage multiplier +1.5.", "fusion":true, "sprite":"demon_clock.svg"},
	"beast_fang": {"name":"Beast Fang","rarity":0,"icon":"beast_fang","text":"Base damage +3. Attacks have a 30% chance to apply 1 Plague.","stats":{"base_damage":3.0},"hit_status":{"status":"plague","chance":0.3,"stacks":1},"sprite":"beast_fang.svg"},
	"firebird_feather": {"name":"Firebird Feather","rarity":0,"icon":"firebird_feather","text":"Base damage +3. Attacks have a 30% chance to apply 1 Burning.","stats":{"base_damage":3.0},"hit_status":{"status":"burning","chance":0.3,"stacks":1},"sprite":"firebird_feather.svg"},
	"snowball": {"name":"Snowball","rarity":0,"icon":"snowball","text":"Base damage +3. Attacks have a 10% chance to apply 1 Frozen.","stats":{"base_damage":3.0},"hit_status":{"status":"frozen","chance":0.1,"stacks":1},"sprite":"snowball.svg"},
	"challenger_badge": {"name":"Challenger's Badge", "rarity":2, "icon":"challenger_badge", "text":"Random attacks focus on the marked foe, ignoring taunt. Drag the mark to change targets.", "sprite":"challenger_badge.svg"},
	"mystery_potion": {"name": "Mysterious Potion", "rarity": 0, "icon": "mystery_potion", "text": "Attacks have a 10% chance to apply 1 random status stack."},
	"ticket": {"name": "Ticket", "rarity": 0, "icon": "ticket", "text": "Gain 2 extra rolls each turn. Spent last; do not earn treasure progress.", "extra_rolls":2, "sprite":"ticket.svg"},
	"banana": {"name":"Candle","rarity":0,"icon":"banana","text":"Damage multiplier +0.5. 20% chance to burn out at turn end, unlocking Magic Candle.","stats":{"damage_add":0.5},"vanish_chance":0.2,"vanish_unlock":"magic_banana","excluded_after_unlock":"magic_banana","sprite":"candle.svg"},
	"unknown_arm": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Unidentified Arm","rarity":0,"icon":"unknown_arm","text":"After the initial throw, attack a random enemy for 0.5x base damage.","sprite":"unknown_arm.svg","roll_attack":{"base_scale":0.5}},
	"unknown_pelvis": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Unidentified Pelvis","rarity":0,"icon":"unknown_pelvis","text":"After the initial throw, attack a random enemy for 0.5x base damage.","sprite":"unknown_pelvis.svg","roll_attack":{"base_scale":0.5}},
	"unknown_leg": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Unidentified Leg Bone","rarity":0,"icon":"unknown_leg","text":"After the initial throw, attack a random enemy for 0.5x base damage.","sprite":"unknown_leg.svg","roll_attack":{"base_scale":0.5}},
	"broken_blade": {"name": "Broken Blade", "rarity": 1, "icon": "broken_blade", "text": "Damage multiplier +0.3.", "stats":{"damage_add":0.3}, "sprite":"broken_blade.svg"},
	"broken_hilt": {"name": "Broken Hilt", "rarity": 1, "icon": "broken_hilt", "text": "A broken sword handle.", "sprite":"broken_hilt.svg"},
	"precognition_eye": {"name": "Precognition Eye", "rarity": 1, "icon": "precognition_eye", "text": "Each tarot used while held permanently adds +0.05 damage multiplier to this relic."},
	"frozen_tilapia": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name": "Frozen Tilapia", "rarity": 1, "icon": "frozen_tilapia", "text": "At player-turn end, attack a random enemy for the leftover pip sum as base damage."},
	"unknown_sternum": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Unidentified Sternum","rarity":1,"icon":"unknown_sternum","text":"After the initial throw, attack a random enemy for 1x base damage.","sprite":"unknown_sternum.svg","roll_attack":{"base_scale":1.0}},
	"unknown_skull": {"name":"Unidentified Skull","rarity":1,"icon":"unknown_skull","text":"After the initial throw, attack a random enemy for 1x base damage.","sprite":"unknown_skull.svg","roll_attack":{"base_scale":1.0}},
	"magic_banana": {"name":"Magic Candle","rarity":2,"icon":"magic_banana","text":"Damage multiplier x1.5. 1% chance to disappear at turn end.","stats":{"damage_factor":1.5},"vanish_chance":0.01,"requires_unlock":true,"sprite":"magic_candle.svg"},
	"general_sword": {"name": "General's Sword", "rarity": 2, "icon": "general_sword", "text": "Fuse both broken sword parts. Damage multiplier +2.", "fusion": true},
	"red_chip": {"name": "Enchanted Chip - Red", "rarity": 2, "icon": "red_chip", "text": "A throw with no straight grants +10 damage multiplier until the next throw or turn end.", "sprite":"red_chip.svg"},
	"blue_chip": {"name": "Enchanted Chip - Blue", "rarity": 2, "icon": "blue_chip", "text": "After a throw, cast its shortest straight at 30% base damage without spending dice.", "sprite":"blue_chip.svg"},
	"black_chip": {"name": "Enchanted Chip - Black", "rarity": 3, "icon": "black_chip", "text": "After a throw, cast its longest straight at 30% base damage without spending dice.", "sprite":"black_chip.svg"},
	"unidentified_ring": {"name": "Unidentified Ring", "rarity": 2, "icon": "unidentified_ring", "text": "Appears in rewards after gathering all five bones.", "requires_set_parts":true},
	"hellfire": {"name": "Hellfire", "rarity": 3, "icon": "hellfire", "text": "Burning enemies take 30% more damage."},
	"nightmare_totem": {"name": "Nightmare Totem", "rarity": 3, "icon": "nightmare_totem", "text": "Enemies in Darkness take 30% more damage.", "sprite":"nightmare_totem.svg"},
	"corrupt_crystal": {"name": "Corrupted Crystal", "rarity": 3, "icon": "corrupt_crystal", "text": "Corroded enemies take 30% more damage."},
	"potion_x": {"name": "Potion X", "rarity": 3, "icon": "potion_x", "text": "At 10 Plague, kill the enemy; bosses lose 30% of current HP. Once per enemy or boss phase."},
	"witch_ghost": {"attack_motion":{"kind":"witch"},"name":"Ghost of the Witch","rarity":3,"icon":"witch_ghost","text":"After the initial throw, attack a random enemy for 5x base damage.","fusion":true,"sprite":"unidentified_ring.png","icon_aura":Color("bc8bff"),"roll_attack":{"base_scale":5.0}},
	"holy_grail": {"name": "Holy Grail", "rarity": 4, "icon": "holy_grail", "text": "Item damage x2. Skill damage x0.5.", "sprite":"holy_grail.svg"},
	"vodka": {"name":"Vodka", "rarity":1, "icon":"vodka", "text":"Enemy Burning damage x2."},
	"mysterious_seed": {"name":"Mysterious Seed", "rarity":1, "icon":"mysterious_seed", "text":"Store 20% of overhealing as base damage. Fire at a random enemy at player-turn end."},
	"magic_bandage": {"name":"Magic Bandage", "rarity":1, "icon":"magic_bandage", "text":"If a turn starts below full HP, healing is doubled for that turn."},
	"steel_sword": {"name":"Steel Sword", "rarity":2, "icon":"steel_sword", "text":"Damage multiplier +1.5.", "stats":{"damage_add":1.5}},
	"split_arrow": {"name":"Split Arrow","rarity":2,"icon":"split_arrow","text":"Single-target skills split into two random hits at 60% damage each."},
	"pet_orb": {"name":"Super Pet Ball", "rarity":3, "icon":"pet_orb", "fusion":true, "text":"Fuse all five pets, keeping their upgraded effects.", "sprite":"pet_ball.svg"},
	"book_of_dead": {"name":"Book of the Dead", "rarity":4, "icon":"book_of_dead", "text":"Maximum HP x3. Lose 30% of current HP at turn end; cannot kill you.", "stats":{"max_hp_factor":3.0}},
	"glass_marble": {"name":"Glass Marble", "rarity":0, "icon":"glass_marble", "text":"Three-straight skill damage +10%. Marble bonuses add together.", "stats":{"three_straight_bonus":0.1}},
	"blood_bag": {"name":"Blood Bag", "rarity":0, "icon":"blood_bag", "text":"Healing and lifesteal +10%."},
	"piggy_bank": {"counter":"savings", "name":"Piggy Bank", "rarity":0, "icon":"piggy_bank", "text":"Store an extra 20% of enemy blood gem drops in this relic's sale value."},
	"bookmark": {"name":"Bookmark", "rarity":0, "icon":"bookmark", "text":"Gain 100 shield when using a tarot."},
	"cross": {"name":"Cross", "rarity":1, "icon":"cross", "text":"Enemy tarot drop chance +5 percentage points."},
	"light_sword": {"name":"Light Sword", "rarity":1, "icon":"light_sword", "text":"Damage multiplier +2 while only one enemy remains."},
	"steel_marble": {"name":"Steel Marble", "rarity":1, "icon":"steel_marble", "text":"Three-straight skill damage +20%. Marble bonuses add together.", "stats":{"three_straight_bonus":0.2}},
	"perfectionist": {"counter":"charges", "name":"Perfectionism", "rarity":1, "icon":"perfectionist", "text":"Three consecutive Perfect throws protect your combo from one miss. Stores one protection."},
	"overflow_prism": {"name":"Overflow Prism","rarity":3,"icon":"overflow_prism","text":"Single-target attacks repeat 30% damage on a random living enemy. Area attacks do not trigger this."},
	"gold_marble": {"name":"Golden Marble", "rarity":2, "icon":"gold_marble", "text":"Three-straight skill damage +30%. Marble bonuses add together.", "stats":{"three_straight_bonus":0.3}},
	"powder_keg": {"name":"Powder Keg","rarity":2,"icon":"powder_keg","text":"At 10 Burning, consume 5 stacks and explode for 5x base damage to all enemies."},
	"echo_bell": {"name":"Echo Bell", "rarity":2, "icon":"echo_bell", "text":"Every third skill repeats at 50% effect. The repeat does not count as a skill cast."},
	"alternating_gears": {"name":"Alternating Gears", "rarity":2, "icon":"alternating_gears", "text":"Skill damage +50% when its type differs from the previous skill."},
	"enchanted_missile": {"name":"Enchanted Missile", "rarity":3, "icon":"enchanted_missile", "fusion":true, "text":"Fuse three marbles and Magic Slingshot. Base damage +10; three-straight damage +100%. Fire a half-pip-sum attack after each throw. At turn start, cast your character's 3-4-5 straight skill."},
	"royal_seal": {"name":"Royal Seal", "rarity":3, "icon":"royal_seal", "text":"Your first manual skill each wave casts one tier higher, up to a six-straight."},
	"magician_hat": {"name":"Magician's Hat", "rarity":3, "icon":"magician_hat", "text":"Receive a Magician tarot immediately, then another every 4 completed turns.", "tarot_generator":{"period":4,"card":"magician"}},
	"lemon_soda": {"name": "Lemon Soda", "rarity": 0, "icon": "lemon_soda", "text": "Auto-attack damage +5. Meal ingredient.", "stats":{"auto_damage":5.0}},
	"oreo_sundae": {"name": "Cookie Sundae", "rarity": 1, "icon": "oreo_sundae", "text": "Base damage +7. Meal ingredient.", "stats":{"base_damage":7.0}, "sprite":"oreo_sundae.tres"},
	"fried_chicken": {"name": "Fried Chicken", "rarity": 1, "icon": "fried_chicken", "text": "Damage multiplier x1.1. Meal ingredient.", "stats":{"damage_factor":1.1}},
	"budget_meal": {"name": "Budget Meal", "rarity": 0, "icon": "budget_meal", "text": "Combines two food effects, then adds +0.3 damage multiplier.", "fusion": true},
	"happy_meal": {"name": "Happy Trio", "rarity": 1, "icon": "happy_meal", "text": "Combines three food effects, then adds +0.5 damage multiplier.", "fusion": true},
	"deluxe_meal": {"name": "Deluxe Quartet", "rarity": 2, "icon": "deluxe_meal", "text": "Combines four food effects, then adds 5 base damage and +0.5 damage multiplier.", "fusion": true},
	"super_meal": {"name": "Super Feast", "rarity": 3, "icon": "super_meal", "text": "Combines five food effects, then adds 5 base damage and +1.5 damage multiplier.", "fusion": true},

	"codex_page": {"counter":"count", "name":"Codex Page", "rarity":0, "icon":"page", "text":"DMG +0.2 per page. Pages share one slot; 10 fuse into an Ancient Codex.", "stats":{"damage_add":0.2}},
	"heart": {"name":"Beating Heart", "rarity":0, "icon":"heart", "text":"Maximum health +10%.", "stats":{"max_hp_factor":1.1}},
	"bracelet": {"name":"Spell Bracelet", "rarity":0, "icon":"bracelet", "text":"Damage multiplier +0.4.", "stats":{"damage_add":0.4}},
	"armor": {"name":"Rusty Armor", "rarity":0, "icon":"armor", "text":"Take 10% less damage.", "stats":{"incoming_factor":0.9}},
	"coin": {"name":"Game Coin", "rarity":0, "icon":"coin", "text":"Gain 67 blood gems after clearing a wave.", "stats":{"wave_rubies":67}},
	"fortune_cookie": {"name":"Fortune Cookie", "rarity":0, "icon":"cookie", "text":"Receive a random tarot immediately, then another every 5 completed turns.", "tarot_generator":{"period":5,"card":""}},
	"magic_shield": {"counter":"charges", "name":"Magic Shield", "rarity":2, "icon":"shield", "text":"Every 4 completed turns, store a shield that blocks one whole hit.", "turn_charge":{"period":4,"message":"SHIELD READY"}},
	"magic_sword": {"counter":"charges", "name":"Magic Sword", "rarity":2, "icon":"sword", "text":"Base damage +10. Every 4 completed turns, store a 3x critical for the next attack skill and all its hits.", "stats":{"base_damage":10.0}, "turn_charge":{"period":4,"message":"CRITICAL READY"}},
	"runestone": {"name":"Runestone", "rarity":2, "icon":"rune", "text":"Base damage +5. Apply 1 extra stack of harmful status effects.", "stats":{"base_damage":5.0}},
	"lucky_die": {"name":"Lucky Die", "rarity":1, "icon":"die", "text":"After 10 throws, the next throw with at least four unused dice guarantees a four-straight. Tarot rules take priority."},
	"bloodstone": {"name":"Bloodstone", "rarity":1, "icon":"blood", "text":"Heal for 200% of attack damage. Cap: 10% max HP, or 5% per combo hit."},
	"twin_scythes": {"name":"Twin Scythes", "rarity":3, "icon":"scythes", "text":"Double the number of hits in combo skills.", "stats":{"combo_uses_factor":2}},
	"contract": {"name":"Last Contract", "rarity":2, "icon":"contract", "text":"Base damage +5. Prevent death once and restore 60% max HP. Consumed on use.", "stats":{"base_damage":5.0}},
	"crystal_ball": {"name":"Crystal Ball", "rarity":3, "icon":"orb", "text":"At turn start, receive a random projection tarot. Unused projections vanish at turn end."},
	"orange_stone": {"name":"Fire Stone", "rarity":2, "icon":"stone", "color":Color("ff9955"), "text":"Base damage +5. Immune to burning. Every attack applies 1 burning stack.", "stats":{"base_damage":5.0}, "sprite":"magic_gem.svg", "tint_sprite":true},
	"blue_stone": {"name":"Ice Stone", "rarity":2, "icon":"stone", "color":Color("82dfff"), "text":"Base damage +5. Immune to freeze. Attacks have a 30% chance to freeze.", "stats":{"base_damage":5.0}, "sprite":"magic_gem.svg", "tint_sprite":true},
	"purple_stone": {"name":"Dark Stone", "rarity":2, "icon":"stone", "color":Color("c18ce8"), "text":"Base damage +5. Immune to darkness. Attacks have a 30% chance to inflict darkness.", "stats":{"base_damage":5.0}, "sprite":"magic_gem.svg", "tint_sprite":true},
	"yellow_stone": {"name":"Mind Stone", "rarity":2, "icon":"stone", "color":Color("ffe388"), "text":"Base damage +5. Immune to stun. Each Perfect adds 2 to the combo counter.", "stats":{"base_damage":5.0}, "sprite":"magic_gem.svg", "tint_sprite":true},
	"green_stone": {"name":"Corruption Stone", "rarity":2, "icon":"stone", "color":Color("8ad26a"), "text":"Base damage +5. Immune to corrosion. Attacks have a 50% chance to corrode.", "stats":{"base_damage":5.0}, "sprite":"magic_gem.svg", "tint_sprite":true},
	"black_stone": {"name":"Plague Stone", "rarity":2, "icon":"stone", "color":Color("8b8599"), "text":"Base damage +5. Every attack applies plague.", "stats":{"base_damage":5.0}, "sprite":"magic_gem.svg", "tint_sprite":true},
	"prismatic_stone": {"name":"Prismatic Stone","rarity":3,"icon":"prism","fusion":true,"text":"All six stone effects; +30 total base damage. Each Perfect attacks a random enemy for 3x base damage.","stats":{},"sprite":"magic_gem.svg","tint_sprite":true,"roll_attack":{"base_scale":3.0,"perfect":true}},
	"mithril_blade": {"name":"Mithril Blade","rarity":3,"icon":"blade","text":"Base damage +30. Damage multiplier +1.5.","stats":{"base_damage":30.0,"damage_add":1.5}},
	"ancient_prophecy": {"name":"Ancient Prophecy", "rarity":3, "icon":"book", "text":"Each tarot activates twice. Make new choices when needed; normal stacking and overwrite rules apply.", "stats":{"tarot_repeat":true}},
	"ancient_codex": {"name":"Ancient Codex", "rarity":3, "icon":"book", "fusion":true, "text":"Double damage independently. Made by combining 10 Codex Pages.", "stats":{"damage_factor":2.0}},
	"cursed_skull": {"name":"Cursed Skull", "rarity":4, "icon":"skull", "text":"A skill containing 6 doubles DMG; without 6, halves DMG."},
	"cursed_die": {"name":"Cursed Die", "rarity":4, "icon":"die", "text":"Three visible sixes turn all dice into sixes. No skills while no six is visible.", "sprite":"cursed_die.svg"},
	"reaper_scythe": {"counter":"kills", "name":"Cursed Scythe", "rarity":4, "icon":"scythe", "text":"Each kill adds +5% damage, up to +200%. Halve max HP. City troops do not count.", "stats":{"max_hp_factor":0.5,"damage_per_kill":0.05,"kill_damage_cap":2.0}},
	"cursed_bow": {"counter":"waves", "name":"Cursed Bow", "rarity":4, "icon":"bow", "text":"Each wave cleared while owned adds 1 combo hit and multiplies single-target damage by 0.95. Compounds each wave.", "stats":{"combo_uses_per_wave":1,"single_target_factor_per_wave":0.95}},
	"cursed_watch": {"name":"Cursed Stopwatch", "rarity":4, "icon":"watch", "text":"Always Perfect. Never roll 666. Cannot gain Reroll Treasure progress.", "stats":{"always_perfect":true,"no_ultimate":true,"no_treasure":true}},
	"worn_dagger": {"name": "Worn Dagger", "rarity": 0, "icon": "worn_dagger", "text": "Base damage +2. Combo skills gain 1 extra hit.", "stats":{"combo_uses_add":1,"base_damage":2.0}},
	"worn_bow": {"name": "Worn Longbow", "rarity": 0, "icon": "worn_bow", "text": "After the initial throw, attack a random enemy for 0.5x base damage."},
	"three_leaf_clover": {"name":"Three-leaf Clover", "rarity":0, "icon":"three_leaf_clover", "text":"Each eligible throw has a 20% chance to guarantee at least a three-straight. Tarot rules take priority.", "sprite":"three_leaf_clover.svg"},
	"four_leaf_clover": {"name": "Four-leaf Clover", "rarity": 1, "icon": "four_leaf_clover", "text": "Each eligible throw has a 10% chance to guarantee at least a four-straight. Tarot rules take priority.", "sprite":"four_leaf_clover.svg"},
	"fries": {"name": "Fries", "rarity": 0, "icon": "fries", "text": "Damage multiplier +0.3.", "stats":{"damage_add":0.3}, "sprite":"fries.tres"},
	"tissue_pack": {"name": "Tissue Pack", "rarity": 0, "icon": "tissue_pack", "text": "After an initial throw with no straight, attack a random enemy for 1x base damage."},
	"pet_bat": {"name": "Pet Bat", "rarity": 0, "icon": "pet_bat", "text": "Heal 1% max HP per attack. With all five pets: 2%.", "sprite":"pet_food_bat.svg"},
	"magic_slingshot": {"name":"Magic Slingshot","rarity":1,"icon":"magic_slingshot","text":"Base damage +2. After the initial throw, attack a random enemy for 50% of the rolled pip sum as base damage.","stats":{"base_damage":2.0}},
	"hamburger": {"name": "Hamburger", "rarity": 1, "icon": "hamburger", "text": "Damage multiplier +0.6.", "stats":{"damage_add":0.6}, "sprite":"hamburger.tres"},
	"soul_vessel": {"name": "Soul Vessel", "rarity": 1, "icon": "soul_vessel", "text": "Souls dropped by enemies +15%."},
	"pet_lizard": {"name": "Pet Lizard", "rarity": 1, "icon": "pet_lizard", "text": "Apply 2 extra Burning stacks. With all five pets: 4.", "sprite":"pet_food_lizard.svg"},
	"ice_rose": {"name":"Ice Rose","rarity":1,"icon":"ice_rose","text":"Freezing an enemy deals 20 base damage to all enemies.","sprite":"ice_rose.svg"},
	"pet_slime": {"name": "Pet Slime", "rarity": 1, "icon": "pet_slime", "text": "Enemy Corrosion becomes permanent. With all five pets: skill hits apply 1 Corrosion.", "sprite":"pet_food_slime.svg"},
	"spiked_helmet": {"attack_motion":{"kind":"jab","tip_degrees":-45.0},"name":"Rusty Helmet","rarity":1,"icon":"spiked_helmet","text":"Retaliate for 10 fixed damage when attacked. Each Perfect deals 1x base damage to a random enemy.","roll_attack":{"base_scale":1.0,"perfect":true}},
	"royal_dagger": {"name": "Royal Dagger", "rarity": 2, "icon": "royal_dagger", "text": "Base damage +10. Combo skills gain 3 extra hits.", "stats":{"combo_uses_add":3,"base_damage":10.0}},
	"disguise_mask": {"name": "Disguise Mask", "rarity": 3, "icon": "disguise_mask", "text": "Retrigger the relic immediately to the left once, except Cursed Tentacle."},
	"five_leaf_clover": {"name": "Five-leaf Clover", "rarity": 2, "icon": "five_leaf_clover", "text": "Each eligible throw has a 5% chance to guarantee at least a five-straight. Tarot rules take priority.", "sprite":"five_leaf_clover.svg"},
	"pet_ghost": {"name": "Pet Ghost", "rarity": 2, "icon": "pet_ghost", "text": "After each throw, deal 20 fixed damage to all enemies. With all five pets: also use the damage multiplier.", "sprite":"pet_food_ghost.svg"},
	"ancient_tentacle": {"name": "Cursed Tentacle", "rarity": 4, "icon": "ancient_tentacle", "text": "Retrigger every relic to the left once. Each extra activation costs 1% max HP and can kill you."},
	"pet_dragon": {"name":"Pet Dragon","rarity":3,"icon":"pet_dragon","text":"After the initial throw, fire two random attacks for 1.5x base damage each. With all five pets: three attacks, each applying 1 Burning.","sprite":"pet_food_dragon.svg","roll_attack":{"base_scale":1.5,"count":2}},
	"cursed_die_5": {"name": "Cursed Die - 5", "rarity": 4, "icon": "cursed_die_5", "text": "Perfect rolls always contain 5. Other rolls never contain 5.", "sprite":"cursed_die_5.svg"},
	"cursed_die_4": {"name": "Cursed Die - 4", "rarity": 4, "icon": "cursed_die_4", "text": "Perfect rolls always contain 4. Other rolls never contain 4.", "sprite":"cursed_die_4.svg"},
	"cursed_die_3": {"name": "Cursed Die - 3", "rarity": 4, "icon": "cursed_die_3", "text": "Perfect rolls always contain 3. Other rolls never contain 3.", "sprite":"cursed_die_3.svg"},
	"cursed_die_2": {"name": "Cursed Die - 2", "rarity": 4, "icon": "cursed_die_2", "text": "Perfect rolls always contain 2. Other rolls never contain 2.", "sprite":"cursed_die_2.svg"},
	"cursed_die_1": {"name": "Cursed Die - 1", "rarity": 4, "icon": "cursed_die_1", "text": "Perfect rolls always contain 1. Other rolls never contain 1.", "sprite":"cursed_die_1.svg"},
}

## Build shared effect indexes from item metadata without retaining writable nested references.
static func effect_table(field: String) -> Dictionary:
	var result: Dictionary = {}
	for id in ITEMS:
		if ITEMS[id].has(field): result[id] = ITEMS[id][field].duplicate(true)
	return result

## Every inventory, reward reel and orbit loads the same explicit or conventional asset path.
static func sprite_path(id: String) -> String:
	return "res://assets/art/relics/"+ITEMS[id].get("sprite",id+".png")

static func rarity_color(id: String) -> Color:
	return COLORS[ITEMS[id].rarity]

## Base salvage follows rarity; stacked pages pay once per page, fusions as one item.
static func forfeit_value(id: String, count: int = 1) -> int:
	if not ITEMS.has(id): return 0
	return SALVAGE_VALUES[ITEMS[id].rarity]*maxi(1,count)

## Owned savings are paid only when this particular inventory instance leaves.
static func sale_value(item: Dictionary) -> int:
	return forfeit_value(item.id,item.get("count",1))+floori(item.get("savings",0.0)+0.000001)

static func color(id: String) -> Color:
	# Element colors tint magic stones and their effects; rarity colors identify loot.
	return ITEMS[id].get("color", rarity_color(id))

static func counter_value(item: Dictionary) -> int:
	var field: String = ITEMS[item.id].get("counter","")
	return maxi(0,int(item.get(field,1 if field == "count" else 0))) if not field.is_empty() else 0

static func charged(item: Dictionary) -> bool:
	return item.get("throws",0) >= 10 if item.id == "lucky_die" else ITEMS[item.id].get("counter","") == "charges" and counter_value(item) > 0

static func description(item: Dictionary, translate: Callable = Callable(), owned_items: Array = []) -> String:
	var localize: Callable = translate
	if not localize.is_valid(): localize = _untranslated
	var text: String = short_description(item.id,localize,[item] if owned_items.is_empty() else owned_items)
	if item.id in DISABLED: text = localize.call("Temporarily disabled for six-dice turns.") + "\n" + text
	if CURSED_DICE.has(item.id): text += "\n" + localize.call("Only one Cursed Die can be held.")
	if item.id == "codex_page": text += "\n" + localize.call("Pages: %d / 10.") % item.get("count", 1)
	if ITEMS[item.id].has("turn_charge"): text += "\n" + localize.call("Turns: %d / %d. Stored charges: %d.") % [item.get("turns",0),ITEMS[item.id].turn_charge.period,item.get("charges",0)]
	if item.id == "lucky_die": text += "\n" + localize.call("Throws: %d / 10.") % item.get("throws",0)
	if Sets.is_fused(item.id) and Sets.recipe_for(item.id).get("retain_effects",true) and not Sets.recipe_for(item.id).get("retain_component_state",false):
		for id in Sets.ingredients(item): text += "\n" + localize.call(ITEMS[id].name) + ": " + localize.call(ITEMS[id].text)
	if ITEMS[item.id].has("tarot_generator"): text += "\n" + localize.call("Turns: %d / %d.") % [item.get("turns",0),ITEMS[item.id].tarot_generator.period]
	if ITEMS[item.id].has("guardian"):
		if item.get("guardian_recovery",0) > 0: text += "\n" + localize.call("Returns in %d turns.") % item.guardian_recovery
		elif item.has("guardian_hp"): text += "\n" + localize.call("Companion HP: %d / %d.") % [item.guardian_hp,item.guardian_max_hp]
	if item.id == "piggy_bank": text += "\n" + localize.call("Saved blood gems: %d.") % floori(item.get("savings",0.0))
	if item.id == "precognition_eye": text += "\n" + localize.call("Stored multiplier: +%.2f.") % item.get("damage_growth",0.0)
	for part in Sets.stateful_parts(item):
		var growth: Dictionary = ITEMS[part.id].get("turn_growth",{})
		if growth.is_empty(): continue
		text += "\n" + localize.call(ITEMS[part.id].name) + ": " + localize.call("Stored multiplier: +%.2f.") % part.get("damage_growth",0.0)
		text += " " + localize.call("Turns: %d / %d.") % [part.get("turns",0),growth.period]
	if item.id == "echo_bell": text += "\n" + localize.call("Skills: %d / 3.") % item.get("casts",0)
	if item.id == "reaper_scythe": text += "\n" + localize.call("Kills: %d.") % item.get("kills", 0)
	if item.id == "cursed_bow":
		text += "\n" + localize.call("Extra hits: %d.") % item.get("waves", 0)
		text += "\n" + localize.call("Single-target damage: x%.3f.") % pow(0.95,item.get("waves",0))
	return text

## Reuse set hints in compact offers and full inventory descriptions.
static func short_description(id: String, translate: Callable = Callable(), owned_items: Array = []) -> String:
	var localize: Callable = translate
	if not localize.is_valid(): localize = _untranslated
	var text: String = localize.call(ITEMS[id].text)
	var set_title: String = Sets.set_label(id)
	if not set_title.is_empty():
		var progress: Vector2i = Sets.collection_progress(id,owned_items)
		var label: String = localize.call("(Set: %s %d/%d)") % [localize.call(set_title),progress.x,progress.y]
		text = text + "\n" + label
	return text

## Identity translator keeps catalogue helpers usable outside the UI.
static func _untranslated(value: String) -> String:
	return value
