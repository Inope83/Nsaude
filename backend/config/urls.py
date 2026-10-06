"""Root URL configuration."""
from django.contrib import admin
from django.urls import include, path
from django.views import defaults as django_defaults

urlpatterns = [
    path("admin/", admin.site.urls),
    path("i18n/", include("django.conf.urls.i18n")),
    path("api/", include("apps.api.urls")),
    path("", include("apps.users.urls")),
    path("", include("apps.dashboard.urls")),
]

# Clear 403 state page instead of a broken/debug page.
handler403 = django_defaults.permission_denied  # renders templates/403.html
