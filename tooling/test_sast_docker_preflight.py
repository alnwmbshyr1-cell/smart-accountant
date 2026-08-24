import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "tooling/sast_docker_preflight.sh").read_text(encoding="utf-8")
DOC = (ROOT / "docs/local-docker-sast-preflight.md").read_text(encoding="utf-8")


class SastDockerPreflightTests(unittest.TestCase):
    def test_images_are_pinned_and_source_is_read_only(self):
        self.assertIn("semgrep/semgrep:1.136.0", SCRIPT)
        self.assertIn("aquasec/trivy:0.59.1", SCRIPT)
        self.assertIn("-v \"$ROOT:/src:ro\"", SCRIPT)
        self.assertIn("--cap-drop=ALL", SCRIPT)
        self.assertIn("--security-opt=no-new-privileges", SCRIPT)

    def test_tools_match_ci_scopes_and_sarif_outputs(self):
        self.assertIn("--config p/python", SCRIPT)
        self.assertIn("--config p/javascript", SCRIPT)
        self.assertIn("--config p/secrets", SCRIPT)
        self.assertIn("--scanners vuln,misconfig,secret", SCRIPT)
        self.assertIn("--severity HIGH,CRITICAL", SCRIPT)
        self.assertIn("semgrep.sarif", SCRIPT)
        self.assertIn("trivy-webhook.sarif", SCRIPT)
        self.assertIn("summary.json", SCRIPT)

    def test_fail_closed_and_no_secret_upload_guidance(self):
        self.assertIn("exit 1", SCRIPT)
        self.assertIn("Docker is required", SCRIPT)
        self.assertIn("لا يضع الأسرار", DOC)
        self.assertIn("لا تشغّل هذا السكربت على مجلد يحتوي أسراراً", DOC)
        self.assertIn("pull_request_target", DOC)


if __name__ == "__main__":
    unittest.main()
