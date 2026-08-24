from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "tooling/k6/redis_stream_circuit_breaker.js"


def test_k6_scenario_is_guarded_and_signed():
    source = SCRIPT.read_text(encoding="utf-8")
    assert "constant-arrival-rate" in source
    assert "ALLOW_NON_LOCAL_LOAD_TEST" in source
    assert "crypto.hmac('sha256'" in source
    assert "http_req_duration" in source
    assert "webhook_error_rate" in source
    assert "load-test-dependency" in source


def test_k6_scenario_does_not_target_production_by_default():
    source = SCRIPT.read_text(encoding="utf-8")
    assert "127.0.0.1:8090" in source
    assert "Refusing non-local load target" in source
