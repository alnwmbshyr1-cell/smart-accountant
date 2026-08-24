from http.server import BaseHTTPRequestHandler, HTTPServer
import os

TEST_ID = os.getenv("TEST_ID", "local-alert-test")
# Start below threshold; set ALERT_LAB_HIGH=1 to trigger p95 and deadlock alerts.
HIGH = os.getenv("ALERT_LAB_HIGH", "0") == "1"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404); self.end_headers(); return
        body = []
        # A compact histogram with all mass in the 1s bucket yields p95 ~= 1s.
        buckets = [
            ("0.1", 0 if HIGH else 100),
            ("0.5", 0 if HIGH else 100),
            ("0.75", 0 if HIGH else 100),
            ("1", 100),
            ("+Inf", 100),
        ]
        for le, value in buckets:
            body.append(f'k6_http_req_duration_seconds_bucket{{testid="{TEST_ID}",le="{le}"}} {value}')
        body.append(f'k6_http_reqs_total{{testid="{TEST_ID}"}} {100 if HIGH else 1}')
        body.append(f'smart_accountant_db_deadlocks_total {3 if HIGH else 0}')
        body.append(f'smart_accountant_staging_test_failures_total{{test="payment-idempotency",environment="staging"}} {1 if HIGH else 0}')
        data = ("\n".join(body) + "\n").encode()
        self.send_response(200); self.send_header("Content-Type", "text/plain; version=0.0.4"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self, *_args):
        return

HTTPServer(("0.0.0.0", 9100), Handler).serve_forever()
