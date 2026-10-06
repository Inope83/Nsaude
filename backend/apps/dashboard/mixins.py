"""Dashboard view access (plan §4): admin passes, DOCTOR passes, everyone
else gets a real 403 page; anonymous users go to login first."""
from apps.users.mixins import RoleRequiredMixin


class DashboardAccessMixin(RoleRequiredMixin):
    allowed_roles = ("DOCTOR",)
