import { createServer, type Server } from 'node:http';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';

let server: Server;
let baseUrl: string;
let privateKey: CryptoKey;
let publicJwk: Record<string, unknown>;
let receivedPrompt = '';
const realFetch = globalThis.fetch;

beforeAll(async () => {
  process.env.NODE_ENV = 'test';
  process.env.GEMINI_API_KEY = 'integration-test-only';
  process.env.AUTH_PROVIDER = 'supabase';
  process.env.SUPABASE_PROJECT_URL = 'https://integration-test.supabase.co';

  const keys = await generateKeyPair('RS256');
  privateKey = keys.privateKey;
  publicJwk = {
    ...(await exportJWK(keys.publicKey)),
    kid: 'integration-key',
    alg: 'RS256',
    use: 'sig',
  };

  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith('/auth/v1/.well-known/jwks.json')) {
      return new Response(JSON.stringify({ keys: [publicJwk] }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }

    const body = JSON.parse(String(init?.body ?? '{}')) as {
      contents?: Array<{ parts?: Array<{ text?: string }> }>;
    };
    receivedPrompt = body.contents?.[0]?.parts?.[0]?.text ?? '';
    return new Response(JSON.stringify({
      candidates: [{
        content: {
          parts: [{
            text: JSON.stringify({
              type: 'مصروف',
              amount: 20000,
              desc: 'بنزين',
              name: '',
              quantity: 1,
            }),
          }],
        },
      }],
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  });

  const { app } = await import('../src/server.js');
  server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('test server did not start');
  baseUrl = `http://127.0.0.1:${address.port}`;
});

afterAll(async () => {
  vi.unstubAllGlobals();
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});

async function token(claims: Record<string, unknown> = {}) {
  return new SignJWT({ role: 'authenticated', ...claims })
    .setProtectedHeader({ alg: 'RS256', kid: 'integration-key' })
    .setIssuer('https://integration-test.supabase.co/auth/v1')
    .setAudience('authenticated')
    .setSubject('integration-user')
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(privateKey);
}

describe('Supabase authenticated Flutter-to-Backend contract', () => {
  it('accepts a signed Supabase token and returns validated Gemini JSON', async () => {
    const response = await realFetch(`${baseUrl}/v1/accounting/parse`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${await token()}`,
      },
      body: JSON.stringify({ text: 'سجل مصروف بنزين بعشرين ألف' }),
    });
    const result = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(result).toMatchObject({ type: 'مصروف', amount: 20000, desc: 'بنزين' });
    expect(receivedPrompt).toContain('سجل مصروف بنزين بعشرين ألف');
  });

  it('rejects an expired or malformed Supabase token before calling Gemini', async () => {
    const before = receivedPrompt;
    const expired = await new SignJWT({ role: 'authenticated' })
      .setProtectedHeader({ alg: 'RS256', kid: 'integration-key' })
      .setIssuer('https://integration-test.supabase.co/auth/v1')
      .setAudience('authenticated')
      .setSubject('integration-user')
      .setIssuedAt()
      .setExpirationTime(Math.floor(Date.now() / 1000) - 60)
      .sign(privateKey);

    const response = await realFetch(`${baseUrl}/v1/accounting/parse`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${expired}`,
      },
      body: JSON.stringify({ text: 'يجب رفض هذا' }),
    });

    expect(response.status).toBe(401);
    expect(receivedPrompt).toBe(before);
  });
});
