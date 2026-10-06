from django.contrib import admin

from .models import Patient


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ("patient_id", "last_name", "first_name", "sex", "date_of_birth", "suco", "is_active")
    list_filter = ("sex", "is_active", "suco")
    search_fields = ("patient_id", "first_name", "last_name", "phone")
    ordering = ("-created_at",)
    readonly_fields = ("patient_id", "created_at", "updated_at")
