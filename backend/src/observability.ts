import { randomUUID } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';

declare global {
  namespace Express {
    interface Request {
      requestId?: string;
    }
  }
}

export type LogLevel = 'info' | 'warn' | 'error';

type MetricSnapshot = {
  requests_total: number;
  responses_4xx_total: number;
  responses_5xx_total: number;
  auth_failures_total: number;
  gemini_failures_total: number;
  request_duration_ms_sum: number;
  request_duration_ms_count: number;
  process_uptime_seconds: number;
  process_rss_bytes: number;
};

const metrics: MetricSnapshot = {
  requests_total: 0,
  responses_4xx_total: 0,
  responses_5xx_total: 0,
  auth_failures_total: 0,
  gemini_failures_total: 0,
  request_duration_ms_sum: 0,
  request_duration_ms_count: 0,
  process_uptime_seconds: 0,
  process_rss_bytes: 0,
};

const safeValue = (value: unknown): string | number | boolean | null => {
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  return null;
};

export function logEvent(level: LogLevel, event: string, fields: Record<string, unknown> = {}) {
  // Never accept arbitrary request bodies, headers, tokens, prompts, or model output in fields.
  const safeFields = Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, safeValue(value)]),
  );
  console[level](JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    service: 'smart-accountant-gemini-backend',
    event,
    ...safeFields,
  }));
}

export function requestObservability(req: Request, res: Response, next: NextFunction) {
  const requestId = req.header('x-request-id')?.slice(0, 128) || randomUUID();
  const started = process.hrtime.bigint();
  req.requestId = requestId;
  metrics.requests_total++;
  res.setHeader('x-request-id', requestId);

  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - started) / 1_000_000;
    metrics.request_duration_ms_sum += durationMs;
    metrics.request_duration_ms_count++;
    if (res.statusCode >= 400 && res.statusCode < 500) metrics.responses_4xx_total++;
    if (res.statusCode >= 500) metrics.responses_5xx_total++;
    logEvent(res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info', 'http_request_completed', {
      request_id: requestId,
      method: req.method,
      route: req.route?.path ?? req.path,
      status_code: res.statusCode,
      duration_ms: Math.round(durationMs * 100) / 100,
    });
  });
  return next();
}

export function recordAuthFailure() {
  metrics.auth_failures_total++;
}

export function recordGeminiFailure() {
  metrics.gemini_failures_total++;
}

export function getMetrics(): MetricSnapshot {
  const memory = process.memoryUsage();
  return {
    ...metrics,
    process_uptime_seconds: Math.round(process.uptime() * 100) / 100,
    process_rss_bytes: memory.rss,
  };
}
