from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.emergencies.models import EmergencyCase
from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco
from apps.patients.models import Patient

from .models import StatusEvent
from .services import record_status_change

User = get_user_model()


class StatusEventTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        municipality = Municipality.objects.create(name="M", code="m")
        posto = AdministrativePost.objects.create(name="P", code="p", municipality=municipality)
        suco = Suco.objects.create(name="S", code="s", administrative_post=posto)
        cls.facility = HealthFacility.objects.create(name="F", suco=suco)
        cls.patient = Patient.objects.create(
            first_name="A", last_name="B", sex=Patient.Sex.FEMALE, suco=suco
        )
        cls.user = User.objects.create_user("u", password="x")
        cls.src_suco = suco

    def make_emergency(self):
        return EmergencyCase.objects.create(
            patient=self.patient,
            created_by=self.user,
            facility=self.facility,
            severity=EmergencyCase.Severity.HIGH,
        )

    def test_requires_a_target(self):
        with self.assertRaises(ValidationError):
            record_status_change(actor=self.user, new_status="X")  # neither target

    def test_rejects_both_targets(self):
        e = self.make_emergency()
        from apps.facilities.models import HealthFacility
        from apps.referrals.models import Referral

        other = HealthFacility.objects.create(name="Other", suco=self.src_suco)
        r = Referral.objects.create(
            patient=self.patient,
            referred_by=self.user,
            source_facility=self.facility,
            destination_facility=other,
            reason="x",
            urgency=Referral.Urgency.ROUTINE,
        )
        with self.assertRaises(ValidationError):
            record_status_change(
                actor=self.user, new_status="X", emergency=e, referral=r
            )

    def test_str_shows_transition(self):
        e = self.make_emergency()
        event = e.change_status(EmergencyCase.Status.ESCALATED, actor=self.user)
        self.assertIn("OPEN", str(event))
        self.assertIn("ESCALATED", str(event))
        self.assertEqual(event.target, e)
