from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import path
from django.views import View

from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco

from .mixins import RoleRequiredMixin

User = get_user_model()


class ProtectedView(RoleRequiredMixin, View):
    allowed_roles = ("DOCTOR",)

    def get(self, request):
        from django.http import HttpResponse

        return HttpResponse("secret data")


urlpatterns = [path("protected/", ProtectedView.as_view())]


def _make_facility():
    suco = Suco.objects.create(
        name="S",
        code="s",
        administrative_post=AdministrativePost.objects.create(
            name="P", code="p", municipality=Municipality.objects.create(name="M", code="m")
        ),
    )
    return HealthFacility.objects.create(name="F", suco=suco)


@override_settings(ROOT_URLCONF=__name__)
class RoleRequiredMixinTests(TestCase):
    """Role matrix for a DOCTOR-only view: allowed and forbidden paths."""

    @classmethod
    def setUpTestData(cls):
        cls.facility = _make_facility()
        cls.anon_ok_url = "/protected/"
        User.objects.create_user("hw", password="x", role=User.Roles.HEALTH_WORKER)
        User.objects.create_user(
            "doc", password="x", role=User.Roles.DOCTOR, facility=cls.facility
        )
        User.objects.create_user("sys", password="x", role=User.Roles.SYSTEM_ADMIN)
        User.objects.create_superuser("root", "r@example.com", "x")

    def test_anonymous_redirected_to_login(self):
        response = self.client.get(self.anon_ok_url)
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_wrong_role_gets_403_page(self):
        self.client.login(username="hw", password="x")
        response = self.client.get(self.anon_ok_url)
        self.assertEqual(response.status_code, 403)
        content = response.content.decode()
        self.assertIn("Ita la'os husia hakarak", content)
        self.assertIn("shield-lock", content)

    def test_doctor_allowed(self):
        self.client.login(username="doc", password="x")
        response = self.client.get(self.anon_ok_url)
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "secret data")

    def test_system_admin_allowed(self):
        self.client.login(username="sys", password="x")
        self.assertEqual(self.client.get(self.anon_ok_url).status_code, 200)

    def test_superuser_allowed(self):
        self.client.login(username="root", password="x")
        self.assertEqual(self.client.get(self.anon_ok_url).status_code, 200)


class UserModelTests(TestCase):
    def test_defaults(self):
        user = User.objects.create_user("u", password="x")
        self.assertEqual(user.role, User.Roles.HEALTH_WORKER)
        self.assertIsNone(user.facility)
        self.assertFalse(user.is_system_admin)
        self.assertTrue(user.is_health_worker)
        self.assertEqual(user.role_label, "Trabaladór saúde")

    def test_role_helpers(self):
        doctor = User.objects.create_user("d", password="x", role=User.Roles.DOCTOR)
        self.assertTrue(doctor.is_doctor)
        self.assertFalse(doctor.is_system_admin)
        sys_admin = User.objects.create_user("s", password="x", role=User.Roles.SYSTEM_ADMIN)
        self.assertTrue(sys_admin.is_system_admin)

    def test_str_contains_role(self):
        user = User.objects.create_user("nurse", password="x", role=User.Roles.DOCTOR)
        self.assertIn("DOCTOR", str(user))


class AuthFlowTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        User.objects.create_user("doc", password="correct", role=User.Roles.DOCTOR)

    def test_login_page_renders(self):
        response = self.client.get("/login/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'name="username"')
        self.assertContains(response, 'name="password"')

    def test_login_wrong_password_shows_error(self):
        response = self.client.post("/login/", {"username": "doc", "password": "wrong"})
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Utilizador ka sandu trókadu")

    def test_login_success_redirects_home(self):
        response = self.client.post("/login/", {"username": "doc", "password": "correct"})
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, "/")

    def test_authenticated_user_redirected_away_from_login(self):
        self.client.login(username="doc", password="correct")
        response = self.client.get("/login/")
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, "/")

    def test_logout_via_post(self):
        self.client.login(username="doc", password="correct")
        response = self.client.post("/logout/")
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, "/login/")

    def test_logout_get_not_allowed(self):
        self.client.login(username="doc", password="correct")
        response = self.client.get("/logout/")
        self.assertEqual(response.status_code, 405)
