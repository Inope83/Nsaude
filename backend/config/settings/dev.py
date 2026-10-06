"""Development settings. Used by default via manage.py / wsgi / asgi."""
from .base import *  # noqa: F401,F403

DEBUG = True

if not SECRET_KEY:  # noqa: F405
    SECRET_KEY = "dev-only-insecure-key-do-not-use-in-production"

if not ALLOWED_HOSTS:  # noqa: F405
    ALLOWED_HOSTS = ["localhost", "127.0.0.1"]
