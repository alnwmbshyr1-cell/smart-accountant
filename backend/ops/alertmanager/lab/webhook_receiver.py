from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from datetime import datetime, timezone
import json

OUT = Path('/received')
OUT.mkdir(parents=True, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/alertmanager':
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get('Content-Length', '0'))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw)
            safe = {
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
                ],
            }
        except (json.JSONDecodeError, TypeError):
            self.send_response(400)
            self.end_headers()
            return
        name = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        (OUT / f'{name}.json').write_text(json.dumps(safe, ensure_ascii=False, indent=2))
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


HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
