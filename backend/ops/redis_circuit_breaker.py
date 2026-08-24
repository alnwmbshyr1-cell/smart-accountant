"""Small Redis-backed Circuit Breaker for protecting external notifications/APIs."""
from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from typing import Awaitable, Callable, TypeVar

from redis.asyncio import Redis

T = TypeVar("T")


class CircuitOpenError(RuntimeError):
    """Raised when a call must fail fast because the dependency is unhealthy."""


@dataclass(frozen=True)
class CircuitConfig:
    failure_threshold: int = 5
    failure_window_seconds: int = 60
    open_cooldown_seconds: int = 30
    half_open_probe_ttl_seconds: int = 10


RELEASE_PROBE_LUA = """
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
end
return 0
"""


class RedisCircuitBreaker:
    def __init__(self, redis: Redis, name: str, config: CircuitConfig = CircuitConfig()):
        self.redis = redis
        self.config = config
        self.prefix = f"circuit:{name}"
        self.failures_key = f"{self.prefix}:failures"
        self.open_key = f"{self.prefix}:open-until"
        self.probe_key = f"{self.prefix}:half-open-probe"

    async def before_call(self) -> str | None:
        now = int(time.time())
        open_until = await self.redis.get(self.open_key)
        if open_until and int(open_until) > now:
            raise CircuitOpenError(f"circuit open until {open_until}")
        if open_until:
            token = uuid.uuid4().hex
            acquired = await self.redis.set(
                self.probe_key, token, nx=True, ex=self.config.half_open_probe_ttl_seconds
            )
            if not acquired:
                raise CircuitOpenError("half-open probe already running")
            return token
        return None

    async def record_success(self, probe_token: str | None = None) -> None:
        await self.redis.delete(self.failures_key, self.open_key)
        if probe_token:
            await self.redis.eval(RELEASE_PROBE_LUA, 1, self.probe_key, probe_token)

    async def record_failure(self, probe_token: str | None = None) -> int:
        failures = int(await self.redis.incr(self.failures_key))
        await self.redis.expire(self.failures_key, self.config.failure_window_seconds)
        if failures >= self.config.failure_threshold:
            now = int(time.time())
            await self.redis.set(
                self.open_key,
                str(now + self.config.open_cooldown_seconds),
                # Keep the marker past cooldown so before_call can grant one half-open probe.
                ex=self.config.open_cooldown_seconds + 60,
            )
        if probe_token:
            await self.redis.eval(RELEASE_PROBE_LUA, 1, self.probe_key, probe_token)
        return failures

    async def call(self, operation: Callable[[], Awaitable[T]]) -> T:
        probe = await self.before_call()
        try:
            result = await operation()
        except Exception:
            await self.record_failure(probe)
            raise
        await self.record_success(probe)
        return result
