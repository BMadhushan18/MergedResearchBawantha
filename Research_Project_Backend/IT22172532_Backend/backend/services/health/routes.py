"""Health check routes."""

from flask import Blueprint, jsonify

from config.settings import DB_NAME
import database.connection as db_conn


health_bp = Blueprint("health", __name__)


@health_bp.route("/health", methods=["GET"])
def health():
    try:
        db_conn.client.admin.command("ping")
        return jsonify({
            "status": "ok",
            "db": DB_NAME,
            "mongo": "local-fallback" if db_conn.USING_LOCAL_STORE else "connected",
            "dbReady": db_conn.DB_READY,
            "startupError": db_conn.DB_INIT_ERROR if db_conn.USING_LOCAL_STORE else "",
        }), 200
    except Exception as e:
        return jsonify({
            "status": "error",
            "db": DB_NAME,
            "mongo": "disconnected",
            "dbReady": db_conn.DB_READY,
            "detail": str(e),
            "startupError": db_conn.DB_INIT_ERROR,
        }), 500
