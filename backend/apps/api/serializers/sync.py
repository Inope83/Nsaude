from rest_framework import serializers

from apps.facilities.models import HealthFacility
from apps.syncapp.models import SyncHeartbeat


class HeartbeatSerializer(serializers.ModelSerializer):
    facility = serializers.PrimaryKeyRelatedField(
        queryset=HealthFacility.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = SyncHeartbeat
        fields = ("id", "facility", "pending_count", "created_at")
        read_only_fields = ("created_at",)
