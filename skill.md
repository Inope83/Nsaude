# SaúdeKonekta — Engineering Skills and Practices

## Django
Custom User model from the start; explicit relationships; migrations; Django Admin; environment-based config; Django security defaults.

## Django REST Framework
Serializers, ViewSets/APIViews, routers, permissions, authentication, pagination, validation, OpenAPI docs when practical.

## PostgreSQL
Proper relational design, foreign keys, constraints, indexes on frequently queried fields, transactions for multi-step operations.

## Flutter (later)
Feature-based organization, Drift/SQLite persistence, repository pattern where useful, connectivity detection, sync queue, retry handling, clear loading/error/offline states.

## Offline-First
Design for intermittent connectivity, local writes, sync queues, idempotent API operations, conflict handling, retry with backoff, duplicate prevention, last successful sync timestamp.
Never assume continuous internet, high bandwidth, low latency, or a single user per device.

## API Design
Consistent JSON, correct HTTP status codes, validate all input, no unnecessary sensitive fields, stable documented contracts.

## Security
Never commit `.env`, hardcode secrets, log passwords/tokens, expose sensitive patient data unnecessarily, or use insecure debug settings in production.
Use JWT or secure sessions, HTTPS, role-based permissions, Django password hashing, restricted CORS, input validation.

## Testing
Test models, authentication, permissions, API endpoints, core workflows, and sync logic. Test failure cases, not only happy paths.

## Git
Small meaningful commits (`feat: add custom user model`, `test: add patient permissions`, `fix: prevent duplicate referral sync`).
Never commit `.env`, virtualenvs, secrets, local databases, IDE files.

## Medical Software Principle
Use wording like "requires medical evaluation", "high-priority case", "recommended referral". Avoid "the system diagnosed the patient" or "AI confirms the disease".

## UI/UX
Simple navigation, few steps per task, icons with text, large buttons, Tetum-first labels, strong offline indicators, clear emergency workflow.

## Performance (shared satellite link)
Minimize payloads and requests, cache where appropriate, compress images, no automatic large uploads, prefer incremental sync.

## Definition of Done
1. Code implemented. 2. Migrations created if needed. 3. Permissions considered. 4. Tests cover important behavior. 5. Tests pass. 6. Docs updated. 7. Works under expected connectivity constraints.
