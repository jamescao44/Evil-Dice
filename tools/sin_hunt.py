#!/usr/bin/env python3
"""Run two natural, goal-directed attempts per sin without touching the player's saves."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import datetime as dt
import json
from pathlib import Path
import subprocess
import time

from balance_test import source_fingerprint, rules_fingerprint
from playtest import ROOT, executable
from plot_playtest import generate

SINS = ["gluttony", "lust", "wrath", "sloth", "envy", "greed", "pride"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    import matplotlib  # noqa: F401

    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    metadata = {"started_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "source_sha256": source_fingerprint(), "rules_sha256": rules_fingerprint(),
                "seeds": [711011, 711029], "perfect_rate": 0.70, "runs": []}
    metadata_path = folder / "metadata.json"
    metadata_path.write_text(json.dumps(metadata, indent=2)+"\n")

    def attempt(sin: str, seed: int) -> tuple[dict, dict]:
        stem = f"{sin}-{seed}"
        output = folder / (stem+".json")
        command = [executable(None), "--headless", "--path", str(ROOT), "--script",
                   "res://tools/sin_hunt.gd", "--", sin, str(seed), str(output)]
        start = time.monotonic()
        with (folder / (stem+".log")).open("w") as log:
            process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        entry = {"goal": sin, "seed": seed, "command": command, "exit_code": process.returncode,
                 "seconds": round(time.monotonic()-start, 2)}
        result = json.loads(output.read_text()) if output.exists() else {}
        log = (folder / (stem+".log")).read_text()
        entry["valid"] = process.returncode == 0 and bool(result.get("runs")) and not result.get("failures") and "SCRIPT ERROR:" not in log and "ERROR:" not in log
        run = result.get("runs", [{}])[0]
        run["build"] = "Hunt: "+sin
        print(f"{sin} {seed}: {run.get('outcome', 'ERROR')} wave {run.get('wave')}; awakened={run.get('awakened')}; peak={run.get('peak_progress')}; {entry['seconds']}s", flush=True)
        return entry, run

    runs = []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        pending = [pool.submit(attempt, sin, seed) for sin in SINS for seed in metadata["seeds"]]
        for future in as_completed(pending):
            entry, run = future.result()
            metadata["runs"].append(entry)
            runs.append(run)
            metadata_path.write_text(json.dumps(metadata, indent=2)+"\n")
    metadata["source_unchanged"] = metadata["source_sha256"] == source_fingerprint()
    metadata["finished_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
    metadata_path.write_text(json.dumps(metadata, indent=2)+"\n")
    runs.sort(key=lambda run: (SINS.index(run["goal"]), run["seed"]))
    source = folder / "runs.json"
    source.write_text(json.dumps({"perfect_rate": 0.70, "runs": runs, "failures": []}, indent=2)+"\n")
    if not metadata["source_unchanged"] or not all(entry["valid"] for entry in metadata["runs"]):
        raise RuntimeError(f"Run errors or changed sources; preserve and inspect {folder}")
    for sin in SINS:
        subset = folder / (sin+".json")
        subset.write_text(json.dumps({"runs": [run for run in runs if run["goal"] == sin]}, indent=2)+"\n")
        generate(subset, title="Evil Dice · "+sin.capitalize()+" acquisition attempts")
    print(f"Validated {len(runs)} attempts. Results and progression plots: {folder}", flush=True)


if __name__ == "__main__":
    main()
