#!/usr/bin/env python3
"""Small authenticated Redis-backed idempotency gateway for security alerts.

It accepts only bounded, redacted summaries. Redis state is claimed atomically with
SET NX and a TTL before optional forwarding to Slack/email. A failed forward releases
the claim so a later retry can deliver the alert.
"""
from __future__ import annotations

import json
import os
import re
import secrets
import ssl
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Mapping, Protocol

KEY_RE = re.compile(r"^sa-[0-9a-f]{32}$")
MAX_BODY_BYTES = 32 * 1024
MAX_FINDINGS = 10
DEFAULT_TTL_SECONDS = 86400


class RedisLike(Protocol):
    def set(self, name: str, value: str, *, nx: bool, ex: int) -> bool | None: ...
    def get(self, name: str) -> str | None: ...
    def delete(self, name: str) -> int: ...
    def expire(self, name: str, time: int) -> bool: ...


def validate_payload(payload: Any, idempotency_header: str | None) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("JSON body must be an object")
    key = payload.get("idempotency_key")
    if not isinstance(key, str) or not KEY_RE.fullmatch(key):
        raise ValueError("invalid idempotency_key")
    if idempotency_header and idempotency_header != key:
        raise ValueError("Idempotency-Key header does not match body")
    if payload.get("event") != "critical_security_findings":
        raise ValueError("unsupported event")
    total = payload.get("total_critical")
    if not isinstance(total, int) or total < 1:
        raise ValueError("total_critical must be a positive integer")
    findings = payload.get("findings")
    if not isinstance(findings, list) or len(findings) > MAX_FINDINGS:
        raise ValueError("findings must be a bounded array")
    safe_findings = []
    for item in findings:
        if not isinstance(item, dict):
            raise ValueError("finding must be an object")
        safe_findings.append({
            "source": str(item.get("source", ""))[:80],
            "rule_id": str(item.get("rule_id", ""))[:120],
            "location": str(item.get("location", ""))[:240],
        })
    return {
        "event": payload["event"],
        "idempotency_key": key,
        "title": str(payload.get("title", "Smart Accountant security alert"))[:160],
        "total_critical": total,
        "shown": len(safe_findings),
        "findings": safe_findings,
        "workflow_url": str(payload.get("workflow_url", ""))[:500],
    }


def claim(redis: RedisLike, key: str, owner: str, ttl_seconds: int) -> bool:
    return bool(redis.set(f"security-alert:{key}", owner, nx=True, ex=ttl_seconds))


def release_if_owner(redis: RedisLike, key: str, owner: str) -> None:
    redis_key = f"security-alert:{key}"
    if redis.get(redis_key) == owner:
        redis.delete(redis_key)


def send_json(url: str, payload: dict[str, Any], headers: Mapping[str, str] | None = None, timeout: float = 10.0) -> None:
    request_headers = {"Content-Type": "application/json", "User-Agent": "smart-accountant-security-gateway/1"}
    request_headers.update(headers or {})
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=request_headers,
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        if not 200 <= response.status < 300:
            raise RuntimeError(f"forward returned HTTP {response.status}")


def forward(payload: dict[str, Any], env: Mapping[str, str]) -> None:
    key = payload["idempotency_key"]
    slack = env.get("FORWARD_SLACK_WEBHOOK_URL", "")
    if slack:
        text = [f"*{payload['title']}*", f"Critical findings: `{payload['total_critical']}`"]
        text.extend(f"• `{item['source']}` `{item['rule_id']}` at `{item['location']}`" for item in payload["findings"])
        if payload["workflow_url"]:
            text.append(payload["workflow_url"])
        send_json(slack, {"text": "\n".join(text)}, {"Idempotency-Key": key})
    email_url = env.get("FORWARD_EMAIL_WEBHOOK_URL", "")
    email_token = env.get("FORWARD_EMAIL_WEBHOOK_TOKEN", "")
    if email_url and email_token:
        send_json(
            email_url,
            {"subject": payload["title"], "text": json.dumps(payload, ensure_ascii=False)},
            {"Authorization": f"Bearer {email_token}", "Idempotency-Key": key},
        )


class GatewayHandler(BaseHTTPRequestHandler):
    redis: RedisLike
    env: Mapping[str, str]

    def _json(self, status: int, body: dict[str, Any]) -> None:
        encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self) -> None:
        if self.path != "/v1/security/notify":
            self._json(404, {"error": "not_found"})
            return
        expected = self.env.get("GATEWAY_INGRESS_TOKEN", "")
        if expected and self.headers.get("Authorization") != f"Bearer {expected}":
            self._json(401, {"error": "unauthorized"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 1 or length > MAX_BODY_BYTES:
                raise ValueError("body too large or empty")
            payload = validate_payload(json.loads(self.rfile.read(length)), self.headers.get("Idempotency-Key"))
        except (ValueError, json.JSONDecodeError):
            self._json(400, {"error": "invalid_request"})
            return
        key = payload["idempotency_key"]
        owner = secrets.token_hex(16)
        ttl = int(self.env.get("IDEMPOTENCY_TTL_SECONDS", str(DEFAULT_TTL_SECONDS)))
        if not claim(self.redis, key, owner, ttl):
            self._json(200, {"accepted": True, "duplicate": True, "idempotency_key": key})
            return
        try:
            forward(payload, self.env)
        except (OSError, urllib.error.URLError, RuntimeError):
            release_if_owner(self.redis, key, owner)
            self._json(502, {"error": "forward_failed", "idempotency_key": key})
            return
        self.redis.delete(f"security-alert:{key}")
        self.redis.set(f"security-alert:{key}", "delivered", nx=False, ex=ttl)
        self._json(202, {"accepted": True, "duplicate": False, "idempotency_key": key})

    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._json(200, {"ok": True})
        else:
            self._json(404, {"error": "not_found"})

    def log_message(self, *_args: Any) -> None:
        return


def create_server(host: str, port: int, redis: RedisLike, env: Mapping[str, str] | None = None) -> ThreadingHTTPServer:
    settings = os.environ if env is None else env
    handler = type("ConfiguredGatewayHandler", (GatewayHandler,), {"redis": redis, "env": settings})
    return ThreadingHTTPServer((host, port), handler)


def redis_client(redis_module: Any, env: Mapping[str, str]) -> Any:
    url = env.get("REDIS_URL", "redis://127.0.0.1:6379/0")
    use_tls = url.startswith("rediss://") or env.get("REDIS_TLS", "false").lower() == "true"
    cert_file = env.get("REDIS_CLIENT_CERT_FILE", "")
    key_file = env.get("REDIS_CLIENT_KEY_FILE", "")
    ca_file = env.get("REDIS_CA_FILE", "")
    if use_tls and (not ca_file or not os.path.isfile(ca_file)):
        raise SystemExit("REDIS_CA_FILE is required and must exist when Redis TLS is enabled")
    if bool(cert_file) != bool(key_file):
        raise SystemExit("REDIS_CLIENT_CERT_FILE and REDIS_CLIENT_KEY_FILE must be supplied together")
    options: dict[str, Any] = {"decode_responses": True}
    if use_tls:
        options.update({
            "ssl": True,
            "ssl_ca_certs": ca_file,
            "ssl_check_hostname": env.get("REDIS_SSL_CHECK_HOSTNAME", "true").lower() == "true",
        })
        if cert_file and key_file:
            options.update({"ssl_certfile": cert_file, "ssl_keyfile": key_file})
    if env.get("REDIS_USERNAME"):
        options["username"] = env["REDIS_USERNAME"]
    if env.get("REDIS_PASSWORD"):
        options["password"] = env["REDIS_PASSWORD"]
    return redis_module.Redis.from_url(url, **options)


def main() -> int:
    try:
        import redis  # type: ignore
    except ImportError as exc:
        raise SystemExit("Install requirements-gateway.txt before starting the gateway") from exc
    env = os.environ
    client = redis_client(redis, env)
    client.ping()
    server = create_server(env.get("GATEWAY_HOST", "0.0.0.0"), int(env.get("GATEWAY_PORT", "8443")), client, env)
    cert = env.get("TLS_CERT_FILE")
    key = env.get("TLS_KEY_FILE")
    if not cert or not key:
        raise SystemExit("TLS_CERT_FILE and TLS_KEY_FILE are required")
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(certfile=cert, keyfile=key)
    if env.get("TLS_REQUIRE_CLIENT_CERT", "false").lower() == "true":
        client_ca = env.get("TLS_CLIENT_CA_FILE")
        if not client_ca or not os.path.isfile(client_ca):
            raise SystemExit("TLS_CLIENT_CA_FILE is required when TLS_REQUIRE_CLIENT_CERT=true")
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_verify_locations(cafile=client_ca)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print("security gateway listening", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
