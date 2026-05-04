"""Three.js HTML storage routes."""

import datetime
from flask import Blueprint, jsonify, request

from core.auth import get_current_uid
from database.connection import threejs_col
from core.errors import err


threejs_bp = Blueprint("threejs", __name__)


@threejs_bp.route("/threejs/<project_id>", methods=["GET"])
def get_threejs(project_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    doc = threejs_col.find_one({"projectId": project_id, "ownerUid": uid})
    if not doc:
        doc = threejs_col.find_one({"projectId": project_id})
    if not doc:
        return jsonify({
            "projectId": project_id,
            "foundation": None,
            "finishing": None,
        }), 200

    return jsonify({
        "projectId": project_id,
        "foundation": doc.get("foundation"),
        "finishing": doc.get("finishing"),
        "updatedAt": doc.get("updatedAt"),
    }), 200


@threejs_bp.route("/threejs/<project_id>", methods=["POST"])
def upsert_threejs(project_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    now = datetime.datetime.utcnow().isoformat()

    update = {
        "projectId": project_id,
        "ownerUid": uid,
        "updatedAt": now,
    }
    if "foundation" in body:
        update["foundation"] = body.get("foundation")
    if "finishing" in body:
        update["finishing"] = body.get("finishing")

    threejs_col.update_one(
        {"projectId": project_id},
        {"$set": update, "$setOnInsert": {"createdAt": now}},
        upsert=True,
    )

    return jsonify({"ok": True, "projectId": project_id}), 200


@threejs_bp.route("/threejs/<project_id>/<category>", methods=["GET"])
def get_threejs_category(project_id, category):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    if category not in ["foundation", "finishing"]:
        return err("category must be foundation or finishing", 400)

    doc = threejs_col.find_one({"projectId": project_id, "ownerUid": uid})
    if not doc:
        doc = threejs_col.find_one({"projectId": project_id})
    if not doc:
        return jsonify({"html_code": None}), 200

    return jsonify({"html_code": doc.get(category)}), 200


@threejs_bp.route("/threejs/<project_id>/<category>", methods=["POST"])
def set_threejs_category(project_id, category):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    if category not in ["foundation", "finishing"]:
        return err("category must be foundation or finishing", 400)

    body = request.json or {}
    html = body.get("html_code")
    now = datetime.datetime.utcnow().isoformat()

    threejs_col.update_one(
        {"projectId": project_id},
        {
            "$set": {
                "projectId": project_id,
                "ownerUid": uid,
                category: html,
                "updatedAt": now,
            },
            "$setOnInsert": {"createdAt": now},
        },
        upsert=True,
    )

    return jsonify({"ok": True, "projectId": project_id, "category": category}), 200
