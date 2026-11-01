"""Tests for build_manual.py; every case works on a temporary copy of the fixture."""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

SCRIPT = HERE / "build_manual.py"
FIXTURE = HERE.parents[1] / "tests" / "manual" / "docs" / "manual"


def run_cli(*args):
    return subprocess.run(
        [sys.executable, "-B", "-I", str(SCRIPT), *map(str, args)],
        capture_output=True, text=True, check=False)


class ManualTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = pathlib.Path(self._tmp.name)
        self.root = self.tmp / "manual"
        shutil.copytree(FIXTURE, self.root)
        self.out = self.tmp / "out"

    def build(self, *extra):
        return run_cli("--root", self.root, "--out", self.out, *extra)

    def test_build_two_languages(self):
        r = self.build()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        en = (self.out / "en" / "index.html").read_text(encoding="utf-8")
        ar = (self.out / "ar" / "index.html").read_text(encoding="utf-8")
        self.assertIn('dir="ltr"', en)
        self.assertIn('dir="rtl"', ar)
        self.assertTrue((self.out / "index.html").exists())
        self.assertTrue((self.out / "assets" / "tiny.png").exists())
        self.assertFalse((self.root / "en").exists())  # sources stay untouched

    def test_check_passes_on_fixture_and_writes_nothing(self):
        r = run_cli("--root", self.root, "--check")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertFalse(self.out.exists())

    def test_check_missing_translation(self):
        (self.root / "content" / "ar" / "index.md").unlink()
        r = run_cli("--root", self.root, "--check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("ar/index.md", r.stdout)

    def test_check_broken_link(self):
        page = self.root / "content" / "en" / "index.md"
        page.write_text(page.read_text(encoding="utf-8") + "\nSee [gone](missing.md).\n",
                        encoding="utf-8")
        r = run_cli("--root", self.root, "--check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("missing", r.stdout)

    def test_check_missing_image(self):
        (self.root / "assets" / "tiny.png").unlink()
        r = run_cli("--root", self.root, "--check")
        self.assertEqual(r.returncode, 1)
        self.assertIn("tiny.png", r.stdout)

    def test_check_labels(self):
        labels = self.tmp / "labels.json"
        labels.write_text(json.dumps({"en": ["Open"], "ar": ["حفظ"]}), encoding="utf-8")
        r = run_cli("--root", self.root, "--check", "--labels", labels)
        self.assertEqual(r.returncode, 1)
        self.assertIn("Save", r.stdout)
        labels.write_text(json.dumps({"en": ["Save:"], "ar": ["حفظ"]}), encoding="utf-8")
        r = run_cli("--root", self.root, "--check", "--labels", labels)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_title_default_and_option(self):
        self.assertEqual(self.build().returncode, 0)
        self.assertIn("<h1>User manual</h1>", (self.out / "index.html").read_text(encoding="utf-8"))
        self.assertEqual(self.build("--title", "Sample Product").returncode, 0)
        index = (self.out / "index.html").read_text(encoding="utf-8")
        self.assertIn("<h1>Sample Product</h1>", index)
        self.assertNotIn("<picture", index)  # no logo without assets/brand/icon-light.png

    def test_logo_only_when_icon_exists(self):
        brand = self.root / "assets" / "brand"
        brand.mkdir()
        shutil.copy(self.root / "assets" / "tiny.png", brand / "icon-light.png")
        self.assertEqual(self.build().returncode, 0)
        index = (self.out / "index.html").read_text(encoding="utf-8")
        self.assertIn("assets/brand/icon-light.png", index)
        self.assertNotIn("icon-dark", index)
        self.assertEqual(run_cli("--root", self.root, "--check").returncode, 0)

    def test_root_template_overrides_default(self):
        (self.root / "template.html").write_text("<p>CUSTOM {{title}}</p>", encoding="utf-8")
        self.assertEqual(self.build().returncode, 0)
        self.assertEqual((self.out / "en" / "index.html").read_text(encoding="utf-8"),
                         "<p>CUSTOM Welcome</p>")

    def test_out_inside_content_is_refused(self):
        r = run_cli("--root", self.root, "--out", self.root / "content" / "en")
        self.assertNotEqual(r.returncode, 0)

    def test_out_is_required_without_check(self):
        self.assertNotEqual(run_cli("--root", self.root).returncode, 0)


if __name__ == "__main__":
    unittest.main()
