"""
Backend configuration values.
"""

import os

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb+srv://smartConstructiondb:admin123@smartconstructioncluste.fmhajos.mongodb.net/",
)
DB_NAME = os.getenv("MONGO_DB_NAME", "smartConstructionDB")
JWT_SECRET = os.getenv("JWT_SECRET", "scms_jwt_secret_2026_changeme")
JWT_EXPIRY_DAYS = int(os.getenv("JWT_EXPIRY_DAYS", "30"))
PORT = int(os.getenv("PORT", "8008"))
MONGO_TIMEOUT_MS = int(os.getenv("MONGO_TIMEOUT_MS", "10000"))
