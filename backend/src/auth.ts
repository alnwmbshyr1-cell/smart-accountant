import { getApps, initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';
import type { NextFunction, Request, Response } from 'express';

export type AuthenticatedUser = {
  uid: string;
  provider: 'firebase' | 'supabase';
  claims: Record<string, unknown>;
};

export type JwtVerifier = (token: string) => Promise<AuthenticatedUser>;

declare global {
  namespace Express {
    interface Request {
      authenticatedUser?: AuthenticatedUser;
    }
  }
}

function bearerToken(req: Request): string | null {
  const value = req.header('authorization') ?? '';
  if (!value.startsWith('Bearer ')) return null;
  const token = value.slice('Bearer '.length).trim();
  return token.length > 0 && token.length <= 8192 ? token : null;
}

function firebaseVerifier() {
  if (getApps().length === 0) {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
    if (serviceAccountJson) {
      initializeApp({ credential: cert(JSON.parse(serviceAccountJson)) });
    } else {
      initializeApp({
        credential: applicationDefault(),
        projectId: process.env.FIREBASE_PROJECT_ID,
      });
    }
  }
  return getAuth();
}

export function createSupabaseVerifier(options?: {
  projectUrl?: string;
  audience?: string;
  jwks?: ReturnType<typeof createRemoteJWKSet>;
}): JwtVerifier {
  const projectUrl = (options?.projectUrl ?? process.env.SUPABASE_PROJECT_URL)?.replace(/\/$/, '');
  if (!projectUrl) throw new Error('SUPABASE_PROJECT_URL is required');
  const issuer = `${projectUrl}/auth/v1`;
  const jwks = options?.jwks ?? createRemoteJWKSet(
    new URL(`${issuer}/.well-known/jwks.json`),
  );
  const audience = options?.audience ?? process.env.SUPABASE_JWT_AUDIENCE ?? 'authenticated';
  return async (token: string): Promise<AuthenticatedUser> => {
    const verified = await jwtVerify(token, jwks, {
      issuer,
      audience,
      algorithms: ['RS256', 'ES256', 'EdDSA'],
    });
    const payload: JWTPayload = verified.payload;
    if (typeof payload.sub !== 'string' || payload.sub.trim().length === 0) {
      throw new Error('supabase_subject_missing');
    }
    if (payload.role !== 'authenticated') {
      throw new Error('supabase_role_denied');
    }
    return {
      uid: payload.sub,
      provider: 'supabase',
      claims: payload as Record<string, unknown>,
    };
  };
}

export function createFirebaseVerifier(
  auth: Pick<ReturnType<typeof firebaseVerifier>, 'verifyIdToken'> = firebaseVerifier(),
): JwtVerifier {
  return async (token: string): Promise<AuthenticatedUser> => {
    const decoded = await auth.verifyIdToken(token, true);
    return {
    uid: decoded.uid,
    provider: 'firebase',
    claims: decoded as unknown as Record<string, unknown>,
  };
  };
}

export function createJwtVerifier(): JwtVerifier {
  const provider = process.env.AUTH_PROVIDER ?? 'supabase';
  if (provider === 'firebase') return createFirebaseVerifier();
  if (provider === 'supabase') return createSupabaseVerifier();
  throw new Error('AUTH_PROVIDER must be firebase or supabase');
}

export function requireJwt(verify: JwtVerifier) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const token = bearerToken(req);
    if (!token) return res.status(401).json({ error: 'missing_or_malformed_token' });
    try {
      req.authenticatedUser = await verify(token);
      return next();
    } catch (error) {
      const name = error instanceof Error ? error.name : 'unknown';
      console.warn('jwt_rejected', name);
      return res.status(401).json({ error: 'invalid_or_expired_token' });
    }
  };
}
