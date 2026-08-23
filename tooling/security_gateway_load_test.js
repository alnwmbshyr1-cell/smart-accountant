import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const gatewayUrl = __ENV.GATEWAY_URL || 'https://127.0.0.1:8443/v1/security/notify';
const ingressToken = __ENV.GATEWAY_INGRESS_TOKEN || '';
const caCert = __ENV.GATEWAY_CA_CERT || '';
const clientCert = __ENV.GATEWAY_CLIENT_CERT || '';
const clientKey = __ENV.GATEWAY_CLIENT_KEY || '';
const duplicateRate = Number(__ENV.DUPLICATE_RPS || 50);
const uniqueRate = Number(__ENV.UNIQUE_RPS || 950);

const duplicateErrors = new Rate('duplicate_request_errors');
const gatewayLatency = new Trend('gateway_latency_ms');

const tlsOptions = {};
if (clientCert || clientKey) {
  if (!clientCert || !clientKey) throw new Error('GATEWAY_CLIENT_CERT and GATEWAY_CLIENT_KEY must be provided together');
  tlsOptions.tlsAuth = [{ domains: [new URL(gatewayUrl).hostname], cert: open(clientCert), key: open(clientKey) }];
}
// Pass the CA separately at runtime: k6 run --tls-ca-cert=ca.pem ...

export const options = {
  scenarios: {
    unique_alerts: {
      executor: 'ramping-arrival-rate',
      startRate: 50,
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: 1800,
      exec: 'uniqueAlerts',
      stages: [
        { target: uniqueRate, duration: '30s' },
        { target: uniqueRate, duration: '60s' },
        { target: uniqueRate, duration: '30s' },
        { target: 0, duration: '15s' },
      ],
    },
    duplicate_claims: {
      executor: 'constant-arrival-rate',
      rate: duplicateRate,
      timeUnit: '1s',
      duration: '2m45s',
      preAllocatedVUs: 50,
      maxVUs: 300,
      exec: 'duplicateClaims',
      startTime: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    checks: ['rate>0.99'],
    duplicate_request_errors: ['rate<0.01'],
  },
  ...(Object.keys(tlsOptions).length ? tlsOptions : {}),
  tags: { service: 'security-gateway' },
};

function headers(key) {
  const result = {
    'Content-Type': 'application/json',
    'Idempotency-Key': key,
  };
  if (ingressToken) result.Authorization = `Bearer ${ingressToken}`;
  return result;
}

function post(key, expectedDuplicate) {
  const payload = JSON.stringify({
    event: 'synthetic_load_test',
    idempotency_key: key,
    findings: [{ severity: 'critical', rule_id: 'LOAD-TEST', source: 'k6' }],
  });
  const response = http.post(gatewayUrl, payload, { headers: headers(key), tags: { scenario: expectedDuplicate ? 'duplicate' : 'unique' } });
  gatewayLatency.add(response.timings.duration);
  const accepted = check(response, {
    'status is accepted or duplicate': (r) => r.status === 202 || (expectedDuplicate && r.status === 200),
    'response is JSON': (r) => String(r.headers['Content-Type'] || '').includes('application/json'),
  });
  if (expectedDuplicate) duplicateErrors.add(!accepted);
  return response;
}

export function uniqueAlerts() {
  const key = `sa-load-${__VU}-${__ITER}-${Date.now()}`;
  post(key, false);
}

export function duplicateClaims() {
  const key = `sa-load-duplicate-${__ITER % 100}`;
  post(key, __ITER % 100 !== 0);
}

export default function () {
  uniqueAlerts();
  sleep(0.01);
}
