"""Shared status-change recording used by emergency and referral models."""
from django.core.exceptions import ValidationError

from .models import StatusEvent


def record_status_change(*, actor, new_status, emergency=None, referral=None, old_status="") -> StatusEvent:
    """Persist an immutable audit row for a status transition.

    Exactly one target; actor required (the human who performed the change).
    """
    if (emergency is None) == (referral is None):
        raise ValidationError("Provide exactly one of emergency= or referral=.")
    return StatusEvent.objects.create(
        actor=actor,
        emergency=emergency,
        referral=referral,
        old_status=old_status,
        new_status=new_status,
    )
