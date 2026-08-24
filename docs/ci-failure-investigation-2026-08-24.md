# CI failure investigation — 2026-08-24

## Runs investigated

- Smart Accountant CI/CD: run 32650212786 — failed — main — https://github.com/alnwmbshyr1-cell/smart-accountant/actions/runs/32650212786
- Supabase integration tests: run 32650212734 — failed — main — https://github.com/alnwmbshyr1-cell/smart-accountant/actions/runs/32650212734

## Initial observations

The captured logs show the Supabase integration job completed artifact upload and `supabase stop --no-backup` cleanup, then emitted a GitHub Actions Node 20 deprecation warning. That warning is not itself the root cause. The complete failing step must be extracted from the beginning of the failed log rather than the tail, because cleanup output appears after the actual assertion/build failure.

The main CI run contains jobs named `Quality gate`, `Integration tests`, `Full coverage`, `Fast checks`, `Security scanning`, and `database-and-client-tests`. The current main branch protection requires these names plus `SAST and dependency security`.

## Source URLs

- https://github.com/alnwmbshyr1-cell/smart-accountant/actions/runs/32650212786
- https://github.com/alnwmbshyr1-cell/smart-accountant/actions/runs/32650212734

## Root causes confirmed

1. `Fast checks`, `Integration tests`, and `Full coverage` failed during `flutter pub get`: the workflow pins Flutter `3.27.1`, while `pubspec.yaml` on `main` required Flutter `>=3.38.1`. This is dependency resolution failure, not a test assertion or coverage regression.
2. The `Quality gate` failure was derivative: it correctly received `FAST_RESULT=failure`, `INTEGRATION_RESULT=failure`, and `COVERAGE_RESULT=failure` and stopped at its fail-closed checks.
3. Supabase `database-and-client-tests` failed first because `public.security_alerts` did not exist after `supabase db reset`; the pgTAP script attempted to insert into that table at line 55. The later `Bad plan. You planned 14 tests but ran 0` was a consequence of that SQL abort, not the primary cause.
4. The pgTAP file contained 13 actual assertions but declared `plan(14)`. The plan was corrected to 13, and a migration creating `public.security_alerts` with RLS and an admin-only read policy was added.
5. The Supabase workflow referenced `integration_test/rls_security_test.dart`, but the repository file is `integration_test/rls_supabase_test.dart`. The workflow was corrected and Flutter was pinned to 3.27.1.
6. GitHub Actions Node 20 deprecation messages and the `punycode` warning were non-blocking warnings, not causes of the failed jobs.

## Fixes committed

- Set the Flutter constraint to `>=3.27.0 <4.0.0` so it is compatible with the pinned CI SDK.
- Added `supabase/migrations/202608240001_security_alerts.sql`.
- Added the missing Supabase migrations and pgTAP/integration inputs to the final branch.
- Corrected the Flutter integration test path and pinned its SDK.
- Added reusable CI diagnosis guidance to the backend security skill.
