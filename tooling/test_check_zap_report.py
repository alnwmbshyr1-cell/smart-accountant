import json
import tempfile
import unittest
from pathlib import Path

from check_zap_report import main


class ZapReportGateTests(unittest.TestCase):
    def write_report(self, alerts):
        handle = tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8")
        with handle:
            json.dump({"site": [{"alerts": alerts}]}, handle)
        return Path(handle.name)

    def test_low_risk_report_passes(self):
        path = self.write_report([{"name": "Informational", "risk": "Informational", "instances": [{}]}])
        try:
            self.assertEqual(main(str(path)), 0)
        finally:
            path.unlink()

    def test_high_risk_report_blocks(self):
        path = self.write_report([{"name": "Missing security header", "risk": "High", "instances": [{}, {}]}])
        try:
            self.assertEqual(main(str(path)), 1)
        finally:
            path.unlink()


if __name__ == "__main__":
    unittest.main()
