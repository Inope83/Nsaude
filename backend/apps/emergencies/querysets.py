from django.db import models


class EmergencyQuerySet(models.QuerySet):
    def active(self):
        return self.exclude(status="RESOLVED")

    def for_facility(self, facility):
        return self.filter(facility=facility)

    def for_list(self):
        """Privacy: dashboard/map lists only get the safe handle, not name or contact."""
        return self.select_related("patient", "facility").values(
            "id",
            "severity",
            "status",
            "created_at",
            "facility__name",
            "patient__patient_id",
        )
