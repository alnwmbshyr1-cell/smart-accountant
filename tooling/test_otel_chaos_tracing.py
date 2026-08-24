from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OTEL = ROOT / "backend/ops/otel_tracing.py"
K6 = ROOT / "tooling/k6/redis_stream_circuit_breaker.js"
COMPOSE = ROOT / "backend/ops/observability/docker-compose.jaeger.yml"


def test_otel_instrumentation_covers_fastapi_workers_and_redis_without_raw_payloads():
    source = OTEL.read_text(encoding="utf-8")
    assert "FastAPIInstrumentor.instrument_app" in source
    assert "redis_span" in source
    assert "traced_worker_call" in source
    assert "security.event_id_hash" in source
    assert "event_id_hash[:64]" in source
    assert "span.set_attribute(\"http.request.body\"" not in source
    assert "span.set_attribute(\"redis.key\"" not in source
    assert "span.set_attribute(\"redis.password\"" not in source


def test_chaos_load_requests_can_carry_bounded_experiment_id():
    source = K6.read_text(encoding="utf-8")
    assert "CHAOS_EXPERIMENT_ID" in source
    assert "X-Chaos-Experiment-Id" in source
    assert "scenario: 'redis_stream_circuit_breaker'" in source


def test_jaeger_is_local_only_in_compose():
    source = COMPOSE.read_text(encoding="utf-8")
    assert "jaegertracing/all-in-one" in source
    assert '127.0.0.1:4318:4318' in source
    assert '127.0.0.1:16686:16686' in source
