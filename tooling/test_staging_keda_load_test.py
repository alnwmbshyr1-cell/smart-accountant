from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "tooling/staging_keda_load_test.py"


def test_staging_runner_has_explicit_safety_guards():
    source = SCRIPT.read_text(encoding="utf-8")
    assert 'startswith("https://")' in source
    assert '"staging" not in args.target_url' in source
    assert 'startswith("rediss://")' in source
    assert "1 <= args.rps <= 2000" in source
    assert "--dry-run" in source


def test_staging_runner_observes_kubernetes_hpa_and_stream_backlog():
    source = SCRIPT.read_text(encoding="utf-8")
    assert 'kubectl' in source
    assert 'XINFO", "GROUPS"' in source
    assert 'desiredReplicas' in source
    assert 'keda-hpa-security-webhook-worker' in source
    assert 'keda-load-observations.jsonl' in source
    assert '--scale-up-timeout' in source
    assert '--scale-down-timeout' in source
    assert 'KEDA did not scale up' in source
    assert 'Redis backlog did not drain' in source
