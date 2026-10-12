# Code structure and extension guide

This is an implementation guide. The shared Mandarin Google Doc remains the design specification.

Prioritize clear ownership, shared rules and small extension points for future functionality. This is a small game; do not introduce caching or generic frameworks without a demonstrated need.

## Boundaries

- `multi_hit_skill.gd` represents one skill, including targeting traits, copies, use modifiers and its frozen cast budget.
- `battle_rules.gd` owns combat state, HP, statuses, action timing and combat events. It does not read wall-clock time or access scenes.
- `run_rules.gd` adds wave progression, chest/relic rewards and city combat. It reuses the base numeric damage calculation before applying city-specific limits.
- `relic_inventory.gd` owns acquisition, uniqueness, slot order, replacement and fusion. Reordering changes the array order; effect evaluation follows it.
- `relic_drop_table.gd` owns the two-stage rarity/item draw. Wave offers, treasure relics and cosmetic reels share it; callers supply eligibility and their own RNG.
- `relic_effects.gd` owns relic behavior. `STATS` describes passive modifiers and flags, `STONES` describes immunity/status effects, and `TURN_CHARGES` describes periodic charges. Lifecycle hooks handle effects that mutate state.
- `damage_feedback.gd` owns the cast-only multiplier display, ordered particle flights, increase waves and decrease shakes. `relic_ui.gd` owns inventory glow/tilt reactions. Both consume model results; neither changes combat numbers. `skill_orb_paint.gd` shares the multi-hit orb shell/core with brighter, larger multiplier energy. Relic dragging is captured on a horizontal rail, and descriptions follow the held item through reorder until release.
- `dice_odds.gd` calculates the conditional chance of a six. It caches immutable copies of weight values, detects array replacement and in-place changes, and never consumes RNG.
- `battle.gd`, `battle_portrait.gd` and presentation nodes own drawing, input and animation. They display model results and should not decide combat outcomes.

Combat RNG and reward RNG remain separate. Cosmetic nodes use their own random generators. Previews must never consume randomness, spend charges, change health or update statuses.

`BattleRules.damage_event()` separates `amount` (actual HP/shield loss) from `display_amount` (calculated hit before remaining-health clamping), and explicitly flags instant kills. Gameplay hooks such as lifesteal consume actual loss; UI uses the display amount and suppresses execution numbers. `Effects.damage_font_size()` owns the log10 scale with a 24px floor. Catalog `counter` metadata chooses inventory badges; `charges > 0` drives the repeatable ready halo independently of brief activation effects.

## Add a relic

1. Add its ID, rarity, display name and description to `relic_catalog.gd`. Add the sourced PNG and credit mapping in `assets/art/relics/`.
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

For each relic reward, roll rarity once at 58% common, 30% rare, 10% epic, 1% legendary and 1% cursed, then select uniformly among eligible items in that rarity. Adding more items to a rarity divides its existing probability; it never increases that rarity's total weight. Owned unique relics, reserved prizes and fusion-only items are excluded. Empty rarity pools redistribute their weight proportionally among the remaining pools. A fully exhausted relic pool falls back to rubies in treasure chests.

Treasure categories are a separate roll: relics have weight 2 (50%), rubies and summon shards weight 1 each (25%). Retired flat-damage, multiplier and potion IDs retain their numeric positions, but are excluded from both actual rolls and cosmetic filler even when custom weights request them; they cannot grant rewards. Cursed is a relic rarity, not a separate reward roll. The legacy curse index remains only for presentation and compatibility; any input weight assigned to it joins the relic category.

`Run.open_chest()` resolves every category, rarity and relic ID before returning. `reward_chest.gd` receives those locked results and generates only cosmetic filler, using separate RNG and every obtainable reward as visual filler. Animation speed, reduced effects, replay and pickup order cannot influence results or future reward rolls. Collecting applies an already chosen prize; it never chooses one. `discard_unclaimed_rewards()` resolves only the remaining slots without granting effects, recording pickups, or consuming RNG. The chest skip control ends the presentation immediately and the existing sequence restores its previous phase, including victory and full-inventory replacement.

`relic_pickup.gd` owns the short lift, accelerating flight and inventory impact for picked relics. `relic_ui.gd` starts it only after successful acquisition and resolves its destination from the resulting inventory, including stacks, replacements and fusions. Wave and chest transitions wait for the landing; repeated taps are ignored during flight. Menus pause it, focus loss only releases held input, and restart or skipping remaining treasure clears it without undoing an already claimed reward. Reduced effects retain a direct flight and landing ring without tilt, trails or squash.

Tarot generators use `RelicEffects.TAROT_GENERATORS` and the acquisition hook. `RunRules.grant_random_tarots()` owns reward RNG and banned-card filtering; generated cards go directly into the separate consumable inventory. Complete-turn guards prevent duplicate grants, and saved bonus casts do not advance counters. Ancient Prophecy snapshots one repeat when a real card commits. `TarotEffects.pending_repeat` owns the transient activation outside inventory; `TarotCast` reuses the normal choice/target/FX flow before resuming battle. Repeats cannot recursively proc, and a failed or declined second choice never undoes the first activation.

## Add a skill or character

The common `MultiHitSkill` lifecycle supports all skills and multi-use modifiers. Damage previews and actual attacks share `unmitigated_damage`, then apply target-specific caps and defenses. Keep fractional base damage until that shared rounding point. City numeric skills override `attack_base` and limits, not the multiplier or critical formula.

Skill classification, names, base formulas, support effects and several presentation captions are still specific to The Horror. Before adding a second character, introduce a character skill definition/behavior registry behind those existing entry points, then have the home skill reference and combat captions read that registry. Do not copy the battle scene or fork the entire combat model for each character.

Freeze the use budget at cast start. A saved skill carries its own modifiers and uses current model modifiers when activated. Repeated hits and saved bonus casts must preserve the existing turn and boon timing rules.

## Add a status

Add the status ID, stacking/cap behavior and duration unit to `status_effect.gd`, presentation metadata to `status_catalog.gd`, and its icon to `status_paint.gd`. Implement its actual rule in the relevant combat phase. Player and enemy application paths must both be considered; the city remains immune to statuses. New status effects must preserve the turn-end rule: both sides' status ticks finish before opening a victory reward screen.

## Performance rules

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
- The `TranslationLiveReload` autoload polls every 0.35 seconds only in the editor executable, including while the scene tree is paused. `translation_csv.gd` compares content hashes, waits for two stable reads, parses quoted/multiline CSV, and validates column counts, unique keys, and formatting placeholders before replacing the catalog. This catches same-second and atomic-rename saves. Invalid/incomplete saves retain the last valid snapshot.
- `GameText` registers each complete snapshot with `TranslationServer`, removing this catalog's previous runtime and compiled resources so deleted entries do not revive stale text. It leaves other translation catalogs intact. Gameplay never depends on the watcher.
- Exported games do not watch files: they use the imported translations bundled by Godot during export. Publishing new wording requires a new build/upload.
- Use `GameText.text()` before measuring or drawing. For dynamic values, use `GameText.format(template, values)` **before** interpolation. Translate names before combining them with dice codes. Keep formatting tokens identical in each language.
- Use `GameText.lines()` for paragraphs: Godot's Unicode line breaking handles Chinese punctuation, English words, long words, and explicit newlines. Do not split only on spaces.
- `GameText.prepare_font()` adds bundled Noto Sans SC at weight 600 as the Latin pixel font's fallback. `GameText.description_font()` keeps Silkscreen pixel letterforms but uses a higher-resolution MSDF atlas for scalable body text and its CJK fallback. Titles and numeric debug input retain their original metrics. Wrap and measure body text with the same description font used for drawing.
- Relic descriptions accept an optional translation callable, so counters and static descriptions share one implementation without coupling the model to the selected language. Damage-feedback notes carry their formatting arguments separately.
- To add a language, add its locale/name to `GameText`, its CSV column, and its imported translation resource to Project Settings → Localization. The current two-button battle row supports English/Chinese; extend its layout for additional choices. Add font coverage as needed.

Run `godot --headless --path . --script tests/test_localization.gd` for translation coverage, placeholder/glyph checks, text wrapping, preference persistence, and switching without resetting a run. Add `-- --capture` without `--headless` to capture both layouts and languages. Tests write preferences to an isolated temporary path.

Run `godot --headless --path . --script tests/test_translation_live_reload.gd` to test saves without reimport, debouncing, malformed files, quoted CSV, atomic replacements, runtime updates, and preservation of paused battle state. Add `-- --capture` without `--headless` for before/after screenshots. The fixture is isolated under `user://`; tests never edit the real CSV.
