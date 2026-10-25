"""Summarize the saved October comparison without altering game balance."""
import argparse
import json
import math
import statistics as stats
from pathlib import Path


def mean(rows, key):
    """Average a recorded quantity across the shared seeds."""
    return stats.mean(row[key] for row in rows)


def summarize_rows(data):
    """Retain both damage distributions and action counts for every tested loadout."""
    output = {}
    for name in dict.fromkeys(row["build"] for row in data["results"]):
        output[name] = {}
        for targets in (1, 3):
            rows = [r for r in data["results"] if r["build"] == name and r["targets"] == targets]
            damage = sorted(r["damage"] for r in rows)
            output[name][str(targets)] = {
                "samples": len(rows), "mean": stats.mean(damage),
                "median": stats.median(damage), "min": min(damage), "max": max(damage),
                "mean_peak_turn": mean(rows, "peak_turn"),
                "mean_rolls": mean(rows, "rolls"), "mean_skills": mean(rows, "skills"),
                "mean_healing": mean(rows, "healing"), "mean_hp": mean(rows, "hp"),
                "mean_max_hp": mean(rows, "max_hp"), "mean_burn_damage": mean(rows, "burn_damage"),
            }
    return output


def main():
    """Check every batch, compare exact old samples, then save a compact reproducible summary."""
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    names = ["legacy-rerun", "candidates", "fusions", "potion-encounters"]
    if (args.input / "followups.json").exists():
        names.append("followups")
    batches = {name: json.loads((args.input / (name + ".json")).read_text()) for name in names}
    for name, batch in batches.items():
        if batch["failures"]:
            raise ValueError(f"{name}: {batch['failures']}")
    old = json.loads(args.baseline.read_text())
    indexed = {(r["build"], r["targets"], r["seed"]): r for r in old["results"]}
    rerun = batches["legacy-rerun"]["results"]
    changed = [r for r in rerun if r["damage"] != indexed[(r["build"], r["targets"], r["seed"])]["damage"]]
    primary = json.loads(json.dumps(batches["candidates"]))
    if "followups" in batches:
        primary["results"].extend(batches["followups"]["results"])
        primary["plan"]["builds"].extend(batches["followups"]["plan"]["builds"])
    totals = summarize_rows(primary)
    comparisons = []
    for family in dict.fromkeys(b["family"] for b in primary["plan"]["builds"]):
        choices = [b for b in primary["plan"]["builds"] if b["family"] == family]
        best = max(choices, key=lambda b: math.sqrt(totals[b["id"]]["1"]["mean"] * totals[b["id"]]["3"]["mean"]))
        reference = next(b for b in choices if b["kind"] == "reference")
        comparisons.append({
            "family": family, "reference": reference["id"], "selected": best["id"],
            "damage": {str(t): {"reference": totals[reference["id"]][str(t)]["mean"],
                "selected": totals[best["id"]][str(t)]["mean"],
                "change_percent": 100 * (totals[best["id"]][str(t)]["mean"] / totals[reference["id"]][str(t)]["mean"] - 1)} for t in (1, 3)},
        })
    encounters = []
    for wave in (24, 30):
        for build in ("potion_x", "hellfire", "mithril_blade"):
            rows = [r for r in batches["potion-encounters"]["probes"] if r["wave"] == wave and r["build"] == build]
            wins = [r for r in rows if r["outcome"] in ("wave_clear", "victory")]
            encounters.append({"wave": wave, "build": build, "samples": len(rows), "clears": len(wins),
                "median_enemy_turns_on_clear": stats.median(r["stats"]["enemy_phases"] for r in wins),
                "mean_enemy_turns_on_clear": stats.mean(r["stats"]["enemy_phases"] for r in wins),
                "start_level": rows[0]["start_level"]})
    summary = {
        "date": "2026-10-26", "gameplay_changed": False,
        "exact_rerun": {"samples": len(rerun), "changed_damage_samples": len(changed)},
        "primary_plan": primary["plan"], "primary": totals, "comparisons": comparisons,
        "selection_note": "Best geometric mean of one- and three-target damage among these illustrative candidates; exploratory, not exhaustive or held-out optimization.",
        "fusions": summarize_rows(batches["fusions"]), "fusion_plan": batches["fusions"]["plan"],
        "encounters": encounters,
        "completed_samples": sum(len(b.get("results", b.get("probes", []))) for b in batches.values()),
        "failures": [], "raw_directory": str(args.input),
    }
    args.output.write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"exact_rerun": summary["exact_rerun"], "comparisons": comparisons, "completed_samples": summary["completed_samples"]}, indent=2))


if __name__ == "__main__":
    main()
