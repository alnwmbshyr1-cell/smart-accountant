#!/usr/bin/env python3
"""Safe Redis integration checks for idempotency and lock fencing.

Run only against an isolated test Redis instance. The script creates a unique
namespace and uses synthetic effects; it never touches payment production data.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

import redis


PREFIX = f"it:idempotency:{os.getenv('TEST_ID', uuid.uuid4().hex)}"
LOCK_TTL = 2


def key(name: str) -> str:
    return f"{PREFIX}:{name}"


def request_hash(body: dict) -> str:
    encoded = json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def connect() -> redis.Redis:
    url = os.getenv("REDIS_URL", "redis://127.0.0.1:6379/15")
    client = redis.Redis.from_url(url, decode_responses=True, socket_timeout=3)
    client.ping()
    return client


def claim(client: redis.Redis, idem_key: str, body_hash: str, owner: str, ttl: int = LOCK_TTL) -> str:
    record = json.dumps({"hash": body_hash, "owner": owner}, separators=(",", ":"))
    if client.set(key(f"claim:{idem_key}"), record, nx=True, ex=ttl):
        return "CLAIMED"
    current = client.get(key(f"claim:{idem_key}"))
    if not current:
        return "RETRY"
    saved = json.loads(current)
    return "DUPLICATE" if saved["hash"] == body_hash else "KEY_REUSE"


def finalize(client: redis.Redis, idem_key: str, owner: str, result: str) -> int:
    script = client.register_script(
        """
        local current = redis.call('GET', KEYS[1])
        if current ~= ARGV[1] then return 0 end
        redis.call('INCR', KEYS[2])
        redis.call('SET', KEYS[3], ARGV[2], 'EX', ARGV[3])
        redis.call('DEL', KEYS[1])
        return 1
        """
    )
    return int(
        script(
            keys=[key(f"claim:{idem_key}"), key(f"effects:{idem_key}"), key(f"result:{idem_key}")],
            args=[json.dumps({"hash": request_hash({"amount": 1}), "owner": owner}, separators=(",", ":")), result, 300],
        )
    )


def finalize_with_hash(client: redis.Redis, idem_key: str, owner: str, body_hash: str, result: str) -> int:
    script = client.register_script(
        """
        local current = redis.call('GET', KEYS[1])
        if not current then return 0 end
        local expected = '{"hash":"' .. ARGV[1] .. '","owner":"' .. ARGV[2] .. '"}'
        if current ~= expected then return 0 end
        redis.call('INCR', KEYS[2])
        redis.call('SET', KEYS[3], ARGV[3], 'EX', ARGV[4])
        redis.call('DEL', KEYS[1])
        return 1
        """
    )
    return int(
        script(
            keys=[key(f"claim:{idem_key}"), key(f"effects:{idem_key}"), key(f"result:{idem_key}")],
            args=[body_hash, owner, result, 300],
        )
    )


def clean(client: redis.Redis) -> None:
    cursor = 0
    while True:
        cursor, keys = client.scan(cursor=cursor, match=f"{PREFIX}:*")
        if keys:
            client.delete(*keys)
        if cursor == 0:
            return


def main() -> int:
    client = connect()
    clean(client)
    body = {"amount": 1, "currency": "TEST", "reference": PREFIX}
    body_hash = request_hash(body)
    idem_key = "same-payment"
    winners = []
    barrier = threading.Barrier(12)

    def contender(index: int) -> str:
        local = connect()
        barrier.wait(timeout=5)
        owner = f"owner-{index}"
        outcome = claim(local, idem_key, body_hash, owner)
        if outcome == "CLAIMED":
            winners.append(owner)
        return outcome

    with ThreadPoolExecutor(max_workers=12) as pool:
        outcomes = list(pool.map(contender, range(12)))

    assert outcomes.count("CLAIMED") == 1, outcomes
    assert outcomes.count("DUPLICATE") == 11, outcomes
    assert len(winners) == 1

    reuse = claim(client, idem_key, request_hash({"amount": 2, "currency": "TEST", "reference": PREFIX}), "attacker")
    assert reuse == "KEY_REUSE", reuse

    # Simulate one owner expiring; a new owner may claim, while the old owner
    # must be fenced out and must not create a second financial effect.
    expiring_key = "expiring-payment"
    old_owner = "old-owner"
    new_owner = "new-owner"
    assert claim(client, expiring_key, body_hash, old_owner, ttl=1) == "CLAIMED"
    time.sleep(1.2)
    assert claim(client, expiring_key, body_hash, new_owner, ttl=LOCK_TTL) == "CLAIMED"
    assert finalize_with_hash(client, expiring_key, old_owner, body_hash, "old-result") == 0
    assert finalize_with_hash(client, expiring_key, new_owner, body_hash, "new-result") == 1
    assert client.get(key(f"effects:{expiring_key}")) == "1"
    assert client.get(key(f"result:{expiring_key}")) == "new-result"

    assert client.get(key(f"effects:{idem_key}")) in (None, "0")
    clean(client)
    print(json.dumps({"status": "PASS", "namespace": PREFIX, "concurrent_claims": 12, "financial_effects": 1}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 - CI must show a concise failure.
        print(json.dumps({"status": "FAIL", "error": str(exc)}), file=sys.stderr)
        raise
