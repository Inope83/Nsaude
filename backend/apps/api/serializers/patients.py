from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from apps.monitoring.models import PatientMonitoringRecord
from apps.patients.models import Patient


class PatientListSerializer(serializers.ModelSerializer):
    """List payload: no phone/address/emergency contact — less sync traffic,
    and list views stay privacy-safe (detail carries full data)."""

    # No UniqueValidator: duplicate client_uuid is answered idempotently
    # with HTTP 200 (apps/api/idempotency.py), not a 400.
    client_uuid = serializers.UUIDField(required=False, allow_null=True)
    suco_name = serializers.CharField(source="suco.name", read_only=True)

    class Meta:
        model = Patient
        fields = (
            "id", "client_uuid", "patient_id", "first_name", "last_name",
            "date_of_birth", "sex", "suco", "suco_name", "is_active",
            "created_at", "updated_at",
        )
        read_only_fields = ("patient_id", "created_at", "updated_at")


class PatientDetailSerializer(PatientListSerializer):
    class Meta(PatientListSerializer.Meta):
        fields = PatientListSerializer.Meta.fields + (
            "phone", "address", "emergency_contact",
        )


class MonitoringRecordSerializer(serializers.ModelSerializer):
    # See PatientListSerializer.client_uuid — idempotent create, not a 400.
    client_uuid = serializers.UUIDField(required=False, allow_null=True)
    recorded_by = serializers.CharField(source="recorded_by.username", read_only=True)

    class Meta:
        model = PatientMonitoringRecord
        fields = (
            "id", "client_uuid", "patient", "recorded_by", "recorded_at",
            "temperature", "heart_rate", "respiratory_rate",
            "blood_pressure_systolic", "blood_pressure_diastolic",
            "oxygen_saturation", "symptoms", "notes", "created_at",
        )
        read_only_fields = ("patient", "recorded_by", "created_at")
        extra_kwargs = {"recorded_at": {"required": False}}

    def validate_recorded_at(self, value):
        if value > timezone.now() + timedelta(minutes=5):
            raise serializers.ValidationError(
                "Observed time cannot be in the future."
            )
        return value

    def create(self, validated_data):
        validated_data.setdefault("recorded_at", timezone.now())
        return super().create(validated_data)
