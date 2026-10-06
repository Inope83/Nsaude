from django.db import models


class PatientQuerySet(models.QuerySet):
    def active(self):
        return self.filter(is_active=True)

    def for_list(self):
        """Privacy: list pages only ever receive these fields — no phone,
        address or emergency contact (design/context privacy rules)."""
        return self.select_related("suco").values(
            "id",
            "patient_id",
            "date_of_birth",
            "sex",
            "is_active",
            "created_at",
            "suco__name",
        )
