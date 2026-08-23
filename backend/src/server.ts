import cors from 'cors';
import express, { type NextFunction, type Request, type Response } from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import { z } from 'zod';

const app = express();
const port = Number(process.env.PORT ?? 8080);
const geminiKey = process.env.GEMINI_API_KEY?.trim();
const geminiModel = process.env.GEMINI_MODEL ?? 'gemini-1.5-flash';
const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

if (!geminiKey) {
  throw new Error('GEMINI_API_KEY is required on the server');
}

export const commandRequestSchema = z.object({
  text: z.string().trim().min(1).max(2000),
});

export const accountingResultSchema = z.object({
  type: z.enum(['مبيعات', 'مشتريات', 'مصروف', 'دين_لي', 'دين_علي', 'مخزون']),
  amount: z.number().finite().nonnegative(),
  desc: z.string().trim().min(1).max(160),
  name: z.string().trim().max(160),
  quantity: z.number().finite().positive(),
});

export function authenticateUser(req: Request, res: Response, next: NextFunction) {
  const authorization = req.header('authorization') ?? '';
  if (!authorization.startsWith(BearerPrefix) || authorization.length <= BearerPrefix.length) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}

const BearerPrefix = 'Bearer ';

export function buildPrompt(text: string): string {
  return `
أنت محاسب يمني دقيق. استخرج عملية واحدة من النص التالي.
أعد JSON فقط وفق المخطط:
{"type":"مبيعات|مشتريات|مصروف|دين_لي|دين_علي|مخزون","amount":number,"desc":string,"name":string,"quantity":number}
حوّل الأرقام العربية والكلمات مثل ألف ومليون إلى رقم.
إذا لم يتضح المبلغ، استخدم amount=0.
النص: ${text}
`;
}

async function callGemini(text: string, signal: AbortSignal): Promise<unknown> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent`,
    {
      method: 'POST',
      signal,
      headers: {
        'content-type': 'application/json',
        'x-goog-api-key': geminiKey!,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: buildPrompt(text) }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 256,
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'OBJECT',
            properties: {
              type: { type: 'STRING', enum: ['مبيعات', 'مشتريات', 'مصروف', 'دين_لي', 'دين_علي', 'مخزون'] },
              amount: { type: 'NUMBER' },
              desc: { type: 'STRING' },
              name: { type: 'STRING' },
              quantity: { type: 'NUMBER' },
            },
            required: ['type', 'amount', 'desc', 'name', 'quantity'],
          },
        },
      }),
    },
  );

  if (!response.ok) throw new Error(`gemini_upstream_${response.status}`);
  const body = (await response.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };
  const raw = body.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    throw new Error('empty_model_response');
  }
  return JSON.parse(raw);
}

app.disable('x-powered-by');
app.use(helmet());
app.use(express.json({ limit: '16kb' }));
app.use(cors({ origin: allowedOrigins.length > 0 ? allowedOrigins : false, methods: ['POST', 'GET'] }));
app.use(rateLimit({ windowMs: 60_000, limit: 30, standardHeaders: true, legacyHeaders: false }));

app.get('/healthz', (_req, res) => res.json({ ok: true }));

app.post('/v1/accounting/parse', authenticateUser, async (req, res) => {
  const request = commandRequestSchema.safeParse(req.body);
  if (!request.success) return res.status(400).json({ error: 'invalid_request' });

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    const decoded = await callGemini(request.data.text, controller.signal);
    const result = accountingResultSchema.safeParse(decoded);
    if (!result.success) return res.status(422).json({ error: 'invalid_model_payload' });
    return res.json(result.data);
  } catch (error) {
    const name = error instanceof Error ? error.name : 'unknown';
    console.error('gemini_parse_failed', name);
    return res.status(name === 'AbortError' ? 504 : 502).json({
      error: name === 'AbortError' ? 'backend_timeout_or_network' : 'gemini_upstream_error',
    });
  } finally {
    clearTimeout(timeout);
  }
});

export { app };

if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => console.log(`accounting backend listening on ${port}`));
}
