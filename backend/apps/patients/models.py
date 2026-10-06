import secrets
import string
from datetime import date

from django.core.validators import RegexValidator
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.locations.models import Suco

from .querysets import PatientQuerySet


def generate_patient_id() -> str:
    """Short non-sequential public identifier.

    Client-generated (mobile offline) in a later phase; server generates the
    same shape when a record arrives without one.
    """
    alphabet = string.ascii_uppercase + string.digits
    return "PT-" + "".join(secrets.choice(alphabet) for _ in range(6))


def age_group_for(dob: date | None) -> str:
    """Coarse age band for list previews (privacy-safe alternative to DOB)."""
    if dob is None:
        return "—"
    today = date.today()
    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    if age < 5:
        return "0–4"
    if age < 18:
        return "5–17"
    if age < 65:
        return "18–64"
    return "65+"


class Patient(models.Model):
    """Patient record (design.md §3).

    Privacy: `patient_id` is the safe public handle; name/phone/address are
    detail-page-only data.
    """

    class Sex(models.TextChoices):
        FEMALE = "F", _("Female")
        MALE = "M", _("Male")
        OTHER = "O", _("Other")

    client_uuid = models.UUIDField(
        _("Client UUID"), null=True, blank=True, unique=True,
        help_text=_("Client-generated UUID for idempotent offline sync (design §8)."),
    )
    patient_id = models.SlugField(
        _("Patient ID"), max_length=20, unique=True, blank=True, db_index=True
    )
    first_name = models.CharField(_("First name"), max_length=100)
    last_name = models.CharField(_("Last name"), max_length=100)
    date_of_birth = models.DateField(_("Date of birth"), null=True, blank=True)
    sex = models.CharField(_("Sex"), max_length=1, choices=Sex.choices)
    phone = models.CharField(
        _("Phone"),
        max_length=40,
        blank=True,
        validators=[RegexValidator(r"^[\d\s+\-()]*$", _("Phone may contain digits and + - ( ) only"))],
    )
    address = models.CharField(_("Address"), max_length=255, blank=True)
    suco = models.ForeignKey(Suco, on_delete=models.PROTECT, related_name="patients")
    emergency_contact = models.CharField(
        _("Emergency contact"), max_length=160, blank=True
    )
    is_active = models.BooleanField(_("Active"), default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = PatientQuerySet.as_manager()

    class Meta:
        ordering = ("-created_at",)
        verbose_name = _("Patient")
        verbose_name_plural = _("Patients")

    def __str__(self):
        # Safe handle — full name stays out of logs/admin churn.
        return self.patient_id or f"{self.first_name} {self.last_name}"

    def save(self, *args, **kwargs):
        if not self.patient_id:
            existing = True
            while existing:
                candidate = generate_patient_id()
                existing = Patient.objects.filter(patient_id=candidate).exists()
            self.patient_id = candidate
        super().save(*args, **kwargs)

    @property
    def age(self) -> int | None:
        if not self.date_of_birth:
            return None
        today = date.today()
        return (
            today.year
            - self.date_of_birth.year
            - ((today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day))
        )

    @property
    def age_group(self) -> str:
        """Coarse age band for list previews (privacy)."""
        return age_group_for(self.date_of_birth)

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"
