#!/usr/bin/env python3
"""Run the current balance policy, retain its source fingerprint, and plot health/Fireball."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import subprocess

from playtest import ROOT, executable
from plot_playtest import generate


def source_fingerprint() -> str:
    """Include policy, recorder and uncommitted gameplay code in each experiment identity."""
    digest = hashlib.sha256()
    paths = [ROOT / "project.godot", *ROOT.glob("scripts/**/*.gd"), *ROOT.glob("tools/**/*.gd"), *ROOT.glob("tools/**/*.py")]
    for path in sorted(paths):
        digest.update(str(path.relative_to(ROOT)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New output directory; previous runs are never overwritten.")
    parser.add_argument("--seed-offset", type=int, default=112000)
    parser.add_argument("--seed-count", type=int, default=6)
    parser.add_argument("--paired", action="store_true", help="Run both tarot policies on each seed.")
    parser.add_argument("--godot")
    args = parser.parse_args()
    if args.seed_count < 1:
        parser.error("seed-count must be positive; the policy validates its available seed pool.")
    # Check plotting before starting the run, so a missing package does not discard useful work.
    import matplotlib  # noqa: F401
    folder = args.output or ROOT / "test-output/playtests" / dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f-balance")
    folder = folder.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = folder / "runs.json"
    command = [executable(args.godot), "--headless", "--path", str(ROOT), "--script", "res://tools/pressure_balance.gd", "--", str(source), str(args.seed_offset), str(args.seed_count)]
    if args.paired:
        command.append("paired")
    fingerprint = source_fingerprint()
    metadata = {"started_at": dt.datetime.now(dt.timezone.utc).isoformat(), "source_sha256": fingerprint, "command": command}
    metadata_path = folder / "metadata.json"
    metadata_path.write_text(json.dumps(metadata, indent=2)+"\n")
    with (folder / "engine.log").open("w") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
    metadata["exit_code"] = result.returncode
    metadata["source_unchanged"] = fingerprint == source_fingerprint()
    metadata_path.write_text(json.dumps(metadata, indent=2)+"\n")
    engine_log = (folder / "engine.log").read_text()
    if result.returncode or "SCRIPT ERROR:" in engine_log or "ERROR:" in engine_log:
        raise RuntimeError(f"Balance run reported an error; inspect {folder / 'engine.log'}")
    data = json.loads(source.read_text())
    if data.get("failures") or not metadata["source_unchanged"]:
        raise RuntimeError(f"Run failed validation or sources changed during play; raw results saved at {folder}")
    for path in generate(source):
        print(path)
    print(f"Cleared {sum(r['outcome'] == 'victory' for r in data['runs'])}/{len(data['runs'])} runs; raw traces: {source}")


if __name__ == "__main__":
    main()
