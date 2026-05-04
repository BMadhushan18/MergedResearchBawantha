"""Auth routes."""

import datetime
import bcrypt
from bson import ObjectId
from flask import Blueprint, jsonify, request

from core.auth import get_current_uid, make_token
from database.connection import users_col
from core.errors import err


auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/auth/signup", methods=["POST"])
def signup():
    body = request.json or {}
    email = (body.get("email") or "").strip().lower()
    password = (body.get("password") or "").strip()
    display_name = (body.get("displayName") or "").strip()

    if not email or not password:
        return err("email and password required")
    if len(password) < 6:
        return err("password must be at least 6 characters")

    if users_col.find_one({"email": email}):
        return err("Email already in use", 409)

    pw_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    now = datetime.datetime.utcnow().isoformat()
    user_doc = {
        "email": email,
        "displayName": display_name,
        "passwordHash": pw_hash,
        "createdAt": now,
        "lastLoginAt": now,
        "role": "user",
    }
    result = users_col.insert_one(user_doc)
    uid = str(result.inserted_id)
    token = make_token(uid)

    user_out = {
        "uid": uid,
        "email": email,
        "displayName": display_name,
        "createdAt": now,
        "lastLoginAt": now,
    }
    return jsonify({"token": token, "user": user_out}), 201


@auth_bp.route("/auth/signin", methods=["POST"])
def signin():
    body = request.json or {}
    email = (body.get("email") or "").strip().lower()
    password = (body.get("password") or "").strip()

    if not email or not password:
        return err("email and password required")

    user = users_col.find_one({"email": email})
    if not user:
        return err("Invalid email or password", 401)

    stored_password = user.get("passwordHash") or user.get("password")
    if not stored_password:
        return err("Invalid email or password", 401)

    try:
        password_valid = bcrypt.checkpw(
            password.encode(),
            stored_password.encode(),
        )
    except ValueError:
        password_valid = stored_password == password

    if not password_valid:
        return err("Invalid email or password", 401)

    uid = str(user["_id"])
    now = datetime.datetime.utcnow().isoformat()
    users_col.update_one({"_id": user["_id"]}, {"$set": {"lastLoginAt": now}})

    token = make_token(uid)
    user_out = {
        "uid": uid,
        "email": user.get("email", ""),
        "displayName": user.get("displayName", ""),
        "createdAt": user.get("createdAt", ""),
        "lastLoginAt": now,
    }
    return jsonify({"token": token, "user": user_out}), 200


@auth_bp.route("/auth/me", methods=["GET"])
def me():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)
    try:
        user = users_col.find_one({"_id": ObjectId(uid)})
    except Exception:
        return err("Invalid token", 401)
    if not user:
        return err("User not found", 404)
    user_out = {
        "uid": str(user["_id"]),
        "email": user.get("email", ""),
        "displayName": user.get("displayName", ""),
        "createdAt": user.get("createdAt", ""),
        "lastLoginAt": user.get("lastLoginAt", ""),
    }
    return jsonify({"user": user_out}), 200


@auth_bp.route("/auth/reset-password", methods=["POST"])
def reset_password():
    body = request.json or {}
    email = (body.get("email") or "").strip().lower()
    user = users_col.find_one({"email": email})
    if not user:
        return jsonify({"message": "If that email exists, a reset link was sent."}), 200
    return jsonify({"message": "If that email exists, a reset link was sent."}), 200
