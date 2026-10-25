# Agent playtesting

`python3 tools/playtest.py --seed 42` starts a headless Godot process and prints one JSON response per input line. This is an agent interface, not another player UI. It uses `RunRules`, the six-dice pool, and the existing combat, tarot, relic, reward and shop transactions. It skips presentation time; it does not duplicate damage formulas or choose a strategy automatically.

The first response includes the run state and log path. Send commands over stdin; blank lines are ignored by the Python bridge. `{"action":"quit"}` or EOF exits. Set `GODOT` or pass `--godot /path/to/Godot` if the executable is not found automatically.

```sh
python3 tools/playtest.py --seed 42 --log /tmp/evil-dice-run.jsonl
python3 tools/playtest.py --replay /tmp/evil-dice-run.jsonl
python3 tools/playtest.py --resume /tmp/evil-dice-run.jsonl --log /tmp/evil-dice-run-continued.jsonl
```

`--commands /path/to/commands.jsonl` accepts a batch of explicit decisions. Replay checks every response exactly; resume reconstructs the same state before accepting new commands. Both require the same source fingerprint, including uncommitted rule changes. Existing logs are never overwritten. Default logs go to ignored `test-output/playtests/`.

## Decisions

All slot numbers are **one-based**. Tarot `instance` is the stable inventory instance ID, not its position. Responses include `state.actions`, available combinations, descriptions, enemy intentions/statuses, inventories, and any pending choice. Invalid commands return `ok:false` and a reason. Use the returned state to choose the next action.

| Command | Meaning |
| --- | --- |
| `{"action":"state"}` | Inspect current visible state without consuming RNG. |
| `{"action":"start"}` | After resolving level-one or level-two rewards, continue to the next level with the entry build. |
| `{"action":"roll"}` | Roll all unused dice; resolve matching attacks and roll relics. |
| `{"action":"roll","perfect":true}` | Explicitly assume a successful Perfect for this throw. Default is false. |
| `{"action":"form","dice":[2,4,6]}` | Reserve the indicated physical dice as a straight. |
| `{"action":"cast","target":1}` | Cast the formed skill; target may be omitted for area skills. |
| `{"action":"cancel"}` | Cancel the formed skill or pending tarot choice. |
| `{"action":"end"}` | Heal from leftovers, resolve enemies/statuses, start the next turn. |
| `{"action":"ice"}` | One ice-breaking tap; the third finishes the frozen turn. |
| `{"action":"tarot","instance":3}` | Use that card; pause for a choice if needed. |
| `{"action":"tarot","instance":3,"target":2}` | Use a targeted card, respecting taunt. |
| `{"action":"choose","die":4,"face":6}` | Resolve Magician's pending choice. |
| `{"action":"choose","ban":"fool"}` | Resolve Hanged Man's pending choice. |
| `{"action":"choose","replace":2}` | Replace an owned relic for a pending Emperor/World grant. |
| `{"action":"choose","discard":true}` | Discard that incoming relic. The granting card stays consumed. |
| `{"action":"sell","slot":1}` | Sell an owned inventory slot for its current blood-gem value. |
| `{"action":"treasure"}` | Spend 10 unused rolls on a Perfect Chest with the shared upgrade chain; no tier choice. |
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
- The state includes cumulative rolls, skills, tarot uses, enemy phases, damage taken, explicit healing events and kills, plus per-wave milestones, boss charge/release/interrupt counters and level/wave identifiers. Level-up full heals are separate `level_up` events, not included in the explicit healing total. Shop waves consume a wave exactly as in the GUI.
- No player save, settings, or persistent chest-pity file is written. Each run starts with fresh in-memory pity and a private in-memory campaign checkpoint. Levels one and two stop at `level_complete`; resolve rewards and send `start` to continue. The GUI separately persists the current level-entry build and retries that level after defeat. Seed and explicit Perfect outcomes are recorded assumptions; the CLI does not test a player's timing skill or simulate the difficulty of Stunned timing.
- Sealed bottle amounts, unopened chest prizes and future rolls are hidden. Once a chest opens, animation is skipped to its already-committed result. Inspection does not redraw RNG.
- Damage previews use the shared calculations; they exclude shield absorption, overkill and bonus Fireball echoes. No timing/FPS, audio, targeting ergonomics or animation-quality conclusions can be drawn from a headless run.
- Make deliberate skill/target/tarot/relic/shop choices when doing a balance playthrough. The deterministic smoke-test policy in the tests is only a flow check, not evidence about normal player strength.

Validation: `godot --headless --path . --script res://tests/test_playtest_session.gd` checks shared-rule parity, every tarot, repeated choices, transactions, information boundaries and seeded natural-run completion. The graphical game has no dependency on `scripts/testing/` or `tools/`.

## Balance probes

`godot --headless --path . --script res://tools/balance_probe.gd -- test-output/probe.json 0.35` runs 1,056 isolated encounter probes and 12 complete policy runs. The policy uses only published state, prioritizes damage/kills and charge interruption, buys ranked relics, and uses selected utility tarots. Fusion items retain high preference scores so the policy does not discard a combined meal as an unknown item. It is a declared heuristic, not human play. Reroll Treasure opens a Perfect Chest with the shared upgrade chain. All Ultra prizes are skipped, while lower tiers including Greed remain eligible. The model still grants their normal opening currency. Optional trailing `runs 10000` skips isolated probes and offsets seeds for held-out runs. Keep each output and its source snapshot rather than overwriting previous revisions.
