"""Status badge mapping — MUST stay identical to
mobile/lib/core/theme/app_status.dart (Severity/EmergencyStatus/ReferralUrgency/
ReferralStatus/SyncStatus/ConnectivityStatus).

Badge rule: tint class + text label + icon — never color alone.
Labels are English msgids; Tetum comes via translation files.
"""
from django import template
from django.utils.translation import gettext_lazy as _

register = template.Library()

# domain -> value -> (css modifier, bootstrap-icon, English label)
_STATUS_MAP = {
    "severity": {
        "LOW": ("success", "bi-arrow-down", _("LOW")),
        "MEDIUM": ("warning", "bi-dash", _("MEDIUM")),
        "HIGH": ("error", "bi-exclamation-triangle", _("HIGH")),
        "CRITICAL": ("emergency", "bi-exclamation-octagon", _("CRITICAL")),
    },
    "emergency_status": {
        "OPEN": ("warning", "bi-lightning", _("OPEN")),
        "IN_REVIEW": ("info", "bi-search", _("IN REVIEW")),
        "ESCALATED": ("error", "bi-arrow-up", _("ESCALATED")),
        "RESOLVED": ("success", "bi-check-circle", _("RESOLVED")),
    },
    "urgency": {
        "ROUTINE": ("success", "bi-clock", _("ROUTINE")),
        "URGENT": ("warning", "bi-fast-forward", _("URGENT")),
        "EMERGENCY": ("emergency", "bi-exclamation-octagon", _("EMERGENCY")),
    },
    "referral_status": {
        "PENDING": ("warning", "bi-hourglass", _("PENDING")),
        "ACCEPTED": ("info", "bi-person-check", _("ACCEPTED")),
        "IN_TRANSIT": ("neutral", "bi-truck", _("IN TRANSIT")),
        "COMPLETED": ("success", "bi-check-circle", _("COMPLETED")),
        "CANCELLED": ("neutral", "bi-x-circle", _("CANCELLED")),
    },
    "sync_status": {
        "PENDING": ("warning", "bi-cloud-slash", _("PENDING SYNC")),
        "SYNCING": ("info", "bi-arrow-repeat", _("SYNCING")),
        "SYNCED": ("success", "bi-cloud-check", _("SYNCED")),
        "FAILED": ("error", "bi-cloud-slash", _("SYNC FAILED")),
    },
    "connectivity": {
        "ONLINE": ("success", "bi-wifi", _("ONLINE")),
        "OFFLINE": ("warning", "bi-wifi-off", _("OFFLINE")),
    },
}


@register.inclusion_tag("components/status_badge.html")
def status_badge(domain, value):
    """Render a status badge: {% status_badge 'severity' case.severity %}"""
    entry = _STATUS_MAP.get(domain, {}).get(str(value))
    if entry is None:
        modifier, icon, label = "neutral", "bi-question-circle", str(value)
    else:
        modifier, icon, label = entry
    return {"modifier": modifier, "icon": icon, "label": label}


@register.filter
def status_modifier(domain, value):
    """Return css modifier for a status, e.g. {{ 'severity'|status_modifier:case.severity }}."""
    return _STATUS_MAP.get(domain, {}).get(str(value), ("neutral", "", ""))[0]
