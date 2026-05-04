"""
bawanthaModel/contour_routes.py
================================
Flask Blueprint that exposes the contour-detection endpoint.

Endpoint
--------
POST /contour/detect
    Form-data:
        image   : file  (required) — any image format OpenCV supports
        min_area: float (optional, default 50)   — minimum contour area
        canny_low : int (optional) — lower Canny threshold (auto if omitted)
        canny_high: int (optional) — upper Canny threshold (auto if omitted)

Response 200 JSON:
{
    "success"        : true,
    "contour_count"  : 42,
    "processed_image": "<base64 JPEG with contours drawn>",
    "edge_map"       : "<base64 JPEG showing Canny edges>",
    "processing_time": 0.12,
    "image_size"     : {"width": 1024, "height": 768}
}

Response 400 JSON (bad input):
{
    "success": false,
    "error"  : "No image file provided."
}
"""

from flask import Blueprint, request, jsonify
from .contour_detector import ContourDetector

contour_bp = Blueprint("contour", __name__, url_prefix="/contour")


@contour_bp.route("/detect", methods=["POST"])
def detect_contours():
    # ── Validate file upload ───────────────────────────────────────────────
    if "image" not in request.files:
        return jsonify({"success": False, "error": "No image file provided."}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"success": False, "error": "Empty filename."}), 400

    image_bytes = file.read()
    if len(image_bytes) == 0:
        return jsonify({"success": False, "error": "Uploaded file is empty."}), 400

    # ── Optional parameters ────────────────────────────────────────────────
    def _int_or_none(key):
        raw = request.form.get(key)
        try:
            return int(raw) if raw is not None else None
        except ValueError:
            return None

    def _float_param(key, default):
        raw = request.form.get(key)
        try:
            return float(raw) if raw is not None else default
        except ValueError:
            return default

    min_area   = _float_param("min_area", 50.0)
    canny_low  = _int_or_none("canny_low")
    canny_high = _int_or_none("canny_high")

    # ── Run detection ──────────────────────────────────────────────────────
    detector = ContourDetector(
        min_area=min_area,
        canny_low=canny_low,
        canny_high=canny_high,
    )
    result = detector.detect(image_bytes)

    status_code = 200 if result.get("success") else 422
    return jsonify(result), status_code
