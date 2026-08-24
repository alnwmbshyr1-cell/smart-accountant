import asyncio
import sys
from pathlib import Path
from unittest.mock import AsyncMock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend" / "ops"))

import pytest
import pytest_asyncio
from prometheus_client import generate_latest

fakeredis = pytest.importorskip("fakeredis.aioredis")
from redis_circuit_breaker import CircuitConfig, CircuitOpenError, RedisCircuitBreaker


@pytest_asyncio.fixture
async def redis():
    client = fakeredis.FakeRedis(decode_responses=True)
    yield client
    await client.aclose()


@pytest.mark.asyncio
async def test_opens_after_threshold_and_fails_fast(redis):
    breaker = RedisCircuitBreaker(redis, "slack", CircuitConfig(failure_threshold=2, open_cooldown_seconds=30))
    for _ in range(2):
        await breaker.record_failure()
    with pytest.raises(CircuitOpenError):
        await breaker.before_call()


@pytest.mark.asyncio
async def test_half_open_allows_one_probe(redis):
    breaker = RedisCircuitBreaker(redis, "slack", CircuitConfig(failure_threshold=2, open_cooldown_seconds=1, half_open_probe_ttl_seconds=10))
    await breaker.record_failure()
    await breaker.record_failure()
    await asyncio.sleep(1.1)
    token = await breaker.before_call()
    assert token
    with pytest.raises(CircuitOpenError):
        await breaker.before_call()
    redis.eval = AsyncMock(return_value=1)
    await breaker.record_success(token)
    assert await redis.get(breaker.open_key) is None


def test_metrics_use_bounded_dependency_label():
    from redis_circuit_breaker import CircuitBreakerMetrics

    first = CircuitBreakerMetrics("slack-security")
    second = CircuitBreakerMetrics("slack-security")
    first.set_state("open")
    second.rejected.labels("slack-security").inc()
    output = generate_latest().decode()
    assert "circuit_breaker_state" in output
    assert 'dependency="slack-security"' in output
    assert "event_id" not in output


@pytest.mark.asyncio
async def test_call_records_success_and_failure(redis):
    breaker = RedisCircuitBreaker(redis, "mail", CircuitConfig(failure_threshold=2))
    assert await breaker.call(lambda: asyncio.sleep(0, result="ok")) == "ok"

    async def fail():
        raise TimeoutError("downstream timeout")

    with pytest.raises(TimeoutError):
        await breaker.call(fail)
    assert await redis.get(breaker.failures_key) == "1"
