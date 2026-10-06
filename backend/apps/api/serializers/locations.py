from rest_framework import serializers

from apps.facilities.models import HealthFacility
from apps.locations.models import AdministrativePost, Municipality, Suco


class MunicipalitySerializer(serializers.ModelSerializer):
    class Meta:
        model = Municipality
        fields = ("id", "name", "code", "latitude", "longitude", "created_at", "updated_at")


class AdministrativePostSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdministrativePost
        fields = ("id", "municipality", "name", "code", "latitude", "longitude")


class SucoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Suco
        fields = ("id", "administrative_post", "name", "code", "latitude", "longitude")


class FacilitySerializer(serializers.ModelSerializer):
    municipality = serializers.CharField(source="suco.administrative_post.municipality.name", read_only=True)
    suco_name = serializers.CharField(source="suco.name", read_only=True)

    class Meta:
        model = HealthFacility
        fields = (
            "id", "name", "facility_type", "address", "latitude", "longitude",
            "phone", "is_active", "suco", "suco_name", "municipality",
            "created_at", "updated_at",
        )
