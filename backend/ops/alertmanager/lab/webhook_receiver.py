from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from datetime import datetime, timezone
import json
import os
import re

OUT = Path(os.environ.get('RECEIVED_DIR', '/received'))

_SECRET_PATTERNS = (
    re.compile(r'(?i)(bearer\s+)[^\s,;]+'),
    re.compile(r'(?i)((?:token|api[_-]?key|secret|password|authorization|cookie)\s*[:=]\s*)[^\s,;]+'),
    re.compile(r'(?i)(https?://[^\s?]+\?[^\s]*)(?:token|key|secret|password)=[^&\s]+'),
)
_SENSITIVE_KEYS = re.compile(r'(?i)(authorization|cookie|token|api[_-]?key|secret|password|client[_-]?key)')


def redact(value):
    """Return JSON-safe data with secret-looking keys and values redacted."""
    if isinstance(value, dict):
        return {
            str(key): '[REDACTED]' if _SENSITIVE_KEYS.search(str(key)) else redact(item)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str):
        result = value
        for pattern in _SECRET_PATTERNS:
            result = pattern.sub(lambda match: f'{match.group(1)}[REDACTED]', result)
        return result
    return value


def build_safe_payload(payload):
    """Keep only the Alertmanager fields needed for assertions and operations."""
    if not isinstance(payload, dict):
        raise TypeError('payload must be an object')
    return redact({
        'status': payload.get('status'),
        'receiver': payload.get('receiver'),
        'groupLabels': payload.get('groupLabels', {}),
        'commonLabels': payload.get('commonLabels', {}),
        'alerts': [
            {
                'status': alert.get('status'),
                'labels': alert.get('labels', {}),
                'annotations': alert.get('annotations', {}),
            }
            for alert in payload.get('alerts', [])
            if isinstance(alert, dict)
        ],
    })


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/alertmanager':
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get('Content-Length', '0'))
        raw = self.rfile.read(length)
        try:
            safe = build_safe_payload(json.loads(raw))
        except (json.JSONDecodeError, TypeError):
            self.send_response(400)
            self.end_headers()
            return
        OUT.mkdir(parents=True, exist_ok=True)
        name = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        (OUT / f'{name}.json').write_text(
            json.dumps(safe, ensure_ascii=False, indent=2),
            encoding='utf-8',
        )
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"accepted":true}\n')

    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok\n')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *_args):
        return


if __name__ == '__main__':
    HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
