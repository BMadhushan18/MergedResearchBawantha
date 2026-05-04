import base64
import os
import uuid
from datetime import datetime

from database.connection import get_db


def utcnow_iso() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def get_mongo_db():
    return get_db()


def artifacts_root() -> str:
    # Keep consistent with existing repo convention under backend/_artifacts.
    here = os.path.dirname(__file__)
    backend_dir = os.path.abspath(os.path.join(here, "..", "..", ".."))
    return os.path.join(backend_dir, "_artifacts", "plan_pipeline")


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def new_sheet_id() -> str:
    return f"sheet_{uuid.uuid4().hex[:12]}"


def new_subplan_id() -> str:
    return f"sub_{uuid.uuid4().hex[:12]}"


def save_bytes(path: str, data: bytes) -> None:
    ensure_dir(os.path.dirname(path))
    with open(path, "wb") as f:
        f.write(data)


def read_bytes(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


def to_b64(data: bytes) -> str:
    return base64.b64encode(data).decode("utf-8")
