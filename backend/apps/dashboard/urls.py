from django.urls import path

from . import views

app_name = "dashboard"

urlpatterns = [
    path("", views.OverviewView.as_view(), name="overview"),
    path("patients/", views.PatientListView.as_view(), name="patient-list"),
    path("patients/<int:pk>/", views.PatientDetailView.as_view(), name="patient-detail"),
    path("emergencies/", views.EmergencyListView.as_view(), name="emergency-list"),
    path("referrals/", views.ReferralListView.as_view(), name="referral-list"),
    path("facilities/", views.FacilityListView.as_view(), name="facility-list"),
    path("map/", views.MapView.as_view(), name="map"),
    path("sync/", views.SyncStatusView.as_view(), name="sync-status"),
]
