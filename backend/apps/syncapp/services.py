"""Shared helpers for sync/connectivity views."""
from .models import SyncHeartbeat


def latest_heartbeats_by_facility() -> dict[int, SyncHeartbeat]:
    """facility_id → most recent heartbeat (one query; grouped in Python)."""
    latest: dict[int, SyncHeartbeat] = {}
    for hb in SyncHeartbeat.objects.select_related("reported_by").order_by("created_at"):
        if hb.facility_id:
            latest[hb.facility_id] = hb
    return latest
