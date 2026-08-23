import { createServer, type Server } from 'node:http';
import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import {
  exportJWK,
  generateKeyPair,
  SignJWT,
  createRemoteJWKSet,
} from 'jose';
import {
  createFirebaseVerifier,
  createSupabaseVerifier,
} from '../src/auth.js';

let server: Server;
let baseUrl: string;
let privateKey: CryptoKey;
let publicJwk: Record<string, unknown>;

beforeAll(async () => {
  const keys = await generateKeyPair('RS256');
  privateKey = keys.privateKey;
  publicJwk = { ...(await exportJWK(keys.publicKey)), kid: 'unit-test-key', alg: 'RS256', use: 'sig' };
  server = createServer((request, response) => {
    if (request.url === '/auth/v1/.well-known/jwks.json') {
      response.setHeader('content-type', 'application/json');
      response.end(JSON.stringify({ keys: [publicJwk] }));
      return;
    }
    response.statusCode = 404;
    response.end();
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('test server did not start');
  baseUrl = `http://127.0.0.1:${address.port}`;
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});

async function makeToken(claims: Record<string, unknown> = {}) {
  return new SignJWT({ role: 'authenticated', ...claims })
    .setProtectedHeader({ alg: 'RS256', kid: 'unit-test-key' })
    .setIssuer(`${baseUrl}/auth/v1`)
    .setAudience(typeof claims.aud === 'string' ? claims.aud : 'authenticated')
    .setSubject('user-123')
    .setIssuedAt()
    .setExpirationTime(typeof claims.exp === 'number' ? claims.exp : '5m')
    .sign(privateKey);
}

describe('Supabase JWT verifier', () => {
  it('accepts a correctly signed token and returns sub as uid', async () => {
    const verifier = createSupabaseVerifier({
      projectUrl: baseUrl,
      jwks: createRemoteJWKSet(new URL(`${baseUrl}/auth/v1/.well-known/jwks.json`)),
    });

    const result = await verifier(await makeToken());

    expect(result.uid).toBe('user-123');
    expect(result.provider).toBe('supabase');
  });

  it.each([
    ['wrong audience', { aud: 'other-app' }],
    ['wrong role', { role: 'anon' }],
    ['expired token', { exp: Math.floor(Date.now() / 1000) - 60 }],
  ])('rejects %s', async (_name, claims) => {
    const verifier = createSupabaseVerifier({
      projectUrl: baseUrl,
      jwks: createRemoteJWKSet(new URL(`${baseUrl}/auth/v1/.well-known/jwks.json`)),
    });

    await expect(verifier(await makeToken(claims))).rejects.toBeTruthy();
  });
});

describe('Firebase ID token verifier adapter', () => {
  it('requires revoked-token checking and returns Firebase uid', async () => {
    let checkRevoked: boolean | undefined;
    const verifier = createFirebaseVerifier({
      verifyIdToken: async (_token: string, revoked: boolean) => {
        checkRevoked = revoked;
        return { uid: 'firebase-user-1', firebase: { sign_in_provider: 'custom' } } as never;
      },
    });

    const result = await verifier('test-token');

    expect(checkRevoked).toBe(true);
    expect(result.uid).toBe('firebase-user-1');
    expect(result.provider).toBe('firebase');
  });

  it('propagates invalid or revoked token failures', async () => {
    const verifier = createFirebaseVerifier({
      verifyIdToken: async () => {
        throw new Error('auth/id-token-revoked');
      },
    });

    await expect(verifier('bad-token')).rejects.toThrow('auth/id-token-revoked');
  });
});
