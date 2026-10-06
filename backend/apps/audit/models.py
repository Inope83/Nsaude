from django.db import models
from django.utils.translation import gettext_lazy as _


class StatusEvent(models.Model):
    """Immutable audit of every status change (approved audit approach).

    One row per transition; never edited or deleted by the app.
    Exactly one of emergency/referral is set.
    """

    actor = models.ForeignKey(
        "users.User",
        on_delete=models.PROTECT,
        related_name="status_events",
        verbose_name=_("Actor"),
    )
    emergency = models.ForeignKey(
        "emergencies.EmergencyCase",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="status_events",
    )
    referral = models.ForeignKey(
        "referrals.Referral",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="status_events",
    )
    old_status = models.CharField(_("Old status"), max_length=20, blank=True)
    new_status = models.CharField(_("New status"), max_length=20)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ("-created_at", "-id")
        verbose_name = _("Status event")
        verbose_name_plural = _("Status events")

    def __str__(self):
        target = self.emergency or self.referral
        return f"{target} · {self.old_status or '—'} → {self.new_status}"

    @property
    def target(self):
        return self.emergency or self.referral
