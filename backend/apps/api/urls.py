"""API routes — paths follow design.md §9 exactly."""
from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from . import views

urlpatterns = [
    path("auth/login/", TokenObtainPairView.as_view(), name="api-login"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="api-refresh"),
    path("auth/me/", views.MeView.as_view(), name="api-me"),
    path("municipalities/", views.MunicipalityListView.as_view(), name="api-municipalities"),
    path(
        "administrative-posts/",
        views.AdministrativePostListView.as_view(),
        name="api-administrative-posts",
    ),
    path("sucos/", views.SucoListView.as_view(), name="api-sucos"),
    path("facilities/", views.FacilityListView.as_view(), name="api-facilities"),
    path("facilities/<int:pk>/", views.FacilityDetailView.as_view(), name="api-facility-detail"),
    path("patients/", views.PatientListCreateView.as_view(), name="api-patients"),
    path("patients/<int:pk>/", views.PatientDetailView.as_view(), name="api-patient-detail"),
    path(
        "patients/<int:pk>/monitoring/",
        views.PatientMonitoringView.as_view(),
        name="api-patient-monitoring",
    ),
    path("emergencies/", views.EmergencyListCreateView.as_view(), name="api-emergencies"),
    path(
        "emergencies/<int:pk>/",
        views.EmergencyDetailView.as_view(),
        name="api-emergency-detail",
    ),
    path("referrals/", views.ReferralListCreateView.as_view(), name="api-referrals"),
    path(
        "referrals/<int:pk>/",
        views.ReferralDetailView.as_view(),
        name="api-referral-detail",
    ),
    path("sync/heartbeat/", views.HeartbeatCreateView.as_view(), name="api-heartbeat"),
]
