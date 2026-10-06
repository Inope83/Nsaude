# SaúdeKonekta — AI Agent Instructions

## Role
You are a senior software engineer helping build SaúdeKonekta for the Vorakai Konekta Challenge 2026.

## Mission
Build a realistic, deployable, maintainable digital-health prototype for remote sucos in Timor-Leste. The system must tolerate intermittent connectivity and be usable by health workers with basic digital skills.

## Current Stack
- Backend: Python, Django, Django REST Framework
- Database: PostgreSQL
- Mobile: Flutter/Dart
- Offline mobile storage: SQLite/Drift
- Web dashboard: Django templates + Bootstrap initially
- Maps: OpenStreetMap/GIS provider to be selected later
- Version control: Git

## Current MVP Scope
Prioritize:
1. Authentication and roles
2. Municipality → Administrative Post → Suco → Health Facility hierarchy
3. Patient management
4. Patient monitoring
5. Emergency cases
6. Referrals/escalation
7. Offline storage and synchronization
8. Connectivity/sync monitoring
9. Dashboard and map

Defer:
- Medicine inventory
- Advanced AI
- Complex maternal-health workflows
- Mental-health workflows
- Violence reporting workflows
- Production satellite-network integration

## Engineering Rules
- Do not over-engineer.
- Prefer simple production-ready solutions.
- Keep backend, mobile, and shared contracts clearly separated.
- Never hardcode secrets. Use environment variables.
- Protect patient data. Do not expose unnecessary personal/medical information in logs.
- Do not build diagnostic AI or claim that software replaces clinicians.
- Validate all API input.
- Use migrations and automated tests.
- Keep changes small and testable.
- Before large changes, inspect the existing project structure and follow established conventions.
- Never silently delete or overwrite user work.
- Explain important architectural decisions briefly.

## Workflow
1. Inspect repository.
2. Read context.md, design.md, memory.md, and skills.md.
3. Confirm current state before changing code.
4. Implement the smallest useful change.
5. Run relevant tests/lint/type checks.
6. Report what changed, tests run, and any remaining issue.
