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
- `scripts/combat/battle_backdrop.gd` owns the paving and distant scenery. Its retained draw commands rebuild only when wave scale, scrolling, layout or city mode changes. `battlefield_view.gd` shares an eased camera projection across the cached terrain, clipped actor layer, target hitboxes and inspection. Layout positions stay in world coordinates; projected positions serve screen-space FX and input. Health, dice, inventory and menus remain fixed. Incoming waves use the same travel progress as the terrain. Large enemies receive only a gentle zoom, intent icons scale with the camera, and target commitment immediately eases back out. Spell endpoints retain world coordinates so they follow the return motion without moving UI effects.

Boss encounters share `scripts/enemies/boss_rules.gd` for phase transitions and cast-based interruption. `enemy_catalog.gd` supplies phase HP, charge length, break count and action weights; `knight_commander.gd` and `elf_spellsword.gd` own their distinct perks. `boss_presentation.gd` reads the same catalog counts for both layouts. Catalog flag `release_on_full_charge` queues the heavy attack as the next step of the final charging action, supporting bosses and elite High Priests; elite Paladins retain a separate following-turn release. Boss sprites use twice the regular unit width and height; size-aware placement centers their body with floor clearance. The shared HUD uses intent icons, and hides charge/break rows until a charge actually lands.

Freeze skips a boss action while preserving charge progress and remaining break marks; ordinary charging enemies still restart. A depleted first boss bar stays alive at zero HP until the complete skill (including bonus casts) or rolled auto-attack sequence finishes. Further damage and statuses are ignored during that interval; the new bar, phase perks and reinforcements appear together afterward. Only the final phase awards death rewards. Death tarot shares boss-filtered targets between the rules, drag indicators and repeated casts. `tests/test_boss_sequences.gd` covers these boundaries through the shared model.

Player-facing descriptions state the main action and useful numbers concisely. Keep item/tarot exceptions, interaction details and edge cases in technical/design documentation so players can discover them in play.

Crystal Ball uses `RelicEffects.turn_started` for temporary tarot; `TarotInventory` tags projection instances and expires only those instances. Full turn closure and wave boundaries clean them up. The expiry signal also clears queued receipts and stale UI selection; the CLI exposes the projection flag and expiry events. Bonus dice pools retain the current full-turn lifetime.

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

Relic balance values stay in `RelicEffects.STATS` and `RelicSets.RECIPES`; meal upgrades replace their earlier tier bonus while preserving ingredient order. Light Sword adds +2 at its inventory position against a lone enemy. Three-leaf Clover shares the existing unused-dice guarantee path (20% for at least three dice); tarot overrides still follow. Cursed Scythe keeps the internal `reaper_scythe` ID for save compatibility.

Magic stones share `assets/art/relics/magic_gem.svg` and get their element color from the catalog at draw time. Prismatic Stone uses the same geometry with a multicolor tint. Keep these in `RelicPaint` so inventory, cards and the generated chest atlas stay consistent.

Damage relics use `RelicEffects.apply_damage_modifier` for both actual damage and the read-only `attack_multiplier_steps` trace. The trace starts at 1, adds baseline/reward/boon contributions, traverses inventory order, multiplies by the independent Perfect factor (1 at zero, otherwise 1.2 + combo × 0.1), and ends with darkness. Critical appears when its source activates but stays mathematically separate from additive bonuses. Flat base damage and extra hits have activation steps without changing DMG. Never implement damage arithmetic again in the animation.

Other actual relic procs emit the model's `relic_activated` signal. Pure queries and previews must not emit it. A consumed relic emits before removal so its activation can finish visually. Mid-combo damage growth can start another flight before the next hit; multiple kills feed the pending flight. Menus pause presentation; restart clears it. The initial buildup leaves combat running; City Fever plays the number sequence at 2×. The impact anticipation beat begins after the buildup. Reduced effects retain numbers and glow while suppressing tilt, particles, bob and shake.

Ordered effects must not be sorted, combined across inventory positions or cached without accounting for reorder and replacement. For example, a page before a skull and a page after a skull intentionally produce different multipliers. Runestone affects later status relics. Guaranteed status effects do not draw RNG; chance-based effects draw once at their original position.

`relic_skill_rules.gd` owns committed skill identity, Royal Seal previews, Echo Bell counters and a generated-cast queue. Only manual casts and Enchanted Missile advance Bell/Gears; character bonus Fireballs and echoes do not. Each generated skill retains its cast source, original dice, locked bonuses and effect scale, so GUI and CLI use the same normal resolution path. Turn-start missiles restore the original roll/frozen phase and never spend dice; echoes do not consume another next-skill charge or boss break mark. Fractional effect factors also feed the shared damage trace.

`relic_combat_triggers.gd` owns guarded secondary damage. Prism transfers half of direct killing excess without multiplying it again or crossing a boss phase. Powder Keg consumes five Burning stacks at ten, then deals an area attack; its proc guard prevents recursive explosions. Keep these rules outside drawing code.

`RelicSets.RECIPES` supports both incremental meal fusion and complete-only marble fusion. A recipe declares whether component effects and composite art survive fusion. `COLLECTIONS` handles non-fusing sets such as five individually owned pets; selling a member immediately disables their enhanced effects. New relics use the shared copy sequence rather than duplicating mutable counters.

## Reward selection and presentation

Enemy kill currency is owned by `RunRules.hit_enemy()` and `_crush_troops()`, using `EnemyCatalog.crystal_reward()` and the shared grant path. Piggy Bank separately stores an additional 20% in its instance sale value. Soul Vessel boosts only enemy souls by 15%, carrying fractional soul bonuses forward; it does not change gems or chest/shop soul grants. The model credits once on the alive-to-dead transition and emits `enemy_crystals_dropped`; `scripts/rewards/crystal_pickup.gd` animates only the receipt. `pending_total` temporarily offsets the displayed counter, never the spendable model balance. Pickup randomness is cosmetic, the currency endpoint is shared by both layouts, menus hide/pause the layer, and restart clears pending visuals. Final-wave rewards wait for receipts to arrive. `tests/test_crystal_pickup.gd` covers payout categories, shield/corpse exclusions, burn/tarot/city kills, fractional bonuses, modal layering, staggered counting and wave handoff.

`scripts/rewards/chest_rules.gd` owns tier names, colors, 1/1/3/5 item counts, 30/50/70/100 crystal payouts, the 3/8/15 Reroll Treasure thresholds and the 25% upgrade chain with a guaranteed fourth attempt per tier. `chest_pity.gd` tracks separate Normal/Perfect/Greed droughts and snapshots the pre-roll counters for presentation. The battle scenes configure its `user://chest_pity.cfg` store; model-only tests remain in-memory. Pity saves when the outcome is committed and survives run resets, while opening, skipping and collecting never count extra attempts. `Run.begin_wave_reward()` commits the selected route payout or relic chest outcomes once per battle clear. `reward_chest.gd` waits in a silent `closed` state until its chest hit area is clicked, then starts the reward reels; each stop tap reveals one upgrade and resumes spinning, or settles on the locked prizes. Its closed/spinning/upgrading/settling states use only cosmetic RNG, and expose only the current tier's columns. `battlefield_reward.gd` owns field chests, route arrows and the shopkeeper transition; the older `wave_chest.gd` is unused. `Run.open_debug_chest()` uses the same tier lottery without changing wave completion or the treasure bank; `_show_chest()` is the common presentation adapter and restores the previous battle phase afterward. Paid wave tarot draws are disabled.

Relic rarity is fixed at 58/30/10/1/1%, followed by a uniform eligible item draw. A guaranteed slot is chosen randomly and reserved before the other slots. `minimum_rarity` promotes low weight to the floor without increasing top-rarity odds. Owned uniques, reserved prizes, conflicting Cursed Dice and fusion-only items are excluded. Empty rarity pools redistribute proportionally. A fully exhausted relic pool falls back to tarot, then a shard. `weights_for_wave()` remains an unused optional curve; current shops and rewards use fixed rates.

All chest item slots now roll relics; tarot and shards are retired categories. Stable retired IDs remain in the catalog but cannot drop; the legacy curse category contributes weight to the relic category. `release_chest_crystals(revealed_tier)` pays only the revealed tier's remaining increment, with duplicate protection. Opening pays 30 for Normal; upgrades pay the differences without exposing future tiers through the balance or particles. Omitting the argument settles any remaining final payout. `crystal_pickup.gd` presents receipts above the chest overlay; it never grants currency and the flow waits for receipts before leaving.

`reward_chest.gd` receives locked results and builds cosmetic reels from all obtainable rewards. Horizontal layout, centered selection bands and dimmed neighbors are shared across phone and landscape. Speed, stop/skip timing, reduced effects and pickup order cannot change outcomes. `discard_unclaimed_rewards()` preserves claimed gifts and crystal payouts without consuming RNG. Full-inventory replacement, tarot ceremonies, victory and restart share the same transaction path.

Normal/Perfect/Greed use quadratic deceleration, a small overshoot, and a spring back to the prize. Ultra retains constant speed until each crisp musical stop. A second stop request finishes non-Ultra reels through the same landing events; Ultra rejects skips, including in reduced-effects mode. Ultra begins settling and starts its payout audio immediately upon upgrade or opening; it requires no stop tap. Its five reels land left to right on the authored final notes at 3.000/3.1875/3.375/3.5625/3.750 seconds, following the audio clock with mix/output latency compensation and a frame-timer fallback if audio is unavailable. Stable center-out reel identities keep the original reel centered during upgrades; side reels slide in at full height. `reward_burst.gd` renders a larger rarity-colored explosion for each landing, with a local flash, two shockwaves, long trails and bright spark cores. Mobile uses a larger logical scale; reduced effects keeps a quiet single ring. Only the central square selection takes the current reward's color; reel frames stay neutral. `scripts/audio/chest_audio.gd` owns two persistent voices: the constant-volume looping reel texture and a non-looping tier payout. `timed_audio_loop.gd` mixes repeated one-shots into an introductory segment and a steady periodic loop; the full tails overlap at an exact 0.84375-second interval without frame-timer drift. Greed selects a separately cached loop from `arcade_slot_roll2.wav`; other tiers use `arcade_slot_roll.wav`. Both original WAVs remain intact. Only the Ultra intro plays before landing; its main section continues at the reveal without restarting. Non-Ultra payouts start once on the first landing explosion. `revealed` fires once after the last reel lands for full-chest impact FX. Before reveal, pausing holds both voices in sync. After reveal, tarot selection pauses chest visuals while the payout continues; mute, cancel and restart still apply to both voices. Pause/resume is sent only when the paused state changes: Web Sample playback restarts a source on redundant unpause calls. `tests/web_chest_audio.tscn` checks actual browser playback advancement, completion and pause/resume in an isolated export. Audio never reads or changes reward RNG. `tests/test_chest_timing.gd` checks these boundaries in both layouts and measures live playback alignment with `--capture`.

`scripts/relics/relic_pickup.gd` owns the short lift, accelerating flight and inventory impact for picked relics. `scripts/relics/relic_ui.gd` starts it only after successful acquisition and resolves its destination from the resulting inventory, including stacks, replacements and fusions. Wave and chest transitions wait for the landing; repeated taps are ignored during flight. Menus pause it, focus loss only releases held input, and restart or skipping remaining treasure clears it without undoing an already claimed reward. Reduced effects retain a direct flight and landing ring without tilt, trails or squash.

Tarot generators use `RelicEffects.TAROT_GENERATORS` and the acquisition hook. `RunRules.grant_random_tarots()` owns reward RNG and banned-card filtering; generated cards go directly into the separate consumable inventory. Complete-turn guards prevent duplicate grants, and saved bonus casts do not advance counters. Ancient Prophecy snapshots one repeat when a real card commits. `TarotEffects.pending_repeat` owns the transient activation outside inventory; `TarotCast` reuses the normal choice/target/FX flow before resuming battle. Repeats cannot recursively proc, and a failed or declined second choice never undoes the first activation.

## Add a skill or character

The common `MultiHitSkill` lifecycle supports all skills and multi-use modifiers. Damage previews and actual attacks share `unmitigated_damage`, then apply target-specific caps and defenses. Keep fractional base damage until that shared rounding point. City numeric skills override `attack_base` and limits, not the multiplier or critical formula.

Skill classification, names, base formulas, support effects and several presentation captions are still specific to The Horror. Before adding a second character, introduce a character skill definition/behavior registry behind those existing entry points, then have the home skill reference and combat captions read that registry. Do not copy the battle scene or fork the entire combat model for each character.

Freeze the use budget at cast start. A saved skill carries its own modifiers and uses current model modifiers when activated. Repeated hits and saved bonus casts must preserve the existing turn and boon timing rules.

## Add enemy artwork and death pieces

`scripts/enemies/enemy_visuals.gd` selects normal/elite sprite overrides and supplies an optional piece set, source dimensions and emission positions. `enemy_debris.gd` handles cosmetic scatter, spin, floor bounces and brief pixel blood splatter with its own RNG. The battle draws pieces in the defeated enemy's existing layer, pauses them with menus, and clears them on wave changes or restart. Combat, kill rewards and corpse targeting stay in the model. Enemies without a piece set keep their original death pose.

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

`scripts/enemies/enemy_catalog.gd` owns the five enemy identities, normal/elite stats and weighted skill pools. `scripts/enemies/enemy_actions.gd` filters valid options, locks an intent and resolves one impact at a time; `scripts/combat/battle_rules.gd` exposes complete-action and per-impact entry points. Taunt targeting and area protection are shared by skills, relic attacks and tarot. `scripts/progression/wave_catalog.gd` holds the thirty-wave route and display sizes: player 224→288 by wave 20; enemies 192→88 by wave 19, remaining that size through wave 30, with unused city troops at 40; paving/scenery shrink steadily. `scripts/progression/run_rules.gd` owns progression. `scripts/combat/combat_motion.gd` samples the growth squash/stretch from transition progress; both layouts render it around the player’s feet without changing combat state or the final size.

`relic_drop_table.weights_for_wave` moves each starting rarity rate 10% toward an even 20% split per wave. This curve is unused; chest rewards, tarot relic rewards and ordinary shop slots use the fixed catalog weights. Concrete rewards remain locked before presentation.

## Six-dice turns (October 16, 2026)

`dice/dice_art.gd` samples the user's thirteen-cell, 48×48 PNG atlas: six numbered faces and seven rolling frames. Battle, home, debug and miniature skill previews share it with nearest-neighbor filtering. The original PNG and Aseprite source remain unchanged in `assets/art/dice/`.

`dice/dice_roll_motion.gd` owns cosmetic per-throw frame offset, forward/reverse playback (30–38 fps at normal speed), whole rotations and curved travel inside the dice area. It receives only the die's cosmetic RNG and samples by normalized time, independent of gameplay outcomes and render frame rate. `die.gd` returns to the fixed hexagram vertex and the model's committed face, keeping the existing quick counterclockwise landing order. Spent dice stay still on rerolls; menus pause travel and frame playback. Reduced effects retain animated sprite frames but suppress roaming, rotation and landing squash. The center prompt is hidden during rolling so it cannot cover the moving art. `tests/test_dice_sprites.gd` covers atlas selection, animation direction, bounded paths, results/RNG, rerolls, menu pause, restart and both layouts.

`dice/dice_turn.gd` owns six faces, three throws, selection, cancellable groups and committed dice. `dice_patterns.gd` validates only unique 3–6-face straights and snapshots matching groups from newly rolled indices. `combat/flamelings_skills.gd` owns this character's coefficients, Burning timing and leftover percentage healing. Fire Storm applies its Burning once after all five damage pulses, including all targets, and before cast-completion relics; Fireball and evolved Slash retain on-hit Burning. Preview totals exclude Storm self-ignition during the cast. `BattleRules.roll_attacks` resolves automatic matches without spending dice; each hit chooses a living legal target, shares `_apply_attack_hit()` with skills, and preserves next-skill tarot. Matching-hit relics retain their modifiers. The queue is blocked from input and cleared on restart/turn preparation or victory.

`effects/flame_spell.gd` paints the character's four straight attacks and automatic embers with world-tracked endpoints. `dice/leftover_volley.gd` now merges leftover embers into the player, committing one rounded percentage heal before enemy actions. Skill-only use of all six dice still grants a bonus turn via `_grant_dice_bonus_turn()`; neither automatic attacks nor leftover healing qualify. Victory takes precedence. Save skills remain disabled.

`Run._bank_unused_rolls()` banks each completed pool by `turn_id`, independently of `round_number`. Bonuses bank before reset; ordinary turns bank after enemy/status resolution; wave-ending casts bank at completion. Untouched/frozen pools grant nothing. This prevents repeated settlement and permits multiple bonuses within one enemy round.

`dice/dice_selection.gd` owns center roll input, path-sampled, reversible drag connections, cached skill previews and bounded cosmetic sparks. Six dice share the hexagram vertices in both layouts. Releasing a valid variable-length combination summons; returning to earlier dice rewinds, re-entering the last of two disconnects it, and pulling 85% of a die spacing (capped at 1.35 hit-box widths) away from the third breaks that link. A contact margin prevents edge jitter from undoing newly selected dice. Incomplete/focus-interrupted gestures clear without cost. `dice_connection_beam.gd` caches a procedural filament texture and renders its glow/streaks without gameplay RNG. Only thrown dice compatible with an available straight have outward pixel waves every two seconds (static with reduced effects); the membership cache updates with selection and spent dice. `dice_idle_feedback.gd` caches only maximum-length straights, retaining tied physical-dice alternatives and excluding smaller subsets. Matching groups glow while their automatic queue resolves; `die.gd` applies a drawing-only bounce per group and firing die, without changing hitboxes. Menus pause it and reset clears it. Both layouts use the same controller and model. The legacy three-die `roll()` / `set_test_roll()` are simulation fixtures; live gameplay exclusively uses `roll_pool()`.

Roll-changing items remain defined but are suspended by catalog `DISABLED` lists. Relic sequences, shared rarity drops, tarot draws, inspection and use validation respect these lists. Trio-dependent relics commit once on cast/save, preventing cancel-and-reconnect bonus farming; per-throw effects still trigger per accepted roll. The temporary city switch retains city code for later adaptation; the current campaign ends each ten-wave level at its boss.

Validate character damage, Burning order and heal semantics with `tests/test_flamelings.gd` and real casts with `tests/test_flamelings_scene.gd`. Other pool coverage: `tests/test_six_dice.gd`, `tests/test_bonus_turns.gd`, `tests/test_reroll_treasure.gd` and `tests/test_six_dice_scene.gd`; these cover selection/locking, rerolls, sequential casts, buffs, saved skills, freeze, disabled rewards, independent faces, both layouts, touch-sized controls, drag previews/cancellation, and modal visibility.

`dice_pattern_style.gd` shares pattern colors and flame levels between the selection preview and skill bubble. Selected die outlines stay white; `die.gd` paints tier flames behind its face, while `dice_selection.gd` owns capped rising sparks. Drag backtracking clears a one-die remainder without changing single-tap selection. `effects/bonus_turn_banner.gd` is a draw-only Node2D: 0.20-second entrance, one-second centered hold, 0.22-second exit, independent of battle speed and input, below menus and held items.

The center roll prompt resets its animation with `DiceTurn.turn_id`: the initial Roll label scales around its text center twice per second, while subsequent throws show Reroll and the remaining count. Confirm and Stop hide the count; reduced effects suppress the scale pulse.

Kill impact uses an independent real-time 0.39-second envelope in `battle.gd`, triggered only when `_sync_corpses()` first records a death. It immediately drops to 0.1x speed, holds for 0.15 seconds, then smoothly recovers over 0.24 seconds, taking the minimum with other cinematic rates rather than multiplying them. World effects, corpse motion and attack waits share it; input and throw timing do not. Restart clears it. One small camera wobble starts immediately at impact, uses the full envelope’s real-time progress, and fades to zero when recovery finishes; it replaces ordinary impact jitter and is suppressed by reduced effects or modals.

`shared/prompt_pulse.gd` provides the rectified-sine scale shared by Roll and End Turn (two pulses per second, 1.0–1.22x, no rest at minimum). End Turn prompts only when `DicePatterns.has_combination()` finds no three-face straight in unused dice; all rerolls must also be exhausted. Button hit areas stay fixed.

## Checkpoint shops

`rewards/shop_stock.gd` owns checkpoint eligibility, eight locked listings, exact-rarity shop guarantees, inclusive randomized prices, visit markups and atomic buys/refreshes. `run_rules.gd` resets it per run and blocks advancement while a checkpoint visit is pending or open. `battle.gd` visits after the chest/optional tarot flow and before growth. `rewards/shop_ui.gd` handles inspection, explicit purchases, full-inventory replacement and leaving; it reuses relic/tarot pickup animations and the sortable relic rail. Stock RNG is independent of paint and comes from the existing reward stream. Disabled/fusion-only/owned unique items remain excluded. The shared announcement accepts a label and holds for one second. `tests/test_shop.gd` covers economy, checkpoint gating, both layouts, and input flow.

The shop draws open wooden shelves next to the CC0 hooded keeper; `offer_art_rect` and `offer_name_rect` reserve separate artwork/text bands. Taps and dragging merchandise onto the large BUY button share `_attempt_buy()` and the same model transaction. A drop elsewhere cancels. `shop_keeper.gdshader` removes only the source's palette-black backdrop at display time.

`relics/inventory_page.gd` owns the ten-slot, five-column inspection page and individual item descriptions. Battle, shop and chest shortcuts use the same modal; all ten slots remain visible. Shop, chest and Emperor/World replacement context is carried into the page, but only the explicit replacement button commits. Full-inventory chest and tarot grants open it directly, with the locked incoming relic visible. Cancellation returns to the unclaimed chest prize or calls `TarotCast.cancel_choice()` to focus the original unconsumed card; its locked grant is retained. Successful commits close without cancelling the pending pickup. Restart closes without resuming an interrupted repeat. Opening cancels captured item/skill gestures. It blocks underlying input, pauses battle, and leaves chest payout audio running. `tests/test_inventory_and_layout.gd` covers both layouts, drag cancellation, direct purchases, modal click isolation and chest replacement.

`enemies/enemy_formation.gd` shares stable world-space formations between both layouts. Portrait rows reserve vertical headroom; landscape rows interleave so front-row intent icons fall between back-row actors. Intent and health geometry follow the shared camera projection. The layout test checks all 19 waves with and without target zoom, including taunt labels.

## Route and character progression

`progression/run_rules.gd` owns route history, locked choices, direct chest payouts, separate Blood Gems/Souls, and automatic soul leveling. Shop destinations increment the same stage counter but load no enemies. `progression/wave_rewards.gd` defines route kinds and the fixed cumulative payout bands. `rewards/battlefield_reward.gd` presents battlefield chests, directional route controls and the keeper arrival; its callbacks never roll rewards.

`progression/character_evolution.gd` queues each level signal and reveals one cached sprite/silhouette per evolution. Stats commit once in the model, before animation. `BattleRules.character_damage_factor()` applies the character level before flat relic bonuses, shared by previews, damage traces and actual hits. `tests/test_wave_rewards.gd` covers complete-run restrictions, currency distributions and leveling; `tests/test_route_flow.gd` drives both real scene layouts through chests, shops and evolution.

`ShopStock` reserves one sealed Soul Bottle with every stock roll: a 100–300 Blood Gem price and hidden integer souls in `[ceil(price/20), floor(price/10)]`. Purchases commit payment and sold state before granting souls, use the existing automatic level-up path, and never consume inventory capacity. `ShopUI` reveals the amount only after purchase; evolution visuals queue until the shop closes. The initial battle route samples the three battle reward types equally and seeds route history with that result.

`rewards/soul_pickup.gd` owns cosmetic soul-chest receipts, bounded orb bursts, counter animation across level thresholds, and the shared Souls-header destination. The model commits the reward once; receipts never alter resources or gameplay RNG. Evolution waits for orb arrival. Chest crystals use a per-receipt speed override, leaving enemy timing unchanged.

`Effects.damage_scale()` shares log10 sizing across damage numbers, per-target flame visuals and hit particles without adding particles. Flame geometry scales around impact points while its endpoints remain camera-aligned. `RunRules.level_cost()` requires 10 × current level, without a level cap; each level fully heals and multiplies character damage and maximum HP by 1.1. `CharacterEvolution` changes form at levels 5 and 10, retaining the final art afterward.

Route choice latches `Battle.travel_direction` only after model acceptance. `BattlefieldView.entrance_translation()` supplies the same entry vector to formations and the keeper; `BattleBackdrop` tiles ground and prop rows in both axes, caching vertical scroll too. Matching attacks wait once after dice reveal using a menu-aware presentation clock. Reroll and End Turn prompts share the existing pulse and are gated by remaining combinations and rolls. `EnemyLevel` owns per-enemy HP/damage/reward scaling; `WaveCatalog` authors each unit’s role, level and elite flag rather than a shared wave multiplier. A wave can mix levels. `EnemyCatalog.make()` accepts an integer level and rounds once from level-one data; `phase_health()` handles each boss bar, and Commander reinforcements have an explicit lower level. `EncounterBalance` now only scales soul-route chests, preserving their reward-band RNG. Charged-hit counts live in `EnemyCatalog.release_hits` for both resolution and inspection.

`rewards/treasure_pickup.gd` listens to committed `reroll_progress_changed` events: one cosmetic orb per credited point, with meter fill on arrival and claim/restart cancellation. `audio/one_shot_audio.gd` preserves authored one-shot levels and merges only `enemy/chop` cues requested within 25 ms. Ordinary repeated effects and staggered deaths receive no attenuation or per-clip cap; the original 12-voice limit replaces the oldest tail. Enemy crystal drops retain their existing short cooldown. Chest music and charging loops retain their dedicated owners.

## Three ten-wave levels (October 25, 2026)

`progression/campaign_progress.gd` owns the completed-level marker and the immutable next-level entry build. `RunRules` keeps the global 0–29 encounter index, reports victory at 9, 19 and 29, and exposes separate level/local-wave labels. Capture waits for the battlefield reward and automatic reroll chest to finish. Restore keeps XP, currency, inventory order, item counters and permanent tarots without replaying acquisition effects; it resets combat state and starts healthy. Retry discards gains made after the saved entry. Chapter completion clears the entry checkpoint.

`Home` owns persistence at `user://campaign_checkpoint.dat`, writes via a temporary file, injects the checkpoint into either battle layout, and routes Start to the correct level. Standalone scenes and the CLI use in-memory checkpoints; debug wave loads cannot overwrite campaign progress. GUI Start, retry and home return share this owner. Chest pity remains independently persistent and is never rewound with a retry. The home route shows three ten-wave rows.

The current thirty-wave roster alternates small introductions, familiar mixed squads and pressure peaks. Every role appears normally before its elite version. `WaveCatalog.requires_combat()` protects first appearances, designed difficulty jumps and bosses from shop replacement; other waves keep the normal route rules. Per-enemy level L scales HP by 1.30^(L-1), damage by 1.04^(L-1), souls by 1+0.12*(L-1), and blood gems by 1+0.10*(L-1). Existing base class rewards remain 5/10/20/50 souls and 5/8/10/15 gems. Shields, skill weights, player leveling and relic values are independent. Normal Paladins no longer charge; elite Paladins charge twice then strike twice next turn, while elite High Priests release immediately on their second charge. `tests/test_campaign_progress.gd` covers boundaries, reward gating, disk reload, immutable carryover, CLI continuation and both scene layouts. The dated HTML report records the policy assumptions and before/after measurements.

Character bonus Fireballs use the generated-cast queue as two distinct single-use skills. `FlamelingsPassive` marks the triggering cast without changing its use count; after it finishes, two fixed 3-4-5 casts run automatically with separate bubbles and no use orbs. They preserve the triggering Strength/critical and one attack-boon charge for the sequence, each counts for boss interruption, and neither charges the passive nor Echo Bell/Alternating Gears. Boss phase transitions still wait for this bonus sequence to finish.

Enemy level tags share the HP bar in both layouts; long-hold inspection and CLI state expose the individual level and base drops. `tests/test_enemy_levels.gd` covers mixed-level payouts, same-level consistency, corpse deduplication, boss phase/summon levels and introduction gates; `tests/test_enemy_levels_scene.gd` checks bilingual label fit, inspection and charge timing. The current enemy-level report includes the authored wave chart and reproducible CLI comparisons.

## Third-level encounter pacing and Fanatical Mage (October 25, 2026)

`WaveCatalog` authors higher-level mixed squads in three-wave blocks: pressure at global waves 11/14/17 and 21/24/27, with familiar combinations and shop opportunities between. The first ten waves, player scaling and relic values are unchanged. Global waves 10/20/30 end at Commander LV.5, Spellsword LV.11 and Fanatical Mage LV.13. High-level taunt tanks at 21/27 have normal archers, avoiding repeated group-heal stalemates. The report `third-level-balance-report-20261025.html` records meal-priority tests, iterations, excluded Ultra prizes and limitations.

`enemies/fanatical_mage.gd` owns servant identities, stable formation slots, hit redirection, splitting, phase-two cleanup and the demon pact. Small servants cap at six; the demon has its own formation position and cannot consume a small-servant slot. Summons grant neither loot nor on-kill relic rewards. Normal attacks redirect once with no spill, while `direct_enemy_hp_damage()` preserves exact HP costs for Tower and the pact. The demon shares cast-contact interruption with bosses through an explicit catalog capability, without falsely treating it as a two-phase boss. Freeze preserves its charge. The pact runs once after the enemy phase, uses a level-scaled 300 HP sacrifice and dismisses all servants on the final mage death. New summoned enemies wait until the next enemy phase.

`BossPresentation` reserves separate health, intent and charge areas for the mage, demon and six small summons in both layouts. Live neighbours determine regular HP-bar gutters; dismissed summon slots never constrain widths. Summon arrivals and damage-redirect links are cosmetic. `test_fanatical_mage.gd` covers rules and farming prevention; `test_fanatic_scene.gd` checks the densest formations and captures both layouts.
