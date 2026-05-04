"""Project routes and subcollections."""

import datetime
from bson import ObjectId
from flask import Blueprint, jsonify, request

from core.auth import get_current_uid
from database.connection import (
    buildingstructure_col,
    finishing_col,
    projects_col,
    structuralframe_col,
    walling_col,
    get_db,
)
from core.errors import err
from core.serialization import bson_to_dict


projects_bp = Blueprint("projects", __name__)


def find_project(pid: str, uid: str):
    """Look up a project by _id (ObjectId or UUID string) or projectId field."""
    try:
        doc = projects_col.find_one({"_id": ObjectId(pid), "ownerUid": uid})
        if doc:
            return doc
    except Exception:
        pass
    return projects_col.find_one({"$or": [{"_id": pid}, {"projectId": pid}], "ownerUid": uid})


def get_sub_col(pid: str, sub: str):
    """Each project's subcollection stored as db['p_<pid_short>_<sub>']."""
    safe_pid = pid.replace("-", "")[:16]
    safe_sub = sub.replace("-", "_").replace("/", "_")
    return get_db()[f"p_{safe_pid}_{safe_sub}"]


def find_sub_doc(col, doc_id: str, sub: str):
    """Find a sub-doc by MongoDB _id (ObjectId or UUID string) or model id field."""
    try:
        doc = col.find_one({"_id": ObjectId(doc_id)})
        if doc:
            return doc
    except Exception:
        pass
    doc = col.find_one({"_id": doc_id})
    if doc:
        return doc
    singular = sub.rstrip("s")
    id_field = singular + "Id"
    return col.find_one({id_field: doc_id})


@projects_bp.route("/projects", methods=["GET"])
def list_projects():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    docs = list(projects_col.find({"ownerUid": uid}))
    return jsonify([bson_to_dict(d) for d in docs]), 200


@projects_bp.route("/projects", methods=["POST"])
def create_project():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    body["ownerUid"] = uid
    body["createdAt"] = datetime.datetime.utcnow().isoformat()
    body["updatedAt"] = datetime.datetime.utcnow().isoformat()
    if "projectId" in body:
        body["_id"] = body["projectId"]
    result = projects_col.insert_one(body)
    body["_id"] = str(result.inserted_id)
    return jsonify(bson_to_dict(body)), 201


@projects_bp.route("/projects/<pid>", methods=["GET"])
def get_project(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    return jsonify(bson_to_dict(doc)), 200


@projects_bp.route("/projects/<pid>", methods=["PUT"])
def update_project(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    body.pop("_id", None)
    body["updatedAt"] = datetime.datetime.utcnow().isoformat()
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    projects_col.update_one({"_id": doc["_id"]}, {"$set": body})
    return jsonify({"updated": True}), 200


@projects_bp.route("/projects/<pid>", methods=["DELETE"])
def delete_project(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    projects_col.delete_one({"_id": doc["_id"]})
    return jsonify({"deleted": True}), 200


@projects_bp.route("/projects/<pid>/<sub>", methods=["GET"])
def list_sub(pid, sub):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    col = get_sub_col(pid, sub)
    docs = list(col.find())
    return jsonify([bson_to_dict(d) for d in docs]), 200


@projects_bp.route("/projects/<pid>/<sub>", methods=["POST"])
def create_sub(pid, sub):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    body["createdAt"] = datetime.datetime.utcnow().isoformat()
    col = get_sub_col(pid, sub)
    singular = sub.rstrip("s")
    id_field = singular + "Id"
    if id_field in body:
        body["_id"] = body[id_field]
    result = col.insert_one(body)
    body["_id"] = str(result.inserted_id)
    return jsonify(bson_to_dict(body)), 201


@projects_bp.route("/projects/<pid>/<sub>/<doc_id>", methods=["GET"])
def get_sub_doc(pid, sub, doc_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    col = get_sub_col(pid, sub)
    doc = find_sub_doc(col, doc_id, sub)
    if not doc:
        return err("Not found", 404)
    return jsonify(bson_to_dict(doc)), 200


@projects_bp.route("/projects/<pid>/<sub>/<doc_id>", methods=["PUT"])
def update_sub_doc(pid, sub, doc_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    body.pop("_id", None)
    body["updatedAt"] = datetime.datetime.utcnow().isoformat()
    col = get_sub_col(pid, sub)
    doc = find_sub_doc(col, doc_id, sub)
    if not doc:
        return err("Not found", 404)
    col.update_one({"_id": doc["_id"]}, {"$set": body})
    return jsonify({"updated": True}), 200


@projects_bp.route("/projects/<pid>/<sub>/<doc_id>", methods=["DELETE"])
def delete_sub_doc(pid, sub, doc_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    col = get_sub_col(pid, sub)
    doc = find_sub_doc(col, doc_id, sub)
    if not doc:
        return err("Not found", 404)
    col.delete_one({"_id": doc["_id"]})
    return jsonify({"deleted": True}), 200


@projects_bp.route("/buildingstructure/<pid>", methods=["POST"])
def save_building_structure(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    body = request.json or {}
    payload = {
        "projectId": pid,
        "ownerUid": uid,
        "data": body,
        "savedAt": datetime.datetime.utcnow().isoformat(),
    }
    buildingstructure_col.update_one(
        {"projectId": pid},
        {"$set": payload},
        upsert=True,
    )
    saved = buildingstructure_col.find_one({"projectId": pid})
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/buildingstructure/<pid>", methods=["GET"])
def get_building_structure(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    saved = buildingstructure_col.find_one({"projectId": pid})
    if not saved:
        return jsonify({}), 200
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/structuralframe/<pid>", methods=["POST"])
def save_structural_frame(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    body = request.json or {}
    payload = {
        "projectId": pid,
        "ownerUid": uid,
        "data": body,
        "savedAt": datetime.datetime.utcnow().isoformat(),
    }
    structuralframe_col.update_one(
        {"projectId": pid},
        {"$set": payload},
        upsert=True,
    )
    saved = structuralframe_col.find_one({"projectId": pid})
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/structuralframe/<pid>", methods=["GET"])
def get_structural_frame(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    saved = structuralframe_col.find_one({"projectId": pid})
    if not saved:
        return jsonify({}), 200
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/structuralframe/<pid>", methods=["PATCH"])
def patch_structural_frame(pid):
    """Partial update for individual column measurements."""
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    set_fields = {"savedAt": datetime.datetime.utcnow().isoformat()}
    for col_key, fields in (body.get("columns") or {}).items():
        for f, v in (fields or {}).items():
            set_fields[f"data.groundFloor.columns.{col_key}.{f}"] = v
    if len(set_fields) > 1:
        structuralframe_col.update_one({"projectId": pid}, {"$set": set_fields})
    return jsonify({"updated": True, "fields": len(set_fields) - 1}), 200


@projects_bp.route("/walling/<pid>", methods=["POST"])
def save_walling(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    body = request.json or {}
    payload = {
        "projectId": pid,
        "ownerUid": uid,
        "data": body,
        "savedAt": datetime.datetime.utcnow().isoformat(),
    }
    walling_col.update_one(
        {"projectId": pid},
        {"$set": payload},
        upsert=True,
    )
    saved = walling_col.find_one({"projectId": pid})
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/walling/<pid>", methods=["GET"])
def get_walling(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    saved = walling_col.find_one({"projectId": pid})
    if not saved:
        return jsonify({}), 200
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/walling/<pid>", methods=["PATCH"])
def patch_walling(pid):
    """Partial update for individual wall / door / window measurements."""
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    set_fields = {"savedAt": datetime.datetime.utcnow().isoformat()}
    for wall_key, fields in (body.get("walls") or {}).items():
        for f, v in (fields or {}).items():
            set_fields[f"data.groundFloor.walls.{wall_key}.{f}"] = v
    for door_key, fields in (body.get("doors") or {}).items():
        for f, v in (fields or {}).items():
            set_fields[f"data.doors.{door_key}.{f}"] = v
    for win_key, fields in (body.get("windows") or {}).items():
        for f, v in (fields or {}).items():
            set_fields[f"data.windows.{win_key}.{f}"] = v
    if len(set_fields) > 1:
        walling_col.update_one({"projectId": pid}, {"$set": set_fields})
    return jsonify({"updated": True, "fields": len(set_fields) - 1}), 200


@projects_bp.route("/finishing/<pid>", methods=["POST"])
def save_finishing(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    doc = find_project(pid, uid)
    if not doc:
        return err("Project not found", 404)
    body = request.json or {}
    payload = {
        "projectId": pid,
        "ownerUid": uid,
        "data": body,
        "savedAt": datetime.datetime.utcnow().isoformat(),
    }
    finishing_col.update_one(
        {"projectId": pid},
        {"$set": payload},
        upsert=True,
    )
    saved = finishing_col.find_one({"projectId": pid})
    return jsonify(bson_to_dict(saved)), 200


@projects_bp.route("/finishing/<pid>", methods=["GET"])
def get_finishing(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    saved = finishing_col.find_one({"projectId": pid})
    if not saved:
        return jsonify({}), 200
    return jsonify(bson_to_dict(saved)), 200
