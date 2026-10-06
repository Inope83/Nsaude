from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.audit.models import StatusEvent
from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco
from apps.patients.models import Patient

from .models import EmergencyCase

User = get_user_model()


def make_emergency(**kwargs):
    if "patient" not in kwargs:
        municipality, _ = Municipality.objects.get_or_create(name="M", defaults={"code": "m"})
        posto, _ = AdministrativePost.objects.get_or_create(
            name="P", defaults={"code": "p", "municipality": municipality}
        )
        suco, _ = Suco.objects.get_or_create(
            name="S", defaults={"code": "s", "administrative_post": posto}
        )
        facility, _ = HealthFacility.objects.get_or_create(name="F", defaults={"suco": suco})
        kwargs["patient"] = Patient.objects.create(
            first_name="A", last_name="B", sex=Patient.Sex.FEMALE, suco=suco
        )
        kwargs["facility"] = facility
        kwargs["created_by"] = User.objects.create_user(
            f"hw{User.objects.count() + 1}", password="x"
        )
    return EmergencyCase.objects.create(**kwargs)


class EmergencyCaseTests(TestCase):
    def test_defaults_open(self):
        e = make_emergency(severity=EmergencyCase.Severity.HIGH)
        self.assertEqual(e.status, EmergencyCase.Status.OPEN)

    def test_str_uses_safe_handle(self):
        e = make_emergency(severity=EmergencyCase.Severity.LOW)
        self.assertIn(e.patient.patient_id, str(e))
        self.assertIn("LOW", str(e))

    def test_change_status_records_event(self):
        e = make_emergency(severity=EmergencyCase.Severity.CRITICAL)
        actor = e.created_by
        event = e.change_status(EmergencyCase.Status.IN_REVIEW, actor=actor)
        e.refresh_from_db()
        self.assertEqual(e.status, EmergencyCase.Status.IN_REVIEW)
        self.assertEqual(event.old_status, "OPEN")
        self.assertEqual(event.new_status, "IN_REVIEW")
        self.assertEqual(event.actor, actor)
        self.assertEqual(event.emergency, e)
        self.assertIsNone(event.referral)

    def test_change_status_same_value_rejected(self):
        e = make_emergency(severity=EmergencyCase.Severity.HIGH)
        with self.assertRaises(ValidationError):
            e.change_status(EmergencyCase.Status.OPEN, actor=e.created_by)

    def test_no_event_on_create(self):
        make_emergency(severity=EmergencyCase.Severity.HIGH)
        self.assertEqual(StatusEvent.objects.count(), 0)

    def test_active_excludes_resolved(self):
        open_e = make_emergency(severity=EmergencyCase.Severity.HIGH)
        done = make_emergency(severity=EmergencyCase.Severity.LOW)
        done.change_status(EmergencyCase.Status.RESOLVED, actor=done.created_by)
        active = list(EmergencyCase.objects.active())
        self.assertIn(open_e, active)
        self.assertNotIn(done, active)

    def test_for_list_privacy(self):
        make_emergency(severity=EmergencyCase.Severity.HIGH)
        row = EmergencyCase.objects.for_list()[0]
        for pii in ("first_name", "last_name", "phone", "address", "emergency_contact"):
            self.assertNotIn(pii, str(row.keys()))
            self.assertNotIn(pii, row)
        self.assertIn("patient__patient_id", row)
