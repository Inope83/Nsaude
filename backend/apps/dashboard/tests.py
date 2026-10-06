from django.contrib.auth import get_user_model
from django.contrib.staticfiles import finders
from django.test import TestCase
from django.utils import translation

from apps.dashboard.templatetags.status_tags import _STATUS_MAP
from apps.emergencies.models import EmergencyCase
from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco
from apps.patients.models import Patient
from apps.referrals.models import Referral

User = get_user_model()


def build_world():
    """Two municipalities, three facilities, two patients, four users."""
    mun_a = Municipality.objects.create(name="Mun A", code="ma")
    posto_a = AdministrativePost.objects.create(name="Posto A", code="pa", municipality=mun_a)
    suco_a = Suco.objects.create(name="Suco A", code="sa", administrative_post=posto_a)
    mun_b = Municipality.objects.create(name="Mun B", code="mb")
    posto_b = AdministrativePost.objects.create(name="Posto B", code="pb", municipality=mun_b)
    suco_b = Suco.objects.create(name="Suco B", code="sb", administrative_post=posto_b)

    fa = HealthFacility.objects.create(name="Health Center A", suco=suco_a)
    fb = HealthFacility.objects.create(name="Hospital B", suco=suco_b)
    fc = HealthFacility.objects.create(name="Health Post C", suco=suco_b)

    pa = Patient.objects.create(
        first_name="Maria", last_name="Santos", sex=Patient.Sex.FEMALE,
        suco=suco_a, phone="772000001",
    )
    pb = Patient.objects.create(
        first_name="Joao", last_name="Silva", sex=Patient.Sex.MALE,
        suco=suco_b, phone="772000002",
    )

    root = User.objects.create_superuser("root", "r@example.com", "pw")
    admin = User.objects.create_user("admin", password="pw", role=User.Roles.SYSTEM_ADMIN)
    doc = User.objects.create_user("doc", password="pw", role=User.Roles.DOCTOR, facility=fa)
    hw = User.objects.create_user("hw", password="pw", role=User.Roles.HEALTH_WORKER)

    ea = EmergencyCase.objects.create(
        patient=pa, created_by=hw, facility=fa, severity=EmergencyCase.Severity.HIGH
    )
    eb = EmergencyCase.objects.create(
        patient=pb, created_by=hw, facility=fb, severity=EmergencyCase.Severity.CRITICAL
    )
    # r1: inbound to doctor's facility (in scope); r2: elsewhere (admin only)
    r1 = Referral.objects.create(
        patient=pa, referred_by=hw, source_facility=fb, destination_facility=fa,
        reason="Needs surgery", urgency=Referral.Urgency.URGENT,
    )
    r2 = Referral.objects.create(
        patient=pb, referred_by=hw, source_facility=fc, destination_facility=fb,
        reason="Needs imaging", urgency=Referral.Urgency.ROUTINE,
    )
    return {
        "suco_a": suco_a, "suco_b": suco_b,
        "fa": fa, "fb": fb, "fc": fc,
        "pa": pa, "pb": pb,
        "root": root, "admin": admin, "doc": doc, "hw": hw,
        "ea": ea, "eb": eb, "r1": r1, "r2": r2,
    }


class LayoutTests(TestCase):
    def test_anonymous_home_redirects_to_login(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_login_page_has_tokens_and_nav(self):
        response = self.client.get("/login/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "css/tokens.css")
        self.assertContains(response, "css/base.css")
        self.assertContains(response, "app-nav")

    def test_no_remote_resources(self):
        """Satellite constraint: no CDN/remote font/script in any page."""
        response = self.client.get("/login/")
        content = response.content.decode()
        self.assertNotIn("https://cdn", content)
        self.assertNotIn("https://fonts.", content)
        self.assertNotIn("http://cdn", content)

    def test_flash_and_language_blocks_present(self):
        response = self.client.get("/login/")
        self.assertContains(response, "/i18n/setlang/")
        self.assertContains(response, 'name="language"')

    def test_vendored_assets_exist(self):
        for path in (
            "vendor/bootstrap.min.css",
            "vendor/bootstrap.bundle.min.js",
            "vendor/bootstrap-icons/bootstrap-icons.min.css",
            "vendor/bootstrap-icons/fonts/bootstrap-icons.woff2",
            "css/tokens.css",
            "css/base.css",
        ):
            self.assertIsNotNone(finders.find(path), f"missing asset: {path}")


class DashboardAccessTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def test_anonymous_redirected_to_login(self):
        for url in ("/", "/patients/", "/emergencies/", "/referrals/"):
            with self.subTest(url=url):
                response = self.client.get(url)
                self.assertEqual(response.status_code, 302)
                self.assertIn("/login/", response.url)

    def test_health_worker_gets_403(self):
        self.client.login(username="hw", password="pw")
        for url in ("/", "/patients/", "/emergencies/", "/referrals/"):
            with self.subTest(url=url):
                response = self.client.get(url)
                self.assertEqual(response.status_code, 403)
                self.assertContains(response, "Ita la'os husia hakarak", status_code=403)

    def test_doctor_allowed_everywhere(self):
        self.client.login(username="doc", password="pw")
        for url in ("/", "/patients/", "/emergencies/", "/referrals/"):
            with self.subTest(url=url):
                self.assertEqual(self.client.get(url).status_code, 200)

    def test_admin_allowed_everywhere(self):
        self.client.login(username="admin", password="pw")
        for url in ("/", "/patients/", "/emergencies/", "/referrals/"):
            with self.subTest(url=url):
                self.assertEqual(self.client.get(url).status_code, 200)

    def test_superuser_allowed(self):
        self.client.login(username="root", password="pw")
        self.assertEqual(self.client.get("/").status_code, 200)


class OverviewTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def test_admin_scope_label_and_counts(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/")
        self.assertContains(response, "Fasilitates hotu")
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertContains(response, self.world["pb"].patient_id)

    def test_doctor_scoped_to_own_facility(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get("/")
        self.assertContains(response, self.world["fa"].name)
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertNotContains(response, self.world["pb"].patient_id)
        self.assertNotContains(response, self.world["fb"].name)

    def test_doctor_sees_only_inbound_referral(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get("/")
        self.assertContains(response, self.world["fa"].name)  # r1 destination
        self.assertNotContains(response, self.world["fb"].name)  # r2 not in scope

    def test_active_emergency_count_excludes_resolved(self):
        ea = self.world["ea"]
        ea.change_status(EmergencyCase.Status.RESOLVED, actor=self.world["doc"])
        self.client.login(username="doc", password="pw")
        response = self.client.get("/")
        # 1 (eb not in scope) → active count for doctor = 0
        self.assertContains(response, "La'os emergensia ativa")


class PatientListTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def test_doctor_sees_own_suco_patients_only(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get("/patients/")
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertNotContains(response, self.world["pb"].patient_id)

    def test_admin_sees_everyone(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/patients/")
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertContains(response, self.world["pb"].patient_id)

    def test_list_never_renders_phone(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/patients/")
        self.assertNotContains(response, "772000001")
        self.assertNotContains(response, "772000002")

    def test_search_by_patient_id(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/patients/", {"q": self.world["pa"].patient_id})
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertNotContains(response, self.world["pb"].patient_id)

    def test_search_no_match_shows_empty_state(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/patients/", {"q": "ZZZZZZ"})
        self.assertContains(response, "La'es paziente konet ho bukaian ida")

    def test_age_group_shown_not_dob(self):
        from datetime import date

        p = self.world["pa"]
        p.date_of_birth = date(1990, 5, 1)
        p.save()
        self.client.login(username="admin", password="pw")
        response = self.client.get("/patients/")
        self.assertContains(response, "18–64")
        self.assertNotContains(response, "1990-05-01")


class EmergencyListTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def test_doctor_scoped_to_own_facility(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get("/emergencies/")
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertNotContains(response, self.world["pb"].patient_id)
        self.assertContains(response, self.world["fa"].name)
        self.assertNotContains(response, self.world["fb"].name)

    def test_admin_sees_all_cases(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/emergencies/")
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertContains(response, self.world["pb"].patient_id)

    def test_status_filter(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/emergencies/", {"status": "OPEN"})
        self.assertContains(response, self.world["pa"].patient_id)
        response = self.client.get("/emergencies/", {"status": "RESOLVED"})
        self.assertContains(response, "La'os kazu ho esta ida")

    def test_invalid_status_ignored(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/emergencies/", {"status": "BOGUS"})
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, self.world["pa"].patient_id)

    def test_severity_and_status_badges_rendered(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/emergencies/")
        self.assertContains(response, "status-badge--error")     # HIGH
        self.assertContains(response, "status-badge--emergency")  # CRITICAL
        self.assertContains(response, "status-badge--warning")   # OPEN


class ReferralListTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def test_doctor_sees_sent_or_received_only(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get("/referrals/")
        self.assertContains(response, self.world["pa"].patient_id)  # r1 destination = FA
        self.assertNotContains(response, self.world["pb"].patient_id)  # r2 elsewhere

    def test_admin_sees_all_referrals(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/referrals/")
        self.assertContains(response, self.world["pa"].patient_id)
        self.assertContains(response, self.world["pb"].patient_id)

    def test_status_filter(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/referrals/", {"status": "PENDING"})
        self.assertContains(response, self.world["pa"].patient_id)
        response = self.client.get("/referrals/", {"status": "COMPLETED"})
        self.assertContains(response, "La'os referália ho esta ida")

    def test_urgency_badges_rendered(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/referrals/")
        self.assertContains(response, "status-badge--warning")   # URGENT
        self.assertContains(response, "status-badge--success")   # ROUTINE


class StatusBadgeTests(TestCase):
    def test_every_status_renders_tint_text_and_icon(self):
        """Mirrors mobile app_status.dart — every enum value has a visual."""
        for domain, values in _STATUS_MAP.items():
            for value, (modifier, icon, label) in values.items():
                html = self._render_badge(domain, value)
                self.assertIn(f"status-badge--{modifier}", html, f"{domain}/{value}")
                self.assertIn(icon, html, f"{domain}/{value}")
                self.assertIn(str(label), html, f"{domain}/{value}")

    def test_unknown_status_falls_back_to_neutral(self):
        html = self._render_badge("severity", "UNKNOWN")
        self.assertIn("status-badge--neutral", html)
        self.assertIn("UNKNOWN", html)

    def _render_badge(self, domain, value):
        from django.template import Context, Template

        tpl = Template("{% load status_tags %}{% status_badge d v %}")
        return tpl.render(Context({"d": domain, "v": value}))


class TokensCssTests(TestCase):
    def test_status_colors_match_mobile_tokens(self):
        css = finders.find("css/tokens.css")
        content = open(css, encoding="utf-8").read()
        expected = {
            "--color-primary": "#6366F1",
            "--color-primary-pressed": "#4F46E5",
            "--color-emergency": "#DC2626",
            "--tint-success": "#ECFDF5",
            "--text-success": "#047857",
            "--tint-warning": "#FFFBEB",
            "--text-warning": "#B45309",
            "--tint-error": "#FEF2F2",
            "--text-error": "#B91C1C",
            "--tint-info": "#EEF2FF",
            "--text-info": "#4338CA",
            "--color-background": "#FAFAFA",
            "--color-surface": "#FFFFFF",
        }
        for token, value in expected.items():
            self.assertIn(f"{token}: {value}", content, f"{token} must be {value}")

    def test_every_css_file_uses_only_variables_from_tokens(self):
        """base.css must reference tokens, not hardcode palette hexes."""
        tokens = open(finders.find("css/tokens.css"), encoding="utf-8").read()
        base = open(finders.find("css/base.css"), encoding="utf-8").read()
        import re

        token_names = set(re.findall(r"(--[\w-]+):", tokens))
        referenced = set(re.findall(r"var\((--[\w-]+)", base))
        # base.css may use our tokens or Bootstrap's own --bs-* variables it overrides
        unknown = {v for v in referenced if not v.startswith("--bs-")} - token_names
        self.assertEqual(unknown, set(), f"unknown tokens referenced: {unknown}")
        # no genesis palette hexes hardcoded in base.css
        for hexval in ("#6366F1", "#4F46E5", "#FAFAFA", "#DC2626", "#EF4444"):
            self.assertNotIn(hexval, base)


class PatientDetailTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()
        from django.utils import timezone
        from apps.monitoring.models import PatientMonitoringRecord

        cls.rec_a = PatientMonitoringRecord.objects.create(
            patient=cls.world["pa"],
            recorded_by=cls.world["hw"],
            recorded_at=timezone.now(),
            temperature=37.5,
            heart_rate=88,
            symptoms="tuse, hotu",
        )
        cls.rec_b = PatientMonitoringRecord.objects.create(
            patient=cls.world["pb"],
            recorded_by=cls.world["hw"],
            recorded_at=timezone.now(),
            temperature=39.1,
        )

    def test_anonymous_redirected_to_login(self):
        url = f"/patients/{self.world['pa'].id}/"
        response = self.client.get(url)
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_health_worker_403(self):
        self.client.login(username="hw", password="pw")
        response = self.client.get(f"/patients/{self.world['pa'].id}/")
        self.assertContains(response, "Ita la'os husia hakarak", status_code=403)

    def test_doctor_in_scope_shows_full_record(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get(f"/patients/{self.world['pa'].id}/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Maria Santos")          # name (detail-level data)
        self.assertContains(response, "772000001")             # phone allowed on detail
        self.assertContains(response, self.world["pa"].patient_id)

    def test_doctor_out_of_scope_404(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get(f"/patients/{self.world['pb'].id}/")
        self.assertEqual(response.status_code, 404)

    def test_admin_can_open_any_patient(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get(f"/patients/{self.world['pb'].id}/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Joao Silva")

    def test_monitoring_timeline_newest_first(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get(f"/patients/{self.world['pa'].id}/")
        self.assertContains(response, "37.5")
        self.assertContains(response, "tuse, hotu")
        self.assertNotContains(response, "39.1")  # other patient's record

    def test_empty_monitoring_state(self):
        self.client.login(username="admin", password="pw")
        rec = self.rec_a
        rec.delete()
        self.rec_b.delete()
        response = self.client.get(f"/patients/{self.world['pa'].id}/")
        self.assertContains(response, "La'os rekordi monitorizasaun")

    def test_inactive_patient_still_viewable(self):
        p = self.world["pa"]
        p.is_active = False
        p.save()
        self.client.login(username="doc", password="pw")
        response = self.client.get(f"/patients/{p.id}/")
        self.assertContains(response, "Rekordi ne'e la'ativu.")

    def test_patient_list_links_to_detail(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/patients/")
        self.assertContains(response, f"/patients/{self.world['pa'].id}/")


class FacilityListTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def test_access_matrix(self):
        self.client.login(username="hw", password="pw")
        self.assertEqual(self.client.get("/facilities/").status_code, 403)
        self.client.logout()
        response = self.client.get("/facilities/")
        self.assertEqual(response.status_code, 302)
        self.client.login(username="doc", password="pw")
        self.assertEqual(self.client.get("/facilities/").status_code, 200)
        self.client.logout()
        self.client.login(username="admin", password="pw")
        self.assertEqual(self.client.get("/facilities/").status_code, 200)

    def test_lists_all_active_facilities(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/facilities/")
        for name in ("Health Center A", "Hospital B", "Health Post C"):
            self.assertContains(response, name)

    def test_inactive_facility_hidden(self):
        self.world["fa"].is_active = False
        self.world["fa"].save()
        self.client.login(username="admin", password="pw")
        response = self.client.get("/facilities/")
        self.assertNotContains(response, "Health Center A")
        self.assertContains(response, "Hospital B")

    def test_municipality_filter(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/facilities/", {"municipality": "ma"})
        self.assertContains(response, "Health Center A")
        self.assertNotContains(response, "Hospital B")

    def test_suco_filter(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/facilities/", {"suco": "sb"})
        self.assertContains(response, "Hospital B")
        self.assertContains(response, "Health Post C")
        self.assertNotContains(response, "Health Center A")

    def test_invalid_filter_codes_ignored(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get(
            "/facilities/", {"municipality": "NOPE", "suco": "NOPE"}
        )
        self.assertContains(response, "Health Center A")
        self.assertContains(response, "Hospital B")

    def test_nav_links_resolve_when_logged_in(self):
        self.client.login(username="doc", password="pw")
        response = self.client.get("/")
        self.assertContains(response, "/facilities/")
        self.assertContains(response, "/sync/")


class SyncStatusTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()

    def _heartbeat(self, facility, pending=0, hours_ago=None):
        from django.utils import timezone
        from apps.syncapp.models import SyncHeartbeat

        hb = SyncHeartbeat.objects.create(
            facility=facility, reported_by=self.world["hw"], pending_count=pending
        )
        if hours_ago:
            from datetime import timedelta

            SyncHeartbeat.objects.filter(pk=hb.pk).update(
                created_at=timezone.now() - timedelta(hours=hours_ago)
            )
            hb.refresh_from_db()
        return hb

    def test_access_matrix(self):
        self.client.login(username="hw", password="pw")
        self.assertEqual(self.client.get("/sync/").status_code, 403)
        self.client.logout()
        response = self.client.get("/sync/")
        self.assertEqual(response.status_code, 302)
        self.client.login(username="admin", password="pw")
        self.assertEqual(self.client.get("/sync/").status_code, 200)

    def test_facilities_without_heartbeat_show_never_synced(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/sync/")
        self.assertContains(response, "Health Center A")
        self.assertContains(response, "NEVER SYNCED")

    def test_latest_heartbeat_wins(self):
        self._heartbeat(self.world["fa"], pending=1, hours_ago=5)
        self._heartbeat(self.world["fa"], pending=9, hours_ago=1)
        self.client.login(username="admin", password="pw")
        response = self.client.get("/sync/")
        self.assertContains(response, "9")
        self.assertNotContains(response, "<td>1</td>")

    def test_stale_after_24_hours(self):
        self._heartbeat(self.world["fa"], pending=0, hours_ago=48)
        self.client.login(username="admin", password="pw")
        response = self.client.get("/sync/")
        self.assertContains(response, "STALE")

    def test_fresh_heartbeat_not_stale(self):
        self._heartbeat(self.world["fa"], pending=0, hours_ago=2)
        self.client.login(username="admin", password="pw")
        response = self.client.get("/sync/")
        self.assertNotContains(response, "STALE")

    def test_pending_banner(self):
        self._heartbeat(self.world["fa"], pending=7, hours_ago=1)
        self.client.login(username="admin", password="pw")
        response = self.client.get("/sync/")
        self.assertContains(response, "7 rekordi he'in sincronizasaun iha fasilitades tomak.")

    def test_orphan_heartbeat_ignored(self):
        from apps.syncapp.models import SyncHeartbeat

        SyncHeartbeat.objects.create(facility=None, reported_by=None, pending_count=5)
        self.client.login(username="admin", password="pw")
        self.assertEqual(self.client.get("/sync/").status_code, 200)


class MapViewTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.world = build_world()
        # coordinates: fa + fb have them, fc does not
        from apps.facilities.models import HealthFacility

        HealthFacility.objects.filter(pk=cls.world["fa"].pk).update(latitude=-8.9, longitude=125.6)
        HealthFacility.objects.filter(pk=cls.world["fb"].pk).update(latitude=-8.5, longitude=126.0)

    def test_access_matrix(self):
        self.client.login(username="hw", password="pw")
        self.assertEqual(self.client.get("/map/").status_code, 403)
        self.client.logout()
        response = self.client.get("/map/")
        self.assertEqual(response.status_code, 302)
        self.client.login(username="doc", password="pw")
        self.assertEqual(self.client.get("/map/").status_code, 200)

    def test_leaflet_vendored_not_cdn(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/map/")
        self.assertContains(response, "vendor/leaflet/leaflet.js")
        self.assertContains(response, "vendor/leaflet/leaflet.css")
        content = response.content.decode()
        self.assertNotIn("https://cdn", content)
        self.assertNotIn("unpkg.com", content)

    def test_no_patient_identifiers_on_map(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/map/")
        self.assertNotContains(response, self.world["pa"].patient_id)
        self.assertNotContains(response, self.world["pb"].patient_id)
        self.assertNotContains(response, "Maria")
        self.assertNotContains(response, "772000001")

    def test_facility_without_coordinates_reported(self):
        self.client.login(username="admin", password="pw")
        response = self.client.get("/map/")
        # fc has no coordinates
        self.assertContains(response, "1 fasilitade ativa la'os koordinadas")

    def test_emergency_counts_scoped_per_role(self):
        # admin: sees CRITICAL count (eb at fb); doctor: only own facility (HIGH)
        self.client.login(username="admin", password="pw")
        response = self.client.get("/map/")
        content = response.content.decode()
        self.assertIn('"max_severity": "CRITICAL"', content)
        self.assertIn('"max_severity": "HIGH"', content)

        self.client.logout()
        self.client.login(username="doc", password="pw")
        content = self.client.get("/map/").content.decode()
        self.assertIn('"max_severity": "HIGH"', content)
        self.assertNotIn("CRITICAL", content)

    def test_sync_state_in_payload(self):
        from django.utils import timezone
        from apps.syncapp.models import SyncHeartbeat

        SyncHeartbeat.objects.create(
            facility=self.world["fa"], reported_by=self.world["hw"], pending_count=2
        )
        self.client.login(username="admin", password="pw")
        content = self.client.get("/map/").content.decode()
        self.assertIn('"sync": "fresh"', content)
        # fb and fc never synced
        self.assertIn('"sync": "never"', content)


class I18nTests(TestCase):
    def test_tetum_catalog_serves_ui_strings(self):
        from django.utils.translation import gettext

        with translation.override("tet"):
            self.assertEqual(gettext("Overview"), "Resumen")
            self.assertEqual(gettext("Log out"), "Sai")
            self.assertEqual(gettext("Female"), "Feto")
        with translation.override("en"):
            self.assertEqual(gettext("Overview"), "Overview")

    def test_status_codes_stay_identical_in_tetum(self):
        from django.utils.translation import gettext

        with translation.override("tet"):
            for code in ("LOW", "HIGH", "CRITICAL", "OPEN", "RESOLVED", "PENDING SYNC"):
                self.assertEqual(gettext(code), code)

    def test_pages_render_in_tetum(self):
        response = self.client.get("/login/")
        self.assertContains(response, 'lang="tet"')
        self.assertContains(response, "Platafórma saúde")
