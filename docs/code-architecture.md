# Code structure and extension guide

This is an implementation guide. The shared Mandarin Google Doc remains the design specification.

Prioritize clear ownership, shared rules and small extension points for future functionality. This is a small game; do not introduce caching or generic frameworks without a demonstrated need.

## Script folders

Scripts are grouped by feature. Keep a feature's catalogs, rules and presentation together, while preserving their separate responsibilities. Shared code should have multiple actual consumers.

| Folder under `scripts/` | Responsibility |
| --- | --- |
| `combat/` | Battle controllers and layouts, combat rules, skill objects, targeting, bubbles, damage feedback and character motion |
| `progression/` | Run state, wave definitions, progression and city combat rules |
| `enemies/` | Enemy definitions, weighted actions, intentions and inspection |
| `city/` | City scenery, residents and destruction presentation |
| `status/` | Status definitions, stacking rules, icons and overlays |
| `dice/` | Six-dice turn state and selection controls, dice rendering, legacy odds, throw timing and charging audio |
| `relics/` | Relic catalog, drops, inventory, ordered effects, copying, attacks and UI |
| `tarot/` | Tarot catalog, inventory, effects, casting, drawing, carousel input and card shader |
| `rewards/` | Treasure rewards, chest animation, reward icons and crystal pickups |
| `home/` | Home screen, character/dice selection and catalog |
| `audio/` | Source-based audio registry |
| `localization/` | Translation access, CSV loading and editor hot reload |
| `effects/` | General battle particles, screen ripple and shaders; the older palette shader is retained but unused |
| `shared/` | Weighted selection and drawing/drag helpers used by multiple features |

Keep `.uid` files beside their scripts and shaders when moving resources. Scene bindings, `preload`/`load` paths, inheritance paths, autoloads and test imports must point to the same destination. Tests remain in `tests/` so existing test commands stay stable. New functionality belongs in the corresponding feature folder; gameplay rules must remain independent of its UI scripts.

## Boundaries

- `scripts/combat/multi_hit_skill.gd` represents one skill, including targeting traits, copies, use modifiers and its frozen cast budget.
- `scripts/combat/battle_rules.gd` owns combat state, HP, statuses, action timing and combat events. It does not read wall-clock time or access scenes.
- `scripts/progression/run_rules.gd` adds wave progression, chest/relic rewards and city combat. It reuses the base numeric damage calculation before applying city-specific limits.
- `scripts/relics/relic_inventory.gd` owns acquisition, uniqueness, slot order, replacement and fusion. Reordering changes the array order; effect evaluation follows it.
- `scripts/relics/relic_drop_table.gd` owns the two-stage rarity/item draw. Gameplay reward sources share it; cosmetic reels use an independent visual bag and RNG.
- `scripts/relics/relic_effects.gd` owns relic behavior. `STATS` describes passive modifiers and flags, `STONES` describes immunity/status effects, and `TURN_CHARGES` describes periodic charges. Lifecycle hooks handle effects that mutate state.
- `scripts/combat/damage_feedback.gd` owns the cast-only multiplier display, ordered particle flights, increase waves and decrease shakes. `scripts/relics/relic_ui.gd` owns inventory glow/tilt reactions. Both consume model results; neither changes combat numbers. `scripts/combat/skill_orb_paint.gd` shares the multi-hit orb shell/core with brighter, larger multiplier energy. Relic dragging is captured on a horizontal rail, and descriptions follow the held item through reorder until release.
- `scripts/dice/dice_odds.gd` calculates the conditional chance of a six. It caches immutable copies of weight values, detects array replacement and in-place changes, and never consumes RNG.
- `scripts/combat/battle.gd`, `scripts/combat/battle_portrait.gd` and presentation nodes own drawing, input and animation. They display model results and should not decide combat outcomes.
- `scripts/combat/battle_backdrop.gd` owns the stone surround, paving and distant scenery. Its retained draw commands rebuild only when the wave scale, scrolling, arena geometry, canvas size or city mode changes; actors and controls remain on their existing animated layers.

Combat RNG and reward RNG remain separate. Cosmetic nodes use their own random generators. Previews must never consume randomness, spend charges, change health or update statuses.

`BattleRules.damage_event()` separates `amount` (actual HP/shield loss) from `display_amount` (calculated hit before remaining-health clamping), and explicitly flags instant kills. Gameplay hooks such as lifesteal consume actual loss; UI uses the display amount and suppresses execution numbers. `Effects.damage_font_size()` owns the log10 scale with a 24px floor. Catalog `counter` metadata chooses inventory badges; `charges > 0` drives the repeatable ready halo independently of brief activation effects.

## Add a relic

1. Add its ID, rarity, display name and description to `scripts/relics/relic_catalog.gd`. Add the sourced PNG and credit mapping in `assets/art/relics/`.
2. For an existing passive behavior, add an entry in `RelicEffects.STATS`. Supported fields include `base_damage`, `max_hp_factor`, `damage_add` per copy, `damage_factor`, `damage_per_kill`, `incoming_factor`, `single_target_factor`, `combo_uses_factor`, `combo_uses_per_wave` and `wave_rubies`.
3. Status relics go in `RelicEffects.STONES`: `immune`, `status`, `stacks`, `chance` and optional `combo_gain`. Prismatic Stone reads the same component definitions, avoiding a second implementation of each stone.
4. A genuinely new behavior belongs in the appropriate effect hook: `begin_attack`, `after_hit`, `incoming`, `prevent_death`, `turn_finished`, `enemy_killed`, `wave_cleared`, `acquired` or `modify_dice`. Keep turn completion and HP ownership in the combat model.
5. Keep independent rules independent. `always_perfect`, `no_ultimate` and `no_treasure` are separate flags; one must not imply another for future relics.
6. Update inventory fusion rules only for a new fusion recipe. Do not add UI checks for relic IDs.
7. Regenerate the chest atlas with `tests/render_relic_atlas.gd` after changing catalog order or art. Run the editor import before testing the rebuilt atlas.

Magic stones share `assets/art/relics/magic_gem.svg` and get their element color from the catalog at draw time. Prismatic Stone uses the same geometry with a multicolor tint. Keep these in `RelicPaint` so inventory, cards and the generated chest atlas stay consistent.

Damage relics use `RelicEffects.apply_damage_modifier` for both actual damage and the read-only `attack_multiplier_steps` trace. The trace starts at 1, adds baseline/reward/boon/combo contributions, traverses inventory order, and ends with darkness. Critical appears when its source activates but stays mathematically separate from additive bonuses. Flat base damage and extra hits have activation steps without changing DMG. Never implement damage arithmetic again in the animation.

Other actual relic procs emit the model's `relic_activated` signal. Pure queries and previews must not emit it. A consumed relic emits before removal so its activation can finish visually. Mid-combo damage growth can start another flight before the next hit; multiple kills feed the pending flight. Menus pause presentation; restart clears it. The initial buildup leaves combat running; City Fever plays the number sequence at 2×. The impact anticipation beat begins after the buildup. Reduced effects retain numbers and glow while suppressing tilt, particles, bob and shake.

Ordered effects must not be sorted, combined across inventory positions or cached without accounting for reorder and replacement. For example, a page before a skull and a page after a skull intentionally produce different multipliers. Runestone affects later status relics. Guaranteed status effects do not draw RNG; chance-based effects draw once at their original position.

## Reward selection and presentation

Enemy kill currency is owned by `RunRules.hit_enemy()` and `_crush_troops()`, using `EnemyCatalog.crystal_reward()` and the shared Soul Vessel-aware grant path. The model credits once on the alive-to-dead transition and emits `enemy_crystals_dropped`; `scripts/rewards/crystal_pickup.gd` animates only the receipt. `pending_total` temporarily offsets the displayed counter, never the spendable model balance. Pickup randomness is cosmetic, the currency endpoint is shared by both layouts, menus hide/pause the layer, and restart clears pending visuals. Final-wave rewards wait for receipts to arrive. `tests/test_crystal_pickup.gd` covers payout categories, shield/corpse exclusions, burn/tarot/city kills, fractional bonuses, modal layering, staggered counting and wave handoff.

`scripts/rewards/chest_rules.gd` owns tier names, colors, 1/1/3/5 item counts, 30/50/70/100 crystal payouts, the 3/8/15 Reroll Treasure thresholds and the 25% upgrade chain with a guaranteed fourth attempt per tier. `chest_pity.gd` tracks separate Normal/Perfect/Greed droughts and snapshots the pre-roll counters for presentation. The battle scenes configure its `user://chest_pity.cfg` store; model-only tests remain in-memory. Pity saves when the outcome is committed and survives run resets, while opening, skipping and collecting never count extra attempts. `Run.begin_wave_reward()` commits the final tier, item outcomes and optional tarot candidates once per clear. `reward_chest.gd` waits in a silent `closed` state until its chest hit area is clicked, then starts the reward reels; each stop tap reveals one upgrade and resumes spinning, or settles on the locked prizes. Its closed/spinning/upgrading/settling states use only cosmetic RNG, and expose only the current tier's columns. `wave_chest.gd` owns the after-chest summary. `Run.open_debug_chest()` uses the same tier lottery without changing wave completion or the treasure bank; `_show_chest()` is the common presentation adapter and restores the previous battle phase afterward. The optional 30-crystal tarot purchase is atomic, once per wave, and continuation waits for its ceremony.

Relic rarity is fixed at 58/30/10/1/1%, followed by a uniform eligible item draw. A guaranteed slot is chosen randomly and reserved before the other slots. `minimum_rarity` promotes low weight to the floor without increasing top-rarity odds. Owned uniques, reserved prizes, conflicting Cursed Dice and fusion-only items are excluded. Empty rarity pools redistribute proportionally. A fully exhausted relic pool falls back to tarot, then a shard. `weights_for_wave()` retains the gradual curve for future shops; current rewards do not call it.

Other chest slots roll 70% relic / 20% tarot / 10% shard. Stable retired IDs remain in the catalog but cannot drop; the legacy curse category contributes weight to the relic category. `release_chest_crystals(revealed_tier)` pays only the revealed tier's remaining increment, with Soul Vessel fractional carry and duplicate protection. Opening pays 30 for Normal; upgrades pay the differences without exposing future tiers through the balance or particles. Omitting the argument settles any remaining final payout. `crystal_pickup.gd` presents receipts above the chest overlay; it never grants currency and the flow waits for receipts before leaving.

`reward_chest.gd` receives locked results and builds cosmetic reels from all obtainable rewards. Horizontal layout, centered selection bands and dimmed neighbors are shared across phone and landscape. Speed, stop/skip timing, reduced effects and pickup order cannot change outcomes. `discard_unclaimed_rewards()` preserves claimed gifts and crystal payouts without consuming RNG. Full-inventory replacement, tarot ceremonies, victory and restart share the same transaction path.

Normal/Perfect/Greed use quadratic deceleration, a small overshoot, and a spring back to the prize. Ultra retains constant speed until each crisp musical stop. A second stop request finishes non-Ultra reels through the same landing events; Ultra rejects skips, including in reduced-effects mode. Ultra begins settling and starts its payout audio immediately upon upgrade or opening; it requires no stop tap. Its five reels land left to right on the authored final notes at 3.000/3.1875/3.375/3.5625/3.750 seconds, following the audio clock with mix/output latency compensation and a frame-timer fallback if audio is unavailable. Stable center-out reel identities keep the original reel centered during upgrades; side reels slide in at full height. `reward_burst.gd` renders a larger rarity-colored explosion for each landing, with a local flash, two shockwaves, long trails and bright spark cores. Mobile uses a larger logical scale; reduced effects keeps a quiet single ring. Only the central square selection takes the current reward's color; reel frames stay neutral. `scripts/audio/chest_audio.gd` owns two persistent voices: the constant-volume looping reel texture and a non-looping tier payout. `timed_audio_loop.gd` mixes repeated one-shots into an introductory segment and a steady periodic loop; the full tails overlap at an exact 0.84375-second interval without frame-timer drift. Greed selects a separately cached loop from `arcade_slot_roll2.wav`; other tiers use `arcade_slot_roll.wav`. Both original WAVs remain intact. Only the Ultra intro plays before landing; its main section continues at the reveal without restarting. Non-Ultra payouts start once on the first landing explosion. `revealed` fires once after the last reel lands for full-chest impact FX. Before reveal, pausing holds both voices in sync. After reveal, tarot selection pauses chest visuals while the payout continues; mute, cancel and restart still apply to both voices. Pause/resume is sent only when the paused state changes: Web Sample playback restarts a source on redundant unpause calls. `tests/web_chest_audio.tscn` checks actual browser playback advancement, completion and pause/resume in an isolated export. Audio never reads or changes reward RNG. `tests/test_chest_timing.gd` checks these boundaries in both layouts and measures live playback alignment with `--capture`.

`scripts/relics/relic_pickup.gd` owns the short lift, accelerating flight and inventory impact for picked relics. `scripts/relics/relic_ui.gd` starts it only after successful acquisition and resolves its destination from the resulting inventory, including stacks, replacements and fusions. Wave and chest transitions wait for the landing; repeated taps are ignored during flight. Menus pause it, focus loss only releases held input, and restart or skipping remaining treasure clears it without undoing an already claimed reward. Reduced effects retain a direct flight and landing ring without tilt, trails or squash.

Tarot generators use `RelicEffects.TAROT_GENERATORS` and the acquisition hook. `RunRules.grant_random_tarots()` owns reward RNG and banned-card filtering; generated cards go directly into the separate consumable inventory. Complete-turn guards prevent duplicate grants, and saved bonus casts do not advance counters. Ancient Prophecy snapshots one repeat when a real card commits. `TarotEffects.pending_repeat` owns the transient activation outside inventory; `TarotCast` reuses the normal choice/target/FX flow before resuming battle. Repeats cannot recursively proc, and a failed or declined second choice never undoes the first activation.

## Add a skill or character

The common `MultiHitSkill` lifecycle supports all skills and multi-use modifiers. Damage previews and actual attacks share `unmitigated_damage`, then apply target-specific caps and defenses. Keep fractional base damage until that shared rounding point. City numeric skills override `attack_base` and limits, not the multiplier or critical formula.

Skill classification, names, base formulas, support effects and several presentation captions are still specific to The Horror. Before adding a second character, introduce a character skill definition/behavior registry behind those existing entry points, then have the home skill reference and combat captions read that registry. Do not copy the battle scene or fork the entire combat model for each character.

Freeze the use budget at cast start. A saved skill carries its own modifiers and uses current model modifiers when activated. Repeated hits and saved bonus casts must preserve the existing turn and boon timing rules.

## Add a status

Add the status ID, stacking/cap behavior and duration unit to `scripts/status/status_effect.gd`, presentation metadata to `scripts/status/status_catalog.gd`, and its icon to `scripts/status/status_paint.gd`. Implement its actual rule in the relevant combat phase. Player and enemy application paths must both be considered; the city remains immune to statuses. New status effects must preserve the turn-end rule: both sides' status ticks finish before opening a victory reward screen.

## Performance rules

Keep function summaries as short `##` lines immediately above their declarations. Describe the gameplay or presentation purpose so editor search can find concepts such as “saved skill”, “chest”, “Perfect”, “status” and “tarot”, not only function names. For example: `rg -n '^##.*(chest|tarot)' scripts`.

`GameText.lines()` keeps at most 256 wrapped descriptions, keyed by translated content, font instance, font size, width and language. Font changes, language switching and successful CSV reloads invalidate the cache; callers receive independent arrays. Do not cache gameplay previews or mutable combat outcomes here.

Tarot carousel sorting calculates only card depths once per sort, rather than full animated poses for every comparison. Inspection lift state exists only while a card is raised or settling, so a closed inventory does no per-card animation work.

`tests/test_presentation_reuse.gd` checks wrapping equivalence/invalidation, terrain invalidation and carousel ordering in both layouts. `tests/benchmark_presentation.gd` measures local CPU work, not phone FPS. On October 15, 2026, wave-19 draw callbacks fell from 4.54 to 2.87 ms in landscape and 4.50 to 3.11 ms in portrait; 100-card sorting over 1,000 calls fell from 7.3–7.6 seconds to 0.22–0.24 seconds. With glyphs warmed in the same run, 5,000 repeated descriptions took 11 ms cached versus 136 ms uncached. Unchanged scenery regions were also compared visually with the previous rendering.

Use `is_enemy_alive(index)` for a single target and `has_living_enemies()` for existence checks. Use `living()` only when an actual list is needed, such as random selection or an area attack. Do not cache enemy membership across hits: kills and plague can change state during resolution.

Damage captions compute the shared damage once, then apply each target's caps and corrosion. Dice probability caches depend on weight contents, not just roll power or array identity. New modifiers must not bypass those invalidation rules.

The 2,000-line battle UI/controller remains the largest structural issue. Its next useful split is input/targeting, menus/debug, and battlefield drawing into focused nodes. Do that incrementally with the existing scene tests, rather than rewriting the working scene at once. Status timing can also move to a dedicated rules module when more status behaviors are added.

## Verification

Run from the project root using the installed Godot executable:

```sh
godot --headless --path . --script tests/test_extension_points.gd
godot --headless --path . --script tests/test_relics.gd
godot --headless --path . --script tests/test_reward_drops.gd
godot --headless --path . --script tests/test_damage_feedback.gd
godot --headless --path . --script tests/test_skills.gd
godot --headless --path . --script tests/test_multi_hit.gd
godot --headless --path . --script tests/test_status_effects.gd
godot --headless --path . --script tests/test_throw_power.gd
godot --headless --path . --script tests/test_skill_storage.gd
godot --headless --path . --script tests/test_rewards.gd
godot --path . --script tests/test_relic_scene.gd -- --visual --portrait
godot --path . --script tests/test_relic_scene.gd -- --visual
godot --headless --path . --script tests/benchmark_combat.gd
```

The benchmark runs 5,000 calls per case; times are diagnostic, not test thresholds or game frame rates. On the local Apple M3 Pro with Godot 4.7.2, the October 11, 2026 refactor measured approximately:

| Case | Before | After |
| --- | ---: | ---: |
| Repeated six-probability lookup | 126.7 ms | 2.9 ms |
| Ten-target damage preview | 676.1 ms | 188.3 ms |
| Relic effects after a hit | 224.3 ms | 91.3 ms |

The before measurement is one baseline run; the after numbers are medians of three runs. The checksum stayed identical. These measurements cover those specific model operations, not overall rendering performance.


## Localization

`GameText` owns the current interface language and persists it under `[interface] language` in `user://settings.cfg`, preserving other settings. A fresh install or unsupported saved locale uses `zh_CN`. Gameplay catalogs, IDs, RNG, and model events remain language-independent; rendering translates their source text through Godot's `TranslationServer`.

- Edit `assets/localization/ui.csv` (English source key, English text, Simplified Chinese text). Local play reads this source on startup and refreshes it automatically; no imported resource refresh is required. Missing keys fall back to their source text.
- The `TranslationLiveReload` autoload polls every 0.35 seconds only in the editor executable, including while the scene tree is paused. `scripts/localization/translation_csv.gd` compares content hashes, waits for two stable reads, parses quoted/multiline CSV, and validates column counts, unique keys, and formatting placeholders before replacing the catalog. This catches same-second and atomic-rename saves. Invalid/incomplete saves retain the last valid snapshot.
- `GameText` registers each complete snapshot with `TranslationServer`, removing this catalog's previous runtime and compiled resources so deleted entries do not revive stale text. It leaves other translation catalogs intact. Gameplay never depends on the watcher.
- Exported games do not watch files: they use the imported translations bundled by Godot during export. Publishing new wording requires a new build/upload.
- Use `GameText.text()` before measuring or drawing. For dynamic values, use `GameText.format(template, values)` **before** interpolation. Translate names before combining them with dice codes. Keep formatting tokens identical in each language.
- Use `GameText.lines()` for paragraphs: Godot's Unicode line breaking handles Chinese punctuation, English words, long words, and explicit newlines. Do not split only on spaces.
- `GameText.prepare_font()` adds bundled Noto Sans SC at weight 600 as the Latin pixel font's fallback. `GameText.description_font()` keeps Silkscreen pixel letterforms but uses a higher-resolution MSDF atlas for scalable body text and its CJK fallback. Titles and numeric debug input retain their original metrics. Wrap and measure body text with the same description font used for drawing.
- Relic descriptions accept an optional translation callable, so counters and static descriptions share one implementation without coupling the model to the selected language. Damage-feedback notes carry their formatting arguments separately.
- To add a language, add its locale/name to `GameText`, its CSV column, and its imported translation resource to Project Settings → Localization. The current two-button battle row supports English/Chinese; extend its layout for additional choices. Add font coverage as needed.

Run `godot --headless --path . --script tests/test_localization.gd` for translation coverage, placeholder/glyph checks, text wrapping, preference persistence, and switching without resetting a run. Add `-- --capture` without `--headless` to capture both layouts and languages. Tests write preferences to an isolated temporary path.

Run `godot --headless --path . --script tests/test_translation_live_reload.gd` to test saves without reimport, debouncing, malformed files, quoted CSV, atomic replacements, runtime updates, and preservation of paused battle state. Add `-- --capture` without `--headless` for before/after screenshots. The fixture is isolated under `user://`; tests never edit the real CSV.

## Enemy and wave catalogs

`scripts/enemies/enemy_catalog.gd` owns the five enemy identities, normal/elite stats and weighted skill pools. `scripts/enemies/enemy_actions.gd` filters valid options, locks an intent and resolves one impact at a time; `scripts/combat/battle_rules.gd` exposes complete-action and per-impact entry points. Taunt targeting and area protection are shared by skills, relic attacks and tarot. `scripts/progression/wave_catalog.gd` holds the twenty-wave route and display sizes: player 224→288 by wave 20; enemies 192→44 by wave 19, then city troops 20; paving/scenery shrink steadily. `scripts/progression/run_rules.gd` owns progression. `scripts/combat/combat_motion.gd` samples the growth squash/stretch from transition progress; both layouts render it around the player’s feet without changing combat state or the final size.

`relic_drop_table.weights_for_wave` moves each starting rarity rate 10% toward an even 20% split per wave. This curve is reserved for future shops; current chest and tarot relic rewards use the fixed catalog weights. Concrete rewards remain locked before presentation.

## Six-dice turns (October 16, 2026)

`dice/dice_turn.gd` owns six faces, three throws, selection, cancellable locked groups, and committed (used/saved) dice. `BattleRules.roll_pool()` rolls unused dice independently; Perfect updates combo and roll triggers without forcing matches. `form_selected_skill()` creates an existing `MultiHitSkill` from any trio. Only one summoned skill may wait at a time; it disables selection and rerolls for the whole pool. Casting or saving it releases the unused dice, and spending both trios completes a single player phase. Cancelling a pending skill unlocks its trio without refunding throws; used or saved groups cannot unlock. Saved bonus casts preserve both budgets. Freeze skips the entire player turn. `Run._bank_unused_rolls()` banks one treasure point per unused throw after the complete enemy/status phase, or on a wave-ending action. It settles once per round, only if dice were thrown; frozen/untouched turns grant nothing. Perfect results never change this bank. Claiming resets the bank; wave transitions retain it.

`dice/dice_selection.gd` owns center roll input, path-sampled, reversible drag connections, cached skill previews and bounded cosmetic sparks. Six dice share the hexagram vertices in both layouts. Releasing three dice summons; returning to earlier dice rewinds, re-entering the last of two disconnects it, and pulling 85% of a die spacing (capped at 1.35 hit-box widths) away from the third breaks that link. A contact margin prevents edge jitter from undoing newly selected dice. Incomplete/focus-interrupted gestures clear without cost. `dice_connection_beam.gd` caches a procedural filament texture and renders its glow/streaks without gameplay RNG. Selectable thrown dice have faint pixel rings that loop through a gentle size bounce (static with reduced effects). Both layouts use the same controller and model. The legacy three-die `roll()` / `set_test_roll()` are simulation fixtures; live gameplay exclusively uses `roll_pool()`.

Roll-changing items remain defined but are suspended by catalog `DISABLED` lists. Relic sequences, shared rarity drops, tarot draws, inspection and use validation respect these lists. Trio-dependent relics commit once on cast/save, preventing cancel-and-reconnect bonus farming; per-throw effects still trigger per accepted roll. The temporary city switch ends normal progression after wave 19, while preserving city code for later adaptation.

Validate with `tests/test_six_dice.gd` and `tests/test_six_dice_scene.gd`; these cover selection/locking, rerolls, sequential casts, buffs, saved skills, freeze, disabled rewards, independent faces, both layouts, touch-sized controls, drag previews/cancellation, and modal visibility.
