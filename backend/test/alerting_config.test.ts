import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const rules = readFileSync(new URL('../ops/prometheus/smart-accountant-alerts.yml', import.meta.url), 'utf8');
const alertmanager = readFileSync(new URL('../ops/alertmanager/alertmanager.yml', import.meta.url), 'utf8');

describe('alerting configuration contract', () => {
  it('keeps the 5xx rule bounded and persistent', () => {
    expect(rules).toContain('alert: SmartAccountantHigh5xxRate');
    expect(rules).toContain('status_code=~"5.."');
    expect(rules).toContain('> 0.05');
    expect(rules).toContain('for: 10m');
    expect(rules).toContain('runbook:');
  });

  it('routes Slack and webhook notifications through secret files', () => {
    expect(alertmanager).toContain('slack_api_url_file: /etc/alertmanager/secrets/slack_webhook_url');
    expect(alertmanager).toContain('url_file: /etc/alertmanager/secrets/ops_webhook_url');
    expect(alertmanager).toContain('send_resolved: true');
    expect(alertmanager).toContain('inhibit_rules:');
    expect(alertmanager).not.toMatch(/https?:\/\/hooks\.slack\.com\/services\/[^\s]+/);
    expect(alertmanager).not.toContain('GEMINI_API_KEY');
  });
});
