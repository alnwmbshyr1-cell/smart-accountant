import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend/ops/alertmanager/lab'))
import webhook_receiver


class WebhookReceiverSecurityTests(unittest.TestCase):
    def test_allowlist_drops_raw_alertmanager_fields(self):
        safe = webhook_receiver.build_safe_payload({
            'status': 'firing',
            'receiver': 'local-webhook',
            'generatorURL': 'https://prometheus/internal?token=never-share',
            'alerts': [{
                'status': 'firing',
                'labels': {'alertname': 'HighP99', 'route': '/v1/security/notify'},
                'annotations': {'summary': 'Latency high'},
                'fingerprint': 'private-fingerprint',
            }],
        })
        serialized = json.dumps(safe)
        self.assertNotIn('generatorURL', serialized)
        self.assertNotIn('fingerprint', serialized)
        self.assertIn('HighP99', serialized)

    def test_redacts_authorization_cookie_and_token_values(self):
        safe = webhook_receiver.build_safe_payload({
            'status': 'firing',
            'commonLabels': {'authorization': 'Bearer live-token'},
            'alerts': [{
                'status': 'firing',
                'labels': {'route': '/notify'},
                'annotations': {
                    'description': 'Authorization: Bearer abc123 Cookie: session=xyz',
                    'debug_token': 'secret-value',
                    'safe': 'normal operational text',
                },
            }],
        })
        serialized = json.dumps(safe)
        self.assertNotIn('live-token', serialized)
        self.assertNotIn('abc123', serialized)
        self.assertNotIn('session=xyz', serialized)
        self.assertNotIn('secret-value', serialized)
        self.assertIn('[REDACTED]', serialized)
        self.assertIn('normal operational text', serialized)

    def test_rejects_non_object_payload(self):
        with self.assertRaises(TypeError):
            webhook_receiver.build_safe_payload(['not', 'an', 'object'])

    def test_ignores_non_object_alert_entries(self):
        safe = webhook_receiver.build_safe_payload({
            'status': 'resolved',
            'alerts': [None, 'raw text', {'status': 'resolved', 'labels': {}}],
        })
        self.assertEqual(len(safe['alerts']), 1)


if __name__ == '__main__':
    unittest.main()
