from django.core.exceptions import ValidationError
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.audit.services import record_status_change
from apps.facilities.models import HealthFacility
from apps.patients.models import Patient

from .querysets import ReferralQuerySet


class Referral(models.Model):
    """Referral between facilities (design.md §3)."""

    class Urgency(models.TextChoices):
        ROUTINE = "ROUTINE", _("Routine")
        URGENT = "URGENT", _("Urgent")
        EMERGENCY = "EMERGENCY", _("Emergency")

    class Status(models.TextChoices):
        PENDING = "PENDING", _("Pending")
        ACCEPTED = "ACCEPTED", _("Accepted")
        IN_TRANSIT = "IN_TRANSIT", _("In transit")
        COMPLETED = "COMPLETED", _("Completed")
        CANCELLED = "CANCELLED", _("Cancelled")

    client_uuid = models.UUIDField(
        _("Client UUID"), null=True, blank=True, unique=True,
        help_text=_("Client-generated UUID for idempotent offline sync (design §8)."),
    )
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="referrals")
    emergency_case = models.ForeignKey(
        "emergencies.EmergencyCase",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="referrals",
    )
    referred_by = models.ForeignKey(
        "users.User", on_delete=models.PROTECT, related_name="referrals_created"
    )
    source_facility = models.ForeignKey(
        HealthFacility, on_delete=models.PROTECT, related_name="referrals_sent"
    )
    destination_facility = models.ForeignKey(
        HealthFacility, on_delete=models.PROTECT, related_name="referrals_received"
    )
    reason = models.TextField(_("Reason"))
    urgency = models.CharField(_("Urgency"), max_length=16, choices=Urgency.choices)
    status = models.CharField(
        _("Status"), max_length=16, choices=Status.choices, default=Status.PENDING, db_index=True
    )
    notes = models.TextField(_("Notes"), blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = ReferralQuerySet.as_manager()

    class Meta:
        ordering = ("-created_at",)
        verbose_name = _("Referral")
        verbose_name_plural = _("Referrals")

    def __str__(self):
        return f"{self.patient.patient_id} · {self.urgency} · {self.status}"

    def clean(self):
        super().clean()
        if (
            self.source_facility_id
            and self.source_facility_id == self.destination_facility_id
        ):
            raise ValidationError(
                {"destination_facility": _("Source and destination must differ.")}
            )

    def change_status(self, new_status, *, actor):
        """Transition + immutable audit row (StatusEvent)."""
        if new_status == self.status:
            raise ValidationError(_("Status unchanged."))
        old_status = self.status
        self.status = new_status
        self.save(update_fields=["status", "updated_at"])
        return record_status_change(
            actor=actor, referral=self, old_status=old_status, new_status=new_status
        )
