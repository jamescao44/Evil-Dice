"""Exercise the actual process protocol, durable logs and resume/replay checks."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/playtest.py"


class TransportTest(unittest.TestCase):
    def run_tool(self, *args, input_text="", success=True):
        result = subprocess.run([sys.executable, str(TOOL), *map(str, args)], input=input_text,
                                text=True, capture_output=True, timeout=30, cwd=ROOT)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        self.assertNotIn("SCRIPT ERROR", result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines()], result

    def test_round_trip_resume_and_replay(self):
        with tempfile.TemporaryDirectory() as folder:
            first = Path(folder) / "first.jsonl"
            continued = Path(folder) / "continued.jsonl"
            commands = '\n{"action":"roll"}\n{"action":"form","dice":[1,1,1]}\n{"action":"state"}\n'
            replies, _ = self.run_tool("--seed", 42, "--log", first, input_text=commands)
            self.assertEqual(len(replies), 4)
            self.assertTrue(replies[1]["ok"])
            self.assertFalse(replies[2]["ok"])
            self.assertEqual(replies[2]["state"], replies[3]["state"])
            replay, _ = self.run_tool("--replay", first)
            self.assertEqual(replay[0]["replayed_commands"], 3)
            self.assertEqual(replay[0]["state"], replies[-1]["state"])
            resume, _ = self.run_tool("--resume", first, "--log", continued,
                                      input_text='{"action":"end"}\n{"action":"quit"}\n')
            self.assertEqual(resume[0]["state"], replies[-1]["state"])
            self.assertTrue(resume[1]["ok"])
            self.assertEqual(resume[1]["state"]["totals"]["enemy_phases"], 1)
            replay, _ = self.run_tool("--replay", continued)
            self.assertEqual(replay[0]["state"], resume[-1]["state"])
            self.assertEqual(replay[0]["replayed_commands"], 4)
            original = first.read_bytes()
            self.run_tool("--log", first, success=False)
            self.assertEqual(first.read_bytes(), original)

    def test_bad_input_batch_and_changed_source_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / "run.jsonl"
            commands = Path(folder) / "commands.jsonl"
            commands.write_text('oops\n[]\n{"action":"roll","perfect":"false"}\n{"action":"roll","perfect":true}\n')
            replies, _ = self.run_tool("--log", log, "--commands", commands)
            self.assertEqual([r["ok"] for r in replies], [True, False, False, False, True])
            self.assertEqual(replies[-1]["state"]["player"]["combo_multiplier"], 1.3)
            entries = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(len(entries), 3)  # Invalid JSON never reached the engine.
            entries[0]["source_sha256"] = "changed"
            log.write_text("\n".join(json.dumps(record) for record in entries))
            _, error = self.run_tool("--replay", log, success=False)
            self.assertIn("Source changed", error.stderr)


if __name__ == "__main__":
    unittest.main()
