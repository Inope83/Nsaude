from django.db import models


class ReferralQuerySet(models.QuerySet):
    def pending(self):
        return self.filter(status="PENDING")

    def for_facility(self, facility):
        """Scope: referrals sent from OR received by this facility."""
        return self.filter(models.Q(source_facility=facility) | models.Q(destination_facility=facility))

    def for_list(self):
        """Privacy: safe handle only — no name/phone."""
        return self.select_related(
            "patient", "source_facility", "destination_facility"
        ).values(
            "id",
            "urgency",
            "status",
            "created_at",
            "source_facility__name",
            "destination_facility__name",
            "patient__patient_id",
        )
