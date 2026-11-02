import os
import subprocess
import tempfile
import unittest

import plan_release


def git(repo, *args):
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
    return subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True,
                          text=True, env=env).stdout.strip()


def commit(repo, subject):
    git(repo, "commit", "--allow-empty", "-m", subject)
    return git(repo, "rev-parse", "HEAD")


class PlanReleaseTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.repo = self._tmp.name
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "tag.gpgsign", "false")
        git(self.repo, "config", "commit.gpgsign", "false")
        commit(self.repo, "feat: first")
        git(self.repo, "tag", "-a", "v1.5.4", "-m", "r")
        commit(self.repo, "feat: beta work 1")
        git(self.repo, "tag", "-a", "v1.6.0-beta.1", "-m", "r")
        commit(self.repo, "feat: beta work 2")
        git(self.repo, "tag", "-a", "v1.6.0-beta.2", "-m", "r")
        self.sha = commit(self.repo, "fix: merge")

    def plan(self, labels, base, head=""):
        return plan_release.plan_tag(self.repo, labels, base, head, self.sha)

    def test_beta_minor_continues_numbering_of_its_base(self):
        self.assertEqual(self.plan(["semver:minor"], "Beta"), "v1.6.0-beta.3")

    def test_beta_without_label_continues_open_series(self):
        self.assertEqual(self.plan([], "Beta"), "v1.6.0-beta.3")

    def test_beta_major_starts_higher_series(self):
        self.assertEqual(self.plan(["semver:major"], "Beta"), "v2.0.0-beta.1")

    def test_beta_after_release_starts_new_series(self):
        git(self.repo, "tag", "-a", "v1.6.0", "-m", "r")
        self.assertEqual(self.plan([], "Beta"), "v1.6.1-beta.1")

    def test_fork_head_is_not_a_promotion(self):
        self.assertEqual(
            plan_release.plan_tag(self.repo, [], "main", "Beta", self.sha, from_fork=True),
            "v1.5.5")

    def test_malformed_tags_are_ignored(self):
        for bad in ("v01.2.3", "v1.2", "v9.9.9-beta.01", "v9.9.9-rc.1"):
            git(self.repo, "tag", bad)
        self.assertEqual(self.plan([], "main", "feature/x"), "v1.5.5")
        self.assertEqual(self.plan(["semver:minor"], "Beta"), "v1.6.0-beta.3")
        self.assertEqual(plan_release.notes(self.repo, "main", self.sha).splitlines()[-1],
                         "- feat: beta work 1")

    def test_main_plain_pr_is_patch(self):
        self.assertEqual(self.plan([], "main", "feature/x"), "v1.5.5")

    def test_main_promotion_releases_beta_base(self):
        self.assertEqual(self.plan([], "main", "Beta"), "v1.6.0")

    def test_promotion_ignores_unreachable_betas(self):
        git(self.repo, "checkout", "-q", "-b", "side", "v1.5.4")
        commit(self.repo, "feat: side")
        git(self.repo, "tag", "-a", "v2.0.0-beta.1", "-m", "r")
        git(self.repo, "checkout", "-q", "main")
        self.assertEqual(self.plan([], "main", "Beta"), "v1.6.0")

    def test_promotion_ignores_betas_not_greater_than_stable(self):
        git(self.repo, "tag", "-a", "v1.6.0", "-m", "r", "HEAD~1")
        self.assertEqual(self.plan([], "main", "Beta"), "v1.6.1")

    def test_promotion_with_semver_none_is_no_release(self):
        self.assertIsNone(self.plan(["semver:none"], "main", "Beta"))

    def test_conflicting_labels_raise(self):
        with self.assertRaises(ValueError):
            self.plan(["semver:minor", "semver:major"], "main", "Beta")

    def test_rerun_on_main_reuses_the_stable_tag_of_the_sha(self):
        self.assertEqual(self.plan([], "main", "feature/x"), "v1.5.5")
        git(self.repo, "tag", "-a", "v1.5.5", "-m", "r", self.sha)
        self.assertEqual(self.plan([], "main", "feature/x"), "v1.5.5")
        # also when the labels would now ask for something else
        self.assertEqual(self.plan(["semver:minor"], "main", "feature/x"), "v1.5.5")

    def test_rerun_on_beta_reuses_the_beta_tag_of_the_sha(self):
        git(self.repo, "tag", "-a", "v1.6.0-beta.3", "-m", "r", self.sha)
        self.assertEqual(self.plan([], "Beta"), "v1.6.0-beta.3")

    def test_tag_of_the_other_kind_is_not_reused(self):
        git(self.repo, "tag", "-a", "v1.6.0-beta.3", "-m", "r", self.sha)
        self.assertEqual(self.plan([], "main", "feature/x"), "v1.5.5")
        git(self.repo, "tag", "-a", "v1.6.0", "-m", "r", self.sha)
        self.assertEqual(self.plan([], "Beta"), "v1.6.0-beta.3")

    def test_notes_of_a_rerun_do_not_start_at_the_sha_itself(self):
        git(self.repo, "tag", "-a", "v1.5.5", "-m", "r", self.sha)
        self.assertEqual(plan_release.notes(self.repo, "main", self.sha).splitlines()[0],
                         "- fix: merge")

    def test_notes_on_main_skip_betas(self):
        text = plan_release.notes(self.repo, "main", self.sha)
        self.assertEqual(text.splitlines(),
                         ["- fix: merge", "- feat: beta work 2", "- feat: beta work 1"])

    def test_notes_ignore_stray_tag(self):
        git(self.repo, "tag", "v1.2")
        self.assertEqual(len(plan_release.notes(self.repo, "main", self.sha).splitlines()), 3)

    def test_notes_on_beta_start_after_latest_tag(self):
        self.assertEqual(plan_release.notes(self.repo, "Beta", self.sha).splitlines(),
                         ["- fix: merge"])

    def test_notes_without_tag_use_all_history(self):
        with tempfile.TemporaryDirectory() as repo:
            git(repo, "init", "-q", "-b", "main")
            sha = commit(repo, "feat: only")
            self.assertEqual(plan_release.notes(repo, "main", sha), "- feat: only\n")
            self.assertEqual(plan_release.plan_tag(repo, [], "main", "", sha), "v0.1.0")


if __name__ == "__main__":
    unittest.main()
