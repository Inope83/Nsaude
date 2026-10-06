from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils.translation import gettext_lazy as _


class User(AbstractUser):
    """Project user with role + facility scope (design.md §4).

    Web dashboard uses session auth; the mobile app will use JWT against the
    same user table in the API phase.
    """

    class Roles(models.TextChoices):
        SYSTEM_ADMIN = "SYSTEM_ADMIN", _("System administrator")
        DOCTOR = "DOCTOR", _("Doctor")
        HEALTH_WORKER = "HEALTH_WORKER", _("Health worker")

    role = models.CharField(
        _("Role"), max_length=20, choices=Roles.choices, default=Roles.HEALTH_WORKER
    )
    facility = models.ForeignKey(
        "facilities.HealthFacility",
        verbose_name=_("Facility"),
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="staff",
        help_text=_("Scoping facility for doctors and health workers."),
    )

    class Meta:
        ordering = ("username",)
        verbose_name = _("User")
        verbose_name_plural = _("Users")

    def __str__(self):
        return f"{self.username} ({self.role})"

    @property
    def is_system_admin(self) -> bool:
        return self.is_superuser or self.role == self.Roles.SYSTEM_ADMIN

    @property
    def is_doctor(self) -> bool:
        return self.role == self.Roles.DOCTOR

    @property
    def is_health_worker(self) -> bool:
        return self.role == self.Roles.HEALTH_WORKER

    @property
    def role_label(self) -> str:
        return self.get_role_display()
