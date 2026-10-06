# SaúdeKonekta — Project Memory

## Decisions Already Made
- Name: SaúdeKonekta
- Competition: Vorakai Konekta Challenge 2026, Build track, Grand Challenge A — Distance & Emergency Healthcare
- Product: offline-first healthcare communication and monitoring platform for remote sucos in Timor-Leste
- Primary user: Health Worker. Secondary: Doctor/Medical Officer, System/Health Administrator
- Mobile: Flutter/Dart. Backend: Django + DRF. Server DB: PostgreSQL. Offline storage: SQLite/Drift
- Core MVP: authentication, geographic hierarchy, facilities, patients, monitoring, emergencies, referrals, offline storage, sync, connectivity monitoring, dashboard/map
- Deferred: medicine inventory, advanced AI, maternal-health / mental-health / violence-reporting workflows

## Principles
- Not a diagnostic system; AI, if added later, is decision support only.
- Nationally scalable across Timor-Leste; prototype demonstrates selected municipalities.
- Never assume continuous connectivity; work offline and sync later.
- Satellite map = visualization/GIS layer; satellite internet = connectivity layer. Separate concepts.
- Build order: Django backend → Flutter → offline sync → dashboard/map.

## Current Starting Point
Django backend foundation.
