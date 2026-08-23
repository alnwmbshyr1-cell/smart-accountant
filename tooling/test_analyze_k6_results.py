#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze_k6_results


class AnalyzeK6ResultsTests(unittest.TestCase):
    def sample(self):
        return {
            "metrics": {
                "http_reqs": {"values": {"count": 1000, "rate": 1000.0}},
                "http_req_failed": {"values": {"rate": 0.002}},
                "checks": {"values": {"rate": 0.998}},
                "http_req_duration": {"values": {"avg": 42, "med": 31, "p(90)": 70, "p(95)": 120, "p(99)": 240, "max": 600}},
            }
        }

    def test_analyze_extracts_rate_failures_checks_and_latency(self):
        result = analyze_k6_results.analyze(self.sample())
        self.assertEqual(result["requests"], 1000)
        self.assertEqual(result["request_rate_rps"], 1000.0)
        self.assertEqual(result["failed_rate"], 0.002)
        self.assertEqual(result["checks_rate"], 0.998)
        self.assertEqual(result["latency_ms"]["p(95)"], 120.0)

    def test_threshold_status_fails_when_p95_or_error_rate_exceeds_starting_gate(self):
        result = analyze_k6_results.analyze(self.sample())
        self.assertEqual(analyze_k6_results.threshold_status(result), "PASS")
        result["latency_ms"]["p(95)"] = 501
        self.assertEqual(analyze_k6_results.threshold_status(result), "FAIL")

    def test_analyze_handles_missing_metrics_without_fabricating_values(self):
        result = analyze_k6_results.analyze({"metrics": {}})
        self.assertEqual(result["requests"], 0)
        self.assertIsNone(result["request_rate_rps"])
        self.assertEqual(result["latency_ms"], {})
        self.assertEqual(analyze_k6_results.threshold_status(result), "PASS")


if __name__ == "__main__":
    unittest.main()
