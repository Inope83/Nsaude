"""API permission classes (plan §4 role rules)."""
from rest_framework.permissions import BasePermission

from apps.users.models import User


class IsAdminOrDoctor(BasePermission):
    """Read access for dashboard-equivalent roles (admin passes everywhere)."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        return user.is_superuser or user.is_system_admin or user.role == User.Roles.DOCTOR


class CanReport(BasePermission):
    """Any authenticated field user may create records (health worker tool)."""

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)
