"""Access control mixins used by every dashboard view.

Rule (plan §4): SYSTEM_ADMIN sees everything; other roles only what their
view allows. Anonymous users are sent to login; authenticated users without
the required role get a real HTTP 403 (handler403 → 403.html).
"""
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.exceptions import PermissionDenied
from django.utils.translation import gettext_lazy as _


class RoleRequiredMixin(LoginRequiredMixin):
    """Require the user to have one of `allowed_roles` (superuser always passes)."""

    allowed_roles: tuple[str, ...] = ()

    def dispatch(self, request, *args, **kwargs):
        user = request.user
        if user.is_authenticated and not user.is_system_admin:
            if self.allowed_roles and user.role not in self.allowed_roles:
                raise PermissionDenied(
                    _("You do not have permission to view this page.")
                )
        return super().dispatch(request, *args, **kwargs)
