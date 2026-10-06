from datetime import timedelta

from django.db.models import Q
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from django.views.generic import DetailView, ListView, TemplateView

from apps.emergencies.models import EmergencyCase
from apps.facilities.models import HealthFacility
from apps.locations.models import Municipality, Suco
from apps.monitoring.models import PatientMonitoringRecord
from apps.patients.models import age_group_for
from apps.referrals.models import Referral
from apps.syncapp.models import SyncHeartbeat
from apps.syncapp.services import latest_heartbeats_by_facility

from .mixins import DashboardAccessMixin
from .scoping import (
    is_admin_scope,
    scope_emergencies,
    scope_monitoring,
    scope_patients,
    scope_referrals,
)


class OverviewView(DashboardAccessMixin, TemplateView):
    template_name = "pages/overview.html"

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        user = self.request.user
        emergencies = scope_emergencies(user)
        referrals = scope_referrals(user)
        if is_admin_scope(user):
            scope_label = _("All facilities")
        else:
            scope_label = user.facility.name if user.facility else _("No facility assigned")
        ctx.update(
            {
                "page_title": _("Overview"),
                "scope_label": scope_label,
                "count_active_emergencies": emergencies.active().count(),
                "count_pending_referrals": referrals.pending().count(),
                "count_patients": scope_patients(user).active().count(),
                "count_monitoring": scope_monitoring(user).count(),
                "recent_emergencies": list(emergencies.active().for_list()[:5]),
                "pending_referrals": list(referrals.pending().for_list()[:5]),
            }
        )
        return ctx


class PatientListView(DashboardAccessMixin, ListView):
    paginate_by = 20
    template_name = "pages/patient_list.html"

    def get_queryset(self):
        qs = scope_patients(self.request.user).active()
        q = self.request.GET.get("q", "").strip()
        if q:
            qs = qs.filter(
                Q(patient_id__icontains=q)
                | Q(first_name__icontains=q)
                | Q(last_name__icontains=q)
            )
        return qs.for_list()

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["page_title"] = _("Patients")
        ctx["q"] = self.request.GET.get("q", "").strip()
        page = ctx.get("page_obj")
        if page is not None:
            # values() rows carry DOB; lists show the coarse age band only.
            page.object_list = [
                dict(row, age_group=age_group_for(row["date_of_birth"]))
                for row in page.object_list
            ]
        return ctx


class EmergencyListView(DashboardAccessMixin, ListView):
    paginate_by = 20
    template_name = "pages/emergency_list.html"

    def get_queryset(self):
        qs = scope_emergencies(self.request.user)
        status = self.request.GET.get("status", "")
        if status in EmergencyCase.Status.values:
            qs = qs.filter(status=status)
        return qs.for_list()

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["page_title"] = _("Emergency cases")
        status = self.request.GET.get("status", "")
        ctx["current_status"] = status if status in EmergencyCase.Status.values else ""
        ctx["status_choices"] = EmergencyCase.Status.choices
        return ctx


class ReferralListView(DashboardAccessMixin, ListView):
    paginate_by = 20
    template_name = "pages/referral_list.html"

    def get_queryset(self):
        qs = scope_referrals(self.request.user)
        status = self.request.GET.get("status", "")
        if status in Referral.Status.values:
            qs = qs.filter(status=status)
        return qs.for_list()

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["page_title"] = _("Referrals")
        status = self.request.GET.get("status", "")
        ctx["current_status"] = status if status in Referral.Status.values else ""
        ctx["status_choices"] = Referral.Status.choices
        return ctx


class PatientDetailView(DashboardAccessMixin, DetailView):
    """Patient record + monitoring timeline (read-only; writes stay on mobile)."""

    template_name = "pages/patient_detail.html"

    def get_queryset(self):
        # Detail also shows inactive records; out-of-scope → 404 (no existence leak).
        return scope_patients(self.request.user)

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["page_title"] = self.object.patient_id
        ctx["monitoring_records"] = list(
            PatientMonitoringRecord.objects.for_patient(self.object)
        )
        return ctx


class FacilityListView(DashboardAccessMixin, ListView):
    """Facility directory with municipality/suco filters (design §6)."""

    paginate_by = 20
    template_name = "pages/facility_list.html"

    def get_queryset(self):
        qs = (
            HealthFacility.objects.active()
            .select_related("suco__administrative_post__municipality")
            .order_by("name")
        )
        muni_code = self.request.GET.get("municipality", "").strip()
        suco_code = self.request.GET.get("suco", "").strip()
        municipalities = Municipality.objects.all()
        valid_muni = municipalities.filter(code=muni_code).first() if muni_code else None
        valid_suco = None
        if suco_code:
            suco_qs = Suco.objects.all()
            if valid_muni:
                suco_qs = suco_qs.filter(administrative_post__municipality=valid_muni)
            valid_suco = suco_qs.filter(code=suco_code).first()
        if valid_muni:
            qs = qs.filter(suco__administrative_post__municipality=valid_muni)
        if valid_suco:
            qs = qs.filter(suco=valid_suco)
        return qs

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["page_title"] = _("Facilities")
        muni_code = self.request.GET.get("municipality", "").strip()
        valid_muni = Municipality.objects.filter(code=muni_code).first() if muni_code else None
        suco_qs = Suco.objects.select_related("administrative_post").order_by("name")
        if valid_muni:
            suco_qs = suco_qs.filter(administrative_post__municipality=valid_muni)
        ctx["municipalities"] = Municipality.objects.order_by("name")
        ctx["sucos"] = suco_qs
        ctx["selected_municipality"] = valid_muni.code if valid_muni else ""
        ctx["selected_suco"] = self.request.GET.get("suco", "").strip()
        return ctx


class SyncStatusView(DashboardAccessMixin, TemplateView):
    """Connectivity/sync overview: last heartbeat per facility (design §6)."""

    template_name = "pages/sync_status.html"

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        facilities = (
            HealthFacility.objects.active()
            .select_related("suco__administrative_post__municipality")
            .order_by("name")
        )
        # oldest → newest so the last row per facility wins
        latest = latest_heartbeats_by_facility()
        now = timezone.now()
        rows = []
        for facility in facilities:
            heartbeat = latest.get(facility.id)
            stale = bool(heartbeat and now - heartbeat.created_at > timedelta(hours=24))
            rows.append({"facility": facility, "heartbeat": heartbeat, "stale": stale})
        ctx.update(
            {
                "page_title": _("Sync status"),
                "rows": rows,
                "total_pending": sum(hb.pending_count for hb in latest.values()),
            }
        )
        return ctx


SEVERITY_RANK = {"LOW": 0, "MEDIUM": 1, "HIGH": 2, "CRITICAL": 3}


class MapView(DashboardAccessMixin, TemplateView):
    """Privacy-safe map (design §7): facility markers + emergency COUNTS only —
    never patient identifiers. Satellite imagery is a visualization layer."""

    template_name = "pages/map.html"

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        user = self.request.user
        facilities = list(
            HealthFacility.objects.active()
            .select_related("suco__administrative_post__municipality")
            .order_by("name")
        )
        heartbeats = latest_heartbeats_by_facility()
        now = timezone.now()

        counts: dict[int, dict] = {}
        qs = scope_emergencies(user).active().values_list("facility_id", "severity")
        for facility_id, severity in qs:
            entry = counts.setdefault(facility_id, {"count": 0, "max_severity": "LOW"})
            entry["count"] += 1
            if SEVERITY_RANK[severity] > SEVERITY_RANK[entry["max_severity"]]:
                entry["max_severity"] = severity

        rows, without_geo = [], 0
        for facility in facilities:
            if facility.latitude is None or facility.longitude is None:
                without_geo += 1
                continue
            heartbeat = heartbeats.get(facility.id)
            if heartbeat is None:
                sync = "never"
            elif now - heartbeat.created_at > timedelta(hours=24):
                sync = "stale"
            else:
                sync = "fresh"
            emergency = counts.get(facility.id, {"count": 0, "max_severity": None})
            rows.append(
                {
                    "id": facility.id,
                    "name": facility.name,
                    "type": str(facility.get_facility_type_display()),
                    "municipality": str(facility.suco.administrative_post.municipality.name),
                    "lat": float(facility.latitude),
                    "lng": float(facility.longitude),
                    "sync": sync,
                    "active_emergencies": emergency["count"],
                    "max_severity": emergency["max_severity"],
                }
            )

        payload = {
            "center": [-8.85, 125.7],
            "zoom": 7,
            "facilities": rows,
            "sync_labels": {
                "fresh": str(_("Recent sync")),
                "stale": str(_("Stale")),
                "never": str(_("Never synced")),
            },
        }
        ctx.update(
            {
                "page_title": _("Map"),
                "payload": payload,
                "facilities_without_geo": without_geo,
                "facility_count": len(rows),
            }
        )
        return ctx
