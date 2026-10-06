from django.contrib import admin

from .models import StatusEvent


@admin.register(StatusEvent)
class StatusEventAdmin(admin.ModelAdmin):
    list_display = ("target", "old_status", "new_status", "actor", "created_at")
    list_filter = ("created_at",)
    ordering = ("-created_at",)
    readonly_fields = ("actor", "emergency", "referral", "old_status", "new_status", "created_at")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
