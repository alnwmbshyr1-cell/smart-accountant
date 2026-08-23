#!/usr/bin/env python3
import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import weekly_security_report


class WeeklySecurityReportTests(unittest.TestCase):
    def test_load_events_keeps_only_last_seven_days(self):
        now = datetime(2026, 8, 24, tzinfo=timezone.utc)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            path.write_text("\n".join([
                json.dumps({"timestamp": "2026-08-23T10:00:00Z", "status": "error", "error": "HTTP 503"}),
                json.dumps({"timestamp": "2026-08-10T10:00:00Z", "status": "error", "error": "old"}),
                "not-json",
            ]), encoding="utf-8")
            events = weekly_security_report.load_events(str(path), now)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["error"], "HTTP 503")

    def test_summary_counts_errors_duplicates_and_duration(self):
        summary = weekly_security_report.summarize([
            {"status": "202", "duplicate": False, "duration_ms": 10},
            {"status": "200", "duplicate": True, "duration_ms": 20},
            {"status": "error", "error": "HTTP 503", "duration_ms": 30},
        ])
        self.assertEqual(summary["events"], 3)
        self.assertEqual(summary["errors"], 1)
        self.assertEqual(summary["duplicates"], 1)
        self.assertEqual(summary["avg_duration_ms"], 20.0)
        self.assertIn("HTTP 503", summary["top_errors"])

    def test_markdown_is_bounded_and_has_no_raw_event_message(self):
        markdown = weekly_security_report.render_markdown({
            "period_days": 7,
            "events": 1,
            "errors": 1,
            "duplicates": 0,
            "avg_duration_ms": 12.5,
            "status_counts": {"error": 1},
            "top_errors": {"HTTP 503": 1},
        })
        self.assertIn("Weekly Security Gateway report", markdown)
        self.assertIn("HTTP 503", markdown)
        self.assertNotIn("Bearer ", markdown)

    def test_weekly_key_is_stable_for_same_repository_and_week(self):
        context = {"GITHUB_REPOSITORY": "org/repo", "GITHUB_WORKFLOW": "weekly", "GITHUB_SHA": "ignored"}
        first = weekly_security_report.make_weekly_key({}, context)
        second = weekly_security_report.make_weekly_key({}, context)
        self.assertEqual(first, second)
        self.assertTrue(first.startswith("sa-weekly-"))

    def test_slack_post_uses_idempotency_header(self):
        class Response:
            status = 200
            def __enter__(self): return self
            def __exit__(self, *_args): return False

        with patch.object(weekly_security_report.urllib.request, "urlopen", return_value=Response()) as request:
            weekly_security_report.post_slack("https://hooks.test", "report", "sa-weekly-key")
        self.assertEqual(request.call_args.args[0].get_header("Idempotency-key"), "sa-weekly-key")


if __name__ == "__main__":
    unittest.main()
