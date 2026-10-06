from django.test import TestCase

from apps.locations.models import AdministrativePost, Municipality, Suco

from .models import Patient, generate_patient_id


def make_patient(**kwargs):
    defaults = {"first_name": "Maria", "last_name": "Santos", "sex": Patient.Sex.FEMALE}
    defaults.update(kwargs)
    return Patient.objects.create(**defaults)


class PatientModelTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.suco = Suco.objects.create(
            name="Suco A",
            code="sa",
            administrative_post=AdministrativePost.objects.create(
                name="Posto A",
                code="pa",
                municipality=Municipality.objects.create(name="Manufahi", code="mf"),
            ),
        )

    def test_patient_id_auto_generated(self):
        p = make_patient(suco=self.suco)
        self.assertTrue(p.patient_id.startswith("PT-"))
        self.assertEqual(len(p.patient_id), 9)

    def test_patient_id_unique(self):
        p1 = make_patient(suco=self.suco)
        p2 = make_patient(first_name="Outru", suco=self.suco)
        self.assertNotEqual(p1.patient_id, p2.patient_id)

    def test_generate_shape(self):
        pid = generate_patient_id()
        self.assertRegex(pid, r"^PT-[A-Z0-9]{6}$")

    def test_str_is_safe_handle(self):
        p = make_patient(suco=self.suco)
        self.assertEqual(str(p), p.patient_id)

    def test_age_and_age_group(self):
        from datetime import date

        p = make_patient(suco=self.suco, date_of_birth=date(2024, 1, 1))
        self.assertIsNotNone(p.age)
        self.assertGreaterEqual(p.age, 1)
        self.assertEqual(p.age_group, "0–4")

    def test_age_group_no_dob(self):
        p = make_patient(suco=self.suco, date_of_birth=None)
        self.assertIsNone(p.age)
        self.assertEqual(p.age_group, "—")

    def test_for_list_excludes_pii(self):
        make_patient(suco=self.suco, phone="77200000", address="Rua 1", emergency_contact="Jose 772")
        keys = set(Patient.objects.for_list()[0].keys())
        for pii in ("phone", "address", "emergency_contact", "first_name", "last_name"):
            self.assertNotIn(pii, keys)
        self.assertIn("patient_id", keys)

    def test_for_list_returns_values_not_models(self):
        make_patient(suco=self.suco)
        row = Patient.objects.for_list()[0]
        self.assertIsInstance(row, dict)
