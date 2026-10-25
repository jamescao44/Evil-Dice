#!/usr/bin/env python3
"""Agent JSONL bridge to the real Godot rules. No human terminal UI or balance policy."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "PLAYTEST_JSON "


def fingerprint() -> str:
    """Bind replays to the exact gameplay source, including uncommitted changes."""
    digest = hashlib.sha256()
    for path in sorted([ROOT / "project.godot", *ROOT.glob("scripts/**/*.gd"), ROOT / "tools/playtest.gd", ROOT / "tools/playtest.py"]):
        digest.update(str(path.relative_to(ROOT)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def executable(explicit: str | None) -> str:
    """Find Godot without relying on a user's shell aliases."""
    options = [explicit, os.environ.get("GODOT"), shutil.which("godot"), shutil.which("godot4"),
               "/Applications/Programming/Godot.app/Contents/MacOS/Godot",
               "/Applications/Godot.app/Contents/MacOS/Godot"]
    for candidate in options:
        if candidate and Path(candidate).is_file():
            return candidate
    raise RuntimeError("Godot not found. Supply --godot /path/to/Godot or set GODOT.")


class Engine:
    """Keep one real rules instance alive between explicit agent decisions."""
    def __init__(self, binary: str, seed: int):
        self.process = subprocess.Popen(
            [binary, "--headless", "--path", str(ROOT), "--script", "res://tools/playtest.gd", "--", str(seed)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1,
        )
        self.initial = self.receive()

    def receive(self) -> dict:
        """Filter engine startup diagnostics so stdout remains valid JSONL."""
        for line in self.process.stdout:
            if line.startswith(PREFIX):
                return json.loads(line[len(PREFIX):])
        raise RuntimeError(f"Godot exited before replying (code {self.process.poll()}); see stderr.")

    def command(self, request: dict) -> dict:
        self.process.stdin.write(json.dumps(request, ensure_ascii=False) + "\n")
        self.process.stdin.flush()
        return self.receive()

    def close(self) -> None:
        """Stop only this child process; the GUI and editor remain untouched."""
        if self.process.poll() is None:
            try:
                self.process.stdin.write('{"action":"quit"}\n')
                self.process.stdin.flush()
                self.process.wait(timeout=5)
            except (BrokenPipeError, subprocess.TimeoutExpired):
                self.process.terminate()
                self.process.wait(timeout=5)


def emit(value: dict) -> None:
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")), flush=True)


def load_log(path: Path) -> list[dict]:
    """Read a recorded session without executing arbitrary code from its contents."""
    records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    if not records or records[0].get("type") != "start":
        raise RuntimeError("Not a playtest log.")
    if records[0].get("source_sha256") != fingerprint():
        raise RuntimeError("Source changed since this log. Start a fresh run; replay/resume requires identical rules.")
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--godot")
    parser.add_argument("--log", type=Path, help="New JSONL log; existing files are never overwritten.")
    parser.add_argument("--commands", type=Path, help="Read JSON commands from a file instead of stdin.")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--resume", type=Path, help="Reconstruct a logged run, then accept more commands.")
    source.add_argument("--replay", type=Path, help="Re-execute a log and compare every response exactly.")
    args = parser.parse_args()
    records = load_log(args.resume or args.replay) if args.resume or args.replay else []
    seed = records[0]["seed"] if records else args.seed
    engine = Engine(executable(args.godot), seed)
    try:
        response = engine.initial
        if records:
            if response != records[0]["response"]:
                raise RuntimeError("Initial state differs from the recorded run.")
            for index, record in enumerate(records[1:], 1):
                response = engine.command(record["request"])
                if response != record["response"]:
                    raise RuntimeError(f"Replay diverged at command {index}: {record['request']}")
            if args.replay:
                emit({"ok": True, "replayed_commands": len(records)-1, "state": response["state"]})
                return 0
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        path = args.log or ROOT / "test-output/playtests" / f"{stamp}-seed-{seed}.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("x", encoding="utf-8") as log:
            initial_records = records or [{"type": "start", "protocol": 1, "seed": seed,
                                           "source_sha256": fingerprint(), "response": engine.initial}]
            for record in initial_records:
                log.write(json.dumps(record, ensure_ascii=False) + "\n")
            log.flush()
            emit({"session": {"seed": seed, "log": str(path.resolve()), "timing": "roll.perfect is an explicit assumption; omitted = false", "pity": "fresh, in-memory; GUI saves untouched"}, **response})
            stream = args.commands.open(encoding="utf-8") if args.commands else sys.stdin
            try:
                for line in stream:
                    if not line.strip():
                        continue
                    try:
                        request = json.loads(line)
                        if not isinstance(request, dict):
                            raise ValueError("Expected a JSON object.")
                        if request.get("action") == "quit":
                            break
                    except (ValueError, json.JSONDecodeError) as error:
                        emit({"ok": False, "error": str(error)})
                        continue
                    response = engine.command(request)
                    log.write(json.dumps({"type": "command", "request": request, "response": response}, ensure_ascii=False) + "\n")
                    log.flush()
                    emit(response)
            finally:
                if args.commands:
                    stream.close()
    finally:
        engine.close()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError) as error:
        print(f"Playtest error: {error}", file=sys.stderr)
        raise SystemExit(1)
