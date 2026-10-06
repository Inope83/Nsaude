from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco

from .serializers.locations import (
    AdministrativePostSerializer,
    FacilitySerializer,
    MunicipalitySerializer,
    SucoSerializer,
)


class MeView(APIView):
    """GET /api/auth/me/ — profile for the mobile app after JWT login."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response(
            {
                "id": user.id,
                "username": user.username,
                "role": user.role,
                "facility": user.facility_id,
                "first_name": user.first_name,
                "last_name": user.last_name,
            }
        )


class MunicipalityListView(generics.ListAPIView):
    """GET /api/municipalities/ (design §9)."""

    queryset = Municipality.objects.order_by("name")
    serializer_class = MunicipalitySerializer
    permission_classes = [AllowAny]  # geography is public; keeps first sync cheap


class AdministrativePostListView(generics.ListAPIView):
    """GET /api/administrative-posts/"""

    serializer_class = AdministrativePostSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = AdministrativePost.objects.select_related("municipality").order_by("name")
        municipality = self.request.query_params.get("municipality")
        if municipality:
            qs = qs.filter(municipality__code=municipality)
        return qs


class SucoListView(generics.ListAPIView):
    """GET /api/sucos/"""

    serializer_class = SucoSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = Suco.objects.select_related(
            "administrative_post__municipality"
        ).order_by("name")
        post = self.request.query_params.get("administrative_post")
        if post:
            qs = qs.filter(administrative_post__code=post)
        return qs


class FacilityListView(generics.ListAPIView):
    """GET /api/facilities/ (design §9)."""

    serializer_class = FacilitySerializer
    queryset = HealthFacility.objects.active().select_related(
        "suco__administrative_post__municipality"
    ).order_by("name")


class FacilityDetailView(generics.RetrieveAPIView):
    """GET /api/facilities/{id}/"""

    serializer_class = FacilitySerializer
    queryset = HealthFacility.objects.select_related(
        "suco__administrative_post__municipality"
    )


# --- Patients + monitoring (design §9) ---

from datetime import datetime  # noqa: E402

from django.db import IntegrityError  # noqa: E402
from django.shortcuts import get_object_or_404  # noqa: E402
from rest_framework import generics, exceptions  # noqa: E402

from apps.dashboard.scoping import scope_patients  # noqa: E402
from apps.monitoring.models import PatientMonitoringRecord  # noqa: E402

from .idempotency import create_idempotent  # noqa: E402
from .serializers.patients import (  # noqa: E402
    MonitoringRecordSerializer,
    PatientDetailSerializer,
    PatientListSerializer,
)


def parse_datetime_param(value: str, name: str):
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise exceptions.ValidationError({name: "Invalid ISO-8601 datetime."})
    if parsed.tzinfo is None:
        from django.utils import timezone

        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


class PatientListCreateView(generics.ListCreateAPIView):
    """GET/POST /api/patients/ (design §9). Scoped by role (plan §4)."""

    def get_queryset(self):
        qs = scope_patients(self.request.user).select_related(
            "suco__administrative_post__municipality"
        ).order_by("-updated_at")
        q = self.request.query_params.get("q", "").strip()
        if q:
            from django.db.models import Q

            qs = qs.filter(
                Q(patient_id__icontains=q)
                | Q(first_name__icontains=q)
                | Q(last_name__icontains=q)
            )
        updated_after = self.request.query_params.get("updated_after")
        if updated_after:
            qs = qs.filter(
                updated_at__gte=parse_datetime_param(updated_after, "updated_after")
            )
        return qs

    def get_serializer_class(self):
        if self.request.method == "POST":
            return PatientDetailSerializer
        return PatientListSerializer

    def create(self, request, *args, **kwargs):
        try:
            return create_idempotent(self, request, *args, **kwargs)
        except IntegrityError:
            raise exceptions.ValidationError(
                {"client_uuid": "This client_uuid already exists."}
            )


class PatientDetailView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/patients/{id}/ — out of scope → 404 (no leak)."""

    serializer_class = PatientDetailSerializer

    def get_queryset(self):
        return scope_patients(self.request.user)


class PatientMonitoringView(generics.ListCreateAPIView):
    """GET/POST /api/patients/{id}/monitoring/ (design §9)."""

    def get_patient(self):
        if not hasattr(self, "_patient"):
            self._patient = get_object_or_404(
                scope_patients(self.request.user), pk=self.kwargs["pk"]
            )
        return self._patient

    def get_queryset(self):
        qs = PatientMonitoringRecord.objects.for_patient(self.get_patient())
        recorded_after = self.request.query_params.get("recorded_after")
        if recorded_after:
            qs = qs.filter(
                recorded_at__gte=parse_datetime_param(recorded_after, "recorded_after")
            )
        return qs

    def get_serializer_class(self):
        return MonitoringRecordSerializer

    def get_serializer(self, *args, **kwargs):
        kwargs.setdefault("context", self.get_serializer_context())
        return super().get_serializer(*args, **kwargs)

    def perform_create(self, serializer):
        serializer.save(patient=self.get_patient(), recorded_by=self.request.user)

    def create(self, request, *args, **kwargs):
        try:
            return create_idempotent(self, request, *args, **kwargs)
        except IntegrityError:
            raise exceptions.ValidationError(
                {"client_uuid": "This client_uuid already exists."}
            )


# --- Emergencies, referrals, heartbeat (design §9 + §8) ---

from apps.dashboard.scoping import (  # noqa: E402
    scope_emergencies,
    scope_referrals,
)
from apps.emergencies.models import EmergencyCase  # noqa: E402
from apps.referrals.models import Referral  # noqa: E402
from apps.syncapp.models import SyncHeartbeat  # noqa: E402

from .serializers.cases import EmergencySerializer, ReferralSerializer  # noqa: E402
from .serializers.sync import HeartbeatSerializer  # noqa: E402


class EmergencyListCreateView(generics.ListCreateAPIView):
    """GET/POST /api/emergencies/ (design §9), scoped (plan §4)."""

    serializer_class = EmergencySerializer

    def get_queryset(self):
        qs = scope_emergencies(self.request.user).select_related(
            "patient", "facility", "created_by"
        ).order_by("-updated_at")
        status_param = self.request.query_params.get("status")
        if status_param in EmergencyCase.Status.values:
            qs = qs.filter(status=status_param)
        updated_after = self.request.query_params.get("updated_after")
        if updated_after:
            qs = qs.filter(
                updated_at__gte=parse_datetime_param(updated_after, "updated_after")
            )
        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    def create(self, request, *args, **kwargs):
        try:
            return create_idempotent(self, request, *args, **kwargs)
        except IntegrityError:
            raise exceptions.ValidationError(
                {"client_uuid": "This client_uuid already exists."}
            )


class EmergencyDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = EmergencySerializer

    def get_queryset(self):
        return scope_emergencies(self.request.user)


class ReferralListCreateView(generics.ListCreateAPIView):
    """GET/POST /api/referrals/ (design §9), scoped (plan §4)."""

    serializer_class = ReferralSerializer

    def get_queryset(self):
        qs = scope_referrals(self.request.user).select_related(
            "patient", "source_facility", "destination_facility", "referred_by"
        ).order_by("-updated_at")
        status_param = self.request.query_params.get("status")
        if status_param in Referral.Status.values:
            qs = qs.filter(status=status_param)
        updated_after = self.request.query_params.get("updated_after")
        if updated_after:
            qs = qs.filter(
                updated_at__gte=parse_datetime_param(updated_after, "updated_after")
            )
        return qs

    def perform_create(self, serializer):
        serializer.save(referred_by=self.request.user)

    def create(self, request, *args, **kwargs):
        try:
            return create_idempotent(self, request, *args, **kwargs)
        except IntegrityError:
            raise exceptions.ValidationError(
                {"client_uuid": "This client_uuid already exists."}
            )


class ReferralDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = ReferralSerializer

    def get_queryset(self):
        return scope_referrals(self.request.user)


class HeartbeatCreateView(generics.CreateAPIView):
    """POST /api/sync/heartbeat/ — client check-in with pending record count."""

    queryset = SyncHeartbeat.objects.all()
    serializer_class = HeartbeatSerializer

    def perform_create(self, serializer):
        user = self.request.user
        facility = serializer.validated_data.get("facility") or user.facility
        if facility is None:
            raise exceptions.ValidationError(
                {"facility": "No facility assigned to this account."}
            )
        if not (user.is_superuser or user.is_system_admin):
            if user.facility_id and facility.id != user.facility_id:
                raise exceptions.ValidationError(
                    {"facility": "You may only report for your own facility."}
                )
        serializer.save(facility=facility, reported_by=user)
