"""Exercise the workflow's scan scope and fail-closed behavior without credentials."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/secret-scanning.yml"
SCRIPT = textwrap.dedent(WORKFLOW.read_text().split("python3 - <<'PY'\n")[2].rsplit("          PY", 1)[0])


class ScanHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.arguments = self.root / "scanner-arguments.json"
        self.summary = self.root / "summary.md"
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
                        GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid",
                        RUNNER_TEMP=str(self.root), GITHUB_STEP_SUMMARY=str(self.summary),
                        SCAN_EVENT="push", SCAN_FULL_HISTORY="false", FIXTURE_FINDINGS="0",
                        FIXTURE_ARGUMENTS=str(self.arguments), PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.git("init", "-b", "main")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", os.devnull)
        self.git("commit", "--allow-empty", "-m", "Base fixture")
        self.base = self.git("rev-parse", "HEAD").strip()
        self.git("commit", "--allow-empty", "-m", "Head fixture")
        self.head = self.git("rev-parse", "HEAD").strip()
        self.env.update(SCAN_BASE=self.base, SCAN_HEAD=self.head)
        scanner = self.bin / "infisical"
        scanner.write_text("#!" + sys.executable + "\n" + textwrap.dedent('''\
            import json, os, pathlib, sys
            pathlib.Path(os.environ["FIXTURE_ARGUMENTS"]).write_text(json.dumps(sys.argv[1:]))
            report = next(value.split("=", 1)[1] for value in sys.argv if value.startswith("--report-path="))
            findings = [{"File": "fixture.txt", "StartLine": 1, "RuleID": "fixture-rule",
                         "Secret": "PRIVATE_CANARY", "Match": "PRIVATE_CANARY"}] if os.environ["FIXTURE_FINDINGS"] == "1" else []
            pathlib.Path(report).write_text(json.dumps(findings))
            print("PRIVATE_CANARY")
            sys.exit(1 if findings else 0)
            '''))
        scanner.chmod(0o700)

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, env=self.env, stderr=subprocess.DEVNULL, text=True)

    def run_scan(self, **updates):
        env = dict(self.env, **updates)
        result = subprocess.run([sys.executable, "-c", SCRIPT], cwd=self.repo, env=env,
                                capture_output=True, text=True, timeout=20)
        self.assertNotIn("PRIVATE_CANARY", result.stdout + result.stderr)
        if self.summary.exists():
            self.assertNotIn("PRIVATE_CANARY", self.summary.read_text())
        return result

    def test_regular_push_preserves_commit_range(self):
        result = self.run_scan()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("--log-opts=" + self.base + ".." + self.head, json.loads(self.arguments.read_text()))

    def test_missing_push_base_scans_complete_new_history(self):
        result = self.run_scan(SCAN_BASE="f" * 40)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("previous push revision unavailable", result.stdout)
        self.assertIn("--log-opts=" + self.head, json.loads(self.arguments.read_text()))

    def test_fallback_still_fails_on_findings_without_printing_source(self):
        result = self.run_scan(SCAN_BASE="f" * 40, FIXTURE_FINDINGS="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("1 findings", result.stdout)

    def test_missing_pr_base_does_not_use_push_fallback(self):
        self.assertEqual(self.run_scan(SCAN_BASE="f" * 40, SCAN_EVENT="pull_request").returncode, 2)
        self.assertFalse(self.arguments.exists())

    def test_invalid_base_does_not_use_fallback(self):
        self.assertEqual(self.run_scan(SCAN_BASE="invalid").returncode, 2)
        self.assertFalse(self.arguments.exists())

    def test_shallow_history_does_not_claim_complete_scan(self):
        (self.repo / ".git/shallow").write_text(self.head + "\n")
        self.assertEqual(self.run_scan(SCAN_BASE="f" * 40).returncode, 2)
        self.assertFalse(self.arguments.exists())

    def test_missing_head_stays_incomplete(self):
        self.assertEqual(self.run_scan(SCAN_HEAD="f" * 40).returncode, 2)
        self.assertFalse(self.arguments.exists())

    def test_manual_current_files_scope_is_unchanged(self):
        result = self.run_scan(SCAN_EVENT="workflow_dispatch")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--no-git", json.loads(self.arguments.read_text()))


if __name__ == "__main__":
    unittest.main()
