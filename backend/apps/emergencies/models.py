from django.core.exceptions import ValidationError
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.audit.services import record_status_change
from apps.facilities.models import HealthFacility
from apps.patients.models import Patient

from .querysets import EmergencyQuerySet


class EmergencyCase(models.Model):
    """Emergency case (design.md §3). Decision support — never a diagnosis."""

    class Severity(models.TextChoices):
        LOW = "LOW", _("Low")
        MEDIUM = "MEDIUM", _("Medium")
        HIGH = "HIGH", _("High")
        CRITICAL = "CRITICAL", _("Critical")

    class Status(models.TextChoices):
        OPEN = "OPEN", _("Open")
        IN_REVIEW = "IN_REVIEW", _("In review")
        ESCALATED = "ESCALATED", _("Escalated")
        RESOLVED = "RESOLVED", _("Resolved")

    client_uuid = models.UUIDField(
        _("Client UUID"), null=True, blank=True, unique=True,
        help_text=_("Client-generated UUID for idempotent offline sync (design §8)."),
    )
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="emergency_cases")
    created_by = models.ForeignKey(
        "users.User", on_delete=models.PROTECT, related_name="emergencies_created"
    )
    facility = models.ForeignKey(
        HealthFacility, on_delete=models.PROTECT, related_name="emergency_cases"
    )
    severity = models.CharField(_("Severity"), max_length=16, choices=Severity.choices)
    symptoms = models.TextField(_("Symptoms"), blank=True)
    description = models.TextField(_("Description"), blank=True)
    status = models.CharField(
        _("Status"), max_length=16, choices=Status.choices, default=Status.OPEN, db_index=True
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = EmergencyQuerySet.as_manager()

    class Meta:
        ordering = ("-created_at",)
        verbose_name = _("Emergency case")
        verbose_name_plural = _("Emergency cases")

    def __str__(self):
        return f"{self.patient.patient_id} · {self.severity} · {self.status}"

    def change_status(self, new_status, *, actor):
        """Transition + immutable audit row (StatusEvent)."""
        if new_status == self.status:
            raise ValidationError(_("Status unchanged."))
        old_status = self.status
        self.status = new_status
        self.save(update_fields=["status", "updated_at"])
        return record_status_change(
            actor=actor, emergency=self, old_status=old_status, new_status=new_status
        )
