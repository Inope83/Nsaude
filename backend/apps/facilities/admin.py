from django.contrib import admin
from django.utils.translation import gettext_lazy as _

from .models import HealthFacility


@admin.register(HealthFacility)
class HealthFacilityAdmin(admin.ModelAdmin):
    list_display = ("name", "facility_type", "suco", "municipality_name", "is_active", "updated_at")
    list_filter = ("facility_type", "is_active", "suco__administrative_post__municipality")
    search_fields = ("name", "address", "phone", "suco__name")
    list_editable = ("is_active",)
    ordering = ("name",)
    autocomplete_fields = ("suco",)
    list_select_related = ("suco", "suco__administrative_post", "suco__administrative_post__municipality")

    @admin.display(description=_("Municipality"), ordering="suco__administrative_post__municipality__name")
    def municipality_name(self, obj):
        return obj.suco.administrative_post.municipality.name
