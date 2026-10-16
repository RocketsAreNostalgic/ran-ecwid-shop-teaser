#!/usr/bin/env python3
"""Exercise the actual Plugin Check report gate with controlled diagnostics."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PluginCheckContract(unittest.TestCase):
    def check(self, text):
        with tempfile.TemporaryDirectory(prefix="ecwid-plugin-check-") as directory:
            report = Path(directory) / "report.json"
            report.write_text(text)
            return subprocess.run(
                [sys.executable, str(ROOT / "tools/verify-plugin-check.py"), str(report)],
                text=True, capture_output=True, timeout=10,
            )

    def test_empty_array_passes(self):
        self.assertEqual(0, self.check("[]").returncode)

    def test_reported_error_fails_even_without_a_command_failure(self):
        result = self.check(json.dumps([{"type": "ERROR", "code": "no_license"}]))
        self.assertEqual(1, result.returncode)
        self.assertIn("no_license", result.stdout)

    def test_warning_is_visible_and_nonblocking(self):
        result = self.check(json.dumps([{"type": "WARNING", "code": "description"}]))
        self.assertEqual(0, result.returncode)
        self.assertIn("description", result.stdout)
        self.assertIn("1 warning(s)", result.stdout)

    def test_malformed_or_untyped_reports_fail_closed(self):
        for payload in ("", "not-json", "null", "{}", '[{}]', '[{"type":"OTHER","code":"x"}]'):
            with self.subTest(payload=payload):
                self.assertEqual(1, self.check(payload).returncode)


if __name__ == "__main__":
    unittest.main()
