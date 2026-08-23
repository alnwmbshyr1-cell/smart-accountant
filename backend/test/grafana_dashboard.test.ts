import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const dashboardPath = new URL('../ops/grafana/smart-accountant-backend-dashboard.json', import.meta.url);
const dashboard = JSON.parse(readFileSync(dashboardPath, 'utf8')) as {
  uid: string;
  title: string;
  panels: Array<{ title: string; datasource?: { uid?: string }; targets?: Array<{ expr?: string }> }>;
};

describe('Grafana dashboard contract', () => {
  it('is valid and uses the provisioned Prometheus datasource', () => {
    expect(dashboard.uid).toBe('smart-accountant-backend');
    expect(dashboard.title).toContain('Smart Accountant');
    expect(dashboard.panels.length).toBeGreaterThanOrEqual(6);
    expect(dashboard.panels.every((panel) => panel.datasource?.uid === 'prometheus')).toBe(true);
  });

  it('references only metrics emitted by the backend registry', () => {
    const queries = dashboard.panels.flatMap((panel) => panel.targets?.map((target) => target.expr ?? '') ?? []);
    expect(queries.some((query) => query.includes('smart_accountant_http_requests_total'))).toBe(true);
    expect(queries.some((query) => query.includes('smart_accountant_http_request_duration_seconds_bucket'))).toBe(true);
    expect(queries.some((query) => query.includes('smart_accountant_auth_failures_total'))).toBe(true);
    expect(queries.some((query) => query.includes('smart_accountant_gemini_failures_total'))).toBe(true);
    expect(queries.some((query) => query.includes('smart_accountant_process_rss_bytes'))).toBe(true);
    expect(queries.join('\n')).not.toMatch(/Authorization|Bearer|GEMINI_API_KEY|Arabic|مصروف/);
  });
});
