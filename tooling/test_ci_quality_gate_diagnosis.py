import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
SUPABASE_WORKFLOW = (ROOT / ".github/workflows/supabase-integration-tests.yml").read_text(encoding="utf-8")
PGTAP = (ROOT / "supabase/tests/database/rls_security_test.sql").read_text(encoding="utf-8")
MIGRATION = (ROOT / "supabase/migrations/202608240001_security_alerts.sql").read_text(encoding="utf-8")
REPORT = (ROOT / "docs/ci-failure-investigation-2026-08-24.md").read_text(encoding="utf-8")


class CIQualityGateDiagnosisTests(unittest.TestCase):
    def test_flutter_pin_and_constraint_match(self):
        self.assertIn("flutter: '>=3.27.0 <4.0.0'", PUBSPEC)
        self.assertIn("flutter-version: '3.27.1'", SUPABASE_WORKFLOW)

    def test_pgtap_inputs_are_present_and_consistent(self):
        self.assertIn("select plan(13);", PGTAP)
        self.assertIn("create table if not exists public.security_alerts", MIGRATION)
        self.assertIn("rls_supabase_test.dart", SUPABASE_WORKFLOW)
        self.assertNotIn("rls_security_test.dart", SUPABASE_WORKFLOW)

    def test_report_separates_root_causes_from_warnings(self):
        self.assertIn("Quality gate` failure was derivative", REPORT)
        self.assertIn("Node 20 deprecation", REPORT)
        self.assertIn("non-blocking warnings", REPORT)


if __name__ == "__main__":
    unittest.main()
