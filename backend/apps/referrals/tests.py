from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.audit.models import StatusEvent
from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco
from apps.patients.models import Patient

from .models import Referral

User = get_user_model()


def setup_world():
    municipality = Municipality.objects.create(name="M", code="m")
    posto = AdministrativePost.objects.create(name="P", code="p", municipality=municipality)
    suco = Suco.objects.create(name="S", code="s", administrative_post=posto)
    src = HealthFacility.objects.create(name="Clinica A", suco=suco)
    dst = HealthFacility.objects.create(name="Hospital B", suco=suco)
    patient = Patient.objects.create(
        first_name="A", last_name="B", sex=Patient.Sex.MALE, suco=suco
    )
    user = User.objects.create_user("doc", password="x", role=User.Roles.DOCTOR, facility=src)
    return src, dst, patient, user


class ReferralTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.src, cls.dst, cls.patient, cls.user = setup_world()

    def make(self, **kwargs):
        defaults = {
            "patient": self.patient,
            "referred_by": self.user,
            "source_facility": self.src,
            "destination_facility": self.dst,
            "reason": "Needs imaging",
            "urgency": Referral.Urgency.URGENT,
        }
        defaults.update(kwargs)
        return Referral.objects.create(**defaults)

    def test_defaults_pending(self):
        r = self.make()
        self.assertEqual(r.status, Referral.Status.PENDING)

    def test_same_facility_rejected_by_clean(self):
        r = self.make(destination_facility=self.src)
        with self.assertRaises(ValidationError) as ctx:
            r.full_clean()
        self.assertIn("destination_facility", ctx.exception.error_dict)

    def test_change_status_records_event(self):
        r = self.make()
        event = r.change_status(Referral.Status.ACCEPTED, actor=self.user)
        r.refresh_from_db()
        self.assertEqual(r.status, Referral.Status.ACCEPTED)
        self.assertEqual(event.old_status, "PENDING")
        self.assertEqual(event.new_status, "ACCEPTED")
        self.assertEqual(event.referral, r)
        self.assertIsNone(event.emergency)

    def test_no_event_on_create(self):
        self.make()
        self.assertEqual(StatusEvent.objects.count(), 0)

    def test_for_facility_includes_sent_and_received(self):
        self.make()
        other_src = HealthFacility.objects.create(name="Clinica C", suco=self.src.suco)
        Referral.objects.create(
            patient=self.patient,
            referred_by=self.user,
            source_facility=other_src,
            destination_facility=self.dst,
            reason="Back",
            urgency=Referral.Urgency.ROUTINE,
        )
        qs = Referral.objects.for_facility(self.dst)
        self.assertEqual(qs.count(), 2)
        qs = Referral.objects.for_facility(self.src)
        self.assertEqual(qs.count(), 1)

    def test_pending_filter(self):
        r = self.make()
        r.change_status(Referral.Status.COMPLETED, actor=self.user)
        self.make(reason="still waiting")
        self.assertEqual(Referral.objects.pending().count(), 1)

    def test_for_list_privacy(self):
        self.make()
        row = Referral.objects.for_list()[0]
        for pii in ("first_name", "last_name", "phone", "reason", "notes"):
            self.assertNotIn(pii, row)
        self.assertIn("patient__patient_id", row)
