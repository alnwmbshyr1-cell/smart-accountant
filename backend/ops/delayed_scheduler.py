#!/usr/bin/env python3
"""Promote due retry jobs from a Redis Sorted Set into a Redis Stream.

Run as a separate process from delivery workers. The Lua script atomically
claims each due member, removes it from the ZSET, and appends it to the Stream.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import signal
import time
from typing import Any

from redis.asyncio import Redis

LOG = logging.getLogger("delayed-scheduler")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/15")
RETRY_ZSET = os.getenv("SECURITY_RETRY_ZSET", "security:webhook:retry-at")
STREAM = os.getenv("SECURITY_STREAM", "security:webhook:events")
BATCH_SIZE = int(os.getenv("SCHEDULER_BATCH_SIZE", "100"))
POLL_SECONDS = float(os.getenv("SCHEDULER_POLL_SECONDS", "0.5"))

PROMOTE_DUE_LUA = """
local members = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, ARGV[2])
local promoted = 0
for _, member in ipairs(members) do
  if redis.call('ZREM', KEYS[1], member) == 1 then
    local obj = cjson.decode(member)
    redis.call('XADD', KEYS[2], '*',
      'event_id', obj.event_id,
      'payload', obj.payload,
      'attempts', obj.attempts,
      'channel', obj.channel)
    promoted = promoted + 1
  end
end
return promoted
"""


async def promote_due(redis: Redis, *, now: float | None = None, limit: int = BATCH_SIZE) -> int:
    """Atomically move due jobs to the Stream and return the count moved."""
    result = await redis.eval(
        PROMOTE_DUE_LUA,
        2,
        RETRY_ZSET,
        STREAM,
        str(now if now is not None else time.time()),
        str(limit),
    )
    return int(result or 0)


async def scheduler(stop: asyncio.Event) -> None:
    redis = Redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=3)
    try:
        while not stop.is_set():
            try:
                moved = await promote_due(redis)
                if moved:
                    LOG.info("promoted_due_jobs=%s", moved)
            except Exception:
                # Redis outages should not kill the scheduler; retry next tick.
                LOG.exception("promotion_failed")
            try:
                await asyncio.wait_for(stop.wait(), timeout=POLL_SECONDS)
            except asyncio.TimeoutError:
                pass
    finally:
        await redis.aclose()


def main() -> None:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
    stop = asyncio.Event()
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop.set)
    try:
        loop.run_until_complete(scheduler(stop))
    finally:
        loop.close()


if __name__ == "__main__":
    main()
