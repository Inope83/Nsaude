from django.db import models


class MonitoringQuerySet(models.QuerySet):
    def for_patient(self, patient):
        """Newest observation first — used by the patient detail page."""
        return self.filter(patient=patient).select_related("recorded_by").order_by(
            "-recorded_at", "-id"
        )

    def recent(self, limit=10):
        return self.select_related("patient", "recorded_by").order_by("-recorded_at")[:limit]
