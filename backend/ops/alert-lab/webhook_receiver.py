from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json
import os
import re

OUT = Path(os.environ.get("ALERT_LAB_EVENTS_PATH", "/data/events.jsonl"))
SECRET_RE = re.compile(r"(?i)(bearer\s+|token|api[_-]?key|secret|password|webhook)[^\s,;]*")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = min(int(self.headers.get("Content-Length", "0")), 65536)
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            self.send_response(400); self.end_headers(); return
        safe = json.loads(SECRET_RE.sub("[REDACTED]", json.dumps(payload, ensure_ascii=False)))
        OUT.parent.mkdir(parents=True, exist_ok=True)
        with OUT.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(safe, ensure_ascii=False, sort_keys=True) + "\n")
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok"); return
        self.send_response(404); self.end_headers()
    def log_message(self, *_args):
        return

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
