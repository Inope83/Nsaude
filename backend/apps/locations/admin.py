from django.contrib import admin
from django.utils.translation import gettext_lazy as _

from .models import AdministrativePost, Municipality, Suco


@admin.register(Municipality)
class MunicipalityAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "latitude", "longitude", "updated_at")
    search_fields = ("name", "code")
    ordering = ("name",)


@admin.register(AdministrativePost)
class AdministrativePostAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "municipality", "updated_at")
    list_filter = ("municipality",)
    search_fields = ("name", "code", "municipality__name")
    ordering = ("municipality__name", "name")


@admin.register(Suco)
class SucoAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "administrative_post", "municipality_name")
    list_filter = ("administrative_post__municipality",)
    search_fields = ("name", "code", "administrative_post__name")
    ordering = ("name",)
    autocomplete_fields = ("administrative_post",)

    @admin.display(description=_("Municipality"), ordering="administrative_post__municipality__name")
    def municipality_name(self, obj):
        return obj.administrative_post.municipality.name
