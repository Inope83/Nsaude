from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.locations.models import Suco

from .querysets import FacilityQuerySet


class HealthFacility(models.Model):
    """Health facility in a suco (design.md §3).

    facility_type choices: the docs specify a free `facility_type` field only;
    these values follow Timor-Leste Ministry of Health levels — adjust if the
    project wants different labels.
    """

    objects = FacilityQuerySet.as_manager()

    class Types(models.TextChoices):
        HOSPITAL = "HOSPITAL", _("Hospital")
        HEALTH_CENTER = "HEALTH_CENTER", _("Health centre")
        HEALTH_POST = "HEALTH_POST", _("Health post")
        CLINIC = "CLINIC", _("Private clinic")

    suco = models.ForeignKey(Suco, on_delete=models.PROTECT, related_name="facilities")
    name = models.CharField(_("Name"), max_length=160)
    facility_type = models.CharField(
        _("Facility type"), max_length=20, choices=Types.choices, default=Types.HEALTH_POST
    )
    address = models.CharField(_("Address"), max_length=255, blank=True)
    latitude = models.FloatField(
        validators=[MinValueValidator(-90), MaxValueValidator(90)], null=True, blank=True
    )
    longitude = models.FloatField(
        validators=[MinValueValidator(-180), MaxValueValidator(180)], null=True, blank=True
    )
    phone = models.CharField(_("Phone"), max_length=40, blank=True)
    is_active = models.BooleanField(_("Active"), default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        verbose_name = _("Health facility")
        verbose_name_plural = _("Health facilities")
        indexes = [
            models.Index(fields=["is_active"], name="facility_active_idx"),
            models.Index(fields=["facility_type"], name="facility_type_idx"),
        ]

    def __str__(self):
        return self.name

    @property
    def full_location(self):
        """'Suco, Administrative Post, Municipality' — for headers/filters."""
        suco = self.suco
        post = suco.administrative_post
        return f"{suco.name}, {post.name}, {post.municipality.name}"