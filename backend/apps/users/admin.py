from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.utils.translation import gettext_lazy as _

from .models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    list_display = ("username", "role", "facility", "is_active", "is_staff")
    list_filter = ("role", "is_active", "is_staff", "facility")
    search_fields = ("username", "first_name", "last_name", "facility__name")
    ordering = ("username",)
    fieldsets = DjangoUserAdmin.fieldsets + (
        (
            _("SaúdeKonekta"),
            {"fields": ("role", "facility")},
        ),
    )
    add_fieldsets = DjangoUserAdmin.add_fieldsets + (
        (
            _("SaúdeKonekta"),
            {"fields": ("role", "facility")},
        ),
    )
