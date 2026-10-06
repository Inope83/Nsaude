"""Production settings. Requires environment variables — fails fast if missing."""
from .base import *  # noqa: F401,F403

import os  # noqa: E402

if not SECRET_KEY:  # noqa: F405
    raise RuntimeError("SECRET_KEY environment variable is required in production")
if not ALLOWED_HOSTS:  # noqa: F405
    raise RuntimeError("ALLOWED_HOSTS environment variable is required in production")
if DEBUG:  # noqa: F405
    raise RuntimeError("DEBUG must not be enabled in production")

# Secure-by-default in production; every flag can still be overridden via env
# (e.g. internal deployments behind a TLS-terminating proxy that set
# USE_X_FORWARDED_PROTO instead).
SESSION_COOKIE_SECURE = env_bool("SESSION_COOKIE_SECURE", True)  # noqa: F405
CSRF_COOKIE_SECURE = env_bool("CSRF_COOKIE_SECURE", True)  # noqa: F405
SECURE_SSL_REDIRECT = env_bool("SECURE_SSL_REDIRECT", True)  # noqa: F405

# One year of HSTS unless explicitly configured. Note: no include_subdomains
# or preload, so it only applies to the exact host.
if "SECURE_HSTS_SECONDS" not in os.environ:
    SECURE_HSTS_SECONDS = 31536000  # noqa: F405

SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"

# WhiteNoise: hashed, pre-compressed static files served by the WSGI process —
# no web-server-specific static configuration required.
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"
    },
}

MIDDLEWARE = [
    "whitenoise.middleware.WhiteNoiseMiddleware",  # noqa: E402
    *MIDDLEWARE,  # noqa: F405
]
