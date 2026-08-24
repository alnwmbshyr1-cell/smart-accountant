"""Reference implementation: FastAPI ingress + Redis Streams delivery worker.

Production requirements: TLS termination, secret manager, Redis ACL/TLS,
real schema validation, durable downstream delivery, and alerting on metrics.
"""
from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import os
import random
import time
import uuid
from dataclasses import dataclass
from typing import Any, Protocol

from fastapi import FastAPI, Header, HTTPException, Request
from redis.asyncio import Redis

try:
    from prometheus_client import Counter, Gauge, Histogram, make_asgi_app
except ImportError:  # Metrics are optional for the small local example.
    Counter = Gauge = Histogram = None

STREAM = os.getenv("SECURITY_STREAM", "security:webhook:events")
DLQ_STREAM = os.getenv("SECURITY_DLQ_STREAM", "security:webhook:dead-letter")
RETRY_ZSET = os.getenv("SECURITY_RETRY_ZSET", "security:webhook:retry-at")
GROUP = os.getenv("SECURITY_CONSUMER_GROUP", "security-delivery")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/15")
MAX_SKEW = int(os.getenv("WEBHOOK_MAX_SKEW_SECONDS", "300"))
IDEMPOTENCY_TTL = int(os.getenv("WEBHOOK_IDEMPOTENCY_TTL_SECONDS", "900"))
MAX_ATTEMPTS = int(os.getenv("WEBHOOK_MAX_ATTEMPTS", "5"))
CONSUMER = os.getenv("HOSTNAME", f"worker-{uuid.uuid4().hex[:8]}")

app = FastAPI(title="Smart Accountant Security Webhook")
if make_asgi_app:
    app.mount("/metrics", make_asgi_app())
redis_client = Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=3)

# Load these from a secret manager or mounted file, never from source control.
HMAC_KEYS: dict[str, bytes] = {
    key_id: value.encode()
    for key_id, value in {
        "current": os.getenv("WEBHOOK_HMAC_CURRENT", ""),
        "previous": os.getenv("WEBHOOK_HMAC_PREVIOUS", ""),
    }.items()
    if value
}

received = Counter("security_webhook_received_total", "Webhook requests received") if Counter else None
accepted = Counter("security_webhook_accepted_total", "Webhook events accepted") if Counter else None
rejected = Counter("security_webhook_rejected_total", "Webhook requests rejected", ["reason"]) if Counter else None
duplicates = Counter("security_webhook_duplicate_total", "Duplicate webhook deliveries") if Counter else None
conflicts = Counter("security_webhook_idempotency_conflict_total", "Idempotency conflicts") if Counter else None
delivery_attempts = Counter("security_webhook_delivery_attempts_total", "Delivery attempts", ["channel"]) if Counter else None
delivery_success = Counter("security_webhook_delivery_success_total", "Successful deliveries", ["channel"]) if Counter else None
delivery_failure = Counter("security_webhook_delivery_failure_total", "Failed deliveries", ["channel", "reason"]) if Counter else None
delivery_latency = Histogram("security_webhook_delivery_latency_seconds", "Delivery latency", ["channel"]) if Histogram else None
dlq_total = Counter("security_webhook_dead_letter_total", "Messages moved to DLQ", ["reason"]) if Counter else None
queue_depth = Gauge("security_webhook_queue_depth", "Approximate stream length") if Gauge else None


class PermanentDeliveryError(Exception):
    pass


class TransientDeliveryError(Exception):
    pass


class Notifier(Protocol):
    async def send(self, payload: dict[str, Any]) -> None: ...


class HttpNotifier:
    """Replace with an allow-listed HTTPS client; do not forward raw secrets."""

    def __init__(self, channel: str):
        self.channel = channel

    async def send(self, payload: dict[str, Any]) -> None:
        # Integrate an HTTP client here with connect/read timeouts and response
        # classification. This example intentionally avoids real side effects.
        raise TransientDeliveryError("configure a real notifier before production")


@dataclass(frozen=True)
class Settings:
    stream: str = STREAM
    dlq_stream: str = DLQ_STREAM
    retry_zset: str = RETRY_ZSET
    group: str = GROUP
    max_attempts: int = MAX_ATTEMPTS


def verify_hmac(raw: bytes, timestamp: str, signature: str, key_id: str) -> bool:
    key = HMAC_KEYS.get(key_id)
    if not key or not timestamp or not signature:
        return False
    try:
        if abs(int(time.time()) - int(timestamp)) > MAX_SKEW:
            return False
    except ValueError:
        return False
    expected = hmac.new(key, timestamp.encode() + b"." + raw, hashlib.sha256).hexdigest()
    provided = signature.removeprefix("sha256=")
    return hmac.compare_digest(expected, provided)


CLAIM_LUA = """
local old = redis.call('GET', KEYS[1])
if not old then
  redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[2], 'NX')
  return 1
end
if old == ARGV[1] then return 0 end
return -1
"""


async def claim_event(event_id: str, body_hash: str) -> int:
    return int(await redis_client.eval(CLAIM_LUA, 1, f"security:webhook:idem:{event_id}", body_hash, IDEMPOTENCY_TTL))


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    await redis_client.ping()
    return {"status": "ok"}


@app.post("/alertmanager")
async def receive_alert(
    request: Request,
    x_webhook_timestamp: str = Header(default=""),
    x_webhook_signature: str = Header(default=""),
    x_webhook_key_id: str = Header(default="current"),
    x_webhook_id: str = Header(default=""),
) -> dict[str, str]:
    raw = await request.body()
    if len(raw) == 0 or len(raw) > 65_536:
        if rejected: rejected.labels("body_size").inc()
        raise HTTPException(413, "invalid body size")
    if received: received.inc()
    if not verify_hmac(raw, x_webhook_timestamp, x_webhook_signature, x_webhook_key_id):
        if rejected: rejected.labels("signature_or_timestamp").inc()
        raise HTTPException(401, "invalid webhook authentication")
    try:
        payload = json.loads(raw)
        if not isinstance(payload, dict) or not isinstance(payload.get("alerts", []), list):
            raise ValueError
    except (json.JSONDecodeError, ValueError):
        if rejected: rejected.labels("schema").inc()
        raise HTTPException(400, "invalid Alertmanager payload")

    event_id = x_webhook_id or hashlib.sha256(raw).hexdigest()
    result = await claim_event(event_id, hashlib.sha256(raw).hexdigest())
    if result == -1:
        if conflicts: conflicts.inc()
        raise HTTPException(409, "idempotency key reused with different body")
    if result == 0:
        if duplicates: duplicates.inc()
        return {"status": "duplicate"}

    await redis_client.xadd(STREAM, {"event_id": event_id, "payload": json.dumps(payload, ensure_ascii=False), "attempts": "0", "channel": "security"})
    if accepted: accepted.inc()
    return {"status": "accepted", "event_id": event_id}


async def ensure_group(settings: Settings = Settings()) -> None:
    try:
        await redis_client.xgroup_create(settings.stream, settings.group, id="0", mkstream=True)
    except Exception as exc:
        if "BUSYGROUP" not in str(exc):
            raise


async def deliver(notifier: Notifier, payload: dict[str, Any], channel: str) -> None:
    started = time.perf_counter()
    if delivery_attempts: delivery_attempts.labels(channel).inc()
    try:
        await notifier.send(payload)
    except PermanentDeliveryError:
        if delivery_failure: delivery_failure.labels(channel, "permanent").inc()
        raise
    except Exception as exc:
        if delivery_failure: delivery_failure.labels(channel, "transient").inc()
        raise TransientDeliveryError(str(exc)) from exc
    finally:
        if delivery_latency: delivery_latency.labels(channel).observe(time.perf_counter() - started)
    if delivery_success: delivery_success.labels(channel).inc()


async def schedule_retry(settings: Settings, fields: dict[str, str], attempt: int, delay_seconds: float) -> None:
    """Put a serialized job in a score-by-due-time index; never sleep in a worker."""
    member = json.dumps({**fields, "attempts": str(attempt)}, ensure_ascii=False, sort_keys=True)
    await redis_client.zadd(settings.retry_zset, {member: time.time() + delay_seconds})


PROMOTE_DUE_LUA = """
local members = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, ARGV[2])
for _, member in ipairs(members) do
  if redis.call('ZREM', KEYS[1], member) == 1 then
    local obj = cjson.decode(member)
    redis.call('XADD', KEYS[2], '*', 'event_id', obj.event_id, 'payload', obj.payload, 'attempts', obj.attempts, 'channel', obj.channel)
  end
end
return #members
"""


async def promote_due_retries(settings: Settings, limit: int = 100) -> int:
    """Atomically claim due ZSET members and re-enqueue them to the Stream."""
    promoted = await redis_client.eval(PROMOTE_DUE_LUA, 2, settings.retry_zset, settings.stream, str(time.time()), str(limit))
    return int(promoted or 0)


async def move_to_dlq(settings: Settings, message_id: str, fields: dict[str, str], reason: str) -> None:
    fields = {**fields, "dead_letter_reason": reason, "dead_lettered_at": str(int(time.time()))}
    await redis_client.xadd(settings.dlq_stream, fields)
    await redis_client.xack(settings.stream, settings.group, message_id)
    if dlq_total: dlq_total.labels(reason).inc()


async def worker_loop(notifier: Notifier, settings: Settings = Settings()) -> None:
    await ensure_group(settings)
    while True:
        await promote_due_retries(settings)
        batches = await redis_client.xreadgroup(settings.group, CONSUMER, {settings.stream: ">"}, count=10, block=1_000)
        if not batches:
            continue
        for _, messages in batches:
            for message_id, fields in messages:
                attempts = int(fields.get("attempts", "0")) + 1
                try:
                    payload = json.loads(fields["payload"])
                    await deliver(notifier, payload, fields.get("channel", "security"))
                    await redis_client.xack(settings.stream, settings.group, message_id)
                except PermanentDeliveryError as exc:
                    await move_to_dlq(settings, message_id, {**fields, "attempts": str(attempts)}, f"permanent:{exc}")
                except TransientDeliveryError as exc:
                    if attempts >= settings.max_attempts:
                        await move_to_dlq(settings, message_id, {**fields, "attempts": str(attempts)}, f"retry_exhausted:{exc}")
                    else:
                        delay = min(300, 2 ** attempts + random.random())
                        await schedule_retry(settings, fields, attempts, delay)
                        await redis_client.xack(settings.stream, settings.group, message_id)
                except (KeyError, json.JSONDecodeError) as exc:
                    await move_to_dlq(settings, message_id, {**fields, "attempts": str(attempts)}, f"invalid_message:{exc}")
                if queue_depth:
                    queue_depth.set(await redis_client.xlen(settings.stream))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8090")))
