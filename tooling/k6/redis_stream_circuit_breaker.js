import http from 'k6/http';
import crypto from 'k6/crypto';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const baseUrl = __ENV.TARGET_URL || 'http://127.0.0.1:8090';
const rate = Number(__ENV.RPS || 50);
const duration = __ENV.DURATION || '60s';
const secret = __ENV.TEST_WEBHOOK_SECRET || 'local-only-secret';
const forceFailure = __ENV.FORCE_DOWNSTREAM_FAILURE === 'true';
const allowNonLocal = __ENV.ALLOW_NON_LOCAL_LOAD_TEST === 'true';
const chaosExperimentId = __ENV.CHAOS_EXPERIMENT_ID || '';

if (!allowNonLocal && !/^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(baseUrl)) {
  throw new Error('Refusing non-local load target. Set ALLOW_NON_LOCAL_LOAD_TEST=true only for approved staging.');
}
if (forceFailure && !allowNonLocal) {
  throw new Error('FORCE_DOWNSTREAM_FAILURE requires an explicitly approved staging target.');
}

const accepted = new Counter('webhook_accepted_total');
const rejected = new Counter('webhook_rejected_total');
const requestLatency = new Trend('webhook_request_latency_ms', true);
const errorRate = new Rate('webhook_error_rate');

export const options = {
  scenarios: {
    webhook_ingress: {
      executor: 'constant-arrival-rate',
      rate,
      timeUnit: '1s',
      duration,
      preAllocatedVUs: Math.min(rate, 100),
      maxVUs: Math.max(rate * 2, 100),
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<750'],
    webhook_error_rate: ['rate<0.05'],
  },
};

function payload(id) {
  return JSON.stringify({
    status: 'firing',
    alerts: [{
      labels: {
        alertname: 'CircuitBreakerOpen',
        category: 'security',
        severity: 'critical',
        dependency: 'load-test-dependency',
        test_mode: 'true',
      },
      annotations: {
        summary: forceFailure ? 'synthetic downstream failure' : 'synthetic circuit test',
      },
      startsAt: new Date().toISOString(),
      generatorURL: 'http://load-test.invalid/synthetic',
    }],
    test_event_id: id,
  });
}

export default function () {
  const id = `${__VU}-${__ITER}-${Date.now()}`;
  const body = payload(id);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = crypto.hmac('sha256', secret, `${timestamp}.${body}`, 'hex');
  const response = http.post(`${baseUrl}/alertmanager`, body, {
    headers: {
      'Content-Type': 'application/json',
      'X-Webhook-Id': id,
      'X-Webhook-Timestamp': timestamp,
      'X-Webhook-Signature': `sha256=${signature}`,
      'X-Load-Test': 'true',
      ...(chaosExperimentId ? { 'X-Chaos-Experiment-Id': chaosExperimentId } : {}),
    },
    tags: { scenario: 'redis_stream_circuit_breaker' },
  });
  requestLatency.add(response.timings.duration);
  const ok = check(response, { 'accepted or rejected deterministically': (r) => [202, 401, 409].includes(r.status) });
  errorRate.add(!ok);
  if (response.status === 202) accepted.add(1); else rejected.add(1);
  sleep(0.01);
}
