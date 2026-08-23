from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import os

STATE = Path(os.environ.get('ERROR_RATE_FILE', '/state/error_ratio'))
COUNTER_TOTAL = 0
COUNTER_5XX = 0


def ratio():
    try:
        value = float(STATE.read_text().strip())
        return max(0.0, min(value, 1.0))
    except (FileNotFoundError, ValueError):
        return 0.10


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        global COUNTER_TOTAL, COUNTER_5XX
        if self.path == '/healthz':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok\n')
            return
        if self.path != '/metrics':
            self.send_response(404)
            self.end_headers()
            return

        # Add a fixed amount per scrape so Prometheus observes a stable ratio.
        batch = 100
        errors = round(batch * ratio())
        COUNTER_TOTAL += batch
        COUNTER_5XX += errors
        body = (
            '# HELP smart_accountant_http_requests_total Total HTTP requests.\n'
            '# TYPE smart_accountant_http_requests_total counter\n'
            f'smart_accountant_http_requests_total{{job="smart-accountant-backend",status_code="200"}} {COUNTER_TOTAL - COUNTER_5XX}\n'
            f'smart_accountant_http_requests_total{{job="smart-accountant-backend",status_code="500"}} {COUNTER_5XX}\n'
        ).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; version=0.0.4')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
