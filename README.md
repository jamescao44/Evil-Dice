# Evil Dice

A Godot 4 pixel-art dice game: grow an eldritch horror through **1v1 → 1v3 → 1v5 → 1v8 → castle-city fever**.

The shared [Chinese Google Design Doc](https://docs.google.com/document/d/1i-PEouZmzwagpz6CTa7CjMVl_UJd99-io_uB7TMgguM/edit) is the primary record for game designs and changes. Write future design updates there in Mandarin (Simplified Chinese), keeping proposals separate from implemented features. The earlier English Google Doc and `docs/game-design.md` remain reference snapshots.

## Play

Open `project.godot` in Godot and click **Run Project** for the portrait home screen. Open `scenes/home.tscn` and use **Run Current Scene** for the landscape home screen. The original `scenes/battle.tscn` and `scenes/battle_portrait.tscn` remain available for direct battle testing. Gameplay uses clicks or taps, with no keyboard controls.

The home screen has five bottom tabs, ordered **Dices / Ancients / Play / Summon / Shop**, with Play selected initially. Ancients shows The Horror, its lore and play style, and a skill reference for normal rolls, all doubles and all triples, including city variants. Swipe its portrait horizontally, drag with a mouse, or open the visual selection menu to browse the collection. Only The Horror is available; the carousel stays on it until more entries exist. Dices contains the basic Bone Dice, with a larger preview and descriptions on tap. The Play button displays the selected dice and starts a new five-stage run in the same layout. Home in the battle grimoire or ending screen leaves the run and returns to Play, retaining the current session's selections and sound/effects/speed settings. Summon is a placeholder; Shop is blank. There is no summoning, currency, purchase flow, or saved collection progression yet.

1. Click or tap inside the circular magic seal to start charging. A power marker travels back and forth, fastest near the center. Click or tap again to lock it and throw. Higher power increases combination odds and produces stronger dice motion and sound. A **Perfect** stop within ±2 pixels on the shared 288-pixel meter scale guarantees a pair or triple: 50% each in squad battles, and 100% triple in city fever. Non-Perfect triple odds cap at 25% in squads; exact doubles cap at 70% in both modes after fever normalization, with excess probability returned to normal results. There are no pity guarantees. Perfect-window positions snap visually to the center. The wider marker and bar flash white on a Perfect stop. The meter scales with the layout; it does not use physical device pixels.
2. Attacks automatically choose a random living foe. Doubles 1/4/5 attack automatically; their spare die adds damage. Doubles 2/3/6 grant regeneration, attack power, or invincibility for the spare die’s number of turns. Each consecutive hit chooses a random living foe.
3. Every living enemy acts. Dead bodies stay until the whole squad is defeated.
4. The Horror feeds, the bodies fade, and the scenery pans and shrinks as you advance and grow. Adventurers become progressively smaller: by stage three the Horror is roughly six times their height, and by stage four roughly thirteen times, leading into the city finale.
5. Stage four has eight adventurers in a staggered party. Stage five is a circular castle city with a moat, bridges, dense houses, and a towering keep. Animation speed is fixed at 2×, with no frenzy bar or hold/spam speed boost. Pair and triple probabilities receive a 1.5× fever boost (non-Perfect triple ceiling 37.5%); if their total exceeds 100%, both are normalized proportionally. Perfect guarantees a triple. Every throw still needs a charge click and a stop click; holding never automatically releases dice. Troops keep attacking while you aim. They wiggle as they run, and civilians and aristocrats flee from destroyed houses inside the walls.

Top controls: **DBG**, ordinary animation speed, sound, reduced effects, and the book-shaped grimoire. Only regeneration, attack power, and invincibility have persistent boon boxes. Hover over them for explanations; tap them in portrait. Active descriptions and grimoire entries show the actual remaining turns, including triple-three's stronger attack boon. All attack skills remain in the grimoire. Either menu pauses the charge meter and city attacks. Losing window focus cancels an unfinished charge without spending a roll. Restart after victory or defeat begins a new run.

## Combat and growth

Normal rolls still use the sum of three different dice, multiplied by 1.5 and growth, with the existing normal per-hit caps. New skills use **regular attack power 10** and ignore the old per-hit caps. Let `s` be the spare die; formulas below are before the global ×1.5, growth, and active attack-power multiplier. Round down after all multipliers, then apply shields and remaining HP.

| Face | Double | Triple |
| --- | --- | --- |
| 1 | One hit: 15 + s | Instantly kill one random foe; city: 50 base damage |
| 2 | Heal 5 at each of the next s turn starts | Restore full health, including grown maximum HP |
| 3 | ×1.5 attack power for the next s actions | ×3 attack power for the next 3 actions |
| 4 | Hit every foe for 6⅔ + s | Hit every foe for 20 |
| 5 | Three quick hits, each 10 + s | Six quick hits, each 10 |
| 6 | Invincible for s enemy phases / city roll intervals | **Annihilation**: clear squad; city: clear troops and deal 800. Heal 12 |

The stronger attack boon applies while both are active; they never multiply together. Refreshing a boon replaces its remaining duration. Attack-boon turns advance once per complete action (including support actions), never per hit. Invincibility protects the granting enemy phase / city interval, then advances on subsequent completed actions. Regeneration ticks at the next turn/roll starts. Unspent durations carry between waves. Multi-hit actions stop early when no foes remain and never hit corpses.

After each squad victory, gain 30 maximum HP and heal 55 up to the new maximum. Growth power is 1 / 1.5 / 3 / 5.625 / 6.75. Normal caps are ⅓ / ⅓ / ½ / ¾ of each foe’s maximum HP. Growth is fixed, with no mutation choices.

The city has 2,400 HP and applies an extra ×2 siege multiplier to damaging skills and normal attacks. **666 always deals 800**, unaffected by growth or attack boons and limited by remaining city HP. City 111 deals 5× regular attack power, not an instant city kill. AoE clears all troops; each rapid hit removes at most one troop. Heal and power-up triples do no damage and do not clear troops. Invincibility blocks both troop and ranged damage; city timers and reinforcements continue. Buildings and walls turn to rubble as health falls.

## Debug dice

Click **DBG**, choose an illustrated double/triple or **Random Singles**, then charge and throw normally. Singles always have three different faces; doubles randomize the spare die. Selection applies once unless **Repeat** is on. **Natural Random** restores power-weighted rolls. Debug outcomes override power and fever odds, even on a Perfect stop.

## Presentation and assets

- Shared public Dungeon Crawl Stone Soup character/scenery art, fantasy stone panels, and Silkscreen pixel lettering.
- Landscape restores its original radius-144 circle and dice size. Portrait uses a slightly larger radius-232 circle with proportionally larger dice and spread triangular positions, clear of the meter and phone safe areas. Its five top controls fit beside the round counter in one compact row; the battlefield extends upward from y=330 to y=228. Both headers show only round progress and controls, without the game title or location name.
- Large PAIR/TRIPLE bursts pop from the dice center, then rise and fade. Skill names appear without a window in large outlined pixel text around the upper third of the screen, with a short effect below; Annihilation has no subtitle.
- After landing, normal-roll numbers gather into one sum and fly into the Horror. Doubles and triples form one compact group of two or three matching mini dice, with pips instead of digits, and fly together as a single emblem. A magic-circle pulse marks absorption before the skill executes. The right panel no longer repeats dice numbers or numerical results.
- Every multi-enemy squad uses displaced positions and matching health-bar placement. City panic uses the same public sprite collection, follows ruined houses, and pauses with the menus.
- Glowing magic seals, slash impacts, feeding particles, persistent bodies, and scenery motion. Normal attacks give a small screen shake; triples give a larger one. Reduced effects disables shaking.
- Restored original dice rolling, landing, and reveal chimes; retained heavier weapon and spell impacts. All sounds come from Kenney's CC0 packs.
- See [asset credits and licenses](assets/CREDITS.md) and the [design document](docs/game-design.md).

Tested with **Godot 4.7.2**, Compatibility renderer on Windows. No external packages or plugins. No saved progression, gacha, or additional playable monsters yet. Existing exported executables must be re-exported from Godot to include source changes.

Web builds use the browser's adaptive canvas size and device-pixel ratio. The 402×874 preview-window override applies only to native desktop runs; applying it on Web can shrink the game into the bottom-left corner on high-density iPhone screens. Export the Web preset to `export-web/index.html` and upload all generated runtime files together, with `index.html` at the ZIP root. The generated folder is excluded from Godot imports.

## Development

The [Chinese design document](https://docs.google.com/document/d/1i-PEouZmzwagpz6CTa7CjMVl_UJd99-io_uB7TMgguM/edit) is current. The local design snapshot predates these changes. Rolls are independent of prior outcomes; the former three-roll match and six-roll triple guarantees have been removed.

| File | Responsibility |
| --- | --- |
| `scripts/home.gd` | Portrait/landscape home tabs, touch and mouse carousel, collection/skill views, battle launch and return |
| `scripts/home_catalog.gd` | Current Ancient and dice entries, lore, play style, and collection identifiers |
| `scripts/battle_rules.gd` | Seeded power/fever odds, classification, capped squad combat, buffs, enemy actions |
| `scripts/run_rules.gd` | Wave composition, growth, carryover, city damage and real-time attack cadence |
| `scripts/battle.gd` | Mouse input, debug picker, scene flow, bodies, travel, city and interface rendering |
| `scripts/die.gd` | Cosmetic dice animation, speed, landing and combination glow |
| `scripts/throw_meter.gd` | Shared timing curve, power and Perfect window for both layouts |
| `scripts/battle_portrait.gd` | Phone layout and touch-sized controls; inherited combat flow |
| `scripts/effects.gd` | Slashes, magic circles, spells, feeding, particles and floating numbers |
| `scripts/pixel_paint.gd` | Shared pixel geometry |
| `scripts/city_paint.gd` | Circular castle-city layout, dense town, towers, walls, moat, bridges, and ruins |
| `scripts/city_life.gd` | Cosmetic inhabitants, destruction-triggered spawning, bounded fleeing movement, and restart cleanup |

Run from the project directory, replacing `godot` with your executable path:

```powershell
godot --headless --path . --script res://tests/test_battle.gd
godot --headless --path . --script res://tests/test_run.gd
godot --headless --path . --script res://tests/test_city_life.gd
godot --headless --path . --script res://tests/smoke_scene.gd
godot --headless --path . --script res://tests/smoke_scene.gd -- --portrait
godot --headless --path . --script res://tests/test_throw_power.gd
godot --headless --path . --script res://tests/test_portrait.gd
godot --headless --path . --script res://tests/test_skills.gd
godot --headless --path . --script res://tests/test_dice_channel.gd
godot --headless --path . --script res://tests/test_home.gd
```

`tests/capture_visuals.gd` renders snapshots to `test-output/` when run with a display. Debug no longer requires a `--demo` launch argument.

The fixed-seed full-run sample uses zero throw power and a fixed 1.5 seconds per city roll. It is a legacy automated combat baseline, not a balance estimate for players using the timing meter. `test_skills.gd` checks each new damage formula, consecutive-hit resolution, corpse retargeting, shields, boon lifetimes, and city adaptations. `test_throw_power.gd` checks weighted probabilities, the Perfect window, charge/stop input, pause, restart, debug overrides, and city attacks while charging in both layouts. `tests/capture_power.gd` renders low/high power, Perfect, throws, and city charging to `test-output/`.
