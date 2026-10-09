# Evil Dice

A Godot 4 pixel-art dice game: grow an eldritch horror through **nine randomized normal/elite waves → castle-city fever**, earning treasure through Perfect throws.

The shared [Chinese Google Design Doc](https://docs.google.com/document/d/1i-PEouZmzwagpz6CTa7CjMVl_UJd99-io_uB7TMgguM/edit) is the primary record for game designs and changes. Write future design updates there in Mandarin (Simplified Chinese), keeping proposals separate from implemented features. The earlier English Google Doc and `docs/game-design.md` remain reference snapshots.

## Play

Open `project.godot` in Godot and click **Run Project** for the portrait home screen. Open `scenes/home.tscn` and use **Run Current Scene** for the landscape home screen. The original `scenes/battle.tscn` and `scenes/battle_portrait.tscn` remain available for direct battle testing. Gameplay uses clicks or taps, with no keyboard controls.

The home screen has five bottom tabs, ordered **Dices / Ancients / Play / Summon / Shop**, with Play selected initially. Ancients shows The Horror, its lore and play style, and a skill reference for normal rolls, all doubles and all triples, including city variants. Swipe its portrait horizontally, drag with a mouse, or open the visual selection menu to browse the collection. Only The Horror is available; the carousel stays on it until more entries exist. Dices contains the basic Bone Dice, with a larger preview and descriptions on tap. The Play button displays the selected dice and starts a new ten-stage run in the same layout. Home in the battle grimoire or ending screen leaves the run and returns to Play, retaining the current session's selections and sound/effects/speed settings. Summon is a placeholder; Shop is blank. Rubies and summon shards exist only within the active run; there is no summoning, purchasing, or saved collection progression yet.

1. Click or tap inside the circular magic seal to start charging, then again to lock the marker and throw. The marker moves fastest near the center, using the gentler blended timing curve at another **10% slower overall speed** (about 2.667 seconds per round trip). The visible bar is 25% shorter: 216 landscape / 432 portrait logical pixels. Higher power increases combination odds and dice motion and sound. A **Perfect** within ±2 pixels on the shared 288-pixel reference scale guarantees a pair or triple: 50% each in squads, 100% triple in fever. Non-Perfect triples cap at 25% in squads; exact doubles cap at 70% in both modes after fever normalization. There are no pity guarantees. Perfect positions snap visually to center, and the marker and bar flash white. The same timing and reference scale apply in both layouts, independent of physical device pixels.
2. Revealed dice form a **skill bubble**, rise enlarged to the middle, then settle lower and bob with their name and description. The used dice seal turns gray and its combination lines disappear. **Drag every skill onto the battlefield to cast.** Normal attacks, 11 and 111 must land on a foe, or can be tapped first and then aimed by tapping a foe; in fever, select the city. Buffs, area skills and combos do not cast on a simple tap. Attacks dim the Horror; support skills dim enemies while selected or casting. Invalid drops preserve the skill. **55 automatically delivers three hits; 555 delivers six after one field drop.** Each hit pops a dot and independently chooses a random living foe (the city in fever); clearing the wave ends the chain. Cast bubbles stay where released and dissolve into pixel particles when finished. Enemy turns, boon clocks, the next roll and treasure claims wait for the whole action.
3. Every living enemy acts. Dead bodies stay until the whole squad is defeated.
4. The Horror feeds, the bodies fade, and the scenery pans and shrinks as you advance and grow. Adventurers become progressively smaller across nine squad waves, leading into the city finale.
5. Stage ten is a circular castle city with a moat, bridges, dense houses, and a towering keep. Animation speed is fixed at 2×, with no frenzy bar or hold/spam speed boost. Pair and triple probabilities receive a 1.5× fever boost (non-Perfect triple ceiling 37.5%); if their total exceeds 100%, both are normalized proportionally. Perfect guarantees a triple. Every throw still needs a charge click and a stop click; holding never automatically releases dice. Troops keep attacking while you aim. They wiggle as they run, and civilians and aristocrats flee from destroyed houses inside the walls.

Top controls: **DBG**, ordinary animation speed, sound, reduced effects, and the book-shaped grimoire. Active statuses appear as small independent icons directly above the Horror, each with its own remaining-turn count. Inactive or expired effects disappear individually. Regeneration, both attack boons, and invincibility use separate indicators; the stronger attack boon still takes precedence. Hover for explanations or tap in portrait. Detailed rules remain in the grimoire. Either menu pauses the charge meter and city attacks. Losing window focus cancels an unfinished charge without spending a roll. Restart after victory or defeat begins a new run.

The **SAVE slot** above and to the right of the dice stores one skill. Dragging a new skill into the empty slot ends the current turn without applying it. Later, drag the stored skill out for a bonus cast between rolls or while holding a new skill; targeted stored skills also support tap-then-select. The saved seal expands to full active size. Any waiting skill stays visible but dimmed and unavailable until the bonus finishes. Bonus casts do not add an enemy phase or tick existing boon durations; the subsequent ordinary action still does. A saved one-turn immunity protects the upcoming squad enemy phase. If a bonus cast clears the wave, an unused summoned skill automatically fills the vacated slot. Saved skills carry between waves, use current damage stats when cast, and reset with a new run. A full slot rejects replacement.

## Combat and growth

Normal rolls use the sum of three different dice plus earned base-damage bonuses, with the existing normal per-hit caps. Skills use **regular attack power P = 10 + earned base-damage bonuses** and ignore caps. Let `s` be the spare die; formulas below are before the global multiplier (1.5 + earned multiplier bonuses), growth, and the active attack boon. Round down after all multipliers, then apply shields and remaining HP.

| Face | Double | Triple |
| --- | --- | --- |
| 1 | One hit: 1.5P + s | Instantly kill one chosen foe; city: 5P base damage |
| 2 | Heal 5 at each of the next s turn starts | Restore full health, including grown maximum HP |
| 3 | ×1.5 attack power for the next s actions | ×3 attack power for the next 3 actions |
| 4 | Hit every foe for ⅔P + s | Hit every foe for 2P |
| 5 | Three automatic hits, each P + s; independently random foes | Six automatic hits, each P; independently random foes |
| 6 | Invincible for s enemy phases / city roll intervals | **Annihilation**: clear squad; city: clear troops and deal 800. Heal 12 |

The stronger attack boon applies while both are active; they never multiply together. Refreshing a boon replaces its remaining duration. Attack-boon turns advance once per complete action (including support actions), never per hit. Invincibility protects the granting enemy phase / city interval, then advances on subsequent completed actions. Regeneration ticks at the next turn/roll starts. Unspent durations carry between waves. Multi-hit actions stop early when no foes remain and never hit corpses.

After each squad victory, gain 30 maximum HP and heal 55 up to the new maximum. Growth power across ten stages is 1 / 1.5 / 3 / 5.625 / 6.75 / 7.875 / 9 / 10.125 / 11.25 / 12.375. Normal caps are ⅓ HP in stages 1–2, ½ in stage 3, and ¾ from stage 4 onward. Growth is fixed, with no mutation choices. Visual Horror size now follows 224 / 248 / 260 / 272 / 280 / 288 / 296 / 308 / 320 / 320 logical pixels: stages 3–7 grow more gradually, while combat stats and final city scale stay the same.

The city has 2,400 HP and applies an extra ×2 siege multiplier to damaging skills and normal attacks. **666 always deals 800**, unaffected by growth or attack boons and limited by remaining city HP. City 111 deals 5× regular attack power, not an instant city kill. AoE clears all troops; each rapid hit removes at most one troop. Heal and power-up triples do no damage and do not clear troops. Invincibility blocks both troop and ranged damage; city timers and reinforcements continue. Buildings and walls turn to rubble as health falls.

## Perfect treasure

Perfect throws fill **nine diamond slots**, preserved through misses and waves. The bank stops at nine until claimed. **3 Perfects = one reward; 6 = a rare chest with three rewards; 9 = a super-rare chest with five rewards.** This replaces the old random 25% three-reward bonus. The **third, sixth and ninth diamonds** are larger and glow strongly when filled. Tap a filled milestone between actions to claim its own tier; any claim empties the entire meter, including extra diamonds. There is no separate chest button. Claims are disabled while a skill forms, waits, targets or casts, including pauses between multi-hit casts. The whole skill must finish before rewards can boost subsequent actions. Unclaimed treasure remains accessible on the ending screen.

Reels independently draw from seven equal default weights, allowing duplicates. Outcomes lock before animation. A 0.38-second pause and white flash precede the chest opening and throwing loot up into extended slot reels. Five rewards use a 3+2 layout on phones and a row in landscape. **Rewards wait for individual taps after every reel stops.** Each tap applies that gift once, shows its skill-style name, and plays its category effect. Combat and city timers pause until every gift is picked up. Rubies rain; power-ups emit edge magic; curses glow ominously; relics shine. Reduced effects suppresses flash, shake, and particle bursts.

| Reward | Effect |
| --- | --- |
| Blood Rubies | +100 run rubies; ruby icon and rain replace coins |
| Sharpened Hunger | +5 base damage to normal dice sums and skill regular power |
| Unbound Power | +0.5 additive global multiplier: 1.5 → 2.0 → 2.5… |
| Forgotten Relic | Relic placeholder; no effect |
| Whispering Curse | Negative-effect placeholder; no effect |
| Crimson Draught | Potion placeholder; no healing yet |
| Summon Shard | +1 run shard, represented by a parchment contract with a magic circle |

Ruby and shard counters appear in the header. New runs clear both currencies, the Perfect bank, rewards, and bonuses; no persistent economy or summoning is implemented. Instant kills and fixed 800-damage city Annihilation remain scaling exceptions. Debug Perfects count.

Dice use weighted category and face selection. Triple faces 1–5 each have weight **1**, and 666 has weight **0.7** (about 12.28% of triple results). This preserves the total triple probability: regular Perfects remain 50% triple / 50% pair; city Perfects retain guaranteed triples. Non-Perfect caps remain 25% triples (up to 37.5% in fever) and 70% pairs. Per-run category, pair, triple, single-face, and reward weights are explicit hooks for future relic modifiers; no relic effects are active yet. Zero-power category probabilities retain their old values, but triple faces are now weighted.


## Ten waves and enemy traits

With `n` = normal and `e` = elite: **1n → 3n → 1e → 5n → 2n1e → 3n2e → 5n2e → 4e → 5n5e → city**. Roles are sampled independently and shuffled; repeated roles are allowed. Enemy base stats do not increase with the wave.

| Role | Normal HP / attack | Elite HP / attack | Support actions |
| --- | --- | --- | --- |
| Vanguard | 75 / 5 | 150 / 10 | Self-shield +6, capped at 20 |
| Mage | 35 / 10 | 75 / 15 | Self-heal 30% max HP; elite can give one other unbuffed ally ×1.5 on its next attack |
| Elf Archer | 50 / 7.5 | 100 / 10 | Elite heals all living allies, including itself, for 20% of their own max HP |

Every living enemy chooses one action per round. When useful support is available, vanguards/elite archers attack 70% of the time and mages attack 65%; otherwise they attack. Healing cannot resurrect or exceed max HP. Mage buffs do not stack and remain until the recipient attacks. Damage/healing round once to integer HP (a normal archer deals 8). All elites start with **10 shield**. A shield absorbs an entire hit even when that hit breaks it: no excess reaches health. Later hits in a combo can hit HP. Triple 1 and squad Annihilation ignore shields. Elites reuse the sprites with gold vanguard, violet mage, and teal archer glows and health bars.

## Debug dice

Click **DBG**, choose an illustrated double/triple or **Random Singles**, then charge and throw normally. Singles always have three different faces; doubles randomize the spare die. **Perfect: On** guarantees a Perfect on the next accepted throw, snaps the marker to the center, and counts toward treasure. It can be combined with any selected result. Both overrides apply once unless **Repeat** is on; canceled charging does not consume them, and restarting clears them. **Natural Random** restores power-weighted rolls, with normal Perfect odds if its toggle is on. Explicit combinations override the odds even on a Perfect stop.

## Presentation and assets

- Shared public Dungeon Crawl Stone Soup character/scenery art, fantasy stone panels, and Silkscreen pixel lettering.
- Landscape restores its original radius-144 circle and dice size. Portrait uses a slightly larger radius-232 circle with proportionally larger dice and spread triangular positions, clear of the meter and phone safe areas. Its five top controls fit beside the round counter in one compact row; the battlefield extends upward from y=330 to y=228. Both headers show wave progress, run currencies, and controls, without the game title or location name. The nine-diamond Perfect bank sits below the battlefield, with direct milestone claims, and active status icons follow the Horror above its head.
- Large PAIR/TRIPLE bursts pop from the dice center, then rise and fade. Skill names and short descriptions remain directly below the bubble in outlined pixel text without a window; Annihilation has no subtitle.
- After landing, dice collapse into a skill bubble, rise to the middle at **1.75× resting size**, then move lower and bob above the spent gray seal. Its icon identifies attack, healing, power, protection or Annihilation. Multi-hit skills have three or six glowing dots, popping once per automatic hit. Dot radii are 12 portrait / 9 landscape logical pixels, with captions below. Saved skills use a small idle seal and expand when selected. Casting finishes with a 0.48-second particle dissolve at the release point. Area skills have outward marks. Triple reveals flash and slow the world to 25% briefly (0.9 seconds including recovery); 666 uses 12% for a longer 1.65-second beat.
- Every accepted skill starts with a brief pause and backdrop dimming, then slow motion and a smooth recovery; a multi-hit chain uses this anticipation once. Normal / double / triple / 666 pauses are 0.06 / 0.08 / 0.10 / 0.16 seconds, followed by 0.16 / 0.20 / 0.26 / 0.44 seconds at 50% / 45% / 30% / 18% world speed, then a 0.18-second recovery. These beats use real time even in fever. City attacks, spell motion and action waits pause/slow together. The Horror dims for attacks, enemies for support. Menus suspend cinematics and dissolves, and restarting clears them. Reduced effects retains timing, bubbles, dots, indicators and a lighter dissolve while disabling flash, bobbing and seal rotation.
- Squads use compact, displaced rows with touch targets kept clear of the Horror’s status icons. Portrait late-wave targets remain at least 44 screen points wide and tall. City panic uses the same public sprite collection, follows ruined houses, and pauses with the menus.
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
| `scripts/reward_chest.gd` | Chest eruption, extended one/three/five reels and manual pickups, category celebrations and presentation signals |
| `scripts/reward_catalog.gd` | Reward names, descriptions and public asset icons |
| `scripts/status_catalog.gd` | Metadata for independently visible statuses; durations remain in the combat model |
| `scripts/battle.gd` | Mouse input, debug picker, scene flow, bodies, travel, city and interface rendering |
| `scripts/skill_bubble.gd` | Dice convergence, floating skill seal and caption, charge dots and pops, target brackets and icons |
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
godot --headless --path . --script res://tests/test_skill_storage.gd
godot --headless --path . --script res://tests/test_home.gd
godot --headless --path . --script res://tests/test_rewards.gd
godot --headless --path . --script res://tests/test_reward_presentation.gd
```

`tests/capture_visuals.gd` renders snapshots to `test-output/` when run with a display. Debug no longer requires a `--demo` launch argument.

`test_dice_channel.gd` checks floating positions and captions, gray spent dice without leftover links, tap and touch-drag targets, cancellation, corpse exclusion, automatic random multi-hit chains, input-spam protection, delayed boon/enemy turns, chest locking, buffs/AoE, city aiming, cinematic time, milestone tiers and formations. `test_skill_storage.gd` covers saving, bonus turns, boon lifetimes, automatic carryover after a bonus victory, full-slot rejection, dimmed waiting skills, actor focus, cast anchors, particle dissolves and restart in both layouts. `capture_skill_bubbles.gd` renders these states plus central reveals, short meters, charge pops and milestone claims.

`test_reward_presentation.gd` checks debug Perfect use/repeat/cancel, independent status expiration, chest emergence, sequential landings, category celebrations and cleanup in both layouts. `capture_rewards.gd` renders the counter, statuses, debug menu, opening, reels, and each reward effect; add `-- --portrait` for the phone layout. These checks run from source without exporting a game build.

The fixed-seed full-run sample uses zero throw power and a fixed 1.5 seconds per city roll. It is a legacy automated combat baseline, not a balance estimate for players using the timing meter. `test_skills.gd` checks each new damage formula, consecutive-hit resolution, corpse retargeting, shields, boon lifetimes, and city adaptations. `test_throw_power.gd` checks weighted probabilities, the Perfect window, charge/stop input, pause, restart, debug overrides, and city attacks while charging in both layouts. `tests/capture_power.gd` renders low/high power, Perfect, throws, and city charging to `test-output/`.
