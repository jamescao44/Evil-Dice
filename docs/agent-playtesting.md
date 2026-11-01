# Agent playtesting

`python3 tools/playtest.py --seed 42` starts a headless Godot process and prints one JSON response per input line. This is an agent interface, not another player UI. It uses `RunRules`, the six-dice pool, and the existing combat, tarot, relic, reward and shop transactions. It skips presentation time; it does not duplicate damage formulas or choose a strategy automatically.

The first response includes the run state and log path. Send commands over stdin; blank lines are ignored by the Python bridge. `{"action":"quit"}` or EOF exits. Set `GODOT` or pass `--godot /path/to/Godot` if the executable is not found automatically.

```sh
python3 tools/playtest.py --seed 42 --log /tmp/evil-dice-run.jsonl
python3 tools/playtest.py --replay /tmp/evil-dice-run.jsonl
python3 tools/playtest.py --resume /tmp/evil-dice-run.jsonl --log /tmp/evil-dice-run-continued.jsonl
```

`--commands /path/to/commands.jsonl` accepts a batch of explicit decisions. Replay checks every response exactly; resume reconstructs the same state before accepting new commands. Both require the same source fingerprint, including uncommitted rule changes. Existing logs are never overwritten. Default logs go to ignored `test-output/playtests/`.

## Health and Fireball tracking (required for future balance tests)

Every `PlaytestSession` records current/max HP, HP fraction, shield, player level, base damage and a fixed **3-4-5 Fireball** damage preview. Samples include command boundaries, individual enemy-action resolutions and level-up full heals. Use the standard runner below for future campaign balance tests: it saves raw JSON, a source fingerprint (including uncommitted rules/policy), engine diagnostics, CSVs and per-seed charts automatically. Each run gets a new directory; preserve failed runs too.

```sh
python3 -m venv test-output/plot-env
test-output/plot-env/bin/python -m pip install -r tools/requirements-playtest.txt
test-output/plot-env/bin/python tools/balance_test.py --seed-offset 112000 --seed-count 6
# Optional: --paired compares policies with and without tarot use.
```

Fireball is **damage per use before shields/overkill**, with current player/relic/tarot/combo modifiers, against no particular enemy. Physical-die gemstones, target-specific bonuses, extra uses and passive/item attacks are excluded; `fireball_uses` is recorded separately. This is a comparable reference, not observed damage from every actual Fireball. Samples do not consume RNG or next-skill charges. Health is sampled after each model resolution; changes within one resolution can be absent. Horizontal spacing within each wave shows sample order, not elapsed time. Boss bands are shaded; dead runs stop where they died.

Relic transitions are logged with names, quantities, sources and before/after inventories, including stacked Codex Pages, duplicate relics, fused ingredients, explicit sales, replacements and Fool rerolls. Fusing ingredients is not selling them. Green triangles mark acquisitions; red triangles mark sales/replacements. Numbered diamonds mark inventory-associated Fireball **cast** increases of at least 25% and 10 damage, including extra uses. Pure combo/Strength spikes are not labelled as build gains. All markers and transactions are exported to `*-power-gains.csv` and `*-relic-events.csv`; the plot labels the five largest gains per run. These are observed associations, not isolated causal tests, and utility/item/status damage is outside the Fireball reference.

The main pacing chart is `*-wave-actions.png`: separate counts for **Fireball, Fiery Slash, Fire Storm and Brimstone**, plus **2/3/4/5/6-alike groups** per wave. Each executed bonus Fireball, Enchanted Missile, Echo or chip skill is a separate cast of its skill type; the raw data preserves its source. Repeated uses of one cast and damage ticks do not inflate cast counts. Auto groups count once when they first execute; their individual shots/AOE pulses are additional CSV columns. Queued attacks cancelled by victory are excluded. `*-wave-actions.csv` also retains begun combat rounds as supporting data (finishing and frozen turns count; shops/rerolls do not). Failed or unfinished waves retain counts spent, with no claimed clear time. Combined wave damage is intentionally not the pacing metric.

Interactive `tools/playtest.py` also stores samples in every JSONL response and creates CSV/PNG files on normal exit. It uses the current Python's matplotlib, `PLAYTEST_PLOT_PYTHON`, or the environment above. Missing plotting dependencies produce an explicit message while preserving the raw log. Replays still check the recorded responses exactly; resume retains the existing samples.

For a custom test, include `"telemetry": session.metrics.report()` in each result before cleanup (already included in campaign, pressure, first-level, encounter, level-gap and reroll probes), then run:

```sh
test-output/plot-env/bin/python tools/plot_playtest.py test-output/custom.json
# Also accepts a tools/playtest.py .jsonl log; legacy logs without samples must be rerun.
```

Do not invent past health dips or Fireball values from old wave-end summaries. Keep the same seeds, policy and Perfect assumptions for before/after comparisons, and check the engine log for errors. Focused verification: `tests/test_playtest_metrics.gd` and `tests/test_playtest_session.gd`.

## Decisions

All slot numbers are **one-based**. Tarot `instance` is the stable inventory instance ID, not its position. Responses include `state.actions`, available combinations, descriptions, enemy intentions/statuses, inventories, and any pending choice. Invalid commands return `ok:false` and a reason. Use the returned state to choose the next action.

| Command | Meaning |
| --- | --- |
| `{"action":"state"}` | Inspect current visible state without consuming RNG. |
| `{"action":"start"}` | After resolving level-one or level-two rewards, continue to the next level with the entry build. |
| `{"action":"roll"}` | First throw of the turn: roll six dice, then resolve matching attacks and roll relics. |
| `{"action":"roll","perfect":true}` | Assume Perfect on the opening throw. Default is false. |
| `{"action":"reroll","die":3}` | Immediately reroll one unused die; spend one roll, preserve combo, never repeat matching attacks. |
| `{"action":"form","dice":[2,4,6]}` | Reserve the indicated physical dice as a straight. |
| `{"action":"cast","target":1}` | Cast the formed skill; omit target for the same automatic random selection as the GUI. |
| `{"action":"cancel"}` | Cancel the formed skill or pending tarot choice. |
| `{"action":"end"}` | End without casting, settle unused rolls, resolve enemies/statuses and start the next turn. |
| `{"action":"ice"}` | One ice-breaking tap; the third finishes the frozen turn. |
| `{"action":"tarot","instance":3}` | Use that card; pause for a choice if needed. |
| `{"action":"tarot","instance":3,"target":2}` | Use a targeted card, respecting taunt. |
| `{"action":"choose","die":4,"face":6}` | Resolve Magician's pending choice. |
| `{"action":"choose","ban":"fool"}` | Resolve Hanged Man's pending choice. |
| `{"action":"choose","replace":2}` | Replace an owned relic for a pending Emperor/World grant. |
| `{"action":"choose","discard":true}` | Discard that incoming relic. The granting card stays consumed. |
| `{"action":"sell","slot":1}` | Sell an owned inventory slot for its current blood-gem value. |
| `{"action":"treasure"}` | Spend 20 unused rolls on a Normal Chest with the shared upgrade chain; no tier choice. |
| `{"action":"open"}` | Open the closed battlefield reward chest. |
| `{"action":"take","slot":1,"replace":2}` | Claim a revealed chest prize; omit replacement when there is room. |
| `{"action":"discard","slot":1}` / `{"action":"skip"}` | Discard one prize / all remaining prizes. |
| `{"action":"route","slot":2}` | Choose one of the two displayed destinations. |
| `{"action":"buy","slot":4,"replace":2}` | Buy shop stock; replacement is optional. |
| `{"action":"refresh"}` / `{"action":"leave"}` | Pay the shared refresh price / leave the shop. |
| `{"action":"divination"}` | Begin the keeper's free three-card choice. |
| `{"action":"choose","slot":2}` | Keep a revealed tarot candidate. |
| `{"action":"reorder","from":3,"to":1}` | Change relic activation order. |

Card-specific choice fields can also accompany the original `tarot` command. Ancient Prophecy repeats effects through the shared model; choice-based repeats pause for a fresh decision, with a negative instance ID identifying the already-consumed card. Cancellation never refunds Emperor/World.

## Evidence and limits

- `events` are the game's model events. Their raw `target` indices remain **zero-based**, with `-1` for the player; commands and state slots are one-based. Damage events distinguish actual HP loss (`amount`) from the displayed hit (`display_amount`).
- Each visible enemy includes its individual `level`, `soul_reward` and `gem_reward` (before item bonuses). Enemy levels can differ within a wave; previews and payouts share the gameplay catalog.
- The state includes cumulative rolls, skills, tarot uses, enemy phases, damage taken, explicit healing events and kills, plus per-wave milestones, boss charge/release/interrupt counters and level/wave identifiers. Level-up full heals are separate `level_up` events, not included in the explicit healing total. Shop visits do not consume a battle wave.
- No player save, settings, or persistent chest-pity file is written. Each run starts with fresh in-memory pity and a private in-memory campaign checkpoint. Levels one and two stop at `level_complete`; resolve rewards and send `start` to continue. The GUI separately persists the current level-entry build and retries that level after defeat. Seed and explicit Perfect outcomes are recorded assumptions; the CLI does not test a player's timing skill or simulate the difficulty of Stunned timing.
- Sealed bottle amounts, unopened chest prizes and future rolls are hidden. Once a chest opens, animation is skipped to its already-committed result. Inspection does not redraw RNG.
- Damage previews use the shared calculations; they exclude shield absorption, overkill and bonus Fireball echoes. No timing/FPS, audio, targeting ergonomics or animation-quality conclusions can be drawn from a headless run.
- Make deliberate skill/target/tarot/relic/shop choices when doing a balance playthrough. The deterministic smoke-test policy in the tests is only a flow check, not evidence about normal player strength.

Validation: `godot --headless --path . --script res://tests/test_playtest_session.gd` checks shared-rule parity, every tarot, repeated choices, transactions, information boundaries and seeded natural-run completion. The graphical game has no dependency on `scripts/testing/` or `tools/`.

## Balance probes

`godot --headless --path . --script res://tools/balance_probe.gd -- test-output/probe.json 0.35` runs isolated encounter probes and 12 complete policy runs. The policy uses only published state, prioritizes damage/kills and charge interruption, buys ranked relics, and uses selected utility tarots. Fusion items retain high preference scores so the policy does not discard a combined meal as an unknown item. It is a declared heuristic, not human play. Reroll Treasure opens a Normal Chest with the shared upgrade chain. Every chest tier is collected, including Ultra. Evaluate all prizes and salvage only when a full inventory has no worthwhile replacement; never exclude a chest tier for balance testing. Optional trailing `runs 10000` skips isolated probes and offsets seeds for held-out runs. Keep each output and its source snapshot rather than overwriting previous revisions.

Current balance policy: `godot --headless --path . --script res://tools/current_balance.gd -- test-output/current.json` runs twelve paired seeds with/without tarot use. Add `probes` (optionally a wave number) for fixed-loadout encounters. Natural gem drops are equipped/merged through CLI commands, unopened rewards remain hidden, all chest tiers are collected, and omitted cast targets now use the same automatic selection as the GUI. The campaign has three eight-wave levels (bosses at 8/16/24). Calculate ordinary and boss throw averages separately from the per-wave cumulative totals, including rerolls and retaining failed runs. Enemy snapshots expose `modifier`, `element`, `swift`, and `interrupt_straight`; totals include cannon shots and interruptions.

First-level tuning: `godot --headless --path . --script res://tools/first_level_balance.gd -- test-output/first-level.json 0` stops after wave eight and runs 216 wave-seven trait probes (no relics versus Bracelet/Fries/Magic Sword, 12 seeds, eight trait/element variants plus a no-trait control). An optional final `runs` or `traits` restricts the batch; change the numeric seed offset for fresh validation. Natural runs pair tarot-enabled/disabled policies at 35% Perfects and collect prizes from all chest tiers. First-boss pacing now targets about four turns per phase, not a percentage of throws. A phase counts distinct full combat-round IDs it touches, including its partial finishing round; the transition round may count in both phases, and bonus player turns do not add round IDs. Report cleared-phase durations separately from failures. The CLI cannot model Stun's effect on human timing, and seeded traits can change subsequent RNG draws.

Enemy-pressure audit: `tools/enemy_pressure_audit.gd -- <output.json>` runs 504 real-CLI fixed-loadout probes. `tools/current_balance.gd -- <output.json> runs 10000` uses a fresh seed offset. Current dated summary: `enemy-balance-20261029.json`; full traces remain in ignored `test-output/`. Elite specials share the same scalar and modifiers as basic elites, and Bomber is introduced at 2-5.

## Enemy pressure checks

`tools/pressure_balance.gd -- <output.json> <seed-offset> <seed-count> paired` records natural runs with and without tarot use, all chest prizes, per-wave entry HP/builds, actual enemy-phase damage and individual boss-phase durations. It does not load or write GUI saves. Attack capacity is the sum if every enemy attacks, not the weighted average of healing/shield/charging turns; defenses and interruption can reduce actual loss. `tests/test_enemy_pressure.gd` checks the quarter-HP squad / half-HP charged-shot targets against a combat-XP-only reference and exports the current stat profile. Fresh seed offsets validate changes separately from tuning.

Level-gap probes: `tools/level_alignment.gd -- test-output/level-gaps.json 4` runs 512 fixed encounters at player LV.1/5/10/15 and enemy gaps 0/2/4/6, with bare or Bracelet + Mithril Blade builds. It uses the current CLI, 35% Perfect, no tarot decisions and no user saves; real kill XP/healing remains enabled. `tools/pressure_balance.gd -- test-output/level-campaign.json 51000 12` follows twelve natural campaigns including all chest tiers. Scan engine logs as well as the JSON failure list.

## One-skill trial (October 29, 2026)

Each turn allows one manually formed straight. A successful `cast` resolves its extra uses, character bonuses and relic casts, then settles unused rolls and advances enemies automatically. Generated skills do not spend this allowance; using all six dice grants no bonus turn. Hermit is temporarily unavailable. Snapshots expose `manual_skills_left`. Charging bosses, the Bound Demon and Cannon expose a fresh 3/4/5 `interrupt_straight` once per turn; matching casts interrupt regardless of targeting, while automatic attacks do not.

`tools/wave_progression.gd -- <output.json>` calculates kill-only XP using live payouts, including Commander guards. `wave-progression-20261101.json` retains all 24 battles and the continuous six-wave gap pattern. Without optional soul rewards, boss-entry player levels are 4/10/15; authored bosses are 5/10/13. Enemy attack budgets use unmodified character-level HP, so health equipment remains useful. Add `--plan` after the output path to propose updated fixed levels sequentially from kill XP, including each proposed wave’s changed rewards. It never changes files or live encounter scaling.

After local waves 3 and 6, collect the battle reward, select the sole `shop` route, then `leave` to see the next battle reward choices. The shop keeps the cleared wave number and grants no battle XP. Only each turn's initial throw triggers throw-related relics and matching attacks; individual rerolls and Justice corrections do not. Rerolls still expire Black Chip's previous-roll bonus.
