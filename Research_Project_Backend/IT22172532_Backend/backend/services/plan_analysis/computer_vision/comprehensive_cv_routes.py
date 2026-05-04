"""
bawanthaModel/comprehensive_cv_routes.py
========================================
Flask Blueprint that exposes the comprehensive CV analysis endpoint.

Endpoint
--------
POST /cv/comprehensive
    Form-data:
        image   : file  (required) — any image format OpenCV supports
        min_area: float (optional, default 50)   — minimum contour area

POST /cv/hough
    Form-data:
        image : file  (required) — any image format OpenCV supports
        method: str   (optional, default "probabilistic") — "probabilistic" or "standard"

Response 200 JSON:
{
    "success": true,
    "processing_time": 0.15,
    "image_size": {"width": 1024, "height": 768},
    "edges": {
        "count": 15,
        "image_b64": "<base64 JPEG of edges>"
    },
    "shapes": {
        "count": 8,
        "shapes": [
            {
                "id": 1,
                "shape": "Rectangle",
                "vertices": 4,
                "area": 1234.56,
                "perimeter": 145.67,
                "aspect_ratio": 1.23,
                "centroid": [512, 384],
                "bounding_box": [100, 200, 300, 150]
            }
        ],
        "image_b64": "<base64 JPEG with shapes>"
    },
    "corners": {
        "count": 24,
        "corners": [
            {
                "id": 1,
                "position": [45, 67],
                "response": 0.023
            }
        ],
        "image_b64": "<base64 JPEG with corners>"
    },
    "hough": {
        "count": 12,
        "lines": [
            {
                "id": 1,
                "start": [10, 20],
                "end": [300, 20],
                "length": 290.0
            }
        ],
        "image_b64": "<base64 JPEG with hough lines>"
    },
    "combined": {
        "image_b64": "<base64 JPEG with all detections>"
    }
}

Response 400 JSON (bad input):
{
    "success": false,
    "error": "No image file provided."
}
"""

from flask import Blueprint, request, jsonify
from .comprehensive_cv import ComprehensiveCV

comprehensive_cv_bp = Blueprint("comprehensive_cv", __name__, url_prefix="/cv")


@comprehensive_cv_bp.route("/comprehensive", methods=["POST"])
def comprehensive_analysis():
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
    def _float_param(key, default):
        raw = request.form.get(key)
        try:
            return float(raw) if raw is not None else default
        except ValueError:
            return default

    min_area = _float_param("min_area", 50.0)

    # ── Run full analysis ──────────────────────────────────────────────────
    analyzer = ComprehensiveCV(min_area=min_area)
    result = analyzer.analyze(image_bytes)

    status_code = 200 if result.get("success") else 422
    return jsonify(result), status_code


@comprehensive_cv_bp.route("/hough", methods=["POST"])
def hough_analysis():
    # ── Validate file upload ───────────────────────────────────────────────
    if "image" not in request.files:
        return jsonify({"success": False, "error": "No image file provided."}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"success": False, "error": "Empty filename."}), 400

    image_bytes = file.read()
    if len(image_bytes) == 0:
        return jsonify({"success": False, "error": "Uploaded file is empty."}), 400

    # ── Get method parameter ───────────────────────────────────────────────
    method = request.form.get("method", "probabilistic")
    if method not in ["probabilistic", "standard"]:
        method = "probabilistic"

    # ── Run hough analysis ─────────────────────────────────────────────────
    analyzer = ComprehensiveCV()
    result = analyzer.analyze_hough(image_bytes, method)

    status_code = 200 if result.get("success") else 422
    return jsonify(result), status_code
