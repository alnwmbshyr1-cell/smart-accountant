from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import os

STATE = Path(os.environ.get('ERROR_RATE_FILE', '/state/error_ratio'))
LATENCY_STATE = Path(os.environ.get('LATENCY_SECONDS_FILE', '/state/latency_seconds'))
COUNTER_TOTAL = 0
COUNTER_5XX = 0
HISTOGRAM = {"0.1": 0, "0.5": 0, "1.0": 0, "+Inf": 0}
ROUTE = '/v1/security/notify'


def ratio():
    try:
        value = float(STATE.read_text().strip())
        return max(0.0, min(value, 1.0))
    except (FileNotFoundError, ValueError):
        return 0.10


def latency_seconds():
    try:
        return max(0.0, float(LATENCY_STATE.read_text().strip()))
    except (FileNotFoundError, ValueError):
        return 0.1


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

        batch = 100
        errors = round(batch * ratio())
        COUNTER_TOTAL += batch
        COUNTER_5XX += errors
        observed = latency_seconds()
        for boundary in ('0.1', '0.5', '1.0', '+Inf'):
            if boundary == '+Inf' or observed <= float(boundary):
                HISTOGRAM[boundary] += batch

        body = (
            '# HELP smart_accountant_http_requests_total Total HTTP requests.\n'
            '# TYPE smart_accountant_http_requests_total counter\n'
            f'smart_accountant_http_requests_total{{job="smart-accountant-backend",status_code="200"}} {COUNTER_TOTAL - COUNTER_5XX}\n'
            f'smart_accountant_http_requests_total{{job="smart-accountant-backend",status_code="500"}} {COUNTER_5XX}\n'
            '# HELP smart_accountant_http_request_duration_seconds Request latency.\n'
            '# TYPE smart_accountant_http_request_duration_seconds histogram\n'
            + ''.join(
                f'smart_accountant_http_request_duration_seconds_bucket{{job="smart_accountant-backend",route="{ROUTE}",le="{boundary}"}} {HISTOGRAM[boundary]}\n'
                for boundary in ('0.1', '0.5', '1.0', '+Inf')
            )
            + f'smart_accountant_http_request_duration_seconds_sum{{job="smart_accountant-backend",route="{ROUTE}"}} {COUNTER_TOTAL * observed}\n'
            + f'smart_accountant_http_request_duration_seconds_count{{job="smart_accountant-backend",route="{ROUTE}"}} {COUNTER_TOTAL}\n'
        ).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; version=0.0.4')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


if __name__ == '__main__':
    HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
