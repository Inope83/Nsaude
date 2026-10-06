from django.contrib import admin

from .models import EmergencyCase


@admin.register(EmergencyCase)
class EmergencyCaseAdmin(admin.ModelAdmin):
    list_display = ("patient", "severity", "status", "facility", "created_by", "created_at")
    list_filter = ("severity", "status", "facility")
    search_fields = ("patient__patient_id", "patient__last_name")
    ordering = ("-created_at",)
    readonly_fields = ("created_at", "updated_at")
