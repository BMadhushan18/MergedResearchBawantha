"""Pixel coordinates service.

Stores and retrieves floor-plan object detection results (walls, doors, windows)
as pixel coordinate polygons per project.

Also exposes image preprocessing helpers (text removal, wall isolation) that
were previously in separate standalone backends - now merged here so the main
Flask app is the single backend.
"""

from __future__ import annotations

import base64
import datetime
import io
from typing import Any, Dict, Optional

import cv2
import numpy as np
from flask import Blueprint, jsonify, request

from core.auth import get_current_uid
from core.errors import err
from database.connection import pixelcoordinates_col

pixel_coordinates_bp = Blueprint("pixel_coordinates", __name__, url_prefix="/pixel-coordinates")


# ─── helpers ──────────────────────────────────────────────────────────────────

def _utcnow() -> str:
    return datetime.datetime.utcnow().isoformat() + "Z"


def _decode_data_url(data_url: str) -> np.ndarray:
    """Decode a base64 data URL or raw base64 string to a BGR OpenCV image."""
    if "," in data_url:
        data_url = data_url.split(",", 1)[1]
    raw = base64.b64decode(data_url)
    arr = np.frombuffer(raw, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image data")
    return img


def _encode_to_data_url(img: np.ndarray) -> str:
    """Encode a BGR OpenCV image to a PNG data URL."""
    ok, buf = cv2.imencode(".png", img)
    if not ok:
        raise ValueError("Could not encode image to PNG")
    b64 = base64.b64encode(buf.tobytes()).decode()
    return f"data:image/png;base64,{b64}"


def _auto_clean(
    img: np.ndarray,
    *,
    remove_text: bool = True,
    remove_dimensions: bool = True,
    blob_size_limit: int = 200,
    aspect_limit: float = 6.0,
    apply_closing: bool = False,
    apply_sharpen: bool = False,
    locked_regions: Optional[list] = None,
) -> tuple[np.ndarray, int]:
    """Remove small text-like connected components from a floor-plan image."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    count, _labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8, cv2.CV_32S)

    h_img, w_img = gray.shape
    lock_mask = np.zeros(gray.shape, dtype=np.uint8)
    for region in (locked_regions or []):
        if len(region) == 4:
            x1, y1, x2, y2 = [int(v) for v in region]
            top = max(0, min(y1, y2))
            bottom = min(h_img, max(y1, y2))
            left = max(0, min(x1, x2))
            right = min(w_img, max(x1, x2))
            if right > left and bottom > top:
                lock_mask[top:bottom, left:right] = 255

    result = img.copy()
    removed = 0

    for i in range(1, count):
        area = int(stats[i, cv2.CC_STAT_AREA])
        w = int(stats[i, cv2.CC_STAT_WIDTH])
        h = int(stats[i, cv2.CC_STAT_HEIGHT])
        left = int(stats[i, cv2.CC_STAT_LEFT])
        top_y = int(stats[i, cv2.CC_STAT_TOP])

        shortest = max(1, min(w, h))
        aspect = max(w, h) / float(shortest)

        is_text_blob = remove_text and area < blob_size_limit and aspect < aspect_limit
        is_dim_blob = (
            remove_dimensions
            and area < int(blob_size_limit * 0.6)
            and aspect < aspect_limit
        )

        if lock_mask[top_y: top_y + h, left: left + w].any():
            continue

        if is_text_blob or is_dim_blob:
            result[top_y: top_y + h, left: left + w] = (255, 255, 255)
            removed += 1

    if apply_closing:
        kernel = np.ones((3, 3), np.uint8)
        result = cv2.morphologyEx(result, cv2.MORPH_CLOSE, kernel)

    if apply_sharpen:
        k = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]])
        result = cv2.filter2D(result, -1, k)

    return result, removed


def _keep_walls(img: np.ndarray, *, keep_fraction: float = 0.85) -> tuple[np.ndarray, int, int]:
    """Keep only the largest structural dark components (wall isolation)."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (3, 3), 0)
    binary = cv2.adaptiveThreshold(
        blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV, blockSize=15, C=6,
    )
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8)
    if num_labels <= 1:
        return img, 0, 0

    comp_areas = sorted(
        [(int(stats[i, cv2.CC_STAT_AREA]), i) for i in range(1, num_labels)],
        reverse=True,
    )
    total_dark = sum(a for a, _ in comp_areas)
    keep_set: set = set()
    accumulated = 0

    for area, label_idx in comp_areas:
        if total_dark > 0 and accumulated / total_dark >= keep_fraction:
            break
        keep_set.add(label_idx)
        accumulated += area

    keep_mask = np.isin(labels, list(keep_set)).astype(np.uint8)
    result = np.full_like(img, 255)
    result[keep_mask == 1] = img[keep_mask == 1]

    removed = (num_labels - 1) - len(keep_set)
    return result, len(keep_set), removed


# ─── image preprocessing endpoint ─────────────────────────────────────────────

@pixel_coordinates_bp.route("/process-images", methods=["POST"])
def process_images():
    """
    Run text removal and wall isolation on one or more floor-plan images.

    Request JSON:
        {
          "images": ["data:image/png;base64,...", ...],
          "remove_text": true,
          "remove_dimensions": true,
          "blob_size_limit": 200,
          "aspect_limit": 6.0,
          "keep_fraction": 0.85
        }

    Response JSON:
        {
          "processed_images": ["data:image/png;base64,...", ...],
          "removed_counts": [42, 18]
        }
    """
    data = request.get_json(silent=True) or {}
    images = data.get("images", [])
    if not images or not isinstance(images, list):
        return err("images array is required", 400)

    remove_text = bool(data.get("remove_text", True))
    remove_dimensions = bool(data.get("remove_dimensions", True))
    blob_size_limit = int(data.get("blob_size_limit", 200))
    aspect_limit = float(data.get("aspect_limit", 6.0))
    keep_fraction = float(data.get("keep_fraction", 0.85))

    processed = []
    removed_counts = []

    for img_data in images:
        try:
            img = _decode_data_url(str(img_data))
        except Exception as e:
            return err(f"Bad image data: {e}", 400)

        cleaned, removed = _auto_clean(
            img,
            remove_text=remove_text,
            remove_dimensions=remove_dimensions,
            blob_size_limit=blob_size_limit,
            aspect_limit=aspect_limit,
        )
        wall_isolated, _, _ = _keep_walls(cleaned, keep_fraction=keep_fraction)
        processed.append(_encode_to_data_url(wall_isolated))
        removed_counts.append(removed)

    return jsonify({"processed_images": processed, "removed_counts": removed_counts})


# ─── pixel coordinates CRUD ───────────────────────────────────────────────────

@pixel_coordinates_bp.route("/<pid>", methods=["POST"])
def save_pixel_coordinates(pid: str):
    """Save detected floor-plan pixel coordinates for a project.

    Request JSON:
        {
          "images": [
            {
              "imageIndex": 0,
              "detectedObjects": [
                {
                  "class": "wall" | "door" | "window",
                  "confidence": 0.85,
                  "polygon": [[x, y], ...],
                  "bbox": [x1, y1, x2, y2]
                }
              ]
            }
          ],
          "summary": {"totalWalls": 8, "totalDoors": 6, "totalWindows": 10}
        }
    """
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    payload = request.get_json(silent=True) or {}
    if not payload:
        return err("Request body is required", 400)

    doc: Dict[str, Any] = {
        "projectId": pid,
        "ownerUid": uid,
        "images": payload.get("images", []),
        "summary": payload.get("summary", {}),
        "processedAt": payload.get("processedAt", _utcnow()),
        "createdAt": _utcnow(),
        "updatedAt": _utcnow(),
    }

    pixelcoordinates_col.update_one(
        {"projectId": pid},
        {"$set": doc},
        upsert=True,
    )

    return jsonify({"ok": True, "projectId": pid}), 201


@pixel_coordinates_bp.route("/<pid>", methods=["GET"])
def get_pixel_coordinates(pid: str):
    """Retrieve saved pixel coordinates for a project."""
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    doc = pixelcoordinates_col.find_one({"projectId": pid})
    if not doc:
        return jsonify({}), 200

    doc.pop("_id", None)
    return jsonify(doc), 200
