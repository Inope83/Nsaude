from rest_framework import serializers

from apps.dashboard.scoping import scope_patients
from apps.facilities.models import HealthFacility
from apps.emergencies.models import EmergencyCase
from apps.referrals.models import Referral


def _own_facility_or_error(user, facility, field):
    """Plan §4: non-admins may only report for their own facility."""
    if user.is_superuser or user.is_system_admin:
        return facility
    if facility is None:
        raise serializers.ValidationError(
            {field: "No facility assigned to this account."}
        )
    if user.facility_id and facility.id != user.facility_id:
        raise serializers.ValidationError(
            {field: "You may only report for your own facility."}
        )
    return facility


class EmergencySerializer(serializers.ModelSerializer):
    # Idempotent duplicate handling lives in apps/api/idempotency.py —
    # no UniqueValidator (mirrors PatientListSerializer).
    client_uuid = serializers.UUIDField(required=False, allow_null=True)
    created_by = serializers.CharField(source="created_by.username", read_only=True)
    facility = serializers.PrimaryKeyRelatedField(
        queryset=HealthFacility.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = EmergencyCase
        fields = (
            "id", "client_uuid", "patient", "created_by", "facility", "severity",
            "symptoms", "description", "status", "created_at", "updated_at",
        )
        read_only_fields = ("created_by", "created_at", "updated_at")

    def validate_patient(self, value):
        user = self.context["request"].user
        if not scope_patients(user).filter(pk=value.pk).exists():
            raise serializers.ValidationError("Patient not in your scope.")
        return value

    def validate(self, attrs):
        user = self.context["request"].user
        if "facility" not in attrs and self.instance is None:
            attrs["facility"] = user.facility
        if attrs.get("facility") is not None or self.instance is None:
            attrs["facility"] = _own_facility_or_error(
                user, attrs.get("facility"), "facility"
            )
        return attrs

    def update(self, instance, validated_data):
        # Status transitions must go through change_status → StatusEvent audit.
        new_status = validated_data.pop("status", None)
        if new_status is not None and new_status != instance.status:
            instance.change_status(new_status, actor=self.context["request"].user)
        return super().update(instance, validated_data)


class ReferralSerializer(serializers.ModelSerializer):
    # See EmergencySerializer.client_uuid.
    client_uuid = serializers.UUIDField(required=False, allow_null=True)
    referred_by = serializers.CharField(source="referred_by.username", read_only=True)
    source_facility = serializers.PrimaryKeyRelatedField(
        queryset=HealthFacility.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = Referral
        fields = (
            "id", "client_uuid", "patient", "emergency_case", "referred_by",
            "source_facility", "destination_facility", "reason", "urgency",
            "status", "notes", "created_at", "updated_at",
        )
        read_only_fields = ("referred_by", "created_at", "updated_at")

    def validate_patient(self, value):
        user = self.context["request"].user
        if not scope_patients(user).filter(pk=value.pk).exists():
            raise serializers.ValidationError("Patient not in your scope.")
        return value

    def validate(self, attrs):
        user = self.context["request"].user
        if "source_facility" not in attrs and self.instance is None:
            attrs["source_facility"] = user.facility
        if attrs.get("source_facility") is not None or self.instance is None:
            attrs["source_facility"] = _own_facility_or_error(
                user, attrs.get("source_facility"), "source_facility"
            )
        source = attrs.get(
            "source_facility",
            self.instance.source_facility_id if self.instance else None,
        )
        destination = attrs.get(
            "destination_facility",
            self.instance.destination_facility_id if self.instance else None,
        )
        source_id = getattr(source, "pk", source)
        destination_id = getattr(destination, "pk", destination)
        if source_id is not None and source_id == destination_id:
            raise serializers.ValidationError(
                {"destination_facility": "Source and destination must differ."}
            )
        return attrs

    def update(self, instance, validated_data):
        new_status = validated_data.pop("status", None)
        if new_status is not None and new_status != instance.status:
            instance.change_status(new_status, actor=self.context["request"].user)
        return super().update(instance, validated_data)
