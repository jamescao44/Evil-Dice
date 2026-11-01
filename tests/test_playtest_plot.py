"""Check metric exports, partial runs and equivalent JSON/JSONL plotting inputs."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from plot_playtest import generate, load_runs, wave_positions, power_points


class PlotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.samples = [dict(sample=i, command=i, reason="resolution", wave=wave, round=1,
                             phase="roll", player_level=1, hp=hp, max_hp=1000,
                             hp_ratio=hp/1000, shield=0, base_damage=5,
                             fireball_per_use=damage, fireball_uses=1, combo_multiplier=1)
                        for i, (wave, hp, damage) in enumerate([(1,1000,21),(1,800,21),(2,0,42)])]
        self.run = {"seed": 11, "outcome": "defeat", "telemetry": {"schema": 1, "samples": self.samples}}

    def test_json_jsonl_equivalence_and_exports(self):
        batch = self.folder / "batch.json"
        batch.write_text(json.dumps({"runs": [self.run]}))
        log = self.folder / "agent.jsonl"
        records = [{"type": "start", "seed": 11, "response": {"state": {"outcome": ""}, "metrics": self.samples[:1]}},
                   {"type": "command", "response": {"state": {"outcome": "defeat"}, "metrics": self.samples[1:]}}]
        log.write_text("\n".join(json.dumps(r) for r in records))
        self.assertEqual(load_runs(batch), load_runs(log))
        paths = generate(batch)
        with paths[0].open() as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual([int(r["hp"]) for r in rows], [1000,800,0])
        self.assertEqual([int(r["fireball_per_use"]) for r in rows], [21,21,42])
        self.assertTrue(all(r["outcome"] == "defeat" for r in rows))
        self.assertTrue(paths[1].read_bytes().startswith(b"\x89PNG\r\n\x1a\n"))

    def test_legacy_and_corrupt_data_fail_explicitly(self):
        path = self.folder / "bad.json"
        for data in [{"runs": [{"seed": 1}]}, {"runs": []}]:
            path.write_text(json.dumps(data))
            with self.assertRaises(ValueError): load_runs(path)
        self.samples[0]["fireball_per_use"] = float("nan")
        path.write_text(json.dumps({"runs": [self.run]}))
        with self.assertRaises(ValueError): load_runs(path)

    def test_wave_spacing_stops_at_defeat(self):
        self.assertEqual(wave_positions(self.samples), [1.0,1.95,2.0])

    def test_relic_power_markers_and_csv(self):
        item = {"id":"bracelet", "name":"Spell Bracelet", "count":1}
        event = dict(sample=1, command=1, wave=1, round=1, source="buy", card="",
                     gained=[item], sold=[], replaced=[], added=[item], removed=[],
                     after=[item], damage_before=21, damage_after=42, uses_before=1, uses_after=1)
        self.run["telemetry"].update(schema=2, inventory_events=[event])
        points = power_points(self.run)
        self.assertEqual(points[0]["gain_percent"], 100)
        self.assertEqual(points[0]["reason"], "Spell Bracelet")
        batch = self.folder / "annotated.json"
        batch.write_text(json.dumps({"runs": [self.run]}))
        paths = generate(batch)
        self.assertEqual(len(paths), 4)
        with paths[1].open() as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(rows[0]["gained"], "Spell Bracelet")
        self.assertEqual(rows[0]["sold"], "")
        # Temporary damage spikes without inventory changes never pretend to be build gains.
        self.run["telemetry"]["inventory_events"] = []
        self.assertEqual(power_points(self.run), [])
        # Extra uses count toward cast power even when per-use damage stays unchanged.
        event.update(damage_after=21, uses_after=2)
        self.run["telemetry"]["inventory_events"] = [event]
        self.assertEqual(power_points(self.run)[0]["gain_percent"], 100)
        event.update(damage_after=22, uses_after=1)
        self.assertEqual(power_points(self.run), [])

    def test_wave_skill_counts_preserve_failed_encounters(self):
        self.run["telemetry"].update(schema=2, wave_turns=[{
            "wave":1,"boss":False,"round_ids":[1,2],"outcome":"defeat","cleared":False,
            "turns_spent":2,"turns_to_clear":None,
            "skills":{"Fireball":{"casts":3,"uses":3,"sources":{"manual":1,"character_bonus":2}},
                      "Fire Storm":{"casts":1,"uses":1,"sources":{"manual":1}}},
            "auto_attacks":{"2":{"groups":2,"pulses":4},"6":{"groups":1,"pulses":6}}
        }])
        path = self.folder / "actions.json"
        path.write_text(json.dumps({"runs":[self.run]}))
        outputs = generate(path)
        with next(p for p in outputs if p.name.endswith("wave-actions.csv")).open() as handle:
            row = next(csv.DictReader(handle))
        self.assertEqual(row["Fireball_casts"], "3")
        self.assertEqual(row["Fire Storm_casts"], "1")
        self.assertEqual(row["alike_6_groups"], "1")
        self.assertEqual(row["alike_6_pulses"], "6")
        self.assertEqual(row["turns_to_clear"], "")
        self.assertEqual(row["outcome"], "defeat")


if __name__ == "__main__":
    unittest.main()
