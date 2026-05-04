"""Error helpers for API responses."""

from flask import jsonify


def err(msg: str, code: int = 400):
    return jsonify({"error": msg}), code
