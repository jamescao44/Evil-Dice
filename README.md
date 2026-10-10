# Evil Dice

A Godot 4 pixel-art dice game: grow an eldritch horror through **nine randomized normal/elite waves → castle-city fever**, earning treasure through Perfect throws.

The shared [Chinese Google Design Doc](https://docs.google.com/document/d/1i-PEouZmzwagpz6CTa7CjMVl_UJd99-io_uB7TMgguM/edit) is the primary record for game designs and changes. Write future design updates there in Mandarin (Simplified Chinese), keeping proposals separate from implemented features. The earlier English Google Doc and `docs/game-design.md` remain reference snapshots.

## Play

Open `project.godot` in Godot and click **Run Project** for the portrait home screen. Open `scenes/home.tscn` and use **Run Current Scene** for the landscape home screen. The original `scenes/battle.tscn` and `scenes/battle_portrait.tscn` remain available for direct battle testing. Gameplay uses clicks or taps, with no keyboard controls.

The home screen has five bottom tabs, ordered **Dices / Ancients / Play / Summon / Shop**, with Play selected initially. Ancients shows The Horror, its lore and play style, and a skill reference for normal rolls, all doubles and all triples, including city variants. Swipe its portrait horizontally, drag with a mouse, or open the visual selection menu to browse the collection. Only The Horror is available; the carousel stays on it until more entries exist. Dices contains the basic Bone Dice, with a larger preview and descriptions on tap. The Play button displays the selected dice and starts a new ten-stage run in the same layout. Home in the battle grimoire or ending screen leaves the run and returns to Play, retaining the current session's selections and sound/effects/speed settings. Summon is a placeholder; Shop is blank. Rubies and summon shards exist only within the active run; there is no summoning, purchasing, or saved collection progression yet.

1. Click or tap inside the circular magic seal to start charging, then again to lock the marker and throw. The marker moves fastest near the center, using the gentler blended timing curve at another **10% slower overall speed** (about 2.667 seconds per round trip). The visible bar is 25% shorter: 216 landscape / 432 portrait logical pixels. Higher power increases combination odds and dice motion and sound. A **Perfect** within ±4 pixels on the shared 288-pixel reference scale guarantees a pair or triple: 50% each in squads, 100% triple in fever. Non-Perfect triples cap at 25% in squads; exact doubles cap at 70% in both modes after fever normalization. There are no pity guarantees. Perfect positions snap visually to center, and the marker and bar flash white. The same timing and reference scale apply in both layouts, independent of physical device pixels.
2. Revealed dice form a **skill bubble**, rise enlarged to the middle, then settle lower and bob with their name and description. The used dice seal turns gray and its combination lines disappear. Dice remain visible and dim through held skills, casts, enemy turns and transitions, then brighten when ready; menus dim them further instead of hiding them. **In squad waves, drag skills onto the battlefield to cast.** Normal attacks, 11 and 111 must land on a foe, or can be tapped first and then aimed by tapping a foe. City rolls cast automatically after their reveal; saved targeted skills still select the city. Buffs, area skills and combos do not cast on a simple tap. Dragging a buff dims enemies while the Horror stays bright; attack selection and every cast keep characters fully lit. Dragging has no tether line or cancel hint; casting bubbles become see-through at 28% opacity with no dark fill. Invalid drops preserve the skill. **55 automatically delivers three hits; 555 delivers six after one field drop.** Each hit pops a dot and independently chooses a random living foe (the city in fever); clearing the wave ends the chain. Cast bubbles stay where released and dissolve into pixel particles when finished. Enemy turns, boon clocks, the next roll and treasure claims wait for the whole action.
3. Every living enemy acts. Before acting, enemies show a sword (attack), plus (heal), shield, or boost-arrow intent icon. Hold an enemy for 0.25 seconds to inspect its move while the rest of the screen dims; release to dismiss. A short tap still casts a selected targeted skill, while holding never spends it. Dead bodies stay until the whole squad is defeated.
4. The Horror feeds, the bodies fade, and the scenery pans and shrinks as you advance and grow. Adventurers become progressively smaller across nine squad waves, leading into the city finale.
5. Stage ten is a circular castle city with a moat, bridges, dense houses, and a towering keep. Animation speed is fixed at 2×, with no frenzy bar or hold/spam speed boost. Pair and triple probabilities receive a 1.5× fever boost (non-Perfect triple ceiling 37.5%); if their total exceeds 100%, both are normalized proportionally. Perfect guarantees a triple. Every throw still needs a charge click and a stop click; holding never automatically releases dice. Each newly rolled skill automatically casts when its bubble finishes forming, including support and all combo hits; no aiming or field drop is needed. Rolls are still started and stopped manually, and saved bonus skills remain manual. Troops keep attacking while you charge and during animations outside cast pauses. They wiggle as they run, and civilians and aristocrats flee from destroyed houses inside the walls.

Top controls: ordinary animation speed, sound, and a **three-bar menu**. The menu page contains **Debug**, **Effects: Full/Reduced**, **Help / Grimoire**, and **Resume**; Help and Debug return to this page when closed. Active statuses appear as small independent icons directly above the Horror, each with its own remaining turns, burning stacks, next-throw stun count, or city-immunity seconds. Inactive or expired effects disappear individually. Regeneration, both attack boons, invincibility, freeze, burning, and stun use separate indicators; the stronger attack boon still takes precedence. Hover for explanations or tap in portrait. Detailed rules remain in the grimoire. The menu page, Help and Debug pause the charge meter, city attacks, charging audio and skill effects. Losing window focus cancels an unfinished charge without spending a roll. Restart after victory or defeat begins a new run.

The **SAVE slot** above and to the right of the dice stores one skill. Dragging a new skill into the empty slot ends the current turn without applying it. Later, drag the stored skill out for a bonus cast between rolls or while holding a new skill; targeted stored skills also support tap-then-select. The saved seal expands to full active size. Any waiting skill stays visible but dimmed and unavailable until the bonus finishes. Bonus casts do not add an enemy phase or tick existing boon durations; the subsequent ordinary action still does. A saved one-turn immunity protects the upcoming squad enemy phase. If a bonus cast clears the wave, an unused summoned skill automatically fills the vacated slot. Saved skills carry between waves, use current damage stats when cast, and reset with a new run. A full slot rejects replacement. The saved skill stays motionless and dimmed whenever interaction is locked, then resumes movement when usable.

## Combat and growth

Every rolled or saved skill is a `MultiHitSkill` object. Normal attacks, aimed attacks, area attacks, support and ultimates start with **one use**, hiding the use orbs; 55 starts with three and 555 with six. Future use multipliers apply to the entire skill: **×2 makes a regular skill two uses/two orbs, and Sixfold Ruin twelve hits/twelve orbs**. Damage previews, orb pops and combat all use the same count. Aimed skills keep their chosen living target and retarget after a kill; random combos choose independently each hit. Area and support skills repeat their whole effect, retaining the existing buff-refresh and healing limits. The full chain remains one action and stops on victory or defeat.

For future modifiers, call `model.set_skill_use_multiplier("echo_buff", 2)` for all skills, or `skill.set_use_multiplier("relic_echo", 2)` for one skill object. Passing `1` removes that named source; refreshing the same source replaces it, while different sources multiply together. Saved skills preserve their own modifiers and use current model modifiers when cast. The use budget freezes at cast start so an expiring modifier cannot change the remaining hits or orb count midway. New runs clear model modifiers. These hooks are implemented; no new multiplier buff or relic is enabled by default.

Normal rolls use the sum of three different dice plus earned base-damage bonuses, with the existing normal per-hit caps. Skills use **regular attack power P = 10 + earned base-damage bonuses** and ignore caps. Let `s` be the spare die; formulas below are before the global multiplier (1.5 + earned multiplier bonuses), growth, the active attack boon, and the Perfect combo multiplier. Round down after all multipliers, then apply shields and remaining HP.

| Face | Double | Triple |
| --- | --- | --- |
| 1 | One hit: 1.5P + s | Instantly kill one chosen foe; city: 5P base damage |
| 2 | Heal 5 at each of the next s turn starts | Restore full health, including grown maximum HP |
| 3 | ×1.5 attack power for the next s actions | ×3 attack power for the next 3 actions |
| 4 | Hit every foe for ⅔P + s | Hit every foe for 2P |
| 5 | Three automatic hits, each P + s; independently random foes | Six automatic hits, each P; independently random foes |
| 6 | Invincible for s enemy phases; city: 2 seconds per stack | **Annihilation**: clear squad; city: clear troops and deal 800 × combo multiplier. Heal 12 |

The stronger attack boon applies while both are active; they never multiply together. Refreshing a boon replaces its remaining duration. A squad turn ends after every surviving enemy finishes its skill: used buff counters decrease together at that point, never after the player alone or between combo hits. Attack boons retain their advertised subsequent actions (including support actions); regeneration heals at the next turn starts and counts down after those enemy phases. Invincibility counts the granting enemy phase and stays active through the last enemy's attack. Clearing a wave closes the turn immediately. In the city, regeneration and attack boons still count completed roll intervals; immunity instead lasts **2 real-time seconds per stack**. Its countdown continues while idle, charging, or casting, including cinematic pauses and slow motion, and pauses with menus/rewards. Reapplying refreshes the new duration; ordinary or saved casts do not directly subtract a stack. Bonus casts do not advance the turn. Unspent durations carry between waves. Multi-hit actions stop early when no foes remain and never hit corpses.

Held attack skills show live per-hit damage as **base + modifier (xN)**; targeted skills show it when selected or dragged. For example, a 5/5/1 at starting power reads `11 + 5 (x3)`. The modifier includes the global multiplier, rewards, growth, attack boons, Perfect combo, normal target caps and city scaling. Base is the integer part of the skill base; the final sum matches combat's rounded impact damage before squad shields and remaining HP. Hovering a target selects its cap; before choosing, differing caps show a modifier range. Cap reductions can produce a negative modifier. Saved previews use current stats. This is an extra red line above the bubble; the original attack description stays below it. Squad instant kills have no numeric line; city 111 and 666 remain numerical. Regeneration shows green `5 HP (xN)` and full heal shows the actual missing health as `+N HP`. Portrait skills settle slightly lower to leave room between this line and the treasure bank. Turn-based buff captions use “for N turns”; city immunity uses “for N seconds”.

After each squad victory, gain 30 maximum HP and heal 55 up to the new maximum. Growth power across ten stages is 1 / 1.5 / 3 / 5.625 / 6.75 / 7.875 / 9 / 10.125 / 11.25 / 12.375. Normal caps are ⅓ HP in stages 1–2, ½ in stage 3, and ¾ from stage 4 onward. Growth is fixed, with no mutation choices. Visual Horror size now follows 224 / 248 / 260 / 272 / 280 / 288 / 296 / 308 / 320 / 288 logical pixels: stages 3–7 grow more gradually, and the city Horror is 10% smaller than stage nine without reducing its combat stats. Enemy sizes are 192 / 96 / 100 / 84 / 86 / 76 / 64 / 54 / 44 / 20: fights 5–9 have a further modest size increase. Enemies form compact groups through the battlefield: landscape groups shift inward, while portrait groups use the upper center and open right flank, reserving room for the Horror and status icons. Health bars, intent icons and target areas remain separate.

The city has 10,000 HP and applies an extra ×2 siege multiplier to damaging skills and normal attacks. **666 deals 800 × the Perfect combo multiplier**, unaffected by other damage bonuses or the city ×2 multiplier and limited by remaining city HP. City 111 deals 5× regular attack power, not an instant city kill. AoE clears all troops; each rapid hit removes at most one troop. Heal and power-up triples do no damage and do not clear troops. Invincibility blocks both troop and ranged damage; city timers and reinforcements continue. Buildings and walls turn to rubble as health falls.

## Perfect combo and treasure

A **Perfect combo** counter sits opposite the saved skill slot, showing the consecutive Perfect count and current damage multiplier. Each accepted Perfect adds one: **damage × (1 + combo × 0.1)**, starting at ×1.1, then ×1.2, ×1.3, and so on without a cap. The bonus applies to the skill from that throw and every subsequent hit, including saved skills at their current cast-time stats and city Annihilation. A non-Perfect throw resets it to zero. Canceling charge, using saved skills, claiming treasure, breaking ice, and changing waves preserve the streak; restarting clears it. The multiplier applies before integer rounding and normal damage caps. Healing and instant kills retain their existing behavior. Debug Perfects count once.

The treasure bank shows nine diamonds without a heading. Perfect throws fill **nine diamond slots**, preserved through misses and waves. The bank stops at nine until claimed. **3 Perfects = one reward; 6 = a rare chest with three rewards; 9 = an epic chest with five rewards.** This replaces the old random 25% three-reward bonus. The **third, sixth and ninth diamonds** are larger when filled. Only the highest available chest has a strong pulsing halo and a bright, clickable **CLAIM** label; lower tiers cannot be claimed. Claiming empties the entire meter, including extra diamonds. There is no separate chest button. Claims are disabled while a skill forms, waits, targets or casts, including pauses between multi-hit casts. The whole skill must finish before rewards can boost subsequent actions. Final city victory automatically claims the highest available chest and locks its one/three/five rewards. A brief “Common/Rare/Epic chest auto claimed” banner overlays the success screen for 2.4 real-time seconds. The normal chest-opening and reward-reel animation then plays automatically, and **each gift waits for the player to tap and collect it**. Rewards apply once on pickup; after the last gift’s effect, the success screen returns. Incomplete banks show no claim message. Squad waves preserve the bank; defeat retains manual claims.

Reels independently draw from seven equal default weights, allowing duplicates. Outcomes lock before animation. A 0.38-second pause and white flash precede the chest opening and throwing loot up into extended slot reels. Five rewards use a 3+2 layout on phones and a row in landscape. **All rewards wait for individual taps after every reel stops, including the automatically claimed victory chest.** Each tap applies that gift once, shows its skill-style name, and plays its category effect. Combat and city timers pause until every gift is picked up. Rubies rain; power-ups emit edge magic; curses glow ominously; relics shine. Reduced effects suppresses flash, shake, and particle bursts.

| Reward | Effect |
| --- | --- |
| Blood Rubies | +100 run rubies; ruby icon and rain replace coins |
| Sharpened Hunger | +5 base damage to normal dice sums and skill regular power |
| Unbound Power | +0.5 additive global multiplier: 1.5 → 2.0 → 2.5… |
| Forgotten Relic | Relic placeholder; no effect |
| Whispering Curse | Negative-effect placeholder; no effect |
| Crimson Draught | Potion placeholder; no healing yet |
| Summon Shard | +1 run shard, represented by a parchment contract with a magic circle |

Ruby and shard counters appear in the header. New runs clear both currencies, the Perfect bank, rewards, and bonuses; no persistent economy or summoning is implemented. Instant kills remain unscaled; city Annihilation scales only with Perfect combo. Debug Perfects count.

Dice use weighted category and face selection. Triple faces 1–5 each have weight **1**, and 666 has weight **0.7** (about 12.28% of triple results). This preserves the total triple probability: regular Perfects remain 50% triple / 50% pair; city Perfects retain guaranteed triples. Non-Perfect caps remain 25% triples (up to 37.5% in fever) and 70% pairs. Per-run category, pair, triple, single-face, and reward weights are explicit hooks for future relic modifiers; no relic effects are active yet. Zero-power category probabilities retain their old values, but triple faces are now weighted.


## Ten waves and enemy traits

With `n` = normal and `e` = elite: **1n → 3n → 1e → 5n → 2n1e → 3n2e → 5n2e → 4e → 5n5e → city**. Roles are sampled independently and shuffled; repeated roles are allowed. Enemy base stats do not increase with the wave. Enemy names are hidden. Health bars shrink to fit the actual column spacing, with room for their borders; crowded waves retain separate rows. Elites have an attribute-colored silhouette, bright foot rings, and rising cylindrical light columns: gold stun, orange fire, and ice blue. Reduced effects retains static rings and columns.

| Role | Normal HP / attack | Elite HP / attack | Support actions |
| --- | --- | --- | --- |
| Vanguard | 75 / 5 | 150 / 10 | Self-shield +6, capped at 20 |
| Mage | 35 / 10 | 75 / 15 | Self-heal 30% max HP; elite can give one other unbuffed ally ×1.5 on its next attack |
| Elf Archer | 50 / 7.5 | 100 / 10 | Elite heals all living allies, including itself, for 20% of their own max HP |

Every living enemy chooses one action per round. When useful support is available, vanguards/elite archers attack 70% of the time and mages attack 65%; otherwise they attack. Healing cannot resurrect or exceed max HP. Mage buffs do not stack and remain until the recipient attacks. Damage/healing round once to integer HP (a normal archer deals 8). All elites start with **10 shield**. A shield absorbs an entire hit even when that hit breaks it: no excess reaches health. Later hits in a combo can hit HP. Triple 1 and squad Annihilation ignore shields. Elites reuse the sprites with gold vanguard, orange mage, and ice-blue archer glows and health bars.

## Elite attributes and statuses

Boons and afflictions share `StatusEffect` objects. The next move, including its attribute, is chosen once at round start; inspecting it never rerolls it. Attributes apply only when an enemy attack actually removes HP: invincibility and fully absorbed hits block new afflictions. Normal enemies have no attributes, and player attack attributes remain future work.

- **Elite archer:** 50% of attack choices are ice arrows. Freeze locks rolls and saved skills, encases the motionless Horror and dice area in ice, and waits for **three taps** on either ice shell. Each tap cracks it; the third breaks free and ends the player's turn, followed by the enemy phase. It never automatically times out. When the player is already frozen at intent selection, every elite archer schedules an ordinary arrow instead of an ice arrow. Breaking free therefore guarantees a playable following turn; ice arrows can be assigned again during that turn.
- **Elite mage:** every attack that removes HP adds **2 burning stacks**, capped at **10**. At nine stacks only one is added; at ten no extra stack or popup is added. After all enemies act, each stack deals one HP in consecutive `-1` ticks, then one stack expires. Death stops the sequence. Invincibility blocks the damage while stacks still decay. Carried burning ticks after a complete ordinary city action; bonus skills do not trigger extra ticks.
- **Elite vanguard:** 50% of attack choices stun. Stars circle above the Horror; the next accepted throw uses an erratic power marker with random direction and speed. Canceling charge or breaking ice preserves the pending stun. Accepted throws consume it, and cosmetic motion never changes combat RNG.

## Debug dice

Open the **three-bar menu → Debug** to choose dice or load a wave by typing **1–10** and tapping **LOAD** (or pressing Enter). Loading starts a fresh run at that wave, with its matching full player health, growth and enemy formation; wave 10 is the 10,000-HP city. It clears prior skills, statuses, treasure, combo, timers and animations. Invalid numbers leave the current run unchanged. The persistent Perfect toggle keeps its setting.

Open **Menu → Debug**, choose an illustrated double/triple or **Random Singles**, then charge and throw normally. Singles always have three different faces; doubles randomize the spare die. **Perfect: On** is a persistent toggle guaranteeing a Perfect on every accepted throw until switched off, snaps the marker to the center, and counts toward treasure. It can be combined with any selected result. The chosen dice combination applies once unless **Repeat** is on. Perfect remains on independently of Repeat, including after restart; use its toggle to turn it off. Canceled charging consumes neither setting. **Natural Random** restores power-weighted rolls, with normal Perfect odds if its toggle is on. Explicit combinations override the odds even on a Perfect stop.

## Presentation and assets

- Shared public Dungeon Crawl Stone Soup character/scenery art, fantasy stone panels, and Silkscreen pixel lettering.
- Landscape restores its original radius-144 circle and dice size. Portrait uses a slightly larger radius-232 circle with proportionally larger dice and spread triangular positions, clear of the meter and phone safe areas. Its five top controls fit beside the round counter in one compact row; the battlefield extends upward from y=330 to y=228. Both headers show wave progress, run currencies, and controls, without the game title or location name. The nine-diamond Perfect bank sits below the battlefield, with direct milestone claims, and active status icons follow the Horror above its head.
- Large PAIR/TRIPLE bursts pop from the dice center, then rise and fade. Skill names and original short descriptions remain below the bubble in outlined pixel text without a window; a separate red damage or green healing line appears above it. Instant kills omit only the numeric line.
- After landing, dice collapse into a skill bubble, rise to the middle at **1.75× resting size**, then move lower and bob above the spent gray seal. Its icon identifies attack, healing, power, protection or Annihilation. Multi-hit skills have three or six glowing dots, popping once per automatic hit. Dot radii are 12 portrait / 9 landscape logical pixels, with captions below. Saved skills use a small idle seal and expand when selected. Casting finishes with a 0.48-second particle dissolve at the release point. Area skills have outward marks. Triple reveals flash and slow the world to 25% briefly (0.9 seconds including recovery); 666 uses 12% for a longer 1.65-second beat.
- Every accepted skill starts with a brief pause and backdrop dimming, then slow motion and a smooth recovery; a multi-hit chain uses this anticipation once. Normal / double / triple / 666 pauses are 0.06 / 0.08 / 0.10 / 0.16 seconds, followed by 0.16 / 0.20 / 0.26 / 0.44 seconds at 50% / 45% / 30% / 18% world speed, then a 0.18-second recovery. These beats use real time even in fever. City attacks, spell motion and action waits pause/slow together. Backdrop shade stays below the fully lit characters. Casting bubbles remain at 28% opacity through their particle dissolve; their dark fill is hidden. Menus suspend cinematics and dissolves, and restarting clears them. Reduced effects retains timing, bubbles, dots, indicators and a lighter dissolve while disabling flash, bobbing and seal rotation.
- Squads use compact, displaced rows with touch targets kept clear of the Horror’s status icons. Portrait late-wave targets remain at least 44 screen points wide and tall. City panic uses the same public sprite collection, follows ruined houses, and pauses with the menus.
- Glowing magic seals, slash impacts, feeding particles, persistent bodies, and scenery motion. Normal attacks give a small screen shake; triples give a larger one. Reduced effects disables shaking.
- Restored original dice rolling, landing, and reveal chimes; retained heavier weapon and spell impacts. Existing interface/combat clips come from Kenney's CC0 packs. Dice throws use the user-provided `soft_sweep.wav` instead of the scraping sweep, now 6 dB louder across the throw-power range, and accepted Perfect throws layer `perfect.wav` onto the confirmation. Finished SFX are copied from `/Users/James/Desktop/Music Files/Station A/Evil Dice/outs-FXs`. Charging also layers the user-provided magic-leak loop at **25% of its original runtime amplitude** (halved again from the previous 50% mix), swelling with the power meter at a stable pitch and fading on stop/cancel/menu; muting stops it immediately. Its source/edit notes are in `assets/audio/magic_leak_loop.txt`.
- See [asset credits and licenses](assets/CREDITS.md) and the [design document](docs/game-design.md).

Tested with **Godot 4.7.2**, Compatibility renderer on Windows. No external packages or plugins. No saved progression, gacha, or additional playable monsters yet. Existing exported executables must be re-exported from Godot to include source changes.

Web builds use the browser's adaptive canvas size and device-pixel ratio. The 402×874 preview-window override applies only to native desktop runs; applying it on Web can shrink the game into the bottom-left corner on high-density iPhone screens. Export the Web preset to `export-web/index.html` and upload all generated runtime files together, with `index.html` at the ZIP root. The generated folder is excluded from Godot imports.

## Development

The [Chinese design document](https://docs.google.com/document/d/1i-PEouZmzwagpz6CTa7CjMVl_UJd99-io_uB7TMgguM/edit) is current. The local design snapshot predates these changes. Rolls are independent of prior outcomes; the former three-roll match and six-roll triple guarantees have been removed.

| File | Responsibility |
| --- | --- |
| `scripts/home.gd` | Portrait/landscape home tabs, touch and mouse carousel, collection/skill views, battle launch and return |
| `scripts/home_catalog.gd` | Current Ancient and dice entries, lore, play style, and collection identifiers |
| `scripts/multi_hit_skill.gd` | Shared skill objects, base uses, named multipliers, frozen cast budgets and remaining uses |
| `scripts/battle_rules.gd` | Seeded power/fever odds, classification, capped squad combat, buffs, enemy actions |
| `scripts/run_rules.gd` | Wave composition, growth, carryover, city damage and real-time attack cadence |
| `scripts/reward_chest.gd` | Chest eruption, extended one/three/five reels and manual pickups, category celebrations and presentation signals |
| `scripts/reward_catalog.gd` | Reward names, descriptions and public asset icons |
| `scripts/status_effect.gd` | Shared boon/affliction counters, refresh and stacking behavior |
| `scripts/status_paint.gd` | Intent icons, ice cracks, orbiting stars and elite light columns |
| `scripts/status_overlay.gd` | Dice ice overlay and remaining-tap prompt |
| `scripts/enemy_inspection.gd` | Hold-only move description and full-screen focus shading |
| `scripts/charge_audio.gd` | Continuous charge-loop playback and power-based volume |
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
godot --headless --path . --script res://tests/test_perfect_combo.gd
godot --headless --path . --script res://tests/test_portrait.gd
godot --headless --path . --script res://tests/test_skills.gd
godot --headless --path . --script res://tests/test_dice_channel.gd
godot --headless --path . --script res://tests/test_skill_storage.gd
godot --headless --path . --script res://tests/test_status_effects.gd
godot --headless --path . --script res://tests/test_intent_inspection.gd
godot --headless --path . --script res://tests/test_charge_audio.gd
godot --headless --path . --script res://tests/test_battle_menu.gd
godot --headless --path . --script res://tests/test_multi_hit.gd
godot --headless --path . --script res://tests/test_home.gd
godot --headless --path . --script res://tests/test_rewards.gd
godot --headless --path . --script res://tests/test_reward_presentation.gd
```

`tests/capture_visuals.gd` renders snapshots to `test-output/` when run with a display. Debug no longer requires a `--demo` launch argument.

`test_multi_hit.gd` checks all 216 roll outcomes, modifier stacking and refresh, saved-object isolation, frozen cast budgets, doubled damage/support/AoE/instant-kill skills in squads and city, and complete animated chains in both layouts. `capture_multi_hit.gd` captures hidden single-use orbs, twelve-orb current and saved skills, and doubled aimed/support skills; add `-- --portrait` for the phone layout.

`test_dice_channel.gd` checks floating positions and captions, gray spent dice without leftover links, tap and touch-drag targets, cancellation, corpse exclusion, automatic random multi-hit chains, input-spam protection, delayed boon/enemy turns, chest locking, buffs/AoE, automatic city casting, cinematic time, highest-tier claims and nonoverlapping health bars across all formations. `test_skill_storage.gd` covers saving, bonus turns, boon lifetimes, automatic carryover after a bonus victory, full-slot rejection, dimmed waiting skills, cast transparency, cast anchors, particle dissolves and restart in both layouts. `capture_skill_bubbles.gd` renders these states plus central reveals, short meters, charge pops and milestone claims.

`test_reward_presentation.gd` checks persistent Perfect toggling across throws/restarts and cancellation, independent status expiration, chest emergence, sequential landings, category celebrations and cleanup in both layouts. `capture_rewards.gd` renders the counter, statuses, debug menu, opening, reels, and each reward effect; add `-- --portrait` for the phone layout. These checks run from source without exporting a game build.

The fixed-seed full-run sample uses zero throw power and a fixed 1.5 seconds per city roll. It is a legacy automated combat baseline, not a balance estimate for players using the timing meter. `test_skills.gd` checks each new damage formula, consecutive-hit resolution, corpse retargeting, shields, boon lifetimes, and city adaptations. `test_throw_power.gd` checks weighted probabilities, the Perfect window, charge/stop input, pause, restart, debug overrides, and city attacks while charging in both layouts. `test_perfect_combo.gd` checks accepted-throw streaks, damage previews and hits, saved casts, ice skips, treasure independence, restart, and both HUD layouts; pass `-- --capture` without headless mode for screenshots. `tests/capture_power.gd` renders low/high power, Perfect, throws, and city charging to `test-output/`.

`test_status_effects.gd` covers elite proc rates, manual three-tap freeze, touch/mouse deduplication, burn ticks, stun, immunity, pause/restart and all squad layouts. `test_intent_inspection.gd` covers hold-versus-tap targeting, drag/focus cleanup, city immunity expiry without throwing, seconds during cinematics, and visual scale changes. `capture_status_effects.gd` renders intent symbols, inspection, cracked ice, crowded formations and city immunity in both layouts.

`test_battle_menu.gd` covers menu navigation and pause, typed wave entry and validation, every wave’s fresh state, old-animation cancellation, throw audio selection, and larger enemy layouts. Run without `--headless` and add `-- --capture` for menu, debug, formation, and victory-reward screenshots.
