# SaúdeKonekta — System Design

## 1. High-Level Architecture
Health Worker → Flutter Mobile App → Local SQLite/Drift → Sync Queue → Intermittent Internet / Shared Satellite Link → Django REST API → PostgreSQL → Web Dashboard

## 2. Backend Structure
backend/
├── config/
├── apps/
│   ├── users/
│   ├── locations/
│   ├── facilities/
│   ├── patients/
│   ├── monitoring/
│   ├── emergencies/
│   └── referrals/
└── manage.py

## 3. Core Data Model
- User: id, username/email, role, facility, is_active, created_at, updated_at
- Municipality: id, name, code, latitude, longitude, created_at, updated_at
- AdministrativePost: id, municipality, name, code, latitude, longitude
- Suco: id, administrative_post, name, code, latitude, longitude
- HealthFacility: id, suco, name, facility_type, address, latitude, longitude, phone, is_active, created_at, updated_at
- Patient: id, patient_id, first_name, last_name, date_of_birth, sex, phone, address, suco, emergency_contact, is_active, created_at, updated_at
- PatientMonitoringRecord: id, patient, recorded_by, recorded_at, temperature, heart_rate, respiratory_rate, blood_pressure_systolic, blood_pressure_diastolic, oxygen_saturation, symptoms, notes, created_at
- EmergencyCase: id, patient, created_by, facility, severity (LOW/MEDIUM/HIGH/CRITICAL), symptoms, description, status (OPEN/IN_REVIEW/ESCALATED/RESOLVED), created_at, updated_at
- Referral: id, patient, emergency_case (optional), referred_by, source_facility, destination_facility, reason, urgency (ROUTINE/URGENT/EMERGENCY), status (PENDING/ACCEPTED/IN_TRANSIT/COMPLETED/CANCELLED), notes, created_at, updated_at

## 4. Roles
- SYSTEM_ADMIN: full administrative access
- HEALTH_WORKER: patient registration/search, monitoring, emergency and referral creation; limited by facility where practical
- DOCTOR: patient and monitoring review, emergency review, referral review/update

## 5. Mobile Screens (MVP)
1. Login 2. Dashboard 3. Patient List 4. Patient Search 5. Add Patient 6. Patient Detail 7. Add Monitoring Record 8. Emergency Assessment 9. Referral 10. Sync/Connectivity Status

## 6. Web Dashboard (MVP)
Emergency cases, pending referrals, patient activity, facility activity, connectivity/sync status, municipality and suco filters, map view.

## 7. Map Concept
Markers may represent health facilities, emergency cases (privacy-safe), connectivity status, pending synchronization. Never expose sensitive patient information on public maps. Satellite imagery is a visualization layer; it is not satellite internet.

## 8. Offline Sync Design
Local metadata per record: local_id, server_id, sync_status, created_at, updated_at, last_sync_attempt, sync_error.

States: PENDING → SYNCING → SYNCED, or PENDING → SYNCING → FAILED → RETRY.
Avoid duplicate records and accidental overwrites (use client-generated UUIDs / idempotent endpoints).

## 9. API Convention
Base: `/api/`
- Auth: POST /api/auth/login/, POST /api/auth/refresh/
- Locations: GET /api/municipalities/, /api/administrative-posts/, /api/sucos/
- Facilities: GET /api/facilities/, /api/facilities/{id}/
- Patients: GET, POST /api/patients/; GET, PATCH /api/patients/{id}/
- Monitoring: GET, POST /api/patients/{id}/monitoring/
- Emergencies: GET, POST /api/emergencies/; GET, PATCH /api/emergencies/{id}/
- Referrals: GET, POST /api/referrals/; GET, PATCH /api/referrals/{id}/

## 10. UI Principles
Tetum-first, large touch targets, simple navigation, clear status indicators, minimal data entry, low-bandwidth friendly, no unnecessary animations, clear offline/online status, plain language, obvious emergency actions.

## 11. MVP Boundary
No medicine inventory, advanced AI, or complex specialist modules until patient → monitoring → emergency → referral → sync works end-to-end.
