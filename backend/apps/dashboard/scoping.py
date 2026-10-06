"""Role-scoped querysets for dashboard views (plan §4).

SYSTEM_ADMIN (or superuser) → everything; DOCTOR → own facility's scope;
HEALTH_WORKER → no dashboard this phase (get 403 via DashboardAccessMixin).
"""
from apps.emergencies.models import EmergencyCase
from apps.monitoring.models import PatientMonitoringRecord
from apps.patients.models import Patient
from apps.referrals.models import Referral


def is_admin_scope(user) -> bool:
    return user.is_superuser or user.is_system_admin


def scope_patients(user):
    """Patients of the doctor's facility suco (patient has no facility FK —
    flagged simplification from step 5)."""
    qs = Patient.objects.all()
    if is_admin_scope(user):
        return qs
    facility = user.facility
    if facility and facility.suco_id:
        return qs.filter(suco=facility.suco)
    return qs.none()


def scope_emergencies(user):
    qs = EmergencyCase.objects.all()
    if is_admin_scope(user):
        return qs
    if user.facility:
        return qs.for_facility(user.facility)
    return qs.none()


def scope_referrals(user):
    qs = Referral.objects.all()
    if is_admin_scope(user):
        return qs
    if user.facility:
        return qs.for_facility(user.facility)
    return qs.none()


def scope_monitoring(user):
    qs = PatientMonitoringRecord.objects.all()
    if is_admin_scope(user):
        return qs
    return qs.filter(patient__in=scope_patients(user))
