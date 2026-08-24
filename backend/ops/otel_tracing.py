"""OpenTelemetry setup and span helpers for the webhook/worker path."""

from __future__ import annotations

import os
from collections.abc import Awaitable, Callable
from contextlib import asynccontextmanager
from typing import Any, AsyncIterator, TypeVar

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

T = TypeVar("T")


def configure_tracing(app: Any | None = None) -> trace.Tracer:
    """Configure OTLP/Jaeger tracing once per process and return the service tracer."""
    provider = trace.get_tracer_provider()
    if not isinstance(provider, TracerProvider):
        resource = Resource.create({
            "service.name": os.getenv("OTEL_SERVICE_NAME", "smart-accountant-webhook"),
            "deployment.environment": os.getenv("DEPLOYMENT_ENVIRONMENT", "staging"),
        })
        provider = TracerProvider(resource=resource)
        endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")
        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{endpoint.rstrip('/')}/v1/traces")))
        trace.set_tracer_provider(provider)
    if app is not None:
        FastAPIInstrumentor.instrument_app(app, tracer_provider=provider)
    return trace.get_tracer("smart-accountant.security-webhook")


@asynccontextmanager
async def redis_span(tracer: trace.Tracer, operation: str, **attributes: str) -> AsyncIterator[Any]:
    """Create a Redis span without recording keys, payloads, credentials, or message bodies."""
    with tracer.start_as_current_span(f"redis.{operation}") as span:
        span.set_attribute("db.system", "redis")
        span.set_attribute("db.operation.name", operation)
        for key, value in attributes.items():
            if key in {"db.namespace", "messaging.destination.name", "messaging.consumer.group"}:
                span.set_attribute(key, value)
        try:
            yield span
        except Exception as exc:
            span.record_exception(exc)
            span.set_status(trace.Status(trace.StatusCode.ERROR, type(exc).__name__))
            raise


async def traced_worker_call(
    tracer: trace.Tracer,
    operation: str,
    callback: Callable[[], Awaitable[T]],
    *,
    event_id_hash: str | None = None,
    experiment_id: str | None = None,
) -> T:
    """Trace one worker delivery while keeping identifiers hashed and bounded."""
    with tracer.start_as_current_span(f"worker.{operation}") as span:
        span.set_attribute("messaging.system", "redis_streams")
        span.set_attribute("messaging.operation", operation)
        if event_id_hash:
            span.set_attribute("security.event_id_hash", event_id_hash[:64])
        if experiment_id:
            span.set_attribute("chaos.experiment_id", experiment_id[:64])
        try:
            result = await callback()
            span.set_attribute("delivery.outcome", "success")
            return result
        except Exception as exc:
            span.set_attribute("delivery.outcome", "failure")
            span.record_exception(exc)
            span.set_status(trace.Status(trace.StatusCode.ERROR, type(exc).__name__))
            raise
