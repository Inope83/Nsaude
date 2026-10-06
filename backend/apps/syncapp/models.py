from django.core.validators import MaxValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _


class SyncHeartbeat(models.Model):
    """Client-reported sync contact (approved audit/sync approach).

    Not connectivity itself: it records "the client checked in and reported
    N pending local records". The connectivity ONLINE/OFFLINE vocabulary
    belongs to the client (mobile) state.
    """

    facility = models.ForeignKey(
        "facilities.HealthFacility",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="heartbeats",
        verbose_name=_("Facility"),
    )
    reported_by = models.ForeignKey(
        "users.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="heartbeats",
        verbose_name=_("Reported by"),
    )
    pending_count = models.PositiveIntegerField(
        _("Pending records"),
        default=0,
        validators=[MaxValueValidator(1_000_000)],
        help_text=_("Client-reported number of local records not yet synced."),
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ("-created_at", "-id")
        verbose_name = _("Sync heartbeat")
        verbose_name_plural = _("Sync heartbeats")

    def __str__(self):
        label = self.facility.name if self.facility else _("No facility")
        return f"{label} · {self.created_at:%Y-%m-%d %H:%M} · {self.pending_count} pending"
