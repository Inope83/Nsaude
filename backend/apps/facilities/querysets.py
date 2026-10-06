from django.db import models


class FacilityQuerySet(models.QuerySet):
    def active(self):
        return self.filter(is_active=True)

    def with_geo(self):
        """Geography joined once — used by list pages and filters."""
        return self.select_related(
            "suco", "suco__administrative_post", "suco__administrative_post__municipality"
        )
