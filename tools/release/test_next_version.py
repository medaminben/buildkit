"""Tests for next_version.py (unit tests and CLI tests)."""

import pathlib
import subprocess
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from next_version import next_version  # noqa: E402

SCRIPT = HERE / "next_version.py"


def run_cli(*args):
    return subprocess.run(
        [sys.executable, "-B", "-I", str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )


class NextVersionTests(unittest.TestCase):
    def test_patch_is_default_bump(self):
        self.assertEqual(next_version("1.5.4", [], "main"), "1.5.5")

    def test_minor_label(self):
        self.assertEqual(next_version("1.5.4", ["semver:minor"], "main"), "1.6.0")

    def test_major_label(self):
        self.assertEqual(next_version("1.5.4", ["semver:major"], "main"), "2.0.0")

    def test_patch_label(self):
        self.assertEqual(next_version("1.5.4", ["semver:patch"], "main"), "1.5.5")

    def test_none_label_returns_none(self):
        self.assertIsNone(next_version("1.5.4", ["semver:none"], "main"))

    def test_conflicting_semver_labels_raise(self):
        with self.assertRaises(ValueError):
            next_version("1.5.4", ["semver:minor", "semver:patch"], "main")

    def test_none_with_other_semver_label_raises(self):
        with self.assertRaises(ValueError):
            next_version("1.5.4", ["semver:none", "semver:minor"], "main")

    def test_first_release(self):
        self.assertEqual(next_version(None, [], "main"), "0.1.0")

    def test_first_release_ignores_label(self):
        self.assertEqual(next_version(None, ["semver:major"], "main"), "0.1.0")

    def test_none_label_on_first_release_returns_none(self):
        self.assertIsNone(next_version(None, ["semver:none"], "main"))

    def test_none_label_on_first_beta_returns_none(self):
        self.assertIsNone(next_version(None, ["semver:none"], "Beta"))

    def test_main_does_not_parse_latest_beta(self):
        self.assertEqual(
            next_version("1.5.4", [], "main", latest_beta="garbage"), "1.5.5"
        )

    def test_beta_first_beta_of_bumped_base(self):
        self.assertEqual(next_version("1.5.4", ["semver:minor"], "Beta"), "1.6.0-beta.1")

    def test_beta_increments_existing_beta(self):
        self.assertEqual(
            next_version("1.5.4", ["semver:minor"], "Beta", latest_beta="1.6.0-beta.2"),
            "1.6.0-beta.3",
        )

    def test_beta_of_other_base_restarts_numbering(self):
        self.assertEqual(
            next_version("1.5.4", ["semver:minor"], "Beta", latest_beta="1.5.5-beta.7"),
            "1.6.0-beta.1",
        )

    def test_main_ignores_latest_beta(self):
        self.assertEqual(
            next_version("1.5.4", [], "main", latest_beta="1.6.0-beta.3"), "1.5.5"
        )

    def test_non_semver_labels_are_ignored(self):
        self.assertEqual(next_version("1.5.4", ["bug", "docs"], "main"), "1.5.5")

    def test_unknown_branch_raises(self):
        with self.assertRaises(ValueError):
            next_version("1.5.4", [], "feature/x")

    def test_malformed_stable_raises(self):
        for bad in ("1.5", "v1.5.4", "1.5.4-beta.1", "a.b.c", "01.5.4"):
            with self.subTest(bad=bad):
                with self.assertRaises(ValueError):
                    next_version(bad, [], "main")

    def test_malformed_latest_beta_raises(self):
        with self.assertRaises(ValueError):
            next_version("1.5.4", [], "Beta", latest_beta="1.6.0")


class CliTests(unittest.TestCase):
    def test_bump_prints_tag(self):
        result = run_cli("--latest-stable", "v1.5.4", "--labels", "semver:minor",
                         "--branch", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "v1.6.0\n")

    def test_tag_without_v_is_accepted(self):
        result = run_cli("--latest-stable", "1.5.4", "--labels", "",
                         "--branch", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "v1.5.5\n")

    def test_none_prints_nothing(self):
        result = run_cli("--latest-stable", "v1.5.4", "--labels", "semver:none",
                         "--branch", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_empty_stable_with_none_label_prints_nothing(self):
        result = run_cli("--latest-stable", "", "--labels", "semver:none",
                         "--branch", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_beta_increments_latest_beta(self):
        result = run_cli("--branch", "Beta", "--latest-beta", "v1.6.0-beta.2",
                         "--labels", "semver:minor", "--latest-stable", "v1.5.4")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "v1.6.0-beta.3\n")

    def test_malformed_stable_exits_2(self):
        result = run_cli("--latest-stable", "v1.5", "--labels", "",
                         "--branch", "main")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertTrue(result.stderr.strip())

    def test_conflict_exits_2(self):
        result = run_cli("--latest-stable", "v1.5.4",
                         "--labels", "semver:minor,semver:patch", "--branch", "main")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertTrue(result.stderr.strip())


if __name__ == "__main__":
    unittest.main()
