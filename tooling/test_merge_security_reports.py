#!/usr/bin/env python3
import importlib.util
import json
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("merge_security_reports", Path(__file__).with_name("merge_security_reports.py"))
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


def test_merge_and_redact() -> None:
    sarif = {
        "version": "2.1.0",
        "runs": [{
            "tool": {"driver": {"name": "Trivy", "rules": [{"id": "CVE-TEST", "shortDescription": {"text": "Test vulnerability"}}]}},
            "results": [{
                "ruleId": "CVE-TEST",
                "level": "error",
                "message": {"text": "token=super-secret-token-value-should-not-appear"},
                "locations": [{"physicalLocation": {"artifactLocation": {"uri": "backend/package-lock.json"}, "region": {"startLine": 12}}}],
            }],
        }],
    }
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "trivy.sarif"
        path.write_text(json.dumps(sarif), encoding="utf-8")
        report = module.build_report([(path, "trivy")])
        assert report["summary"]["total"] == 1
        assert report["summary"]["by_severity"]["high"] == 1
        assert "super-secret" not in json.dumps(report)
        assert report["findings"][0]["file"] == "backend/package-lock.json"
        assert report["findings"][0]["line"] == 12


def test_missing_input_is_safe() -> None:
    report = module.build_report([(Path("/does/not/exist.sarif"), "snyk")])
    assert report["summary"]["total"] == 0
    assert report["inputs"] == []


if __name__ == "__main__":
    test_merge_and_redact()
    test_missing_input_is_safe()
    print("2 merge-security-report tests passed")
