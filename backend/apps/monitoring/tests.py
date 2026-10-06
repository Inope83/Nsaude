from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from apps.locations.models import AdministrativePost, Municipality, Suco
from apps.patients.models import Patient

from .models import PatientMonitoringRecord

User = get_user_model()


def setup_patient():
    municipality, _ = Municipality.objects.get_or_create(name="M", defaults={"code": "m"})
    posto, _ = AdministrativePost.objects.get_or_create(
        name="P", defaults={"code": "p", "municipality": municipality}
    )
    suco, _ = Suco.objects.get_or_create(name="S", defaults={"code": "s", "administrative_post": posto})
    return Patient.objects.create(
        first_name="A", last_name="B", sex=Patient.Sex.MALE, suco=suco
    )


class MonitoringModelTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.patient = setup_patient()
        cls.worker = User.objects.create_user(
            "hw1", password="x", role=User.Roles.HEALTH_WORKER
        )

    def _record(self, **kwargs):
        defaults = {"patient": self.patient, "recorded_at": timezone.now()}
        defaults.update(kwargs)
        return PatientMonitoringRecord.objects.create(**defaults)

    def test_minimal_record_ok(self):
        r = self._record()
        self.assertIsNone(r.temperature)
        self.assertIsNone(r.heart_rate)

    def test_full_record(self):
        r = self._record(
            recorded_by=self.worker,
            temperature=37.2,
            heart_rate=88,
            respiratory_rate=18,
            blood_pressure_systolic=120,
            blood_pressure_diastolic=80,
            oxygen_saturation=98,
            symptoms="tuse, fever",
            notes="resting",
        )
        self.assertEqual(r.recorded_by, self.worker)
        self.assertIn(self.patient.patient_id, str(r))

    def test_temperature_out_of_range_fails_validation(self):
        from django.core.exceptions import ValidationError

        r = self._record(temperature=99.0)
        with self.assertRaises(ValidationError):
            r.full_clean()

    def test_ordering_newest_first(self):
        now = timezone.now()
        old = self._record(recorded_at=now - timedelta(hours=2))
        new = self._record(recorded_at=now)
        qs = list(PatientMonitoringRecord.objects.values_list("id", flat=True))
        self.assertEqual(qs[0], new.id)
        self.assertEqual(qs[-1], old.id)

    def test_for_patient_queryset(self):
        other = setup_patient()
        self._record(recorded_by=self.worker)
        PatientMonitoringRecord.objects.create(
            patient=other, recorded_at=timezone.now()
        )
        qs = PatientMonitoringRecord.objects.for_patient(self.patient)
        self.assertEqual(qs.count(), 1)
        self.assertEqual(qs[0].patient, self.patient)

    def test_recent_prefetches_relations(self):
        self._record(recorded_by=self.worker)
        rec = PatientMonitoringRecord.objects.recent()[0]
        self.assertEqual(rec.recorded_by, self.worker)
