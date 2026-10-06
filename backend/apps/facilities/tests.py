from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase
from django.urls import reverse

from apps.locations.models import AdministrativePost, Municipality, Suco

from .models import HealthFacility


class FacilityModelTests(TestCase):
    def setUp(self):
        muni = Municipality.objects.create(name="Dili", code="dili")
        post = AdministrativePost.objects.create(name="Nain Feto", code="nf", municipality=muni)
        self.suco = Suco.objects.create(name="Maliana", code="mal", administrative_post=post)
        self.facility = HealthFacility.objects.create(
            name="Postu Maliana", suco=self.suco, facility_type=HealthFacility.Types.HEALTH_POST
        )

    def test_defaults(self):
        self.assertTrue(self.facility.is_active)
        self.assertEqual(self.facility.facility_type, HealthFacility.Types.HEALTH_POST)

    def test_full_location_string(self):
        self.assertEqual(self.facility.full_location, "Maliana, Nain Feto, Dili")

    def test_facility_type_validated(self):
        with self.assertRaises(ValidationError):
            f = HealthFacility(name="X", suco=self.suco, facility_type="WELLNESS_CENTRE")
            f.full_clean()

    def test_suco_protected_from_delete(self):
        """A facility's suco must not disappear under it."""
        from django.db.models import ProtectedError

        with self.assertRaises(ProtectedError):
            self.suco.delete()

    def test_manager_active_filter(self):
        HealthFacility.objects.create(name="Closed", suco=self.suco, is_active=False)
        self.assertEqual(list(HealthFacility.objects.active()), [self.facility])

    def test_with_geo_uses_select_related(self):
        qs = HealthFacility.objects.with_geo()
        self.assertIn("suco", qs.query.select_related)


class FacilityAdminTests(TestCase):
    def test_admin_requires_login(self):
        response = self.client.get(reverse("admin:facilities_healthfacility_changelist"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/admin/login/", response.url)

    def test_admin_changelist_renders(self):
        user = get_user_model().objects.create_superuser("admin2", "b@example.com", "x-not-a-secret")
        self.client.force_login(user)
        response = self.client.get(reverse("admin:facilities_healthfacility_changelist"))
        self.assertEqual(response.status_code, 200)
