#!/usr/bin/env python3
"""Summarize preserved CLI evidence and render a standalone balance report."""
from pathlib import Path
import base64
import csv
import html
import json
import statistics as stats
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "test-output/balance-20261024"
VERSIONS = ["baseline", "revision1", "revision2", "revision3"]
LABELS = ["Before", "1 · Enemy progression", "2 · Relic limits", "3 · Recovery & rewards"]
WAVES = [1, 3, 5, 7, 9, 10, 11, 13, 15, 17, 19, 20]


def median(rows, key):
    """Aggregate a metric without dropping failed encounters."""
    return stats.median(key(row) for row in rows)


def probes(data, wave, build="typical"):
    """Select paired encounter cases independently of successful outcomes."""
    return [row for row in data["probes"] if row["wave"] == wave
            and row["build"] == build and not row["passive_only"]]


def table(headers, rows):
    """Escape report data into a compact native HTML table."""
    def cells(items, tag):
        return "".join(f"<{tag}>{html.escape(str(x))}</{tag}>" for x in items)
    return ("<table><thead><tr>" + cells(headers, "th") + "</tr></thead><tbody>"
            + "".join("<tr>" + cells(row, "td") + "</tr>" for row in rows) + "</tbody></table>")


def main():
    """Build tables, chart, machine-readable summary and one portable report."""
    runs = {name: json.loads((DATA / f"{name}.json").read_text())
            for name in VERSIONS + ["holdout35", "holdout0", "holdout70"]}
    assert all(not data["failures"] for data in runs.values()), "Probe failures must be reviewed"
    rows = []
    for name in VERSIONS:
        for wave in WAVES:
            for build in ["bare", "typical", "dragon_only", "dragon_build", "mithril_only", "reaper_only", "copy_build"]:
                sample = probes(runs[name], wave, build)
                rows.append({"revision": name, "wave": wave, "build": build, "samples": len(sample),
                             "clears": sum(x["outcome"] in ("wave_clear", "victory") for x in sample),
                             "median_rolls": median(sample, lambda x: x["stats"]["rolls"]),
                             "median_enemy_phases": median(sample, lambda x: x["stats"]["enemy_phases"]),
                             "median_hp_loss": median(sample, lambda x: x["stats"]["damage_taken"] / x["start_hp"]),
                             "start_level": sample[0]["start_level"]})
    with (DATA / "summary.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    (DATA / "summary.json").write_text(json.dumps(rows, indent=2))

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.spines.top": False, "axes.spines.right": False})
    fig, axes = plt.subplots(2, 1, figsize=(11, 7), sharex=True, layout="constrained")
    colors = ["#8d9ba8", "#dc9d51", "#a08fc2", "#1a887a"]
    for name, label, color in zip(VERSIONS, LABELS, colors):
        values = [probes(runs[name], wave) for wave in WAVES]
        axes[0].plot(WAVES, [median(x, lambda q: q["stats"]["rolls"]) for x in values],
                     marker="o", label=label, color=color, linewidth=2)
    axes[0].set(ylabel="Median rolls to outcome", title="Representative build: shorter bosses, visible recovery")
    axes[0].legend(ncol=2, loc="upper left", frameon=False)
    for name, label, color in [("baseline", "Before", colors[0]), ("revision3", "Final", colors[3])]:
        values = [probes(runs[name], wave) for wave in WAVES]
        axes[1].plot(WAVES, [100 * median(x, lambda q: q["stats"]["damage_taken"] / q["start_hp"]) for x in values],
                     marker="o", label=label, color=color, linewidth=2)
    axes[1].set(ylabel="Damage taken / starting max HP (%)", xlabel="Sampled wave",
                title="Pressure proxy: damage received, including damage later healed")
    axes[1].legend(frameon=False)
    for ax in axes:
        ax.grid(axis="y", alpha=.18)
        ax.axvline(10, color="#444444", alpha=.15); ax.axvline(20, color="#444444", alpha=.15)
        ax.set_xticks(WAVES); ax.set_xlim(.5, 20.5)
    fig.savefig(DATA / "progression.png", dpi=180)
    plt.close(fig)
    chart = base64.b64encode((DATA / "progression.png").read_bytes()).decode()

    pass_rows = []
    for name, label in zip(VERSIONS, LABELS):
        data = runs[name]
        completed = [r for r in data["runs"] if r["outcome"] == "victory"]
        pass_rows.append([label, f"{len(completed)}/12", median(completed, lambda r: r["stats"]["rolls"]),
                          median(probes(data, 10), lambda r: r["stats"]["rolls"]),
                          median(probes(data, 20), lambda r: r["stats"]["rolls"])])
    item_rows = []
    for build, label in [("dragon_only", "Pet Dragon only"), ("mithril_only", "Mithril only"), ("reaper_only", "Reaper only")]:
        counts = [sum(p["outcome"] in ("wave_clear", "victory") for p in probes(runs[v], 19, build)) for v in ("baseline", "revision3")]
        item_rows.append([label, f"{counts[0]}/12", f"{counts[1]}/12"])
    validation = []
    for key, label in [("holdout35", "Fresh seeds · 35% Perfect"), ("holdout70", "Same fresh seeds · 70% Perfect"), ("holdout0", "Different fresh seeds · no Perfect")]:
        r = runs[key]["runs"]
        validation.append([label, f"{sum(x['outcome']=='victory' for x in r)}/12", median(r, lambda x: x["stats"]["rolls"])])

    report = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Evil Dice — progression balance, 24 October 2026</title>
<style>body{{margin:0;background:#f3f3ef;color:#202a32;font:16px/1.6 system-ui,sans-serif}}main{{max-width:1040px;margin:auto;padding:40px 28px 80px}}h1{{font-size:40px;line-height:1.15;max-width:800px}}h2{{font-size:23px;margin-top:38px}}p{{max-width:920px}}.eyebrow{{text-transform:uppercase;letter-spacing:.12em;font-size:12px;color:#376c64}}.lead{{font-size:21px}}table{{width:100%;border-collapse:collapse;background:#fff;font-size:14px;margin:20px 0}}th,td{{padding:11px 14px;border-bottom:1px solid #dde2df;text-align:left}}th{{background:#e6eee9}}img{{width:100%;background:white;border-radius:10px}}.note{{border-left:4px solid #bc8f49;padding:10px 18px;background:#fff9ea}}a{{color:#136b65}}code{{font-size:13px}}@media(max-width:650px){{main{{padding:24px 14px}}h1{{font-size:30px}}table{{font-size:12px}}th,td{{padding:8px}}}}</style>
<main><div class="eyebrow">Evil Dice · 24 October 2026 · three completed revisions</div>
<p class="note"><b>Later design update:</b> Mithril Blade now grants a ×2 damage multiplier (+100%), replacing +25 flat base. The benchmark results below are preserved from the completed three-pass study and used the previous +25 version.</p>
<h1>Shorter pressure peaks.<br>Room to feel stronger.</h1>
<p class="lead">Enemy growth now separates durability, damage and XP. Boss health is lower, dangerous late enemy attacks are gentler, and four runaway relic values are bounded. Player base damage and its +10% per-level growth are unchanged.</p>
<h2>Why this approach</h2>
<p>Valve’s Left 4 Dead presentation describes alternating buildup, peaks and recovery rather than unchanging pressure. I used that pacing principle as a design analogy, not its real-time durations or adaptive system. Evil Dice now uses a fixed wave curve that does not secretly react to equipment or player performance. <a href="https://cdn.akamai.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf">Valve, pp. 77–81 and 91</a>.</p>
<p>GameFlow treats challenge alongside control, goals and feedback, so I preserved visible leveling, big skill payoffs and boss interruption. A later preregistered study with 311 participants found no significant enjoyment difference from difficulty–skill ratios alone. Consequently, these tests measure mechanical pacing—not boredom, frustration, dopamine or proven enjoyment. <a href="https://doi.org/10.1145/1077246.1077253">Sweetser &amp; Wyeth, 2005</a>; <a href="https://pmc.ncbi.nlm.nih.gov/articles/PMC9890114/">Cutting et al., 2023</a>.</p>
<h2>What changed, and why</h2>
{table(['Area','Final rule','Reason'],[
['Enemy HP','1.055^(wave−1), with fixed recovery/pressure beats','Encounters gain durability without equally fast damage growth.'],
['Enemy damage','1.025^(wave−1), with milder fixed beats','Reduce late burst deaths, especially stacked elite attacks.'],
['Special-unit base attacks','Paladin 20/35 → 18/26; High Priest 30/50 → 22/30','These roles already bring taunt, statuses, buffs and charged multi-attacks.'],
['Commander HP','Base 2000/3000 → 500/750; wave 10 now 810/1214','The old first boss was a long health grind; guards and charge mechanics remain.'],
['Spellsword HP','Base 2000/2000 → 900/1100; wave 20 now 2489/3042','Keep two distinct phases without requiring excessive repeat rolls.'],
['Enemy souls','Base 5/10/20/50 × [1 + .04 × (wave−1)]','Harder enemies contribute more toward level-ups and recovery.'],
['Soul chests','Original roll × [1 + .08 × (wave−1)]','A soul route retains value as level costs rise; wave 20 gives 25–101.'],
['Mithril Blade','+100 → +25 base','Still a large upgrade, rather than twenty times initial character base.'],
['Pet Dragon / Pet Ghost','2 × 30 → 2 × 15 base; 30 → 18 fixed area','Reduce automatic damage while retaining the existing trigger and synergy rules.'],
['Reaper’s Scythe','Exponential ×1.1 per kill → +5% per kill, capped at +200%','Avoid exponential late-run damage; half-health risk and ordered copies remain.'],
['Player / economy','Base 5, +10% level growth, full-heal levels, rarity/shop rates unchanged','Enemy and relic adjustments were sufficient for this pass.']])}
<p>For each ten-wave block the health beats are 1/.95/1.1/.85/1.05/.9/1.15/.95/1.15/1; damage beats are 1/.95/1/.85/1/.9/1.05/.95/1.05/1. Wave 11 uses .75 health for post-boss relief; wave 19 uses 1.25 for a short pressure peak. Enemy actions, weights and boss interruption rules are unchanged. All stats round once; reinforcements and phase changes retain the correct independent scales.</p>
<h2>Three actual test-and-revise passes</h2>
<p><b>1.</b> Changed enemy progression, special-unit damage and boss health, and increased enemy XP. The first-boss representative median fell from 30 to 16 rolls; wave 19 no longer abruptly killed four of twelve representative builds.<br><b>2.</b> Reduced the four relic outliers after isolated-item tests exposed their contribution. Single-item late-wave cases became meaningfully weaker, while multi-item synergies still paid off.<br><b>3.</b> Added post-boss relief, strengthened the late pressure beat, scaled soul chests, and reduced Commander base HP further. Its final median was 16.5 rolls: lower HP did not guarantee fewer rolls because phase boundaries, guards and random outcomes also affect pacing.</p>
{table(['Version','Completed policy runs','Median rolls, completed runs','Wave 10 probe rolls','Wave 20 probe rolls'],pass_rows)}
<p>Representative midgame fights take about 4–7.5 rolls. Wave 11 falls to 5.5 after the first boss; wave 19 rises to 7.5. These are controlled full-health encounter starts, not the cumulative run curve.</p>
<img src="data:image/png;base64,{chart}" alt="Four revision curves comparing roll counts and before/after damage taken at sampled waves">
<h2>Single-item checks and fresh seeds</h2>
{table(['Wave 19 isolated loadout','Before: cleared cases','Final: cleared cases'],item_rows)}
<p>These item-only cases start with combat-derived levels and full HP. Reaper additionally receives three prior kills per earlier wave as an explicit early-acquisition stress assumption. The copy build intentionally combines several strong relics: it remains powerful and is not evidence that one item wins the run.</p>
{table(['Validation condition','Completed policy runs','Median total rolls'],validation)}
<p>The unchanged 35% and 70% policies use matched fresh seeds; the no-Perfect check uses a separate seed set. Perfect still accelerates play but is not a survival requirement in these cases. This fits the intended relaxed direction. It does not establish a human success rate.</p>
<h2>Evidence, scope and remaining risk</h2>
<p>Each version ran 1,056 encounter probes plus 12 natural runs: <b>4,224 probes and 48 runs</b>, followed by <b>36 fresh-seed runs</b>. The shared Godot CLI adapter resolves real combat, status, tarot, loot and shop rules. The fixed policy uses visible previews, chooses damage/kill opportunities, values charge interruption, takes utility tarots, buys ranked relics and chooses routes. It does not optimize every tarot (notably Magician), reorder items optimally, or model touch mistakes. Isolated probes use full health, no tarots, an authored representative inventory, and combat-only XP from prior rosters without shop skips.</p>
<p>Reroll Treasure explicitly claims <b>Greed</b>. Randomly upgraded Ultra wave-chest prizes are discarded; their automatic opening currency is still paid. Lower chests, shop and tarot rolls can naturally supply legendary relics; their rarity pool was not rebalanced. The full-run reward/RNG paths diverge after combat changes, so only controlled probes isolate loadouts reliably.</p>
<p class="note"><b>Remaining concern:</b> passive roll-and-heal play can stall bosses for a long time. The final Dragon-only no-skill probes can still survive some very long fights through leftover healing. I did not compensate with lethal unavoidable attacks. Boss pressure and healing timing deserve the next GUI playtest. CLI results cannot establish animation pacing, touch feel, FPS, audio quality or whether a fight feels boring.</p>
<p>Targeted regression checks cover independent scales, phase/guard inheritance, XP receipt sizes, capped Reaper retriggers, pets, Greed selection, enemy actions, relics, localization and CLI parity. The existing CLI regression suite still emits shutdown resource-leak warnings after passing; the balance probe batches finish without errors. One baseline passive Dragon case reached the 600-command safety limit (405 rolls) and is retained as censored, not a clear. Final probes had no capped cases. Raw JSON, CSV, source archives, hashes and logs are preserved in <code>test-output/balance-20261024/</code>. Reproduce with <code>tools/balance_probe.gd</code>; build this report with <code>tools/summarize_balance.py</code> (Matplotlib required).</p>
</main></html>"""
    output = ROOT / "docs/balance-report-20261024.html"
    output.write_text(report)
    print(output)


if __name__ == "__main__":
    main()
