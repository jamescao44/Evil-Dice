# First level balance observations

2026-10-28. Target: roughly four turns per Commander phase. Scope: level 1, eight waves.

## Changes

- Commander HP: **110 → 907**, then **162 → 855**. Phase two has a smaller HP budget because it adds two guards and stronger shielding.
- Charged hit: **111 → 72**. A longer boss fight needs survivable punishment; charging, five-cast interruption and guard stats stay intact.
- Wave 4: Archer 2 / Mage **2**. Wave 5: Cleric **2** / Vanguard **3**. Wave 6: Assassin **2** / Archer **3**. Wave 7: elite Vanguard 3 / Mage **3** / Cleric **2**. Early introductions stay gentle; support units provide the later step up.
- Tested elite Vanguard 4 in wave 7, then reduced it to 3: the healer/mage combination made its first introduction too punishing, particularly with Thorns.

## Boss results

48 natural-reward runs, 24 seeds paired with/without tarot use; half the seeds were fresh validation. **45 cleared**, with all three losses in boss phase one after entering at 56–69 HP. No ordinary-wave losses in this final batch.

| Cleared phases | Before | Final mean | Final median |
| --- | ---: | ---: | ---: |
| Phase one | 1.1 turns | **3.6 turns** | **4** |
| Phase two | 2.5 turns | **4.3 turns** | **4** |

The boss released 38 charged attacks and was interrupted 14 times. Strong builds can still finish a phase quickly; observed cleared-phase ranges were 1–7 and 1–8 turns. The goal is average pacing, not a forced minimum duration.

## Elite observations

216 wave-seven probes cover all four categories, all five elemental variants, and a no-trait control. Twelve seeds each, both without relics and with Bracelet/Fries/Magic Sword:

- **Thorns:** strongest immediate HP pressure. With the three-item build, mean damage taken rose from 11 to 36; all 12 still cleared. Without items, 8/12 cleared versus 11/12 in the control.
- **Shielding:** mainly slows weak damage builds. No-item encounters averaged 5.7 turns versus 5.0; the equipped build handled it readily.
- **Manic:** creates dangerous bursts but occasionally helps the player by attacking allies. Equipped-build mean damage taken was 25.
- **Elemental:** Freeze prolonged fights slightly; Burning added attrition. Corrosion/Darkness often had little opportunity to matter against the equipped build. Stun needs GUI testing because fixed CLI Perfect odds omit its timing disruption.

35% Perfect assumption; natural gems, shops and card choices; Ultra prizes skipped. Counts include partial finishing rounds, and the phase-transition round can count in both phases. This is one visible-state policy, not a predicted human win rate. Final raw data: `test-output/first-level-final.json` and `test-output/first-level-fresh.json`; reproduce with `tools/first_level_balance.gd` using offsets 0 and 20000. No player saves are touched.
