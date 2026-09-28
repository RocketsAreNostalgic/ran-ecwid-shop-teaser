#!/usr/bin/env python3
"""Exercise PHP quality tools on disposable source copies, without WordPress."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PHPQualityContract(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="ecwid-quality-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "tools").mkdir()
        shutil.copy2(ROOT / "tools/lint-php.php", self.root / "tools/lint-php.php")

    def run_tool(self, command):
        return subprocess.run(
            command, cwd=self.root, text=True, capture_output=True, timeout=120
        )

    def lint(self):
        return self.run_tool(["php", str(self.root / "tools/lint-php.php")])

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def test_syntax_checks_source_tests_tools_and_generated_php(self):
        for directory in ("includes", "blocks", "build/blocks", "tests", "tools"):
            with self.subTest(directory=directory):
                path = self.write(f"{directory}/space ' quote ; $ name.php", "<?php\n")
                clean = self.lint()
                self.assertEqual(0, clean.returncode, clean.stdout + clean.stderr)
                path.write_text("<?php function broken( {\n")
                broken = self.lint()
                self.assertNotEqual(0, broken.returncode)
                self.assertIn(path.name, broken.stdout + broken.stderr)
                path.unlink()

    def test_dependency_and_git_php_are_excluded(self):
        for directory in ("vendor", "node_modules", ".git"):
            self.write(f"{directory}/nested/broken.php", "<?php function broken( {\n")
        result = self.lint()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    @unittest.skipIf(os.geteuid() == 0, "root bypasses directory permissions")
    def test_discovery_failure_is_not_success(self):
        path = self.root / "unreadable-source"
        path.mkdir()
        self.addCleanup(path.chmod, 0o700)
        path.chmod(0)
        self.assertNotEqual(0, self.lint().returncode)

    def test_render_template_is_checked_and_formatter_is_stable(self):
        for name in ("ran-ecwid-shop-teaser.php", "phpcs.xml.dist"):
            shutil.copy2(ROOT / name, self.root / name)
        for name in ("includes", "blocks", "tests"):
            shutil.copytree(ROOT / name, self.root / name)

        shutil.copytree(ROOT / "tools", self.root / "tools", dirs_exist_ok=True)

        def standards(tool="phpcs", *extra):
            return self.run_tool([
                "php", str(ROOT / "vendor/bin" / tool),
                "--standard=" + str(self.root / "phpcs.xml.dist"), *extra,
            ])

        def snapshot():
            return {
                str(path.relative_to(self.root)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in self.root.rglob("*.php")
            }

        clean = standards()
        self.assertEqual(0, clean.returncode, clean.stdout + clean.stderr)
        original = snapshot()
        for _ in range(2):
            fixed = standards("phpcbf")
            self.assertEqual(0, fixed.returncode, fixed.stdout + fixed.stderr)
            self.assertEqual(original, snapshot())

        # Tools and tests are first-party standards roots, and the Ecwid API
        # field exception must not disable owned property enforcement elsewhere.
        for relative in ("includes/Commerce/Ecwid/ProductRepository.php", "tools/lint-php.php", "tests/phpunit/test-ecwid-client.php"):
            path = self.root / relative
            original_bytes = path.read_bytes()
            try:
                path.write_bytes(original_bytes + b"\n$quality_probe->badProperty = 1;\n")
                result = standards("phpcs", "--report=json")
                self.assertNotEqual(0, result.returncode)
                report = json.loads(result.stdout)
                messages = report["files"][str(path)]["messages"]
                self.assertTrue(any(message["source"] == "WordPress.NamingConventions.ValidVariableName.UsedPropertyNotSnakeCase" for message in messages), messages)
            finally:
                path.write_bytes(original_bytes)

        template = self.root / "blocks/ecwid-shop-teaser/render.php"
        template.write_text(template.read_text() + "\necho $attributes['unsafe'];\n")
        invalid = standards("phpcs", "--report=json")
        self.assertNotEqual(0, invalid.returncode)
        report = json.loads(invalid.stdout)
        messages = report["files"][str(template)]["messages"]
        self.assertTrue(any(
            message["source"] == "WordPress.Security.EscapeOutput.OutputNotEscaped"
            for message in messages
        ), messages)


if __name__ == "__main__":
    unittest.main()
