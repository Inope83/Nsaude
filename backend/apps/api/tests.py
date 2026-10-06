from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco

User = get_user_model()


def build_geo():
    mun = Municipality.objects.create(name="Dili", code="dili")
    post = AdministrativePost.objects.create(name="Dom Aleixo", code="da", municipality=mun)
    suco = Suco.objects.create(name="Comoro", code="com", administrative_post=post)
    return mun, post, suco


class AuthEndpointTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        User.objects.create_user("worker", password="secret-pass", role=User.Roles.HEALTH_WORKER)

    def setUp(self):
        self.client = APIClient()

    def test_login_returns_jwt_pair(self):
        response = self.client.post(
            "/api/auth/login/", {"username": "worker", "password": "secret-pass"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)

    def test_login_rejects_bad_password(self):
        response = self.client.post(
            "/api/auth/login/", {"username": "worker", "password": "nope"}
        )
        self.assertEqual(response.status_code, 401)

    def test_refresh_rotates_token(self):
        login = self.client.post(
            "/api/auth/login/", {"username": "worker", "password": "secret-pass"}
        )
        response = self.client.post(
            "/api/auth/refresh/", {"refresh": login.data["refresh"]}
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)

    def test_me_requires_auth(self):
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 401)

    def test_me_returns_profile(self):
        login = self.client.post(
            "/api/auth/login/", {"username": "worker", "password": "secret-pass"}
        )
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        response = self.client.get("/api/auth/me/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["username"], "worker")
        self.assertEqual(response.data["role"], "HEALTH_WORKER")
        self.assertIsNone(response.data["facility"])


class GeographyEndpointTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.mun, cls.post, cls.suco = build_geo()

    def setUp(self):
        self.client = APIClient()

    def test_municipalities_open_without_auth(self):
        response = self.client.get("/api/municipalities/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["code"], "dili")

    def test_administrative_posts_filter_by_municipality(self):
        response = self.client.get(
            "/api/administrative-posts/", {"municipality": "dili"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)
        response = self.client.get(
            "/api/administrative-posts/", {"municipality": "nope"}
        )
        self.assertEqual(response.data["count"], 0)

    def test_sucos_filter_by_post(self):
        response = self.client.get("/api/sucos/", {"administrative_post": "da"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)


class FacilityEndpointTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.mun, cls.post, cls.suco = build_geo()
        cls.facility = HealthFacility.objects.create(name="Clinica Teste", suco=cls.suco)
        cls.hidden = HealthFacility.objects.create(
            name="Fechada", suco=cls.suco, is_active=False
        )
        cls.worker = User.objects.create_user(
            "worker2", password="pw2", role=User.Roles.HEALTH_WORKER
        )

    def setUp(self):
        self.client = APIClient()

    def test_facilities_require_auth(self):
        response = self.client.get("/api/facilities/")
        self.assertEqual(response.status_code, 401)

    def test_facilities_list_authenticated(self):
        self.client.force_authenticate(user=self.worker)
        response = self.client.get("/api/facilities/")
        self.assertEqual(response.status_code, 200)
        names = [f["name"] for f in response.data["results"]]
        self.assertIn("Clinica Teste", names)
        self.assertNotIn("Fechada", names)  # inactive excluded

    def test_facility_detail(self):
        self.client.force_authenticate(user=self.worker)
        response = self.client.get(f"/api/facilities/{self.facility.id}/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["municipality"], "Dili")
        self.assertEqual(response.data["suco_name"], "Comoro")

    def test_facility_detail_404(self):
        self.client.force_authenticate(user=self.worker)
        response = self.client.get("/api/facilities/99999/")
        self.assertEqual(response.status_code, 404)


class PatientApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        from apps.patients.models import Patient

        _, _, suco_a = build_geo()
        mun_b = Municipality.objects.create(name="Baucau", code="bau")
        post_b = AdministrativePost.objects.create(name="Venilale", code="ven", municipality=mun_b)
        suco_b = Suco.objects.create(name="Lata", code="lata", administrative_post=post_b)
        cls.suco_a, cls.suco_b = suco_a, suco_b
        cls.fa = HealthFacility.objects.create(name="FA", suco=suco_a)
        cls.fb = HealthFacility.objects.create(name="FB", suco=suco_b)
        cls.patient_a = Patient.objects.create(
            first_name="Ana", last_name="Costa", sex=Patient.Sex.FEMALE,
            suco=suco_a, phone="772111111",
        )
        cls.patient_b = Patient.objects.create(
            first_name="Bruno", last_name="Ximenes", sex=Patient.Sex.MALE,
            suco=suco_b, phone="772222222",
        )
        cls.admin = User.objects.create_user("admin", password="pw", role=User.Roles.SYSTEM_ADMIN)
        cls.doc = User.objects.create_user(
            "doc", password="pw", role=User.Roles.DOCTOR, facility=cls.fa
        )
        cls.hw = User.objects.create_user(
            "hw", password="pw", role=User.Roles.HEALTH_WORKER, facility=cls.fa
        )

    def setUp(self):
        self.client = APIClient()

    def test_requires_auth(self):
        self.assertEqual(self.client.get("/api/patients/").status_code, 401)

    def test_list_excludes_contact_fields(self):
        self.client.force_authenticate(user=self.admin)
        row = self.client.get("/api/patients/").data["results"][0]
        for field in ("phone", "address", "emergency_contact"):
            self.assertNotIn(field, row)
        self.assertIn("patient_id", row)
        self.assertIn("first_name", row)

    def test_detail_includes_contact_fields(self):
        self.client.force_authenticate(user=self.admin)
        row = self.client.get(f"/api/patients/{self.patient_a.id}/").data
        self.assertEqual(row["phone"], "772111111")

    def test_scoping_admin_sees_all_doc_sees_own_suco(self):
        self.client.force_authenticate(user=self.admin)
        self.assertEqual(self.client.get("/api/patients/").data["count"], 2)
        self.client.force_authenticate(user=self.doc)
        results = self.client.get("/api/patients/").data["results"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["patient_id"], self.patient_a.patient_id)

    def test_out_of_scope_detail_404(self):
        self.client.force_authenticate(user=self.doc)
        self.assertEqual(
            self.client.get(f"/api/patients/{self.patient_b.id}/").status_code, 404
        )

    def test_create_returns_201_with_generated_id(self):
        import uuid

        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            "/api/patients/",
            {
                "client_uuid": str(uuid.uuid4()),
                "first_name": "Cruz",
                "last_name": "Fernandes",
                "sex": "M",
                "suco": self.suco_a.id,
            },
        )
        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.data["patient_id"].startswith("PT-"))

    def test_create_idempotent_on_client_uuid(self):
        import uuid
        from apps.patients.models import Patient

        token = str(uuid.uuid4())
        payload = {
            "client_uuid": token,
            "first_name": "Duplicado",
            "last_name": "Teste",
            "sex": "F",
            "suco": self.suco_a.id,
        }
        self.client.force_authenticate(user=self.hw)
        first = self.client.post("/api/patients/", payload)
        second = self.client.post("/api/patients/", payload)
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.data["id"], second.data["id"])
        self.assertEqual(Patient.objects.filter(client_uuid=token).count(), 1)

    def test_create_missing_sex_400(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            "/api/patients/", {"first_name": "X", "last_name": "Y", "suco": self.suco_a.id}
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("sex", response.data)

    def test_patch_out_of_scope_404(self):
        self.client.force_authenticate(user=self.doc)
        response = self.client.patch(
            f"/api/patients/{self.patient_b.id}/", {"first_name": "Hack"}
        )
        self.assertEqual(response.status_code, 404)

    def test_patch_in_scope(self):
        self.client.force_authenticate(user=self.doc)
        response = self.client.patch(
            f"/api/patients/{self.patient_a.id}/", {"address": "Rua X"}
        )
        self.assertEqual(response.status_code, 200)
        self.patient_a.refresh_from_db()
        self.assertEqual(self.patient_a.address, "Rua X")

    def test_updated_after_filter(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(
            "/api/patients/", {"updated_after": "2100-01-01T00:00:00Z"}
        )
        self.assertEqual(response.data["count"], 0)
        response = self.client.get(
            "/api/patients/", {"updated_after": "2000-01-01T00:00:00Z"}
        )
        self.assertEqual(response.data["count"], 2)

    def test_invalid_updated_after_400(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get("/api/patients/", {"updated_after": "yesterday"})
        self.assertEqual(response.status_code, 400)

    def test_search_q(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get("/api/patients/", {"q": "Bruno"})
        self.assertEqual(response.data["count"], 1)


class MonitoringApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        from django.utils import timezone
        from apps.monitoring.models import PatientMonitoringRecord
        from apps.patients.models import Patient

        _, _, suco_a = build_geo()
        cls.suco_a = suco_a
        cls.fa = HealthFacility.objects.create(name="FA", suco=suco_a)
        cls.patient = Patient.objects.create(
            first_name="Ana", last_name="Costa", sex=Patient.Sex.FEMALE, suco=suco_a
        )
        cls.hw = User.objects.create_user(
            "hw", password="pw", role=User.Roles.HEALTH_WORKER, facility=cls.fa
        )
        cls.admin = User.objects.create_user(
            "admin", password="pw", role=User.Roles.SYSTEM_ADMIN
        )
        cls.record = PatientMonitoringRecord.objects.create(
            patient=cls.patient,
            recorded_by=cls.hw,
            recorded_at=timezone.now(),
            temperature=36.8,
        )

    def setUp(self):
        self.client = APIClient()

    def test_list_records(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(f"/api/patients/{self.patient.id}/monitoring/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["recorded_by"], "hw")

    def test_recorded_at_defaults_to_now(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            f"/api/patients/{self.patient.id}/monitoring/", {"heart_rate": 70}
        )
        self.assertEqual(response.status_code, 201)
        self.assertIsNotNone(response.data["recorded_at"])

    def test_recorded_by_not_spoofable(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            f"/api/patients/{self.patient.id}/monitoring/",
            {"heart_rate": 71, "recorded_by": "admin"},
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["recorded_by"], "hw")

    def test_invalid_temperature_400(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            f"/api/patients/{self.patient.id}/monitoring/", {"temperature": 99.0}
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("temperature", response.data)

    def test_future_recorded_at_400(self):
        from django.utils import timezone

        self.client.force_authenticate(user=self.hw)
        future = (timezone.now() + timezone.timedelta(days=1)).isoformat()
        response = self.client.post(
            f"/api/patients/{self.patient.id}/monitoring/",
            {"heart_rate": 60, "recorded_at": future},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("recorded_at", response.data)

    def test_monitoring_create_idempotent(self):
        import uuid
        from apps.monitoring.models import PatientMonitoringRecord

        token = str(uuid.uuid4())
        self.client.force_authenticate(user=self.hw)
        payload = {"client_uuid": token, "heart_rate": 66}
        first = self.client.post(f"/api/patients/{self.patient.id}/monitoring/", payload)
        second = self.client.post(f"/api/patients/{self.patient.id}/monitoring/", payload)
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(PatientMonitoringRecord.objects.filter(client_uuid=token).count(), 1)

    def test_out_of_scope_patient_404(self):
        mun_b = Municipality.objects.create(name="Baucau2", code="bau2")
        post_b = AdministrativePost.objects.create(name="P2", code="p2", municipality=mun_b)
        suco_b = Suco.objects.create(name="S2", code="s2", administrative_post=post_b)
        from apps.patients.models import Patient

        other = Patient.objects.create(
            first_name="O", last_name="P", sex=Patient.Sex.MALE, suco=suco_b
        )
        self.client.force_authenticate(user=self.hw)
        self.assertEqual(
            self.client.get(f"/api/patients/{other.id}/monitoring/").status_code, 404
        )

    def test_recorded_after_filter(self):
        self.client.force_authenticate(user=self.admin)
        base = f"/api/patients/{self.patient.id}/monitoring/"
        response = self.client.get(base, {"recorded_after": "2100-01-01T00:00:00Z"})
        self.assertEqual(response.data["count"], 0)
        response = self.client.get(base, {"recorded_after": "2000-01-01T00:00:00Z"})
        self.assertEqual(response.data["count"], 1)


class EmergencyApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        from apps.emergencies.models import EmergencyCase
        from apps.patients.models import Patient

        _, _, suco_a = build_geo()
        cls.suco_a = suco_a
        cls.fa = HealthFacility.objects.create(name="FA", suco=suco_a)
        cls.fb = HealthFacility.objects.create(name="FB", suco=suco_a)
        cls.patient = Patient.objects.create(
            first_name="Ana", last_name="Costa", sex=Patient.Sex.FEMALE, suco=suco_a
        )
        cls.hw = User.objects.create_user(
            "hw", password="pw", role=User.Roles.HEALTH_WORKER, facility=cls.fa
        )
        cls.doc = User.objects.create_user(
            "doc", password="pw", role=User.Roles.DOCTOR, facility=cls.fa
        )
        cls.admin = User.objects.create_user(
            "admin", password="pw", role=User.Roles.SYSTEM_ADMIN
        )
        cls.case_a = EmergencyCase.objects.create(
            patient=cls.patient, created_by=cls.hw, facility=cls.fa,
            severity=EmergencyCase.Severity.HIGH,
        )
        cls.case_b = EmergencyCase.objects.create(
            patient=cls.patient, created_by=cls.hw, facility=cls.fb,
            severity=EmergencyCase.Severity.LOW,
        )

    def setUp(self):
        self.client = APIClient()

    def test_requires_auth(self):
        self.assertEqual(self.client.get("/api/emergencies/").status_code, 401)

    def test_scoped_list(self):
        self.client.force_authenticate(user=self.doc)
        results = self.client.get("/api/emergencies/").data["results"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["facility"], self.fa.id)
        self.client.force_authenticate(user=self.admin)
        self.assertEqual(self.client.get("/api/emergencies/").data["count"], 2)

    def test_status_filter(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get("/api/emergencies/", {"status": "OPEN"})
        self.assertEqual(response.data["count"], 2)
        response = self.client.get("/api/emergencies/", {"status": "BOGUS"})
        self.assertEqual(response.data["count"], 2)  # ignored

    def test_create_defaults_own_facility_and_creator(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            "/api/emergencies/",
            {"patient": self.patient.id, "severity": "CRITICAL"},
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["facility"], self.fa.id)
        self.assertEqual(response.data["created_by"], "hw")
        self.assertEqual(response.data["status"], "OPEN")

    def test_create_for_other_facility_forbidden(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            "/api/emergencies/",
            {"patient": self.patient.id, "severity": "HIGH", "facility": self.fb.id},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("facility", response.data)

    def test_patch_status_writes_audit_event(self):
        from apps.audit.models import StatusEvent

        self.client.force_authenticate(user=self.doc)
        response = self.client.patch(
            f"/api/emergencies/{self.case_a.id}/", {"status": "ESCALATED"}
        )
        self.assertEqual(response.status_code, 200)
        event = StatusEvent.objects.get(emergency=self.case_a)
        self.assertEqual(event.old_status, "OPEN")
        self.assertEqual(event.new_status, "ESCALATED")
        self.assertEqual(event.actor, self.doc)

    def test_patch_out_of_scope_404(self):
        self.client.force_authenticate(user=self.doc)
        response = self.client.patch(
            f"/api/emergencies/{self.case_b.id}/", {"status": "RESOLVED"}
        )
        self.assertEqual(response.status_code, 404)

    def test_create_idempotent(self):
        import uuid

        self.client.force_authenticate(user=self.hw)
        payload = {
            "client_uuid": str(uuid.uuid4()),
            "patient": self.patient.id,
            "severity": "MEDIUM",
        }
        first = self.client.post("/api/emergencies/", payload)
        second = self.client.post("/api/emergencies/", payload)
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.data["id"], second.data["id"])


class ReferralApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        from apps.patients.models import Patient
        from apps.referrals.models import Referral

        _, _, suco_a = build_geo()
        cls.fa = HealthFacility.objects.create(name="FA", suco=suco_a)
        cls.fb = HealthFacility.objects.create(name="FB", suco=suco_a)
        cls.patient = Patient.objects.create(
            first_name="Ana", last_name="Costa", sex=Patient.Sex.FEMALE, suco=suco_a
        )
        cls.hw = User.objects.create_user(
            "hw", password="pw", role=User.Roles.HEALTH_WORKER, facility=cls.fa
        )
        cls.doc = User.objects.create_user(
            "doc", password="pw", role=User.Roles.DOCTOR, facility=cls.fa
        )
        cls.admin = User.objects.create_user(
            "admin", password="pw", role=User.Roles.SYSTEM_ADMIN
        )
        cls.outbound = Referral.objects.create(
            patient=cls.patient, referred_by=cls.hw, source_facility=cls.fa,
            destination_facility=cls.fb, reason="Imaging",
            urgency=Referral.Urgency.URGENT,
        )
        cls.unrelated = Referral.objects.create(
            patient=cls.patient, referred_by=cls.hw, source_facility=cls.fb,
            destination_facility=cls.fb, reason="Internal",
            urgency=Referral.Urgency.ROUTINE,
        )

    def setUp(self):
        self.client = APIClient()

    def test_scoped_list_includes_inbound_and_outbound(self):
        self.client.force_authenticate(user=self.doc)
        results = self.client.get("/api/referrals/").data["results"]
        self.assertEqual(len(results), 1)  # outbound only (fa involved)
        self.client.force_authenticate(user=self.admin)
        self.assertEqual(self.client.get("/api/referrals/").data["count"], 2)

    def test_create_defaults_source_and_sets_creator(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            "/api/referrals/",
            {
                "patient": self.patient.id,
                "destination_facility": self.fb.id,
                "reason": "Needs specialist",
                "urgency": "EMERGENCY",
            },
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["source_facility"], self.fa.id)
        self.assertEqual(response.data["referred_by"], "hw")
        self.assertEqual(response.data["status"], "PENDING")

    def test_same_source_destination_400(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post(
            "/api/referrals/",
            {
                "patient": self.patient.id,
                "destination_facility": self.fa.id,
                "reason": "x",
                "urgency": "ROUTINE",
            },
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("destination_facility", response.data)

    def test_patch_status_writes_audit_event(self):
        from apps.audit.models import StatusEvent

        self.client.force_authenticate(user=self.doc)
        response = self.client.patch(
            f"/api/referrals/{self.outbound.id}/", {"status": "ACCEPTED"}
        )
        self.assertEqual(response.status_code, 200)
        event = StatusEvent.objects.get(referral=self.outbound)
        self.assertEqual(event.old_status, "PENDING")
        self.assertEqual(event.new_status, "ACCEPTED")

    def test_create_idempotent(self):
        import uuid

        self.client.force_authenticate(user=self.hw)
        payload = {
            "client_uuid": str(uuid.uuid4()),
            "patient": self.patient.id,
            "destination_facility": self.fb.id,
            "reason": "again",
            "urgency": "ROUTINE",
        }
        first = self.client.post("/api/referrals/", payload)
        second = self.client.post("/api/referrals/", payload)
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)


class HeartbeatApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        _, _, suco_a = build_geo()
        cls.fa = HealthFacility.objects.create(name="FA", suco=suco_a)
        cls.hw = User.objects.create_user(
            "hw", password="pw", role=User.Roles.HEALTH_WORKER, facility=cls.fa
        )
        cls.loose_hw = User.objects.create_user(
            "loose", password="pw", role=User.Roles.HEALTH_WORKER
        )
        cls.admin = User.objects.create_user(
            "admin", password="pw", role=User.Roles.SYSTEM_ADMIN
        )

    def setUp(self):
        self.client = APIClient()

    def test_requires_auth(self):
        self.assertEqual(
            self.client.post("/api/sync/heartbeat/", {}).status_code, 401
        )

    def test_heartbeat_defaults_own_facility(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post("/api/sync/heartbeat/", {"pending_count": 3})
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["facility"], self.fa.id)

    def test_heartbeat_without_facility_400(self):
        self.client.force_authenticate(user=self.loose_hw)
        response = self.client.post("/api/sync/heartbeat/", {"pending_count": 1})
        self.assertEqual(response.status_code, 400)
        self.assertIn("facility", response.data)

    def test_negative_pending_400(self):
        self.client.force_authenticate(user=self.hw)
        response = self.client.post("/api/sync/heartbeat/", {"pending_count": -1})
        self.assertEqual(response.status_code, 400)

    def test_heartbeat_appears_on_dashboard_sync_page(self):
        self.client.force_authenticate(user=self.hw)
        self.client.post("/api/sync/heartbeat/", {"pending_count": 5})
        # dashboard pages use session auth, not JWT
        self.client = APIClient()
        self.client.login(username="admin", password="pw")
        response = self.client.get("/sync/")
        self.assertContains(response, "5 rekordi he'in sincronizasaun iha fasilitades tomak.")
