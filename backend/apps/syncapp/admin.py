from django.contrib import admin

from .models import SyncHeartbeat


@admin.register(SyncHeartbeat)
class SyncHeartbeatAdmin(admin.ModelAdmin):
    list_display = ("facility", "reported_by", "pending_count", "created_at")
    list_filter = ("facility",)
    ordering = ("-created_at",)
    readonly_fields = ("created_at",)
