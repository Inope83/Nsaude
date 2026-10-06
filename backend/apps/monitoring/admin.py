from django.contrib import admin

from .models import PatientMonitoringRecord


@admin.register(PatientMonitoringRecord)
class PatientMonitoringRecordAdmin(admin.ModelAdmin):
    list_display = ("patient", "recorded_at", "recorded_by", "temperature", "heart_rate", "oxygen_saturation")
    list_filter = ("recorded_at",)
    search_fields = ("patient__patient_id", "patient__last_name")
    ordering = ("-recorded_at",)
    readonly_fields = ("created_at",)
