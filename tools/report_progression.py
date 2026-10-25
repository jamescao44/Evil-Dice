"""Summarize the retained October 25 CLI cohorts without rerunning or hiding losses."""
import collections
import html
import json
import statistics
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "test-output/progression-20261025"
DOCS = ROOT / "docs"
NAMES = ["baseline-meal", "step-pass1-level2", "full-pass1", "full-pass2", "final-natural", "release-control", "release-natural", "release-low-perfect"]


def cohort(name):
    """Derive per-wave enemy phases from cumulative counters, excluding shop visits."""
    raw = json.loads((DATA / (name + ".json")).read_text())
    assert not raw["failures"], raw["failures"]
    waves = collections.defaultdict(list)
    for run in raw["runs"]:
        previous = {"enemy_phases": 0, "damage_taken": 0, "boss_releases": 0}
        for row in run["history"]:
            delta = {key: row["totals"][key] - previous[key] for key in previous}
            previous = {key: row["totals"][key] for key in previous}
            if row["kind"] == "shop":
                continue
            waves[row["wave"]].append({**delta, "seed": run["seed"], "player_level": row["level"], "relics": row["relics"], "minimum_hp_fraction": run.get("wave_min_hp", {}).get(str(row["wave"]))})
    return {"name": name, "perfect_rate": raw["perfect_rate"], "runs": [{"seed": r["seed"], "outcome": r["outcome"], "wave": r["wave"]} for r in raw["runs"]], "waves": dict(sorted(waves.items()))}


def phases(data, start, end):
    """Flatten only completed combat encounters in the requested global-wave band."""
    return [r["enemy_phases"] for wave, rows in data["waves"].items() if start <= wave <= end for r in rows]


def median(data, start, end):
    """Keep half-turn medians rather than rounding away small pacing changes."""
    return statistics.median(phases(data, start, end))


def wave_line(ax, data, start, end, label, color):
    """Plot per-wave medians so alternating pressure and recovery remain visible."""
    xs = list(range(start, end + 1))
    ys = [median(data, w, w) for w in xs]
    ax.plot(xs, ys, marker="o", linewidth=2.2, markersize=5, label=label, color=color)


def main():
    """Write one portable report, its chart and auditable cohort summaries."""
    groups = {name: cohort(name) for name in NAMES}
    old, control = groups["baseline-meal"], groups["release-control"]
    natural, low = groups["release-natural"], groups["release-low-perfect"]
    payload = {"date": "2026-10-25", "policy": "Visible-state decisions; prioritize meal sets; random dice; Ultra relics forfeited through ordinary salvage; no forced dice or injected gear in full runs.", "cohorts": groups}
    (DOCS / "third-level-balance-20261025.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2))
    plt.rcParams.update({"font.size": 10, "figure.facecolor": "#131b22", "axes.facecolor": "#131b22", "text.color": "#e8e8dc", "axes.labelcolor": "#b8c7ce", "xtick.color": "#b8c7ce", "ytick.color": "#b8c7ce", "axes.edgecolor": "#44525b"})
    fig, axes = plt.subplots(2, 1, figsize=(11, 7.2), layout="constrained")
    wave_line(axes[0], old, 11, 20, "Before · same 12 seeds", "#839da9")
    wave_line(axes[0], control, 11, 20, "Now · same 12 seeds", "#ffbd69")
    wave_line(axes[1], natural, 21, 30, "Third level · 35% Perfect", "#ffbd69")
    wave_line(axes[1], low, 21, 30, "Third level · 15% Perfect", "#77c8da")
    for ax, start, title in zip(axes, [11, 21], ["Level 2 · more time for enemies to act", "Level 3 · sharp steps, then faster familiar fights"]):
        for wave in [start, start + 3, start + 6]:
            ax.axvspan(wave - .35, wave + .35, color="#ffbd69", alpha=.08)
        ax.set_title(title, loc="left", fontsize=13, pad=14)
        ax.set_ylabel("Median enemy phases")
        ax.set_xlabel("Global wave")
        ax.set_xticks(range(start, start + 10))
        ax.set_ylim(bottom=0)
        ax.grid(axis="y", alpha=.14)
        ax.spines[["top", "right"]].set_visible(False)
        ax.legend(frameon=False, labelcolor="#e8e8dc", loc="upper left")
    fig.savefig(DOCS / "third-level-pacing-20261025.svg")
    fig.savefig(DOCS / "third-level-pacing-20261025.png", dpi=160)
    plt.close(fig)
    svg = (DOCS / "third-level-pacing-20261025.svg").read_text()
    svg = svg[svg.index("<svg"):]
    victory = sum(r["outcome"] == "victory" and r["wave"] == 30 for data in [control, natural, low] for r in data["runs"])
    instant_old = sum(x == 0 for x in phases(old, 11, 19)) / len(phases(old, 11, 19))
    instant_new = sum(x == 0 for x in phases(control, 11, 19)) / len(phases(control, 11, 19))
    table = "".join(f"<tr><td>{w}</td><td>{median(natural,w,w):g}</td><td>{median(low,w,w):g}</td><td>{len(natural['waves'][w])} / {len(low['waves'][w])}</td></tr>" for w in range(21, 31))
    rosters = json.loads((DATA / "wave-table.json").read_text())
    rosters[13][3] = "跃升：保护与远程支援"
    wave_table = "".join("<tr>" + "".join("<td>" + html.escape(value) + "</td>" for value in row) + "</tr>" for row in rosters)
    report = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Evil Dice · Three-level balance</title>
<style>body{{margin:0;background:#10161b;color:#e8e8dc;font:17px/1.65 system-ui,sans-serif}}main{{max-width:1050px;margin:auto;padding:52px 24px 90px}}h1{{font-size:clamp(30px,5vw,48px);line-height:1.15;margin:12px 0 20px}}h2{{font-size:24px;margin-top:40px}}p{{max-width:900px}}.eyebrow{{color:#ffbd69;letter-spacing:.16em;font-size:12px;text-transform:uppercase}}.muted,figcaption{{color:#a5b7c0;font-size:14px}}.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:14px;margin:28px 0}}.card{{padding:22px;background:#1a252d;border-radius:10px}}.card strong{{display:block;color:#ffbd69;font-size:32px}}figure{{margin:26px 0;background:#131b22;padding:18px;border-radius:12px}}svg{{width:100%;height:auto}}table{{border-collapse:collapse;width:100%;font-size:15px}}th,td{{padding:10px 12px;border-bottom:1px solid #30404b;text-align:left}}th{{color:#ffbd69}}.scroll{{overflow-x:auto}}a{{color:#85d2e4}}li{{margin:9px 0}}details{{margin-top:30px}}summary{{cursor:pointer;color:#ffbd69}}code{{font-size:13px;overflow-wrap:anywhere}}</style><main>
<div class="eyebrow">Evil Dice · 25 October 2026 · Balance pass</div><h1>Three levels.<br>Sharper climbs, room to recover.</h1>
<p>Level two now needs a stronger build to clear quickly. Level three adds ten authored encounters and the Fanatical Mage. Pressure waves arrive in three-wave blocks, followed by more familiar lineups; the first ten waves and existing player/relic growth remain unchanged.</p>
<div class="cards"><div class="card"><strong>30 waves</strong>Three ten-wave levels with saved entry builds</div><div class="card"><strong>{median(old,11,19):g} → {median(control,11,19):g}</strong>Median enemy phases in level-two ordinary fights</div><div class="card"><strong>{victory} / 36</strong>Completed final-version CLI runs</div></div>
<h2>What changed and why</h2><ul>
<li><b>Enemy levels rise in steps.</b> Level-two main threats reach LV.9, 11 and 13. Level three uses LV.14, 16 and 18 pressure groups. These encounters cannot be replaced by a shop; support units still mix levels.</li>
<li><b>Health rises faster than damage.</b> The existing per-enemy scaling stays ×1.30 HP and ×1.04 damage per level, with linear soul/gem growth. Stronger enemies survive more hits without proportionally multiplying unavoidable damage.</li>
<li><b>Remove healing loops, keep sturdy enemies.</b> Two stress-test lineups reached 37–54 enemy phases when elite archers repeatedly healed a protected Paladin. Waves 21 and 27 now use normal archers. In the revised 35% Perfect cohort, both waves finish within 18 enemy phases.</li>
<li><b>Keep the boss increase measured.</b> Spellsword moves from LV.10 to LV.11: 13,786 / 16,543 HP and 30 attack. Testing LV.12 made weaker builds drag. Fanatical Mage starts at LV.13, with 34,947 HP per phase.</li>
</ul>
<figure>{svg}<figcaption>Completed combat encounters only; shops are excluded. Shaded columns mark planned difficulty steps. These are medians, not fixed turn counts or measured human frustration.</figcaption></figure>
<h2>The new boss</h2><p>The Fanatical Mage summons damage-absorbing octopuses, splits them into tentacles and applies Darkness. Phase two replaces the small servants with a charging, taunting demon while the mage continues its move pool. Three separate skills interrupt the demon. Its pact consumes one fifth of the mage’s scaled health per enemy phase, so this phase also has a five-turn survival route.</p>
<p class="muted">Current defaults for the open clarification: at most six small servants; one servant absorbs each redirected hit without spill; summoned creatures grant no loot or kill-trigger bonuses; demon base attack 30, double on release; pact loss scales with the mage and continues while the demon is interrupted. These rules are isolated in the boss module for easy revision. Added four CC0 placeholder sprites and checked crowded formations in portrait and landscape.</p>
<h2>What the tests show</h2><p>The same 12 seeds and meal-priority policy changed level-two ordinary fights from a median of {median(old,11,19):g} to {median(control,11,19):g} enemy phases. Fights ending before any enemy phase fell from {instant_old:.1%} to {instant_new:.1%}. All 12 runs still cleared. Two additional 12-seed cohorts, at 35% and 15% assumed Perfect success, also cleared all 30 waves. Meal tiers varied naturally; no full set was injected into these runs.</p>
<div class="scroll"><table><thead><tr><th>Wave</th><th>35% Perfect</th><th>15% Perfect</th><th>Combat samples</th></tr></thead><tbody>{table}</tbody></table></div>
<p>Earlier passes exposed two wave-19 deaths, so its supporting priest was reduced and its elite group healer replaced. Fixed-build probes also covered a full meal with modest support and a stronger meal synergy build. Final full runs choose skills, targets, tarots, routes and shop purchases from visible state, and actively seek meal ingredients.</p>
<p class="muted">Limits: this is one automated policy, not a human win-rate estimate. It skips Ultra relic prizes through normal forfeiture, retaining their currency/salvage; it does not prove every legendary build is balanced. Some weaker low-Perfect runs still need roughly 20–30 enemy phases for a boss or late pressure wave. GUI timing, tactile pacing and phone performance require human play. A successful powerful build can still clear individual waves immediately.</p>
<details><summary>All 30 authored lineups</summary><div class="scroll"><table><thead><tr><th>Level–wave</th><th>Enemies</th><th>Count</th><th>Purpose</th></tr></thead><tbody>{wave_table}</tbody></table></div></details>
<h2>Verification and reproduction</h2><p>Checked campaign carryover/retries, all 30 waves’ bilingual HP/level layout, reward and shop flow, boss phases, interruption, freeze, redirection, exact Tower damage, summon cleanup and non-farmable drops. The third boss’s densest formation is tested in both layouts. Headless scene teardown still reports existing resource-leak warnings in some tests; no gameplay assertion failed in the final checks.</p>
<p class="muted">Cohort summaries: <a href="third-level-balance-20261025.json">JSON</a>. Reproduce with <code>Godot --headless --path . --script tools/balance_probe.gd -- OUTPUT.json 0.35 runs 30000</code>; use offsets 40000 and 50000 for the other cohorts, with 0.15 for the last. Raw actions and snapshots remain in <code>test-output/progression-20261025/</code>. Generate this report with <code>tools/report_progression.py</code>.</p>
</main></html>'''
    (DOCS / "third-level-balance-report-20261025.html").write_text(report)
    print(f"Report saved; {victory}/36 final runs reached wave 30.")


if __name__ == "__main__":
    main()
