"""Materials library routes."""

import datetime
from bson import ObjectId
from flask import Blueprint, jsonify, request

from core.auth import get_current_uid
from database.connection import materials_col
from core.errors import err
from core.serialization import bson_to_dict


materials_bp = Blueprint("materials", __name__)


@materials_bp.route("/materials", methods=["GET"])
def list_materials():
    docs = list(
        materials_col.find(
            {},
            {
                "_id": 1,
                "name": 1,
                "category": 1,
                "unit": 1,
                "unitPrice": 1,
                "brands": 1,
                "sizes": 1,
                "boqSections": 1,
            },
        ).sort("name", 1)
    )
    return jsonify([bson_to_dict(d) for d in docs]), 200


@materials_bp.route("/materials", methods=["POST"])
def create_material():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    name = (body.get("name") or "").strip()
    if not name:
        return err("name is required")
    brands = [b.strip() for b in (body.get("brands") or []) if b.strip()]
    sizes = [s.strip() for s in (body.get("sizes") or []) if s.strip()]
    category = (body.get("category") or "General").strip()
    unit = (body.get("unit") or "No.").strip()
    unit_price = body.get("unitPrice")

    if materials_col.find_one({"name_lower": name.lower()}):
        return err(f"Material '{name}' already exists", 409)

    now = datetime.datetime.utcnow().isoformat()
    doc = {
        "name": name,
        "name_lower": name.lower(),
        "category": category,
        "unit": unit,
        "unitPrice": unit_price,
        "brands": brands,
        "sizes": sizes,
        "createdAt": now,
        "updatedAt": now,
    }
    result = materials_col.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return jsonify(bson_to_dict(doc)), 201


@materials_bp.route("/materials/options/<path:material_name>", methods=["GET"])
def get_material_options(material_name):
    doc = materials_col.find_one(
        {"name_lower": material_name.strip().lower()},
        {"_id": 0, "brands": 1, "sizes": 1},
    )
    if not doc:
        return jsonify({"brands": [], "sizes": []}), 200
    return jsonify({"brands": doc.get("brands", []), "sizes": doc.get("sizes", [])}), 200


@materials_bp.route("/materials/<material_id>", methods=["GET"])
def get_material(material_id):
    try:
        doc = materials_col.find_one({"_id": ObjectId(material_id)})
    except Exception:
        return err("Invalid id", 400)
    if not doc:
        return err("Not found", 404)
    return jsonify(bson_to_dict(doc)), 200


@materials_bp.route("/materials/<material_id>", methods=["PUT"])
def update_material(material_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    body = request.json or {}
    update = {"updatedAt": datetime.datetime.utcnow().isoformat()}
    if "brands" in body:
        update["brands"] = [b.strip() for b in body["brands"] if b.strip()]
    if "sizes" in body:
        update["sizes"] = [s.strip() for s in body["sizes"] if s.strip()]
    if "name" in body:
        name = body["name"].strip()
        if name:
            update["name"] = name
            update["name_lower"] = name.lower()
    try:
        res = materials_col.update_one({"_id": ObjectId(material_id)}, {"$set": update})
    except Exception:
        return err("Invalid id", 400)
    if res.matched_count == 0:
        return err("Not found", 404)
    doc = materials_col.find_one({"_id": ObjectId(material_id)})
    return jsonify(bson_to_dict(doc)), 200


@materials_bp.route("/materials/<material_id>", methods=["DELETE"])
def delete_material(material_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    try:
        res = materials_col.delete_one({"_id": ObjectId(material_id)})
    except Exception:
        return err("Invalid id", 400)
    if res.deleted_count == 0:
        return err("Not found", 404)
    return jsonify({"ok": True}), 200
