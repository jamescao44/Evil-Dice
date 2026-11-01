#!/usr/bin/env python3
"""Export health/Fireball traces from CLI JSON or JSONL to CSV and PNG charts."""
from __future__ import annotations

import argparse
import csv
import json
import math
import textwrap
from pathlib import Path

FIELDS = ["sample", "command", "reason", "wave", "round", "phase", "player_level",
          "hp", "max_hp", "hp_ratio", "shield", "base_damage", "fireball_per_use",
          "fireball_uses", "combo_multiplier"]


def load_runs(path: Path) -> list[dict]:
    """Accept both agent decision logs and the shared balance-run output schema."""
    if path.suffix == ".jsonl":
        records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
        if not records or records[0].get("type") != "start":
            raise ValueError("Expected a playtest JSONL log.")
        response = records[-1]["response"]
        runs = [{"seed": records[0]["seed"], "outcome": response["state"]["outcome"] or "in progress",
                 "telemetry": {"schema": records[0]["response"].get("metric_schema", 1), "samples": [sample for record in records
                              for sample in record["response"].get("metrics", [])]}}]
        if runs[0]["telemetry"]["schema"] >= 2:
            for field, key in [("inventory_events", "metric_inventory"), ("commands", "metric_commands")]:
                runs[0]["telemetry"][field] = [event for record in records for event in record["response"].get(key, [])]
            runs[0]["telemetry"]["wave_turns"] = response.get("metric_wave_turns", [])
    else:
        data = json.loads(path.read_text())
        runs = data.get("runs", []) + data.get("probes", [])
    if not runs:
        raise ValueError("No recorded runs to plot.")
    for run in runs:
        telemetry = run.get("telemetry", {})
        samples = telemetry.get("samples", [])
        if telemetry.get("schema") not in [1, 2] or not samples:
            raise ValueError("Missing health/Fireball telemetry; rerun using the current CLI.")
        for row in samples:
            if any(key not in row for key in FIELDS):
                raise ValueError("Incomplete telemetry sample.")
            if any(not math.isfinite(float(row[key])) for key in FIELDS if key not in ["reason", "phase"]):
                raise ValueError("Non-finite telemetry value.")
    return runs


def label(run: dict) -> str:
    """Keep paired policies and isolated builds distinguishable on plots and CSVs."""
    parts = [f"Seed {run['seed']}"]
    for key in ["build", "trait", "mode", "lineup"]:
        if key in run:
            parts.append(str(run[key]))
    cards = run.get("tarots", run.get("tarots_enabled"))
    if cards is not None:
        parts.append("cards on" if cards else "cards off")
    return " / ".join(parts)


def wave_positions(samples: list[dict]) -> list[float]:
    """Give every wave equal width; sample order is progression, not elapsed time."""
    counts: dict[int, int] = {}
    seen: dict[int, int] = {}
    for row in samples:
        wave = int(row["wave"])
        counts[wave] = counts.get(wave, 0) + 1
    positions = []
    for row in samples:
        wave = int(row["wave"])
        ordinal = seen.get(wave, 0)
        positions.append(wave + 0.95 * ordinal / max(1, counts[wave]-1))
        seen[wave] = ordinal + 1
    return positions


def item_names(items: list[dict]) -> str:
    """Keep stacks readable without losing duplicate acquisition quantities."""
    return ", ".join(item["name"] + (f" x{item['count']}" if item.get("count", 1) > 1 else "") for item in items)


def power_points(run: dict) -> list[dict]:
    """Flag observed inventory-related cast gains >=25% and >=10 damage; ignore combo/card-only spikes."""
    points = []
    for event in run["telemetry"].get("inventory_events", []):
        before = event["damage_before"] * event["uses_before"]
        after = event["damage_after"] * event["uses_after"]
        if before <= 0 or after-before < 10 or after < before*1.25:
            continue
        acquired = item_names(event["gained"])
        removed = item_names(event["sold"] or event["replaced"])
        reason = acquired or ("Remove " + removed if removed else "Reorder / inventory change")
        points.append({"point": len(points)+1, "sample": event["sample"], "command": event["command"],
                       "wave": event["wave"], "reason": reason, "before": before, "after": after,
                       "gain_percent": (after/before-1)*100})
    return points


def write_events(runs: list[dict], path: Path, powers_path: Path) -> None:
    """Export all acquisitions, sales, replacements, fusions and the exact graph-marker rule."""
    with path.open("w", newline="", encoding="utf-8") as handle:
        fields = ["run", "seed", "sample", "command", "wave", "round", "source", "card", "gained", "sold", "replaced", "added", "removed", "inventory_after", "damage_before", "damage_after", "uses_before", "uses_after"]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for index, run in enumerate(runs):
            for event in run["telemetry"].get("inventory_events", []):
                row = {k: event[k] for k in fields if k in event}
                for key in ["gained", "sold", "replaced", "added", "removed"]:
                    row[key] = item_names(event[key])
                row.update(run=index+1, seed=run["seed"], inventory_after=item_names(event["after"]))
                writer.writerow(row)
    with powers_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["run", "seed", "point", "sample", "command", "wave", "reason", "before", "after", "gain_percent"])
        writer.writeheader()
        for index, run in enumerate(runs):
            for point in power_points(run):
                writer.writerow({"run": index+1, "seed": run["seed"], **point})


def write_csv(runs: list[dict], path: Path) -> None:
    """Retain raw sample values, including failed runs, for future comparisons."""
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["run", "seed", "label", "outcome", *FIELDS])
        writer.writeheader()
        for index, run in enumerate(runs):
            for sample in run["telemetry"]["samples"]:
                writer.writerow({"run": index+1, "seed": run["seed"], "label": label(run),
                                 "outcome": run.get("outcome", ""), **{k: sample[k] for k in FIELDS}})


def plot_page(runs: list[dict], path: Path, title: str) -> None:
    """Show every run separately so deaths and temporary health dips are not averaged away."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.ticker import MaxNLocator, StrMethodFormatter

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9,
                         "axes.spines.top": False, "axes.spines.right": False})
    annotated = any(r["telemetry"].get("schema", 1) >= 2 for r in runs)
    height = (3.0 if annotated else 2.3)*len(runs)+2.2
    fig, axes = plt.subplots(len(runs), 2, figsize=(13.8, height), squeeze=False)
    all_samples = [s for r in runs for s in r["telemetry"]["samples"]]
    first_wave = min(int(s["wave"]) for s in all_samples)
    last_wave = max(int(s["wave"]) for s in all_samples)
    highest_hp = max(s["max_hp"] for s in all_samples)
    highest_damage = max(s["fireball_per_use"] for s in all_samples)
    positive_damage = [s["fireball_per_use"] for s in all_samples if s["fireball_per_use"] > 0]
    log_damage = bool(positive_damage) and highest_damage/min(positive_damage) > 100
    for index, run in enumerate(runs):
        samples = run["telemetry"]["samples"]
        x = wave_positions(samples)
        hp_ax, damage_ax = axes[index]
        hp_ax.plot(x, [s["max_hp"] for s in samples], color="#8994a3", linestyle="--", linewidth=1.2, label="Maximum HP")
        hp_ax.plot(x, [s["hp"] for s in samples], color="#be3e55", linewidth=1.15, label="Current HP")
        damage_ax.plot(x, [s["fireball_per_use"] for s in samples], color="#d87413", linewidth=1.2)
        hp_ax.set_ylim(0, highest_hp*1.08)
        if log_damage:
            damage_ax.set_yscale("symlog", linthresh=10)
            damage_ax.set_ylim(0, highest_damage*1.15)
        else:
            damage_ax.set_ylim(0, max(1, highest_damage)*1.08)
            damage_ax.yaxis.set_major_locator(MaxNLocator(4))
        damage_ax.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
        hp_ax.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
        outcome = run.get("outcome", "in progress") or "in progress"
        hp_ax.set_title(f"{label(run)}  |  {outcome}", loc="left", fontsize=9, pad=7)
        damage_ax.set_title(f"Final player LV.{samples[-1]['player_level']}  |  reached wave {samples[-1]['wave']}", loc="left", fontsize=9, pad=7)
        hp_ax.set_ylabel("HP")
        damage_ax.set_ylabel("Damage / use")
        sample_x = {s["sample"]: position for s, position in zip(samples, x)}
        sample_damage = {s["sample"]: s["fireball_per_use"] for s in samples}
        for event in run["telemetry"].get("inventory_events", []):
            position = sample_x[event["sample"]]
            if event["gained"]:
                hp_ax.plot(position, 0.035, marker="^", color="#21885c", markersize=4,
                           transform=hp_ax.get_xaxis_transform(), clip_on=False)
            if event["sold"] or event["replaced"]:
                hp_ax.plot(position, 0.075, marker="v", color="#bc3852", markersize=4,
                           transform=hp_ax.get_xaxis_transform(), clip_on=False)
        points = power_points(run)
        for point in points:
            px, py = sample_x[point["sample"]], sample_damage[point["sample"]]
            damage_ax.plot(px, py, marker="D", color="#267957", markeredgecolor="white", markeredgewidth=0.5, markersize=5)
            damage_ax.annotate(str(point["point"]), (px, py), xytext=(2, 5+8*(point["point"] % 2)), textcoords="offset points", fontsize=7, color="#185b41")
        if points:
            # Show the five strongest labels; every numbered point remains in the exported CSV.
            selected = sorted(sorted(points, key=lambda p: p["gain_percent"], reverse=True)[:5], key=lambda p: p["point"])
            notes = ";  ".join(f"{p['point']}: {p['reason']} +{p['gain_percent']:.0f}%" for p in selected)
            if len(points) > 5:
                notes += "; remaining points in power-gains CSV"
            damage_ax.text(0, -0.22, "\n".join(textwrap.wrap(notes, width=83)), transform=damage_ax.transAxes,
                           fontsize=7.3, va="top", color="#185b41")
        for ax in [hp_ax, damage_ax]:
            for wave in range(first_wave, last_wave+1):
                if wave % 8 == 0:
                    ax.axvspan(wave, wave+1, color="#7163a6", alpha=0.10, zorder=0)
                if wave > first_wave and (wave-1) % 8 == 0:
                    ax.axvline(wave, color="#8994a3", linestyle=":", linewidth=1)
            ax.set_xlim(first_wave, last_wave+1)
            stride = 2 if last_wave-first_wave > 12 else 1
            ticks = list(range(first_wave, last_wave+1, stride))
            if last_wave not in ticks:
                ticks.append(last_wave)
            ax.set_xticks([w+0.45 for w in ticks], [str(w) for w in ticks])
            ax.grid(axis="y", color="#e1e5eb", linewidth=0.6)
            if index == len(runs)-1 and not annotated:
                ax.set_xlabel("Battle wave (shops stay in the preceding wave)")
    axes[0, 0].legend(loc="upper left", fontsize=8, framealpha=0.85, ncol=2)
    fig.suptitle(title, x=0.065, ha="left", fontsize=18, fontweight="bold", y=1-0.15/height)
    fig.text(0.065, 1-0.65/height, "PLAYER HEALTH", fontsize=11, fontweight="bold", color="#be3e55")
    fig.text(0.555, 1-0.65/height, "3-4-5 FIREBALL"+("  ·  log damage axis" if log_damage else ""), fontsize=11, fontweight="bold", color="#b55d09")
    if annotated:
        fig.text(0.065, 1-0.9/height, "Green ▲ acquired  ·  Red ▼ sold/replaced  ·  Numbered diamonds: inventory-associated cast damage gain ≥25% and ≥10", fontsize=8, color="#505b68")
    fig.text(0.065, 0.14/height,
             "Fireball: current relics, buffs and combo; per use before shields/overkill. No socket/target modifiers, extra uses or passive attacks.\n"
             "Samples at command/resolution boundaries and level-ups; intermediate changes inside a single resolution may be absent.\n"
             "X = battle wave, equal width (not elapsed time); shops stay in the preceding wave. Purple = bosses. Failed runs stop at defeat.\n"
             "Power markers include extra uses; inventory changes are observed associations, not isolated causal tests. Utility/item/status damage is not measured by Fireball.",
             fontsize=8, color="#505b68", linespacing=1.6)
    fig.tight_layout(rect=(0.025, 0.95/height, 0.99, 1-(1.05 if annotated else 0.85)/height), h_pad=3.4 if annotated else 1.2, w_pad=3)
    fig.savefig(path, dpi=160, facecolor="white")
    plt.close(fig)


def plot_pacing(runs: list[dict], path: Path, csv_path: Path) -> None:
    """Plot each skill and matching-group size independently; retain turns as supporting data."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch
    from matplotlib.ticker import MaxNLocator

    rows = [row for run in runs for row in run["telemetry"].get("wave_turns", [])]
    known = ["Fireball", "Fiery Slash", "Fire Storm", "Brimstone"]
    names = known + sorted({name for row in rows for name in row.get("skills", {})}-set(known))
    groups = sorted({str(size) for size in range(2, 7)} | {size for row in rows for size in row.get("auto_attacks", {})}, key=int)
    colors = ["#e5a02a", "#d05e43", "#984f9b", "#55418c", "#527e9c"]
    auto_colors = ["#86aaad", "#448c95", "#3563a0", "#7754ad", "#ad4564"]
    fields = ["run", "seed", "wave", "boss", "outcome", "cleared", "turns_spent", "turns_to_clear"]
    fields += [name+"_"+metric for name in names for metric in ["casts", "uses"]]
    fields += ["alike_"+size+"_"+metric for size in groups for metric in ["groups", "pulses"]]
    fields.append("skill_sources")
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for index, run in enumerate(runs):
            for row in run["telemetry"].get("wave_turns", []):
                out = {key: row[key] for key in fields if key in row}
                out.update(run=index+1, seed=run["seed"])
                for name in names:
                    for metric in ["casts", "uses"]:
                        out[name+"_"+metric] = row.get("skills", {}).get(name, {}).get(metric, 0)
                for size in groups:
                    for metric in ["groups", "pulses"]:
                        out["alike_"+size+"_"+metric] = row.get("auto_attacks", {}).get(size, {}).get(metric, 0)
                out["skill_sources"] = json.dumps({name: value["sources"] for name, value in row.get("skills", {}).items()})
                writer.writerow(out)
    height = 2.25*len(runs)+2.3
    fig, axes = plt.subplots(len(runs), 2, figsize=(13.8, height), squeeze=False)
    last_wave = max(row["wave"] for row in rows)
    skill_max = max(sum(v["casts"] for v in row.get("skills", {}).values()) for row in rows)
    auto_max = max(sum(v["groups"] for v in row.get("auto_attacks", {}).values()) for row in rows)
    for index, run in enumerate(runs):
        wave_rows = run["telemetry"].get("wave_turns", [])
        waves = [row["wave"] for row in wave_rows]
        for column, (keys, field, metric, palette, maximum) in enumerate([
            (names, "skills", "casts", colors, skill_max), (groups, "auto_attacks", "groups", auto_colors, auto_max)
        ]):
            ax = axes[index, column]
            bottoms = [0]*len(wave_rows)
            for i, key in enumerate(keys):
                values = [row.get(field, {}).get(key, {}).get(metric, 0) for row in wave_rows]
                ax.bar(waves, values, bottom=bottoms, width=0.72, color=palette[i % len(palette)])
                bottoms = [a+b for a, b in zip(bottoms, values)]
            for row, total in zip(wave_rows, bottoms):
                if row["boss"]:
                    ax.axvspan(row["wave"]-0.5, row["wave"]+0.5, color="#7163a6", alpha=0.09, zorder=0)
                if not row["cleared"]:
                    ax.scatter(row["wave"], total+0.5, marker="x", color="#c42e48", zorder=5)
            ax.set_title(label(run)+f" | {run.get('outcome', 'in progress')}", loc="left", fontsize=9)
            ax.set(xlim=(0.4, last_wave+0.6), ylim=(0, max(1, maximum)+2), ylabel="Casts" if column == 0 else "Matching groups")
            ax.set_xticks(range(1, last_wave+1))
            ax.tick_params(axis="x", labelsize=8)
            ax.yaxis.set_major_locator(MaxNLocator(integer=True, nbins=4))
            ax.grid(axis="y", alpha=0.15)
            ax.set_axisbelow(True)
            ax.spines[["top", "right"]].set_visible(False)
            if index == len(runs)-1:
                ax.set_xlabel("Battle wave")
    fig.suptitle("Evil Dice · skills and auto-attacks per wave", x=0.065, ha="left", fontsize=17, fontweight="bold", y=1-0.15/height)
    fig.legend([Patch(color=colors[i % len(colors)]) for i in range(len(names))], names,
               loc="upper left", bbox_to_anchor=(0.065, 1-0.5/height), ncol=2, frameon=False, fontsize=9, title="Individual skill casts")
    fig.legend([Patch(color=auto_colors[i % len(auto_colors)]) for i in range(len(groups))], [size+" alike" for size in groups],
               loc="upper left", bbox_to_anchor=(0.55, 1-0.5/height), ncol=3, frameon=False, fontsize=9, title="Automatic matching groups")
    fig.text(0.065, 0.12/height, "Each bonus/relic Fireball is a separate cast. Damage ticks and extra uses do not create extra casts. Only executed attacks count.\n"
             "Auto-attacks count matching groups once; individual shots/AOE pulses, extra skill uses, cast sources and turns are retained in CSV.\n"
             "Purple bands = bosses. Red X = failed/unfinished wave (counts spent, not a completed clear). Shops and reward choices add no casts.", fontsize=8, color="#505b68")
    fig.tight_layout(rect=(0.02, 0.85/height, 0.99, 1-1.35/height), h_pad=1.5, w_pad=2)
    fig.savefig(path, dpi=160, facecolor="white")
    plt.close(fig)


def generate(source: Path, output: Path | None = None, title: str | None = None) -> list[Path]:
    """Create one CSV and paginated charts beside the original immutable run log."""
    runs = load_runs(source)
    base = output or source.with_suffix("")
    base.parent.mkdir(parents=True, exist_ok=True)
    csv_path = Path(str(base)+"-metrics.csv")
    write_csv(runs, csv_path)
    paths = [csv_path]
    if any(r["telemetry"].get("schema", 1) >= 2 for r in runs):
        events_path = Path(str(base)+"-relic-events.csv")
        powers_path = Path(str(base)+"-power-gains.csv")
        write_events(runs, events_path, powers_path)
        paths += [events_path, powers_path]
    for start in range(0, len(runs), 6):
        suffix = "" if start == 0 else f"-{start//6+1}"
        image_path = Path(str(base)+"-health-fireball"+suffix+".png")
        plot_page(runs[start:start+6], image_path, title or "Evil Dice · health and Fireball progression")
        paths.append(image_path)
        page = runs[start:start+6]
        if any(r["telemetry"].get("wave_turns") for r in page):
            turns_path = Path(str(base)+"-wave-actions"+suffix+".png")
            turns_csv = Path(str(base)+"-wave-actions"+suffix+".csv")
            plot_pacing(page, turns_path, turns_csv)
            paths += [turns_path, turns_csv]
    return paths


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, help="Artifact prefix; defaults to the input stem.")
    parser.add_argument("--title")
    args = parser.parse_args()
    for path in generate(args.source, args.output, args.title):
        print(path.resolve())


if __name__ == "__main__":
    main()
