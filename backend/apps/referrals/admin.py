from django.contrib import admin

from .models import Referral


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ("patient", "urgency", "status", "source_facility", "destination_facility", "created_at")
    list_filter = ("urgency", "status", "source_facility", "destination_facility")
    search_fields = ("patient__patient_id", "patient__last_name")
    ordering = ("-created_at",)
    readonly_fields = ("created_at", "updated_at")
