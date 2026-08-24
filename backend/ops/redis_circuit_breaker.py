"""Small Redis-backed Circuit Breaker for protecting external notifications/APIs."""
from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from typing import Awaitable, Callable, TypeVar

from redis.asyncio import Redis
from prometheus_client import Counter, Gauge, Histogram

T = TypeVar("T")


class CircuitOpenError(RuntimeError):
    """Raised when a call must fail fast because the dependency is unhealthy."""


@dataclass(frozen=True)
class CircuitConfig:
    failure_threshold: int = 5
    failure_window_seconds: int = 60
    open_cooldown_seconds: int = 30
    half_open_probe_ttl_seconds: int = 10


_STATE = Gauge("circuit_breaker_state", "Circuit state: 0=closed, 1=open, 2=half_open", ["dependency"])
_CALLS = Counter("circuit_breaker_calls_total", "Calls through the circuit", ["dependency", "result"])
_TRANSITIONS = Counter("circuit_breaker_transitions_total", "Circuit state transitions", ["dependency", "state"])
_FAILURES = Counter("circuit_breaker_failures_total", "Recorded dependency failures", ["dependency", "reason"])
_REJECTED = Counter("circuit_breaker_rejected_total", "Calls rejected while circuit is open", ["dependency"])
_LATENCY = Histogram("circuit_breaker_call_duration_seconds", "Protected call duration", ["dependency"])


class CircuitBreakerMetrics:
    """Facade over process-wide collectors; only dependency is a label."""

    def __init__(self, dependency: str):
        self.dependency = dependency
        self.state = _STATE
        self.calls = _CALLS
        self.transitions = _TRANSITIONS
        self.failures = _FAILURES
        self.rejected = _REJECTED
        self.latency = _LATENCY

    def set_state(self, state: str) -> None:
        values = {"closed": 0, "open": 1, "half_open": 2}
        self.state.labels(self.dependency).set(values[state])
        self.transitions.labels(self.dependency, state).inc()


RELEASE_PROBE_LUA = """
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
end
return 0
"""


class RedisCircuitBreaker:
    def __init__(self, redis: Redis, name: str, config: CircuitConfig = CircuitConfig(), metrics: CircuitBreakerMetrics | None = None):
        self.redis = redis
        self.config = config
        self.prefix = f"circuit:{name}"
        self.failures_key = f"{self.prefix}:failures"
        self.open_key = f"{self.prefix}:open-until"
        self.probe_key = f"{self.prefix}:half-open-probe"
        self.metrics = metrics
        if self.metrics:
            self.metrics.set_state("closed")

    async def before_call(self) -> str | None:
        now = int(time.time())
        open_until = await self.redis.get(self.open_key)
        if open_until and int(open_until) > now:
            if self.metrics:
                self.metrics.set_state("open")
                self.metrics.rejected.labels(self.metrics.dependency).inc()
                self.metrics.calls.labels(self.metrics.dependency, "rejected_open").inc()
            raise CircuitOpenError(f"circuit open until {open_until}")
        if open_until:
            token = uuid.uuid4().hex
            acquired = await self.redis.set(
                self.probe_key, token, nx=True, ex=self.config.half_open_probe_ttl_seconds
            )
            if not acquired:
                if self.metrics:
                    self.metrics.set_state("half_open")
                    self.metrics.rejected.labels(self.metrics.dependency).inc()
                    self.metrics.calls.labels(self.metrics.dependency, "rejected_probe_busy").inc()
                raise CircuitOpenError("half-open probe already running")
            if self.metrics:
                self.metrics.set_state("half_open")
                self.metrics.calls.labels(self.metrics.dependency, "half_open_probe").inc()
            return token
        return None

    async def record_success(self, probe_token: str | None = None) -> None:
        await self.redis.delete(self.failures_key, self.open_key)
        if self.metrics:
            self.metrics.set_state("closed")
            self.metrics.calls.labels(self.metrics.dependency, "success").inc()
        if probe_token:
            await self.redis.eval(RELEASE_PROBE_LUA, 1, self.probe_key, probe_token)

    async def record_failure(self, probe_token: str | None = None) -> int:
        failures = int(await self.redis.incr(self.failures_key))
        if self.metrics:
            self.metrics.failures.labels(self.metrics.dependency, "dependency_error").inc()
            self.metrics.calls.labels(self.metrics.dependency, "failure").inc()
        await self.redis.expire(self.failures_key, self.config.failure_window_seconds)
        if failures >= self.config.failure_threshold:
            now = int(time.time())
            await self.redis.set(
                self.open_key,
                str(now + self.config.open_cooldown_seconds),
                # Keep the marker past cooldown so before_call can grant one half-open probe.
                ex=self.config.open_cooldown_seconds + 60,
            )
            if self.metrics:
                self.metrics.set_state("open")
        if probe_token:
            await self.redis.eval(RELEASE_PROBE_LUA, 1, self.probe_key, probe_token)
        return failures

    async def call(self, operation: Callable[[], Awaitable[T]]) -> T:
        started = time.perf_counter()
        probe = await self.before_call()
        try:
            result = await operation()
        except Exception:
            await self.record_failure(probe)
            raise
        await self.record_success(probe)
        if self.metrics:
            self.metrics.latency.labels(self.metrics.dependency).observe(time.perf_counter() - started)
        return result
