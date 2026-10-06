from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import TestCase
from django.urls import reverse

from .models import AdministrativePost, Municipality, Suco


class LocationModelTests(TestCase):
    def setUp(self):
        self.muni = Municipality.objects.create(name="Dili", code="dili")
        self.post = AdministrativePost.objects.create(
            name="Nain Feto", code="nain-feto", municipality=self.muni
        )
        self.suco = Suco.objects.create(
            name="Maliana", code="maliana", administrative_post=self.post
        )

    def test_str_includes_code(self):
        self.assertIn("dili", str(self.post))
        self.assertIn("dili", str(self.suco))

    def test_code_is_unique(self):
        with self.assertRaises(IntegrityError):
            Municipality.objects.create(name="Dili 2", code="dili")

    def test_latitude_range_validated(self):
        with self.assertRaises(ValidationError):
            m = Municipality(name="X", code="x", latitude=91)
            m.full_clean()

    def test_cascade_post_delete_removes_sucos(self):
        self.post.delete()
        self.assertFalse(Suco.objects.exists())

    def test_hierarchy_ordering(self):
        Municipality.objects.create(name="Ainaro", code="ainaro")
        names = list(Municipality.objects.values_list("name", flat=True))
        self.assertEqual(names, ["Ainaro", "Dili"])


class LocationAdminTests(TestCase):
    def test_admin_requires_login(self):
        for name in ("locations_municipality_changelist", "locations_suco_changelist"):
            response = self.client.get(reverse(f"admin:{name}"))
            self.assertEqual(response.status_code, 302)
            self.assertIn("/admin/login/", response.url)

    def test_admin_changelists_render_for_superuser(self):
        from django.contrib.auth import get_user_model

        Municipality.objects.create(name="Dili", code="dili")
        self.client.force_login(
            get_user_model().objects.create_superuser("admin", "a@example.com", "test-not-a-secret")
        )
        for name in (
            "locations_municipality_changelist",
            "locations_administrativepost_changelist",
            "locations_suco_changelist",
        ):
            response = self.client.get(reverse(f"admin:{name}"))
            self.assertEqual(response.status_code, 200, name)
