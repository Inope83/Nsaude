from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.patients.models import Patient

from .querysets import MonitoringQuerySet

RANGE_VALIDATORS = {
    "temperature": [MinValueValidator(20), MaxValueValidator(50)],
    "heart_rate": [MinValueValidator(0), MaxValueValidator(250)],
    "respiratory_rate": [MinValueValidator(0), MaxValueValidator(100)],
    "blood_pressure_systolic": [MinValueValidator(0), MaxValueValidator(300)],
    "blood_pressure_diastolic": [MinValueValidator(0), MaxValueValidator(200)],
    "oxygen_saturation": [MinValueValidator(0), MaxValueValidator(100)],
}


class PatientMonitoringRecord(models.Model):
    """One observation by a health worker (design.md §3).

    All vitals optional — offline records may capture only what was measured.
    This is decision-support data: it never states a diagnosis.
    """

    client_uuid = models.UUIDField(
        _("Client UUID"), null=True, blank=True, unique=True,
        help_text=_("Client-generated UUID for idempotent offline sync (design §8)."),
    )
    patient = models.ForeignKey(
        Patient, on_delete=models.CASCADE, related_name="monitoring_records"
    )
    recorded_by = models.ForeignKey(
        "users.User", on_delete=models.SET_NULL, null=True, related_name="monitoring_records"
    )
    recorded_at = models.DateTimeField(_("Observed at"), db_index=True)
    temperature = models.FloatField(
        _("Temperature (°C)"), null=True, blank=True, validators=RANGE_VALIDATORS["temperature"]
    )
    heart_rate = models.IntegerField(
        _("Heart rate (bpm)"), null=True, blank=True, validators=RANGE_VALIDATORS["heart_rate"]
    )
    respiratory_rate = models.IntegerField(
        _("Respiratory rate"), null=True, blank=True, validators=RANGE_VALIDATORS["respiratory_rate"]
    )
    blood_pressure_systolic = models.IntegerField(
        _("BP systolic"), null=True, blank=True,
        validators=RANGE_VALIDATORS["blood_pressure_systolic"],
    )
    blood_pressure_diastolic = models.IntegerField(
        _("BP diastolic"), null=True, blank=True,
        validators=RANGE_VALIDATORS["blood_pressure_diastolic"],
    )
    oxygen_saturation = models.IntegerField(
        _("SpO₂ (%)"), null=True, blank=True, validators=RANGE_VALIDATORS["oxygen_saturation"]
    )
    symptoms = models.TextField(_("Symptoms"), blank=True, help_text=_("Symptoms observed, free text or chip list."))
    notes = models.TextField(_("Notes"), blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = MonitoringQuerySet.as_manager()

    class Meta:
        ordering = ("-recorded_at", "-id")
        verbose_name = _("Monitoring record")
        verbose_name_plural = _("Monitoring records")
        indexes = [
            models.Index(fields=["patient", "-recorded_at"], name="monitoring_patient_time"),
        ]

    def __str__(self):
        return f"{self.patient.patient_id} @ {self.recorded_at:%Y-%m-%d %H:%M}"
