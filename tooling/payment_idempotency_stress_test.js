import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const paymentUrl = __ENV.PAYMENT_URL || '';
const ingressToken = __ENV.PAYMENT_TOKEN || '';
const testId = __ENV.TEST_ID || `payment-${Date.now()}`;
const maxRetries = Math.min(Number(__ENV.MAX_RETRIES || 2), 3);
const retryBaseMs = Math.max(Number(__ENV.RETRY_BASE_MS || 100), 50);

const retryRate = new Rate('payment_retry_rate');
const idempotencyViolationRate = new Rate('idempotency_violation_rate');
const paymentLatency = new Trend('payment_latency_ms');
const retryAttempts = new Counter('payment_retry_attempts');

export const options = {
  scenarios: {
    unique_payments: {
      executor: 'ramping-arrival-rate',
      startRate: 5,
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 100,
      exec: 'uniquePayment',
      stages: [
        { target: 20, duration: '30s' },
        { target: 50, duration: '60s' },
        { target: 100, duration: '60s' },
        { target: 0, duration: '30s' },
      ],
    },
    retry_and_replay: {
      executor: 'constant-arrival-rate',
      rate: 10,
      timeUnit: '1s',
      duration: '3m',
      preAllocatedVUs: 20,
      maxVUs: 100,
      exec: 'retryAndReplay',
      startTime: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<750', 'p(99)<1500'],
    checks: ['rate>0.98'],
    idempotency_violation_rate: ['rate==0'],
    payment_retry_rate: ['rate<0.20'],
  },
  tags: { service: 'payment-gateway', test_type: 'idempotency-stress', testid: testId },
};

function requestHeaders(key) {
  const headers = {
    'Content-Type': 'application/json',
    'Idempotency-Key': key,
    'X-Test-Run': testId,
  };
  if (ingressToken) headers.Authorization = `Bearer ${ingressToken}`;
  return headers;
}

function payload(key) {
  return JSON.stringify({
    amount: 1,
    currency: 'TEST',
    merchant_reference: `synthetic-${key}`,
    idempotency_key: key,
  });
}

function isRetryable(response) {
  return response.status === 408 || response.status === 425 || response.status === 429 || response.status >= 500 || response.status === 0;
}

function accepted(response) {
  return response.status === 200 || response.status === 201 || response.status === 202;
}

function responsePaymentId(response) {
  try {
    const body = JSON.parse(response.body || '{}');
    return body.payment_id || body.transaction_id || body.id || null;
  } catch (_) {
    return null;
  }
}

function postPayment(key) {
  const response = http.post(paymentUrl, payload(key), {
    headers: requestHeaders(key),
    timeout: '3s',
    tags: { endpoint: paymentUrl, testid: testId },
  });
  paymentLatency.add(response.timings.duration);
  return response;
}

function postWithBoundedRetry(key) {
  let response = postPayment(key);
  let attempts = 0;
  while (isRetryable(response) && attempts < maxRetries) {
    attempts += 1;
    retryAttempts.add(1);
    sleep((retryBaseMs * Math.pow(2, attempts - 1)) / 1000);
    response = postPayment(key);
  }
  retryRate.add(attempts > 0);
  return { response, attempts };
}

export function uniquePayment() {
  if (!paymentUrl) throw new Error('PAYMENT_URL is required');
  const key = `payment-unique-${testId}-${__VU}-${__ITER}`;
  const result = postWithBoundedRetry(key);
  check(result.response, {
    'unique payment is accepted': accepted,
    'unique payment is not an unbounded retry': () => result.attempts <= maxRetries,
  });
}

export function retryAndReplay() {
  if (!paymentUrl) throw new Error('PAYMENT_URL is required');
  const key = `payment-replay-${testId}-${__ITER % 50}`;
  const first = postWithBoundedRetry(key).response;
  const replay = postPayment(key);
  const replaySafe = replay.status === 409 || accepted(replay);
  const firstPaymentId = responsePaymentId(first);
  const replayPaymentId = responsePaymentId(replay);
  const samePayment = Boolean(firstPaymentId && replayPaymentId && firstPaymentId === replayPaymentId);
  const violation = accepted(first) && accepted(replay) && !samePayment;
  idempotencyViolationRate.add(violation);
  check(replay, {
    'replay has an idempotent outcome': () => replaySafe,
    'accepted replay is identical to first result': () => !violation,
  });
}

export default function () {
  uniquePayment();
}
