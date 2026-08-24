import hashlib
import hmac
import json
import time

import pytest

fakeredis = pytest.importorskip("fakeredis.aioredis")
worker = pytest.importorskip("backend.ops.security_webhook_worker")


@pytest.fixture
def secret(monkeypatch):
    key = b"test-secret"
    monkeypatch.setitem(worker.HMAC_KEYS, "test", key)
    return key


@pytest.mark.asyncio
async def test_sorted_set_retry_is_due_and_promoted(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(worker, "redis_client", fake)
    settings = worker.Settings(stream="events:test", retry_zset="retry:test", group="group:test")
    fields = {"event_id": "evt-1", "payload": json.dumps({"alerts": []}), "channel": "security"}

    await worker.schedule_retry(settings, fields, attempt=2, delay_seconds=0)
    assert await fake.zcard(settings.retry_zset) == 1
    assert await worker.promote_due_retries(settings, limit=10) == 1
    assert await fake.zcard(settings.retry_zset) == 0
    entries = await fake.xrange(settings.stream)
    assert len(entries) == 1
    assert entries[0][1]["attempts"] == "2"


@pytest.mark.asyncio
async def test_retry_does_not_block_other_messages(monkeypatch):
    fake = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(worker, "redis_client", fake)
    settings = worker.Settings(stream="events:test", retry_zset="retry:test", group="group:test")
    first = {"event_id": "evt-1", "payload": json.dumps({"alerts": []}), "attempts": "1", "channel": "security"}
    second = {"event_id": "evt-2", "payload": json.dumps({"alerts": []}), "attempts": "1", "channel": "security"}
    await worker.schedule_retry(settings, first, attempt=2, delay_seconds=60)
    await fake.xadd(settings.stream, second)
    assert await fake.zcard(settings.retry_zset) == 1
    assert len(await fake.xrange(settings.stream)) == 1


def test_hmac_accepts_current_and_rejects_stale_or_tampered(monkeypatch, secret):
    raw = b'{"status":"firing","alerts":[]}'
    timestamp = str(int(time.time()))
    signature = hmac.new(secret, timestamp.encode() + b"." + raw, hashlib.sha256).hexdigest()
    assert worker.verify_hmac(raw, timestamp, signature, "test")
    assert not worker.verify_hmac(raw + b" ", timestamp, signature, "test")
    assert not worker.verify_hmac(raw, str(int(time.time()) - 3600), signature, "test")
