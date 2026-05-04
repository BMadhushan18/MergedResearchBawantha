import logging
import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

from bson import ObjectId
from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.collection import Collection

logger = logging.getLogger(__name__)

load_dotenv()

_client: Optional[MongoClient] = None
_db = None
_last_error: str = ""


def _db_name_from_uri(uri: str) -> Optional[str]:
    try:
        parsed = urlparse(uri)
        path = (parsed.path or "").lstrip("/")
        if path and path.lower() != "admin":
            return path.split("/")[0]
    except Exception:
        return None
    return None


def _select_database_name(client: MongoClient, requested_name: str) -> str:
    try:
        database_names = client.list_database_names()
    except Exception:
        return requested_name

    if requested_name in database_names:
        return requested_name

    # Prefer a DB that contains core collections used by this app.
    for db_name in database_names:
        if db_name in {"admin", "local", "config"}:
            continue
        try:
            collections = set(client[db_name].list_collection_names())
        except Exception:
            continue
        if "projects" in collections or "boqReport" in collections:
            return db_name

    for fallback in ("smartConstructionDB", "smartboq_db", "smartboq"):
        if fallback in database_names:
            return fallback

    return requested_name


def _get_db():
    global _client, _db, _last_error
    if _db is not None:
        return _db

    mongo_uri = os.getenv("MONGO_URI") or os.getenv("MONGODB_URI")
    if not mongo_uri:
        logger.warning("MONGO_URI/MONGODB_URI is not configured. MongoDB operations are disabled.")
        _last_error = "MONGO_URI/MONGODB_URI is not configured"
        return None

    requested_db_name = (
        os.getenv("MONGO_DB_NAME")
        or os.getenv("MONGODB_DB_NAME")
        or _db_name_from_uri(mongo_uri)
        or "smartboq"
    )
    attempts = 3
    delay_seconds = 1.5
    for attempt in range(1, attempts + 1):
        try:
            _client = MongoClient(
                mongo_uri,
                serverSelectionTimeoutMS=15000,
                connectTimeoutMS=15000,
                socketTimeoutMS=20000,
                retryReads=True,
                retryWrites=True,
            )
            _client.admin.command("ping")
            db_name = _select_database_name(_client, requested_db_name)
            _db = _client[db_name]
            _last_error = ""
            logger.info("MongoDB connected using database: %s", db_name)
            return _db
        except Exception as exc:
            _last_error = str(exc)
            logger.warning("MongoDB connection attempt %s/%s failed: %s", attempt, attempts, exc)
            _client = None
            _db = None
            if attempt < attempts:
                time.sleep(delay_seconds)

    logger.warning("MongoDB connection failed after retries: %s", _last_error)
    return None


def is_mongo_available() -> bool:
    return _get_db() is not None


def get_mongo_error() -> str:
    _get_db()
    return _last_error


def _prediction_collection() -> Optional[Collection]:
    db = _get_db()
    if db is None:
        return None
    return db["boq_predictions"]


def _projects_collection() -> Optional[Collection]:
    db = _get_db()
    if db is None:
        return None
    names = ["projects", "project", "Projects"]
    try:
        existing = set(db.list_collection_names())
        for name in names:
            if name in existing:
                return db[name]
    except Exception:
        pass
    return db["projects"]


def _boq_report_collection() -> Optional[Collection]:
    db = _get_db()
    if db is None:
        return None
    names = ["boqReport", "boqreport", "boq_reports", "boq_reports_collection"]
    try:
        existing = set(db.list_collection_names())
        for name in names:
            if name in existing:
                return db[name]
    except Exception:
        pass
    return db["boqReport"]


def _users_collection() -> Optional[Collection]:
    db = _get_db()
    if db is None:
        return None
    names = ["users", "user", "Users"]
    try:
        existing = set(db.list_collection_names())
        for name in names:
            if name in existing:
                return db[name]
    except Exception:
        pass
    return db["users"]


def _id_variants(value: str) -> List[Any]:
    variants: List[Any] = [value]
    if ObjectId.is_valid(value):
        variants.append(ObjectId(value))
    return variants


def save_upload(
    project_id: str,
    project_name: str,
    project_type: str,
    site_location: str,
    file_name: str,
    prediction: Dict[str, Any],
) -> bool:
    collection = _prediction_collection()
    if collection is None:
        return False

    document = {
        "project_id": project_id,
        "project_name": project_name,
        "project_type": project_type,
        "site_location": site_location,
        "file_name": file_name,
        "prediction": prediction,
        "created_at": datetime.now(timezone.utc),
    }

    collection.insert_one(document)
    return True


def get_project_history(project_id: str) -> List[Dict[str, Any]]:
    collection = _prediction_collection()
    if collection is None:
        return []

    cursor = collection.find({"project_id": project_id}).sort("created_at", -1)
    records: List[Dict[str, Any]] = []
    for item in cursor:
        prediction = item.get("prediction") or {}
        records.append(
            {
                "id": str(item.get("_id", "")),
                "project_id": item.get("project_id", ""),
                "project_name": item.get("project_name", ""),
                "prediction": prediction,
                "created_at": item.get("created_at"),
            }
        )
    return records


def get_all_history(limit: int = 500) -> List[Dict[str, Any]]:
    collection = _prediction_collection()
    if collection is None:
        return []

    cursor = collection.find({}).sort("created_at", -1).limit(limit)
    records: List[Dict[str, Any]] = []
    for item in cursor:
        prediction = item.get("prediction") or {}
        records.append(
            {
                "id": str(item.get("_id", "")),
                "project_id": item.get("project_id", ""),
                "project_name": item.get("project_name", ""),
                "prediction": prediction,
                "created_at": item.get("created_at"),
            }
        )
    return records


def get_latest_prediction(project_id: str) -> Optional[Dict[str, Any]]:
    collection = _prediction_collection()
    if collection is None:
        return None

    item = collection.find_one({"project_id": project_id}, sort=[("created_at", -1)])
    if not item:
        return None
    return item.get("prediction")


def get_projects_catalog() -> List[Dict[str, str]]:
    collection = _projects_collection()
    if collection is None:
        return []

    cursor = collection.find({}).sort("_id", 1)
    projects: List[Dict[str, str]] = []
    for item in cursor:
        project_id = str(item.get("projectId") or item.get("project_id") or item.get("id") or item.get("_id") or "")
        projects.append(
            {
                "project_id": project_id,
                "project_name": str(
                    item.get("project_name")
                    or item.get("projectName")
                    or item.get("name")
                    or ""
                ),
                "project_type": str(
                    item.get("project_type")
                    or item.get("projectType")
                    or "Residential"
                ),
                "site_location": str(
                    item.get("site_location")
                    or item.get("siteLocation")
                    or ""
                ),
            }
        )
    return projects


def get_project_by_id(project_id: str) -> Optional[Dict[str, Any]]:
    collection = _projects_collection()
    if collection is None:
        return None

    for candidate in _id_variants(project_id):
        item = collection.find_one(
            {
                "$or": [
                    {"_id": candidate},
                    {"projectId": candidate},
                    {"project_id": candidate},
                    {"id": candidate},
                ]
            }
        )
        if item:
            normalized_project_id = str(
                item.get("projectId")
                or item.get("project_id")
                or item.get("id")
                or item.get("_id")
                or project_id
            )
            return {
                "project_id": normalized_project_id,
                "project_name": str(item.get("project_name") or item.get("projectName") or item.get("name") or ""),
                "project_type": str(item.get("project_type") or item.get("projectType") or "Residential"),
                "site_location": str(item.get("site_location") or item.get("siteLocation") or ""),
                "total_floor_area_sqft": int(item.get("total_floor_area_sqft") or item.get("totalFloorAreaSqft") or 3000),
                "number_of_floors": int(item.get("number_of_floors") or item.get("numberOfFloors") or 1),
                "building_complexity_index": float(item.get("building_complexity_index") or item.get("buildingComplexityIndex") or 6.0),
                "working_days": int(item.get("working_days") or item.get("workingDays") or 5),
            }
    return None


def get_latest_boq_report(project_id: str) -> Optional[Dict[str, Any]]:
    collection = _boq_report_collection()
    if collection is None:
        return None

    variants = _id_variants(project_id)
    query = {
        "$or": [
            {"projectId": {"$in": variants}},
            {"projectId": {"$in": [str(v) for v in variants]}},
            {"project_id": {"$in": variants}},
            {"project_id": {"$in": [str(v) for v in variants]}},
        ]
    }
    item = collection.find_one(query, sort=[("updatedAt", -1), ("createdAt", -1)])
    if not item:
        return None
    return item


def get_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    collection = _users_collection()
    if collection is None:
        return None
    return collection.find_one({"email": email})


def create_user(user_data: Dict[str, Any]) -> bool:
    collection = _users_collection()
    if collection is None:
        return False
    
    # Ensure mandatory fields
    if "email" not in user_data or ("password" not in user_data and "passwordHash" not in user_data):
        return False
        
    user_data["createdAt"] = datetime.now(timezone.utc)
    collection.insert_one(user_data)
    return True
# --- Retraining & History Extensions ---

def _retrain_log_collection() -> Collection:
    return _get_db()["retrain_log"]

def _pending_retrain_collection() -> Collection:
    return _get_db()["pending_retrain"]

def _fuel_history_collection() -> Collection:
    return _get_db()["fuel_price_history"]

def _labour_history_collection() -> Collection:
    return _get_db()["labour_rate_history"]

def _rental_history_collection() -> Collection:
    return _get_db()["rental_rate_history"]

# Cost Parameter Versioning
def update_fuel_price(fuel_type: str, value: float, source: str = "Manual Update", user: str = "admin"):
    doc = {
        "fuel_type": fuel_type,
        "value": value,
        "source_reference": source,
        "updated_by": user,
        "effective_date": datetime.now(timezone.utc),
        "created_at": datetime.now(timezone.utc)
    }
    return _fuel_history_collection().insert_one(doc).inserted_id

def get_latest_fuel_price(fuel_type: str = "Auto Diesel") -> float:
    # Gets the latest entry where effective_date <= now
    latest = _fuel_history_collection().find_one(
        {"fuel_type": fuel_type, "effective_date": {"$lte": datetime.now(timezone.utc)}},
        sort=[("effective_date", -1)]
    )
    return latest["value"] if latest else 330.0 # Default fallback

def update_labour_rate(role: str, rate: float, user: str = "admin"):
    doc = {
        "role": role,
        "rate": rate,
        "updated_by": user,
        "effective_date": datetime.now(timezone.utc),
        "created_at": datetime.now(timezone.utc)
    }
    return _labour_history_collection().insert_one(doc).inserted_id

def get_latest_labour_rates() -> Dict[str, float]:
    # Aggregation to get latest rate per role
    pipeline = [
        {"$match": {"effective_date": {"$lte": datetime.now(timezone.utc)}}},
        {"$sort": {"effective_date": -1}},
        {"$group": {"_id": "$role", "latest_rate": {"$first": "$rate"}}}
    ]
    results = _labour_history_collection().aggregate(pipeline)
    return {r["_id"]: r["latest_rate"] for r in results}

# Retrain Tracking
def log_pending_change(change_type: str, summary: str):
    doc = {
        "change_type": change_type,
        "change_summary": summary,
        "created_at": datetime.now(timezone.utc),
        "batched_into_job_id": None
    }
    return _pending_retrain_collection().insert_one(doc).inserted_id

def get_pending_changes_count() -> int:
    return _pending_retrain_collection().count_documents({"batched_into_job_id": None})

def clear_pending_changes(job_id: str):
    _pending_retrain_collection().update_many(
        {"batched_into_job_id": None},
        {"$set": {"batched_into_job_id": job_id}}
    )

def insert_retrain_log(log_data: dict):
    log_data["created_at"] = datetime.now(timezone.utc)
    return _retrain_log_collection().insert_one(log_data).inserted_id

def get_retrain_history(limit: int = 20) -> List[dict]:
    cursor = _retrain_log_collection().find().sort("created_at", -1).limit(limit)
    return list(cursor)
