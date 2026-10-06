import copy
import json
from pathlib import Path
import unittest
from scripts.report import evaluate, render
from scripts.probe import build_probe

ROOT = Path(__file__).resolve().parents[1]


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.evidence = json.loads((ROOT / "examples/hardened.json").read_text())

    def test_before_and_after(self):
        for name in ("hardened", "vulnerable"):
            self.assertTrue(evaluate(json.loads((ROOT / f"examples/{name}.json").read_text())))

    def test_retain_canary_access(self):
        self.evidence["events"][0]["status"] = 403
        self.assertFalse(evaluate(self.evidence))

    def test_overprivileged_hardened_identity_fails(self):
        self.evidence["events"][1]["status"] = 200
        self.assertFalse(evaluate(self.evidence))

    def test_duplicate_targets_rejected(self):
        self.evidence["events"][1] = copy.deepcopy(self.evidence["events"][0])
        with self.assertRaises(ValueError): evaluate(self.evidence)

    def test_incomplete_probe_rejected(self):
        self.evidence["events"].pop()
        with self.assertRaises(ValueError): evaluate(self.evidence)

    def test_boolean_status_rejected(self):
        self.evidence["events"][0]["status"] = True
        with self.assertRaises(ValueError): evaluate(self.evidence)

    def test_unknown_provenance_rejected(self):
        self.evidence["provenance"] = "verified-cloud"
        with self.assertRaises(ValueError): evaluate(self.evidence)

    def test_sample_label_preserved(self):
        self.assertIn("Synthetic example only", render(self.evidence))

    def test_live_probe_does_not_claim_sentinel_detection(self):
        self.evidence["provenance"] = "live-vm-probe"
        self.assertIn("Verify corresponding cloud audit logs separately", render(self.evidence))

    def test_command_arguments_cannot_inject_script(self):
        with self.assertRaises(ValueError): build_probe("vault';evil", "a" * 36)
        with self.assertRaises(ValueError): build_probe("lab-vault", "';echo evil")

    def test_generated_probe_is_valid_python(self):
        script = build_probe("lab-vault", "00000000-0000-0000-0000-000000000000")
        compile(script.split("\n", 1)[1].rsplit("\nPY", 1)[0], "probe", "exec")


if __name__ == "__main__": unittest.main()
