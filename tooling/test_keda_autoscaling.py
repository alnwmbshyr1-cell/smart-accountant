import pytest
from pathlib import Path

yaml = pytest.importorskip("yaml")

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "backend/ops/kubernetes/redis-stream-worker-autoscaling.yml"


def _objects():
    return list(yaml.safe_load_all(MANIFEST.read_text(encoding="utf-8")))


def test_keda_manifest_has_secure_worker_and_autoscaler():
    objects = {item["kind"]: item for item in _objects() if item}
    assert {"Deployment", "TriggerAuthentication", "ScaledObject", "PodDisruptionBudget"} <= objects.keys()
    deployment = objects["Deployment"]
    container = deployment["spec"]["template"]["spec"]["containers"][0]
    assert container["securityContext"]["runAsNonRoot"] is True
    assert container["securityContext"]["readOnlyRootFilesystem"] is True
    assert container["resources"]["limits"]["memory"] == "512Mi"


def test_scaled_object_uses_stream_lag_and_safe_scale_down():
    scaled = next(item for item in _objects() if item and item["kind"] == "ScaledObject")
    spec = scaled["spec"]
    assert spec["minReplicaCount"] == 2
    assert spec["maxReplicaCount"] == 20
    trigger = spec["triggers"][0]
    assert trigger["type"] == "redis-streams"
    assert trigger["metadata"]["consumerGroup"] == "security-webhook-workers"
    assert trigger["metadata"]["pendingEntriesCount"] == "100"
    assert trigger["metadata"]["enableTLS"] == "true"
    assert spec["advanced"]["horizontalPodAutoscalerConfig"]["behavior"]["scaleDown"]["stabilizationWindowSeconds"] == 300


def test_redis_credentials_are_secret_references():
    objects = _objects()
    deployment = next(item for item in objects if item and item["kind"] == "Deployment")
    env = deployment["spec"]["template"]["spec"]["containers"][0]["env"]
    assert all("secretKeyRef" in entry["valueFrom"] for entry in env[:2])
    auth = next(item for item in objects if item and item["kind"] == "TriggerAuthentication")
    assert all(ref["name"] == "smart-accountant-redis" for ref in auth["spec"]["secretTargetRef"])
