"""Shared create handling: client-generated UUID → idempotent offline sync
(design §8 "avoid duplicate records — client-generated UUIDs / idempotent
endpoints"). Re-POSTing the same client_uuid returns the existing record
with HTTP 200 instead of creating a duplicate."""
from rest_framework import status
from rest_framework.response import Response


def create_idempotent(view, request, *args, **kwargs):
    serializer = view.get_serializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    client_uuid = serializer.validated_data.get("client_uuid")
    if client_uuid is not None:
        existing = view.get_queryset().filter(client_uuid=client_uuid).first()
        if existing is not None:
            return Response(
                view.get_serializer(existing).data, status=status.HTTP_200_OK
            )
    view.perform_create(serializer)
    headers = view.get_success_headers(serializer.data)
    return Response(
        serializer.data, status=status.HTTP_201_CREATED, headers=headers
    )
