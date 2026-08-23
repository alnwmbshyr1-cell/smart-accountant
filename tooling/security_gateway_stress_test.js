import http from 'k6/http';
import { check, sleep } from 'k6';

const target = __ENV.STRESS_TEST_URL || '';
const testId = __ENV.TEST_ID || `stress-${__VU}-${__ITER}`;

export const options = {
  scenarios: {
    medium_stress: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 100,
      stages: [
        { target: 20, duration: '1m' },
        { target: 50, duration: '2m' },
        { target: 100, duration: '2m' },
        { target: 0, duration: '1m' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<750', 'p(99)<1500'],
    checks: ['rate>0.98'],
  },
  tags: { test_type: 'medium_stress', test_id: testId },
};

export default function () {
  if (!target) throw new Error('STRESS_TEST_URL is required');
  const response = http.get(target, {
    tags: { endpoint: target, test_id: testId },
    timeout: '3s',
  });
  check(response, {
    'status is healthy': (r) => r.status >= 200 && r.status < 400,
    'response is bounded': (r) => r.body.length < 1024 * 1024,
  });
  sleep(0.1);
}
