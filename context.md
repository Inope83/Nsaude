# SaúdeKonekta — Project Context

## Competition
SaúdeKonekta is being developed for the Vorakai Konekta Challenge 2026, Grand Challenge A: Distance & Emergency Healthcare, under the Build track.

The challenge describes remote sucos that may be hours from the nearest doctor and asks for a service using a village's new connection for telehealth triage, maternal-health check-ins and referral, mental health/psychosocial support, violence prevention/reporting, emergency escalation, or medicine-stock visibility. The service must work over a shared satellite link, tolerate outages, and be usable in Tetum by health workers with basic digital skills.

## Core Problem
A health worker in a remote suco may need to record a patient's condition and request medical support while connectivity is slow, shared, intermittent, or temporarily unavailable.

## Core Solution
SaúdeKonekta is an offline-first digital health platform that connects remote health workers with health facilities and medical staff. It supports patient records, basic monitoring, emergency case handling, referral/escalation, and synchronization when connectivity returns.

## Users
### Health Worker
Primary mobile user (Flutter): register/search patients, record monitoring observations, create emergency cases and referrals, work offline, synchronize when connected.

### Doctor / Medical Officer
Web dashboard: review patient information, monitoring records, emergency cases, referrals, and follow up through the workflow.

### System / Health Administrator
Dashboard: monitor facilities, emergency/referral activity, connectivity and sync status, municipality/suco distribution.

## Geographic Model
Timor-Leste → Municipality → Administrative Post → Suco → Health Facility → Health Worker

The prototype may demonstrate selected municipalities, but the architecture must not be hard-coded to one municipality.

## Connectivity Principle
Connectivity is an infrastructure constraint, not the medical feature itself. The app must:
- Save critical data locally
- Mark unsynchronized records as pending
- Detect connectivity changes
- Sync safely when connectivity returns
- Avoid assuming continuous internet access
- Minimize unnecessary network traffic

## Safety
The platform is decision support and communication software, not a diagnostic system. It must not claim to diagnose disease or replace doctors.

## Language
User-facing app: Tetum-first. English for development documentation. Portuguese may be added later.

## Competition Goal
Demonstrate real technical correctness, deployability, Timor-Leste-specific constraints, offline-first behavior, a clear emergency/referral workflow, and a convincing path from small prototype to national scale.
