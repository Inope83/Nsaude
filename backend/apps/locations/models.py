from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _


class Municipality(models.Model):
    """Timor-Leste → Municipality (design.md §3)."""

    name = models.CharField(_("Name"), max_length=120)
    code = models.SlugField(_("Code"), max_length=20, unique=True)
    latitude = models.FloatField(
        validators=[MinValueValidator(-90), MaxValueValidator(90)], null=True, blank=True
    )
    longitude = models.FloatField(
        validators=[MinValueValidator(-180), MaxValueValidator(180)], null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        verbose_name = _("Municipality")
        verbose_name_plural = _("Municipalities")

    def __str__(self):
        return self.name


class AdministrativePost(models.Model):
    """Municipality → Administrative Post."""

    municipality = models.ForeignKey(
        Municipality, on_delete=models.CASCADE, related_name="administrative_posts"
    )
    name = models.CharField(_("Name"), max_length=120)
    code = models.SlugField(_("Code"), max_length=20, unique=True)
    latitude = models.FloatField(
        validators=[MinValueValidator(-90), MaxValueValidator(90)], null=True, blank=True
    )
    longitude = models.FloatField(
        validators=[MinValueValidator(-180), MaxValueValidator(180)], null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        verbose_name = _("Administrative post")
        verbose_name_plural = _("Administrative posts")

    def __str__(self):
        return f"{self.name} ({self.municipality.code})"


class Suco(models.Model):
    """Administrative Post → Suco."""

    administrative_post = models.ForeignKey(
        AdministrativePost, on_delete=models.CASCADE, related_name="sucos"
    )
    name = models.CharField(_("Name"), max_length=120)
    code = models.SlugField(_("Code"), max_length=20, unique=True)
    latitude = models.FloatField(
        validators=[MinValueValidator(-90), MaxValueValidator(90)], null=True, blank=True
    )
    longitude = models.FloatField(
        validators=[MinValueValidator(-180), MaxValueValidator(180)], null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        verbose_name = _("Suco")
        verbose_name_plural = _("Sucos")

    def __str__(self):
        return f"{self.name} ({self.administrative_post.municipality.code})"
