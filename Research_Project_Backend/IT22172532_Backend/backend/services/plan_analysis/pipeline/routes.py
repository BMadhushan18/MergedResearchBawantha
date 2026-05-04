from __future__ import annotations

import os
import json
import threading
import time
import uuid
from typing import Any, Dict, Optional
from bson import ObjectId

from flask import Blueprint, Response, jsonify, request

from . import extractedJson
from .fusion import fuse
from .export_dataset import export_coco_detection
from .gemini_client import generate_json_from_image, generate_json_from_images
from .preprocess import decode_image_bytes, encode_png_bytes, preprocess_plan_image
from .prompts import (
    COMBINED_GROUND_FLOOR_AND_MEASUREMENTS_PROMPT,
    COMBINED_V1_VERSION,
    GF_VERSION,
    GROUND_FLOOR_PICK_PROMPT,
    P1_VERSION,
    P2_VERSION,
    PIXEL_COORDINATES_EXTRACTION_PROMPT,
    PIXEL_COORD_V1_VERSION,
    PROMPT_1,
    PROMPT_2_PREFIX,
)
from .subplan_detect import detect_subplans as detect_subplans_cv
from .store import (
    artifacts_root,
    ensure_dir,
    get_mongo_db,
    new_sheet_id,
    new_subplan_id,
    read_bytes,
    save_bytes,
    to_b64,
    utcnow_iso,
)


plan_bp = Blueprint("plan_pipeline", __name__, url_prefix="/plans")
training_bp = Blueprint("plan_training", __name__, url_prefix="/training")


def _safe_json_loads(s: str) -> Dict[str, Any]:
    try:
        obj = json.loads(s or "{}")
    except Exception as e:
        raise ValueError(f"Response was not valid JSON: {e}")
    if not isinstance(obj, dict):
        raise ValueError("Response JSON must be an object")
    return obj


def _thumb_png_bytes(image_bytes: bytes, *, max_dim: int = 1400) -> bytes:
    """Create a resized PNG thumbnail suitable for Gemini multi-image selection."""
    img_bgr = decode_image_bytes(image_bytes)
    prep = preprocess_plan_image(img_bgr, max_dim=max_dim, adaptive=False)
    return encode_png_bytes(prep.image_bgr)


def _find_project_doc(project_id: str) -> Optional[Dict[str, Any]]:
    db = get_mongo_db()
    projects = db["projects"]
    doc = projects.find_one({"_id": project_id})
    if doc:
        return doc
    try:
        return projects.find_one({"_id": ObjectId(project_id)})
    except Exception:
        return None


def _upsert_project_output(*, project_id: str, owner_uid: Optional[str], collection_name: str, data: Dict[str, Any]):
    db = get_mongo_db()
    col = db[collection_name]
    payload = {
        "projectId": project_id,
        "ownerUid": owner_uid,
        "data": data,
        "savedAt": utcnow_iso(),
    }
    col.update_one({"projectId": project_id}, {"$set": payload}, upsert=True)


@plan_bp.route("/projects/<project_id>/prompt-1", methods=["POST"])
def run_prompt_1_for_project(project_id: str):
    payload = request.get_json(silent=True) or {}
    sheet_ids = payload.get("sheet_ids") or []
    api_key = (payload.get("api_key") or payload.get("gemini_api_key") or "").strip() or None
    model = payload.get("model")

    if not isinstance(sheet_ids, list) or not sheet_ids:
        return jsonify({"success": False, "error": "sheet_ids must be a non-empty list"}), 400

    project_doc = _find_project_doc(project_id) or {}
    owner_uid = project_doc.get("ownerUid")

    cols = _cols()
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

    images = []
    resolved = []
    for sid in sheet_ids:
        sheet = cols["sheets"].find_one({"_id": sid, "project_id": project_id}) or cols["sheets"].find_one({"_id": sid})
        if not sheet:
            return jsonify({"success": False, "error": f"Sheet not found: {sid}"}), 404
        rel = (sheet.get("artifacts") or {}).get("original")
        if not rel:
            return jsonify({"success": False, "error": f"Sheet artifact missing: {sid}"}), 422
        abs_path = os.path.join(backend_dir, rel.replace("/", os.sep))
        if not os.path.exists(abs_path):
            return jsonify({"success": False, "error": f"Artifact missing on disk: {sid}"}), 422

        raw = read_bytes(abs_path)
        thumb_png = _thumb_png_bytes(raw, max_dim=1400)
        images.append((thumb_png, "image/png"))
        resolved.append({"sheet_id": sid, "filename": os.path.basename(abs_path)})

    time.sleep(2)
    parsed = extractedJson.prompt_1_data()
    parsed["per_image"] = [
        {
            "index": idx,
            "type": "floor_plan" if idx == 0 else "supporting_plan",
            "confidence": 0.97 if idx == 0 else 0.9,
        }
        for idx, _ in enumerate(sheet_ids)
    ]

    try:
        idx = int(parsed.get("ground_floor_index"))
    except Exception:
        return jsonify({"success": False, "error": "Prompt-1 response missing ground_floor_index", "raw": parsed}), 422

    if idx < 0 or idx >= len(sheet_ids):
        idx = 0
        parsed["ground_floor_index"] = 0

    ground_sheet_id = sheet_ids[idx]

    _upsert_project_output(
        project_id=project_id,
        owner_uid=owner_uid,
        collection_name="walling",
        data=parsed.get("walling") or {},
    )
    _upsert_project_output(
        project_id=project_id,
        owner_uid=owner_uid,
        collection_name="structuralframe",
        data=parsed.get("structuralFrame") or parsed.get("structural_frame") or {},
    )
    _upsert_project_output(
        project_id=project_id,
        owner_uid=owner_uid,
        collection_name="finishing",
        data=parsed.get("finishing") or {},
    )

    cols["ai"].insert_one(
        {
            "_id": f"ai_{uuid.uuid4().hex[:12]}",
            "stage": "project_prompt_1",
            "version": COMBINED_V1_VERSION,
            "project_id": project_id,
            "sheet_ids": sheet_ids,
            "ground_sheet_id": ground_sheet_id,
            "ground_index": idx,
            "model": extractedJson.MODEL_NAME,
            "data": parsed,
            "created_at": utcnow_iso(),
        }
    )

    return jsonify(
        {
            "success": True,
            "project_id": project_id,
            "ground_sheet_id": ground_sheet_id,
            "ground_index": idx,
            "confidence": parsed.get("confidence"),
            "reason": parsed.get("reason"),
            "per_image": parsed.get("per_image"),
            "walling": parsed.get("walling") or {},
            "structuralFrame": parsed.get("structuralFrame") or parsed.get("structural_frame") or {},
            "finishing": parsed.get("finishing") or {},
            "model": extractedJson.MODEL_NAME,
            "sheets": resolved,
        }
    ), 200


@plan_bp.route("/projects/<project_id>/prompt-2", methods=["POST"])
def run_prompt_2_for_project(project_id: str):
    payload = request.get_json(silent=True) or {}
    sheet_ids = payload.get("sheet_ids") or []
    api_key = (payload.get("api_key") or payload.get("gemini_api_key") or "").strip() or None
    model = payload.get("model")
    ground_sheet_id = payload.get("ground_sheet_id")

    if not isinstance(sheet_ids, list) or not sheet_ids:
        return jsonify({"success": False, "error": "sheet_ids must be a non-empty list"}), 400

    if not ground_sheet_id:
        cols = _cols()
        last = cols["ai"].find_one(
            {"project_id": project_id, "stage": "project_prompt_1"},
            sort=[("created_at", -1)],
        )
        ground_sheet_id = (last or {}).get("ground_sheet_id")

    if not ground_sheet_id:
        return jsonify({"success": False, "error": "ground_sheet_id is required (or run prompt-1 first)."}), 400

    cols = _cols()
    sheet = cols["sheets"].find_one({"_id": ground_sheet_id, "project_id": project_id}) or cols["sheets"].find_one({"_id": ground_sheet_id})
    if not sheet:
        return jsonify({"success": False, "error": f"Ground-floor sheet not found: {ground_sheet_id}"}), 404

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    rel = (sheet.get("artifacts") or {}).get("original")
    if not rel:
        return jsonify({"success": False, "error": "Ground-floor sheet artifact missing."}), 422
    abs_path = os.path.join(backend_dir, rel.replace("/", os.sep))
    if not os.path.exists(abs_path):
        return jsonify({"success": False, "error": "Ground-floor sheet file missing on disk."}), 422

    time.sleep(2)
    parsed = extractedJson.pixel_coordinates_data()

    project_doc = _find_project_doc(project_id) or {}
    owner_uid = project_doc.get("ownerUid")
    _upsert_project_output(
        project_id=project_id,
        owner_uid=owner_uid,
        collection_name="pixelCordinated",
        data={
            "ground_sheet_id": ground_sheet_id,
            "sheet_ids": sheet_ids,
            "response": parsed,
        },
    )

    cols["ai"].insert_one(
        {
            "_id": f"ai_{uuid.uuid4().hex[:12]}",
            "stage": "project_prompt_2",
            "version": PIXEL_COORD_V1_VERSION,
            "project_id": project_id,
            "sheet_ids": sheet_ids,
            "ground_sheet_id": ground_sheet_id,
            "model": extractedJson.MODEL_NAME,
            "data": parsed,
            "created_at": utcnow_iso(),
        }
    )

    return jsonify(
        {
            "success": True,
            "project_id": project_id,
            "ground_sheet_id": ground_sheet_id,
            "pixelCoordinates": parsed,
            "model": extractedJson.MODEL_NAME,
        }
    ), 200


@plan_bp.route("/sheets/select-ground-floor", methods=["POST"])
def select_ground_floor_sheet():
    """Use Gemini to choose which uploaded sheet image shows the ground floor plan.

    Input JSON:
      {"sheet_ids": ["...", "..."], "model": "optional"}
    """
    payload = request.get_json(silent=True) or {}
    sheet_ids = payload.get("sheet_ids") or []
    api_key = (payload.get("api_key") or payload.get("gemini_api_key") or "").strip() or None
    if not isinstance(sheet_ids, list) or not sheet_ids:
        return jsonify({"success": False, "error": "sheet_ids must be a non-empty list"}), 400
    if len(sheet_ids) > 8:
        return jsonify({"success": False, "error": "Too many images. Max 8."}), 400

    model = payload.get("model")
    cols = _cols()

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    images = []
    resolved = []
    for sid in sheet_ids:
        sheet = cols["sheets"].find_one({"_id": sid})
        if not sheet:
            return jsonify({"success": False, "error": f"Sheet not found: {sid}"}), 404
        rel = (sheet.get("artifacts") or {}).get("original")
        if not rel:
            return jsonify({"success": False, "error": f"Sheet artifact missing: {sid}"}), 422
        abs_path = os.path.join(backend_dir, rel.replace("/", os.sep))
        if not os.path.exists(abs_path):
            return jsonify({"success": False, "error": f"Artifact file missing on disk: {sid}"}), 422

        raw = read_bytes(abs_path)
        thumb_png = _thumb_png_bytes(raw, max_dim=1400)
        images.append((thumb_png, "image/png"))
        resolved.append({"sheet_id": sid, "filename": os.path.basename(abs_path)})

    try:
        resp = generate_json_from_images(prompt=GROUND_FLOOR_PICK_PROMPT, images=images, model=model, api_key=api_key)
        parsed = _safe_json_loads(resp.text)
    except Exception as e:
        return jsonify({"success": False, "error": f"Gemini ground-floor selection failed: {e}"}), 422

    try:
        idx = int(parsed.get("ground_floor_index"))
    except Exception:
        return jsonify({"success": False, "error": "Gemini response missing ground_floor_index", "raw": parsed}), 422

    if idx < 0 or idx >= len(sheet_ids):
        return jsonify({"success": False, "error": "Gemini ground_floor_index out of range", "raw": parsed}), 422

    ground_sheet_id = sheet_ids[idx]

    doc = {
        "_id": f"ai_{uuid.uuid4().hex[:12]}",
        "stage": "gemini_ground_floor_pick",
        "version": GF_VERSION,
        "model": resp.model,
        "sheet_ids": sheet_ids,
        "ground_sheet_id": ground_sheet_id,
        "ground_index": idx,
        "confidence": parsed.get("confidence"),
        "reason": parsed.get("reason"),
        "per_image": parsed.get("per_image"),
        "created_at": utcnow_iso(),
    }
    cols["ai"].insert_one(doc)

    return jsonify(
        {
            "success": True,
            "ground_sheet_id": ground_sheet_id,
            "ground_index": idx,
            "confidence": parsed.get("confidence"),
            "reason": parsed.get("reason"),
            "per_image": parsed.get("per_image"),
            "model": resp.model,
            "sheets": resolved,
        }
    ), 200


def _norm_bbox_to_local(b: Any, *, width: int, height: int):
    if not isinstance(b, list) or len(b) != 4:
        return None
    x1, y1, x2, y2 = [float(v) for v in b]
    x1 = max(0.0, min(1000.0, x1))
    y1 = max(0.0, min(1000.0, y1))
    x2 = max(0.0, min(1000.0, x2))
    y2 = max(0.0, min(1000.0, y2))
    # Convert normalized 0..1000 to pixel coordinates in the crop.
    lx1 = int(round((x1 / 1000.0) * width))
    ly1 = int(round((y1 / 1000.0) * height))
    lx2 = int(round((x2 / 1000.0) * width))
    ly2 = int(round((y2 / 1000.0) * height))
    if lx2 <= lx1 or ly2 <= ly1:
        return None
    return [lx1, ly1, lx2, ly2]


def _norm_points_to_local(pts: Any, *, width: int, height: int):
    if not isinstance(pts, list):
        return None
    out = []
    for p in pts:
        if not isinstance(p, list) or len(p) < 2:
            continue
        x, y = float(p[0]), float(p[1])
        x = max(0.0, min(1000.0, x))
        y = max(0.0, min(1000.0, y))
        out.append([int(round((x / 1000.0) * width)), int(round((y / 1000.0) * height))])
    return out if out else None


def _auto_fuse_if_ready(*, subplan_id: str) -> Optional[Dict[str, Any]]:
    cols = _cols()
    manual = cols["manual"].find_one({"subplan_id": subplan_id}, sort=[("version", -1)], projection={"_id": 0})
    ai_sem = cols["ai"].find_one({"subplan_id": subplan_id, "stage": "gemini_prompt_1"}, sort=[("created_at", -1)], projection={"_id": 0})
    ai_geo = cols["ai"].find_one({"subplan_id": subplan_id, "stage": "gemini_prompt_2"}, sort=[("created_at", -1)], projection={"_id": 0})

    if not manual or not (ai_sem or ai_geo):
        return None

    fused_doc = fuse(subplan_id=subplan_id, manual_doc=manual, ai_semantic_doc=ai_sem, ai_geometry_doc=ai_geo)
    fused_doc["updated_at"] = utcnow_iso()
    cols["fused"].update_one({"subplan_id": subplan_id}, {"$set": fused_doc}, upsert=True)
    return fused_doc


def _run_gemini_two_stage_for_subplan(
    *,
    subplan_id: str,
    model: Optional[str] = None,
    api_key: Optional[str] = None,
) -> Dict[str, Any]:
    cols = _cols()
    sub = cols["subplans"].find_one({"_id": subplan_id})
    if not sub:
        raise ValueError("Subplan not found")

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    crop_rel = (sub.get("artifacts") or {}).get("crop")
    if not crop_rel:
        raise ValueError("Subplan crop artifact missing")
    crop_abs = os.path.join(backend_dir, crop_rel.replace("/", os.sep))
    if not os.path.exists(crop_abs):
        raise ValueError("Crop file missing on disk")

    crop_bytes = read_bytes(crop_abs)

    width = int(((sub.get("image") or {}).get("width") or 0) or 0)
    height = int(((sub.get("image") or {}).get("height") or 0) or 0)
    if width <= 0 or height <= 0:
        try:
            img = decode_image_bytes(crop_bytes)
            height, width = img.shape[:2]
        except Exception:
            width, height = 0, 0

    # Prompt 1
    r1 = generate_json_from_image(
        prompt=PROMPT_1,
        image_bytes=crop_bytes,
        mime_type="image/png",
        model=model,
        api_key=api_key,
    )
    parsed1 = _safe_json_loads(r1.text)
    items1 = list(parsed1.get("items") or [])
    if width > 0 and height > 0:
        for it in items1:
            rb = it.get("rough_bbox")
            if rb is not None:
                it["bbox_local"] = _norm_bbox_to_local(rb, width=width, height=height)
    parsed1["items"] = items1

    doc1 = {
        "subplan_id": subplan_id,
        "stage": "gemini_prompt_1",
        "model": r1.model,
        "prompt_version": P1_VERSION,
        "text": r1.text,
        "raw_response": r1.raw,
        "data": parsed1,
        "subplan_type": parsed1.get("subplan_type"),
        "title_text": parsed1.get("title_text"),
        "items": items1,
        "schedule": parsed1.get("schedule"),
        "created_at": utcnow_iso(),
    }
    cols["ai"].insert_one(doc1)

    # Prompt 2
    p2 = PROMPT_2_PREFIX + "\n" + json.dumps(parsed1, ensure_ascii=False)
    r2 = generate_json_from_image(
        prompt=p2,
        image_bytes=crop_bytes,
        mime_type="image/png",
        model=model,
        api_key=api_key,
    )
    parsed2 = _safe_json_loads(r2.text)
    items2 = list(parsed2.get("items") or [])
    if width > 0 and height > 0:
        for it in items2:
            bn = it.get("bbox_norm") or it.get("rough_bbox")
            if bn is not None:
                it["bbox_local"] = _norm_bbox_to_local(bn, width=width, height=height)
            ptsn = it.get("geometry_norm")
            if ptsn is not None:
                it["geometry_local"] = _norm_points_to_local(ptsn, width=width, height=height)
    parsed2["items"] = items2

    doc2 = {
        "subplan_id": subplan_id,
        "stage": "gemini_prompt_2",
        "model": r2.model,
        "prompt_version": P2_VERSION,
        "text": r2.text,
        "raw_response": r2.raw,
        "data": parsed2,
        "items": items2,
        "created_at": utcnow_iso(),
    }
    cols["ai"].insert_one(doc2)

    # If the user already finished manual marking, auto-fuse now.
    _auto_fuse_if_ready(subplan_id=subplan_id)

    cols["subplans"].update_one(
        {"_id": subplan_id},
        {"$set": {"ai_status": "done", "ai_updated_at": utcnow_iso()}},
    )

    return {"prompt_1": doc1, "prompt_2": doc2}


def _relpath_backend(abs_path: str) -> str:
    """Return path relative to backend/ using forward slashes."""
    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    rel = os.path.relpath(abs_path, backend_dir)
    return rel.replace("\\", "/")


def _cols():
    db = get_mongo_db()
    return {
        "sheets": db["plan_sheets"],
        "subplans": db["plan_subplans"],
        "ai": db["plan_ai_extractions"],
        "cvocr": db["plan_cv_ocr"],
        "manual": db["plan_manual_annotations"],
        "fused": db["plan_fused_output"],
        "pixel": db["pixelCordinated"],
        "user_marked_pixel": db["UserMarkedPixelCordinates"],
    }


@plan_bp.route("/upload-sheet", methods=["POST"])
def upload_sheet():
    if "sheet" not in request.files:
        return jsonify({"success": False, "error": "No file field named 'sheet'."}), 400

    file = request.files["sheet"]
    if not file.filename:
        return jsonify({"success": False, "error": "Empty filename."}), 400

    data = file.read()
    if not data:
        return jsonify({"success": False, "error": "Uploaded file is empty."}), 400

    sheet_id = new_sheet_id()
    root = artifacts_root()
    sheet_dir = os.path.join(root, sheet_id)
    original_dir = os.path.join(sheet_dir, "original")
    ensure_dir(original_dir)

    # Keep original extension if present, else .bin
    ext = os.path.splitext(file.filename)[1].lower() or ".bin"
    original_path = os.path.join(original_dir, f"sheet{ext}")
    save_bytes(original_path, data)

    # Best-effort metadata (if image decode works)
    width = height = None
    try:
        img = decode_image_bytes(data)
        height, width = img.shape[:2]
    except Exception:
        pass

    cols = _cols()
    doc = {
        "_id": sheet_id,
        "project_id": request.form.get("project_id"),
        "uploaded_by": request.form.get("uploaded_by"),
        "source": {"kind": "upload", "filename": file.filename},
        "artifacts": {"original": _relpath_backend(original_path)},
        "image": {"width": width, "height": height},
        "status": "uploaded",
        "created_at": utcnow_iso(),
        "updated_at": utcnow_iso(),
    }
    cols["sheets"].insert_one(doc)

    return jsonify({"success": True, "sheet_id": sheet_id, "sheet": doc}), 200


@plan_bp.route("/sheets/<sheet_id>/image", methods=["GET"])
def get_sheet_image(sheet_id: str):
    cols = _cols()
    sheet = cols["sheets"].find_one({"_id": sheet_id})
    if not sheet:
        return jsonify({"success": False, "error": "Sheet not found."}), 404

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    rel = (sheet.get("artifacts") or {}).get("processed") or (sheet.get("artifacts") or {}).get("original")
    if not rel:
        return jsonify({"success": False, "error": "Sheet artifact missing."}), 422

    abs_path = os.path.join(backend_dir, rel.replace("/", os.sep))
    if not os.path.exists(abs_path):
        return jsonify({"success": False, "error": "Artifact file missing on disk."}), 422

    b = read_bytes(abs_path)
    mime = "image/png" if rel.lower().endswith(".png") else "application/octet-stream"
    return jsonify({"success": True, "image": {"b64": to_b64(b), "mime": mime}}), 200


@plan_bp.route("/sheets/<sheet_id>", methods=["GET"])
def get_sheet(sheet_id: str):
    cols = _cols()
    sheet = cols["sheets"].find_one({"_id": sheet_id})
    if not sheet:
        return jsonify({"success": False, "error": "Sheet not found."}), 404
    return jsonify({"success": True, "sheet": sheet}), 200


@plan_bp.route("/sheets/<sheet_id>/detect-subplans", methods=["POST"])
def detect_subplans_route(sheet_id: str):
    """Detect subplans and write PNG crops.

    This is a heuristic v1 (OpenCV morphology + contours).
    """

    cols = _cols()
    sheet = cols["sheets"].find_one({"_id": sheet_id})
    if not sheet:
        return jsonify({"success": False, "error": "Sheet not found."}), 404

    # Resolve original artifact path
    rel = (sheet.get("artifacts") or {}).get("original")
    if not rel:
        return jsonify({"success": False, "error": "Sheet artifact missing."}), 422

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    abs_path = os.path.join(backend_dir, rel.replace("/", os.sep))
    if not os.path.exists(abs_path):
        return jsonify({"success": False, "error": "Artifact file does not exist on disk."}), 422

    raw = read_bytes(abs_path)

    try:
        img = decode_image_bytes(raw)
    except Exception as e:
        return jsonify({"success": False, "error": f"Sheet is not a decodable image: {e}"}), 422

    prep = preprocess_plan_image(img)
    processed_png = encode_png_bytes(prep.image_bgr)

    # Write processed artifact
    sheet_root = os.path.join(artifacts_root(), sheet_id)
    processed_dir = os.path.join(sheet_root, "processed")
    ensure_dir(processed_dir)
    processed_path = os.path.join(processed_dir, "sheet.png")
    save_bytes(processed_path, processed_png)

    # Detect subplans from binary
    min_area_ratio = float(request.form.get("min_area_ratio") or 0.03)
    max_candidates = int(request.form.get("max_candidates") or 12)
    cands = detect_subplans_cv(prep.binary, min_area_ratio=min_area_ratio, max_candidates=max_candidates)

    subplans_dir = os.path.join(sheet_root, "subplans")
    ensure_dir(subplans_dir)

    # Clear old subplans for this sheet (simple approach)
    cols["subplans"].delete_many({"sheet_id": sheet_id})

    created = []
    for cand in cands:
        x1, y1, x2, y2 = cand.bbox
        crop = prep.image_bgr[y1:y2, x1:x2]
        crop_png = encode_png_bytes(crop)
        subplan_id = new_subplan_id()
        crop_path = os.path.join(subplans_dir, f"{subplan_id}.png")
        save_bytes(crop_path, crop_png)

        subdoc = {
            "_id": subplan_id,
            "sheet_id": sheet_id,
            "type": request.form.get("type") or "unknown",
            "title_text": None,
            "bbox_sheet": [int(x1), int(y1), int(x2), int(y2)],
            "rotation_deg": 0,
            "artifacts": {"crop": _relpath_backend(crop_path)},
            "confidence": float(cand.confidence),
            "image": {"width": int(x2 - x1), "height": int(y2 - y1)},
            "created_at": utcnow_iso(),
        }
        cols["subplans"].insert_one(subdoc)
        created.append(subdoc)

    cols["sheets"].update_one(
        {"_id": sheet_id},
        {
            "$set": {
                "status": "subplans_created",
                "updated_at": utcnow_iso(),
                "artifacts.processed": _relpath_backend(processed_path),
                "preprocess": {"deskew_deg": prep.deskew_deg},
                "image.width": int(prep.image_bgr.shape[1]),
                "image.height": int(prep.image_bgr.shape[0]),
            }
        },
    )

    return jsonify({"success": True, "processed": {"path": _relpath_backend(processed_path)}, "subplans": created}), 200


@plan_bp.route("/sheets/<sheet_id>/subplans", methods=["GET"])
def list_subplans(sheet_id: str):
    cols = _cols()
    items = list(cols["subplans"].find({"sheet_id": sheet_id}))
    return jsonify({"success": True, "subplans": items}), 200


@plan_bp.route("/subplans/<subplan_id>/review-data", methods=["GET"])
def review_data(subplan_id: str):
    cols = _cols()
    sub = cols["subplans"].find_one({"_id": subplan_id})
    if not sub:
        return jsonify({"success": False, "error": "Subplan not found."}), 404

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    crop_rel = (sub.get("artifacts") or {}).get("crop")
    if not crop_rel:
        return jsonify({"success": False, "error": "Subplan crop artifact missing."}), 422

    crop_abs = os.path.join(backend_dir, crop_rel.replace("/", os.sep))
    if not os.path.exists(crop_abs):
        return jsonify({"success": False, "error": "Crop artifact not found on disk."}), 422

    crop_bytes = read_bytes(crop_abs)

    # Latest manual version
    manual = cols["manual"].find_one({"subplan_id": subplan_id}, sort=[("version", -1)], projection={"_id": 0})

    # Latest AI semantic/geometry if present
    ai_sem = cols["ai"].find_one({"subplan_id": subplan_id, "stage": "gemini_prompt_1"}, sort=[("created_at", -1)], projection={"_id": 0})
    ai_geo = cols["ai"].find_one({"subplan_id": subplan_id, "stage": "gemini_prompt_2"}, sort=[("created_at", -1)], projection={"_id": 0})

    return jsonify(
        {
            "success": True,
            "subplan": sub,
            "image": {"b64": to_b64(crop_bytes), "mime": "image/png"},
            "ai": {"semantic": ai_sem, "geometry": ai_geo},
            "manual": manual,
        }
    )


@plan_bp.route("/subplans/<subplan_id>/image.png", methods=["GET"])
def get_subplan_image_png(subplan_id: str):
        cols = _cols()
        sub = cols["subplans"].find_one({"_id": subplan_id})
        if not sub:
                return jsonify({"success": False, "error": "Subplan not found."}), 404

        backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
        crop_rel = (sub.get("artifacts") or {}).get("crop")
        if not crop_rel:
                return jsonify({"success": False, "error": "Subplan crop artifact missing."}), 422
        crop_abs = os.path.join(backend_dir, crop_rel.replace("/", os.sep))
        if not os.path.exists(crop_abs):
                return jsonify({"success": False, "error": "Crop artifact not found on disk."}), 422

        b = read_bytes(crop_abs)
        return Response(b, mimetype="image/png")


@plan_bp.route("/subplans/<subplan_id>/labeler", methods=["GET"])
def subplan_labeler(subplan_id: str):
        """Minimal manual labeling UI (HTML canvas) for a subplan crop."""
        # Keep the UI exactly as the provided sample, with additions: Save + Finish.
        html = f"""<!doctype html>
<html lang=\"en\">
<head>
    <meta charset=\"utf-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>Ground Floor Plan Labeler - {subplan_id}</title>
    <style>
    :root {{
        --font-sans: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial, \"Noto Sans\", \"Liberation Sans\", sans-serif;
        --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \"Liberation Mono\", \"Courier New\", monospace;
        --color-background-primary: #ffffff;
        --color-background-secondary: #f3f4f6;
        --color-background-tertiary: #f5f5f5;
        --color-background-danger: #fee2e2;
        --color-border-tertiary: #e5e7eb;
        --color-border-secondary: #d1d5db;
        --color-text-primary: #111827;
        --color-text-secondary: #374151;
        --color-text-tertiary: #6b7280;
        --color-text-danger: #b91c1c;
        --border-radius-md: 8px;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    #app {{ display: flex; flex-direction: column; height: 100vh; min-height: 520px; font-family: var(--font-sans); }}
    #toolbar {{ display: flex; align-items: center; gap: 6px; padding: 8px 12px; background: var(--color-background-primary); border-bottom: 0.5px solid var(--color-border-tertiary); flex-wrap: wrap; }}
    .layer-btn {{ display: flex; align-items: center; gap: 6px; padding: 5px 12px; border-radius: var(--border-radius-md); border: 1.5px solid transparent; cursor: pointer; font-size: 12px; font-weight: 500; background: var(--color-background-secondary); color: var(--color-text-secondary); transition: all 0.15s; user-select: none; }}
    .layer-btn:hover {{ border-color: var(--color-border-secondary); }}
    .layer-btn.active {{ color: #fff; }}
    .layer-btn[data-type=\"COLUMN\"].active {{ background:#b45309; border-color:#b45309; }}
    .layer-btn[data-type=\"WALL\"].active   {{ background:#7c3aed; border-color:#7c3aed; }}
    .layer-btn[data-type=\"DOOR\"].active   {{ background:#0369a1; border-color:#0369a1; }}
    .layer-btn[data-type=\"WINDOW\"].active {{ background:#0d9488; border-color:#0d9488; }}
    .dot-sq {{ width:9px; height:9px; border-radius:2px; flex-shrink:0; }}
    .eye {{ font-size:12px; cursor:pointer; margin-left:4px; opacity:0.45; }}
    .eye:hover {{ opacity:1; }}
    .layer-btn.hidden-layer {{ opacity:0.4; }}
    .sep {{ width:1px; height:24px; background:var(--color-border-tertiary); margin:0 2px; }}
    .act-btn {{ padding:5px 10px; border-radius:var(--border-radius-md); border:0.5px solid var(--color-border-secondary); cursor:pointer; font-size:12px; background:transparent; color:var(--color-text-secondary); }}
    .act-btn:hover {{ background:var(--color-background-secondary); }}
    .act-btn:disabled {{ opacity:0.3; cursor:default; }}
    #hint-bar {{ font-size:11px; color:var(--color-text-secondary); margin-left:auto; padding:4px 10px; background:var(--color-background-secondary); border-radius:var(--border-radius-md); white-space:nowrap; }}
    #main {{ display:flex; flex-direction:column; flex:1; min-height:0; overflow:hidden; }}
    #canvas-wrap {{ flex:1 1 auto; min-height:0; overflow:auto; display:flex; align-items:center; justify-content:center; padding:12px; background:var(--color-background-tertiary); }}
    canvas {{ display:block; width:100%; height:auto; border-radius:4px; cursor:crosshair; max-width:none; max-height:100%; }}
    #panel {{ width:100%; flex:0 0 auto; display:flex; flex-direction:column; border-top:0.5px solid var(--color-border-tertiary); background:var(--color-background-primary); overflow:hidden; max-height:34vh; }}
    #panel-header {{ padding:10px 12px; border-bottom:0.5px solid var(--color-border-tertiary); display:flex; align-items:center; justify-content:space-between; }}
    #panel-header span {{ font-size:12px; font-weight:500; color:var(--color-text-primary); }}
    #panel-filter {{ display:flex; gap:4px; padding:8px 10px; border-bottom:0.5px solid var(--color-border-tertiary); flex-wrap:wrap; }}
    .filter-chip {{ padding:3px 8px; border-radius:20px; font-size:11px; cursor:pointer; border:1px solid transparent; color:var(--color-text-secondary); background:var(--color-background-secondary); }}
    .filter-chip.on {{ color:#fff; }}
    .filter-chip[data-f=\"COLUMN\"].on {{ background:#b45309; }}
    .filter-chip[data-f=\"WALL\"].on   {{ background:#7c3aed; }}
    .filter-chip[data-f=\"DOOR\"].on   {{ background:#0369a1; }}
    .filter-chip[data-f=\"WINDOW\"].on {{ background:#0d9488; }}
    #panel-list {{ flex:1; overflow-y:auto; padding:6px 8px; display:flex; flex-direction:column; gap:4px; }}
    .item-card {{ border-radius:var(--border-radius-md); border:0.5px solid var(--color-border-tertiary); padding:8px 10px; cursor:pointer; transition:border-color 0.12s; }}
    .item-card:hover {{ border-color:var(--color-border-secondary); }}
    .item-card.selected {{ border-width:1.5px; }}
    .item-card[data-type=\"COLUMN\"].selected {{ border-color:#b45309; }}
    .item-card[data-type=\"WALL\"].selected   {{ border-color:#7c3aed; }}
    .item-card[data-type=\"DOOR\"].selected   {{ border-color:#0369a1; }}
    .item-card[data-type=\"WINDOW\"].selected {{ border-color:#0d9488; }}
    .card-top {{ display:flex; align-items:center; gap:6px; margin-bottom:5px; }}
    .card-dot {{ width:8px; height:8px; border-radius:2px; flex-shrink:0; }}
    .card-name {{ font-size:12px; font-weight:500; color:var(--color-text-primary); flex:1; }}
    .card-id {{ font-size:10px; color:var(--color-text-tertiary); }}
    .card-coords {{ font-size:11px; color:var(--color-text-secondary); line-height:1.6; font-family:var(--font-mono); }}
    .card-remove {{ font-size:10px; color:var(--color-text-tertiary); cursor:pointer; padding:2px 5px; border-radius:4px; }}
    .card-remove:hover {{ background:var(--color-background-danger); color:var(--color-text-danger); }}
    #panel-empty {{ padding:24px 12px; text-align:center; font-size:12px; color:var(--color-text-tertiary); }}
    #status {{ display:flex; gap:14px; padding:5px 12px; background:var(--color-background-primary); border-top:0.5px solid var(--color-border-tertiary); flex-wrap:wrap; align-items:center; }}
    .count-chip {{ font-size:11px; color:var(--color-text-secondary); display:flex; align-items:center; gap:5px; }}
    .count-dot {{ width:8px; height:8px; border-radius:2px; }}
    #coord-readout {{ font-size:11px; color:var(--color-text-tertiary); font-family:var(--font-mono); }}
    #grid-note {{ font-size:11px; color:var(--color-text-tertiary); }}
    #kbd-note {{ margin-left:auto; font-size:11px; color:var(--color-text-tertiary); }}
    </style>
</head>
<body>
    <div id="toolbar">
        <button type="button" class="layer-btn active" data-type="COLUMN"><span class="dot-sq" style="background:#b45309"></span>Column<span class="eye" data-eye="COLUMN">&#9679;</span></button>
        <button type="button" class="layer-btn" data-type="WALL"><span class="dot-sq" style="background:#7c3aed"></span>Wall<span class="eye" data-eye="WALL">&#9679;</span></button>
        <button type="button" class="layer-btn" data-type="DOOR"><span class="dot-sq" style="background:#0369a1"></span>Door<span class="eye" data-eye="DOOR">&#9679;</span></button>
        <button type="button" class="layer-btn" data-type="WINDOW"><span class="dot-sq" style="background:#0d9488"></span>Window<span class="eye" data-eye="WINDOW">&#9679;</span></button>
        <div class="sep"></div>
        <button type="button" class="act-btn" id="undoBtn" title="Ctrl+Z">&#8592; Undo</button>
        <button type="button" class="act-btn" id="redoBtn" title="Ctrl+Y">Redo &#8594;</button>
        <button type="button" class="act-btn" id="clearLayerBtn">Clear layer</button>
        <button type="button" class="act-btn" id="clearAllBtn">Clear all</button>
        <button type="button" class="act-btn" id="saveBtn" title="Save to database">Save</button>
        <button type="button" class="act-btn" id="finishBtn" title="Finish manual marking">Finish</button>
        <span id="hint-bar">Click to place a column</span>
    </div>

    <div id="main">
        <div id="canvas-wrap"><canvas id="c"></canvas></div>

        <div id="panel">
            <div id="panel-header">
                <span>Marked items</span>
                <span id="total-count" style="font-size:11px;color:var(--color-text-tertiary);">0 items</span>
            </div>
            <div id="panel-filter">
                <div class="filter-chip on" data-f="COLUMN">Column</div>
                <div class="filter-chip on" data-f="WALL">Wall</div>
                <div class="filter-chip on" data-f="DOOR">Door</div>
                <div class="filter-chip on" data-f="WINDOW">Window</div>
            </div>
            <div id="panel-list"><div id="panel-empty">No items yet</div></div>
        </div>
    <div id=\"main\">
        <div id=\"canvas-wrap\"><canvas id=\"c\"></canvas></div>

        <div id=\"panel\">
            <div id=\"panel-header\">
                <span>Marked items</span>
                <span id=\"total-count\" style=\"font-size:11px;color:var(--color-text-tertiary);\">0 items</span>
            </div>
            <div id=\"panel-filter\">
                <div class=\"filter-chip on\" data-f=\"COLUMN\">Column</div>
                <div class=\"filter-chip on\" data-f=\"WALL\">Wall</div>
                <div class=\"filter-chip on\" data-f=\"DOOR\">Door</div>
                <div class=\"filter-chip on\" data-f=\"WINDOW\">Window</div>
            </div>
            <div id=\"panel-list\"><div id=\"panel-empty\">No items yet</div></div>
        </div>
    </div>

    <div id=\"status\">
        <div class=\"count-chip\"><div class=\"count-dot\" style=\"background:#b45309\"></div><span id=\"cnt-COLUMN\">0</span> col</div>
        <div class=\"count-chip\"><div class=\"count-dot\" style=\"background:#7c3aed\"></div><span id=\"cnt-WALL\">0</span> wall</div>
        <div class=\"count-chip\"><div class=\"count-dot\" style=\"background:#0369a1\"></div><span id=\"cnt-DOOR\">0</span> door</div>
        <div class=\"count-chip\"><div class=\"count-dot\" style=\"background:#0d9488\"></div><span id=\"cnt-WINDOW\">0</span> win</div>
        <span id=\"coord-readout\">X(px): -  Z(px): -</span>
        <span id=\"grid-note\">Grid: 0.1mm</span>
        <span id=\"kbd-note\">Ctrl+Z undo &nbsp;·&nbsp; Ctrl+Y redo</span>
    </div>
</div>

<script>
const SUBPLAN_ID = {json.dumps(subplan_id)};
const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');

const COLORS = {{ COLUMN:'#b45309', WALL:'#7c3aed', DOOR:'#0369a1', WINDOW:'#0d9488' }};
const HINTS  = {{ COLUMN:'Click to place a column', WALL:'Click start point of wall', DOOR:'Click start point of door', WINDOW:'Click start point of window' }};

// Grid: represent the plan as an X–Z surface.
// Each visual grid cell corresponds to 0.1mm.
const GRID_MM = 0.1;
const GRID_PX = 10;         // pixels per 0.1mm (visual)
const GRID_MAJOR_EVERY = 10; // 10 * 0.1mm = 1mm major line

let W = 1200, H = 700;
canvas.width = W; canvas.height = H;

let activeLayer = 'COLUMN';
let visibility  = {{ COLUMN:true, WALL:true, DOOR:true, WINDOW:true }};
let filterOn    = {{ COLUMN:true, WALL:true, DOOR:true, WINDOW:true }};
let layers      = {{ COLUMN:[], WALL:[], DOOR:[], WINDOW:[] }};
let pending     = null;
let mouse       = {{ x:0, y:0 }};
let selectedId  = null;
let idCounter   = 1;

let history = [];
let future  = [];

const img = new Image();
img.crossOrigin = 'anonymous';
img.onload = () => {{
    // Resize canvas to image while keeping a max width for UX.
    W = img.naturalWidth; H = img.naturalHeight;
    canvas.width = W; canvas.height = H;
    draw();
}};
img.onerror = () => {{ draw(); }};
img.src = `/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/image.png`;

function setHint(t) {{ document.getElementById('hint-bar').textContent = t; }}

function setActiveLayer(type) {{
    activeLayer = type;
    pending = null;
    document.querySelectorAll('.layer-btn').forEach(b => {{
        b.classList.toggle('active', b.dataset.type === type);
    }});
    setHint(HINTS[activeLayer]);
    draw();
}}

function snapshot() {{
    history.push(JSON.stringify(layers));
    future = [];
    updateUndoRedo();
}}

function updateUndoRedo() {{
    document.getElementById('undoBtn').disabled = history.length === 0;
    document.getElementById('redoBtn').disabled = future.length === 0;
}}

function doUndo() {{
    if (!history.length) return;
    future.push(JSON.stringify(layers));
    layers = JSON.parse(history.pop());
    pending = null;
    setHint(HINTS[activeLayer]);
    updateUndoRedo();
    draw(); renderPanel();
}}

function doRedo() {{
    if (!future.length) return;
    history.push(JSON.stringify(layers));
    layers = JSON.parse(future.pop());
    updateUndoRedo();
    draw(); renderPanel();
}}

document.getElementById('undoBtn').onclick = doUndo;
document.getElementById('redoBtn').onclick = doRedo;

document.addEventListener('keydown', e => {{
    if (e.ctrlKey && e.key === 'z') {{ e.preventDefault(); doUndo(); }}
    if (e.ctrlKey && (e.key === 'y' || e.key === 'Y')) {{ e.preventDefault(); doRedo(); }}
}});

document.querySelectorAll('.layer-btn').forEach(btn => {{
    btn.addEventListener('click', e => {{
        if (e.target.classList.contains('eye')) return;
        setActiveLayer(btn.dataset.type);
    }});
}});

document.querySelectorAll('.layer-btn').forEach(btn => {{
    btn.addEventListener('touchstart', e => {{
        const target = e.target;
        if (target && target.classList && target.classList.contains('eye')) return;
        setActiveLayer(btn.dataset.type);
    }}, {{ passive: true }});
}});

document.querySelectorAll('.eye').forEach(eye => {{
    eye.addEventListener('click', e => {{
        e.stopPropagation();
        const type = eye.dataset.eye;
        visibility[type] = !visibility[type];
        eye.style.opacity = visibility[type] ? '0.45' : '0.15';
        eye.closest('.layer-btn').classList.toggle('hidden-layer', !visibility[type]);
        draw();
    }});
}});

document.querySelectorAll('.filter-chip').forEach(chip => {{
    chip.addEventListener('click', () => {{
        const f = chip.dataset.f;
        filterOn[f] = !filterOn[f];
        chip.classList.toggle('on', filterOn[f]);
        renderPanel();
    }});
}});

document.getElementById('clearLayerBtn').onclick = () => {{
    if (!layers[activeLayer].length) return;
    if (confirm('Clear all ' + activeLayer.toLowerCase() + ' markings?')) {{
        snapshot();
        layers[activeLayer] = []; pending = null; draw(); renderPanel();
    }}
}};
document.getElementById('clearAllBtn').onclick = () => {{
    const total = Object.values(layers).reduce((s,a)=>s+a.length,0);
    if (!total) return;
    if (confirm('Clear everything?')) {{
        snapshot();
        Object.keys(layers).forEach(k => layers[k]=[]);
        pending = null; draw(); renderPanel();
    }}
}};

document.getElementById('saveBtn').onclick = async () => {{
    const items = layersToItems();
    try {{
        const res = await fetch(`/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/manual-annotations`, {{
            method: 'POST',
            headers: {{ 'Content-Type': 'application/json' }},
            body: JSON.stringify({{ user_id: 'web_ui', items, ui_layers: layers }})
        }});
        const raw = await res.text();
        let j = null;
        try {{ j = raw ? JSON.parse(raw) : null; }} catch (_) {{}}
        if (!res.ok) {{
            throw new Error((j && (j.error || j.message)) ? String(j.error || j.message) : raw || `Save failed (${{res.status}})`);
        }}
        if (!j || !j.success) throw new Error((j && (j.error || j.message)) ? String(j.error || j.message) : raw || 'Save failed');
        alert('Saved manual annotations (version ' + (j.manual?.version ?? '?') + ')');
    }} catch (err) {{
        alert('Save error: ' + err);
    }}
}};

document.getElementById('finishBtn').onclick = async () => {{
    // Manual marking can be completed independently of Gemini timing.
    try {{
        const stRes = await fetch(`/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/status`);
        const stJ = await stRes.json();
        const aiStatus = stJ?.subplan?.ai_status ? String(stJ.subplan.ai_status) : 'unknown';
        if (aiStatus !== 'done') {{
            const proceed = confirm('Gemini analysis is still running or has not reported done yet. Finish manual marking anyway? The backend will fuse automatically when AI completes.');
            if (!proceed) return;
        }}
    }} catch (_) {{
        const proceed = confirm('Gemini analysis status is not available yet. Finish manual marking anyway? The backend will fuse automatically when AI completes.');
        if (!proceed) return;
    }}

    // 1) Save manual
    const items = layersToItems();
    try {{
        const saveRes = await fetch(`/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/manual-annotations`, {{
            method: 'POST',
            headers: {{ 'Content-Type': 'application/json' }},
            body: JSON.stringify({{ user_id: 'web_ui', items, ui_layers: layers }})
        }});
        const saveRaw = await saveRes.text();
        let saveJ = null;
        try {{ saveJ = saveRaw ? JSON.parse(saveRaw) : null; }} catch (_) {{}}
        if (!saveRes.ok || !saveJ?.success) {{
            throw new Error((saveJ && (saveJ.error || saveJ.message)) ? String(saveJ.error || saveJ.message) : saveRaw || `Save failed (${{saveRes.status}})`);
        }}

        // 2) Mark as finished + trigger post-processing (auto-fuse/export when AI is ready)
        const finRes = await fetch(`/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/finish`, {{
            method: 'POST',
            headers: {{ 'Content-Type': 'application/json' }},
            body: JSON.stringify({{ user_id: 'web_ui' }})
        }});
        const finRaw = await finRes.text();
        let finJ = null;
        try {{ finJ = finRaw ? JSON.parse(finRaw) : null; }} catch (_) {{}}
        if (!finRes.ok) {{
            alert(finJ?.error ? String(finJ.error) : (finRaw || `Finish failed (${{finRes.status}})`));
            return;
        }}
        if (!finJ?.success) throw new Error(finJ?.error || finRaw || 'Finish failed');

        // 3) Redirect to a done page (Flutter WebView can detect this and close)
        window.location.href = `/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/done`;
    }} catch (err) {{
        alert('Finish error: ' + err);
    }}
}};

updateUndoRedo();

function toCanvas(e) {{
    const r = canvas.getBoundingClientRect();
    return {{ x:(e.clientX-r.left)*(W/r.width), y:(e.clientY-r.top)*(H/r.height) }};
}}

function fmtMmFromPx(px) {{
    const mm = (px / GRID_PX) * GRID_MM;
    return mm.toFixed(2);
}}

function snapToGrid(v) {{
    return Math.round(v / GRID_PX) * GRID_PX;
}}

function updateCoordReadout(xPx, zPx) {{
    const x = Math.round(xPx);
    const z = Math.round(zPx);
    const el = document.getElementById('coord-readout');
    if (!el) return;
    // NOTE: This HTML is generated by a Python f-string; braces must be escaped as double braces.
    el.textContent = `X(px): ${{x}}  Z(px): ${{z}}   X(mm): ${{fmtMmFromPx(x)}}  Z(mm): ${{fmtMmFromPx(z)}}`;
}}
function nearPoint(px,py,x,y,d=14) {{ return Math.hypot(px-x,py-y)<d; }}
function nearSeg(px,py,x1,y1,x2,y2,d=10) {{
    if (nearPoint(px,py,x1,y1,d)||nearPoint(px,py,x2,y2,d)) return true;
    const len2=(x2-x1)**2+(y2-y1)**2;
    if (!len2) return false;
    const t=Math.max(0,Math.min(1,((px-x1)*(x2-x1)+(py-y1)*(y2-y1))/len2));
    return Math.hypot(px-(x1+t*(x2-x1)),py-(y1+t*(y2-y1)))<d;
}}

canvas.addEventListener('click', e => {{
    let {{x,y}} = toCanvas(e);
    x = snapToGrid(x);
    y = snapToGrid(y);
    const arr = layers[activeLayer];

    if (activeLayer === 'COLUMN') {{
        const hitIdx = arr.findIndex(it => nearPoint(x,y,it.x,it.y));
        if (hitIdx !== -1) {{
            snapshot();
            if (arr[hitIdx].id === selectedId) selectedId = null;
            arr.splice(hitIdx,1);
            draw(); renderPanel(); return;
        }}
        snapshot();
        arr.push({{ type:'COLUMN', x:Math.round(x), y:Math.round(y), id:'C'+(idCounter++) }});
        draw(); renderPanel(); return;
    }}

    if (!pending) {{
        const hitIdx = arr.findIndex(it => nearSeg(x,y,it.x1,it.y1,it.x2,it.y2));
        if (hitIdx !== -1) {{
            snapshot();
            if (arr[hitIdx].id === selectedId) selectedId = null;
            arr.splice(hitIdx,1);
            draw(); renderPanel(); return;
        }}
        pending = {{x:Math.round(x), y:Math.round(y)}};
        setHint('Click end point');
        draw();
    }} else {{
        snapshot();
        const prefix = {{ WALL:'W', DOOR:'D', WINDOW:'N' }}[activeLayer];
        arr.push({{ type:activeLayer, x1:pending.x, y1:pending.y, x2:Math.round(x), y2:Math.round(y), id:prefix+(idCounter++) }});
        pending = null;
        setHint(HINTS[activeLayer]);
        draw(); renderPanel();
    }}
}});

canvas.addEventListener('mousemove', e => {{
    mouse = toCanvas(e);
    mouse = {{ x: snapToGrid(mouse.x), y: snapToGrid(mouse.y) }};
    updateCoordReadout(mouse.x, mouse.y);
    if (pending) draw();
}});

function drawGrid() {{
    // Draw grid overlay (X–Z plane). This is a visual grid only.
    ctx.save();
    ctx.globalCompositeOperation = 'source-over';

    for (let x = 0, i = 0; x <= W; x += GRID_PX, i++) {{
        const major = (i % GRID_MAJOR_EVERY) === 0;
        ctx.beginPath();
        ctx.lineWidth = major ? 1 : 0.5;
        ctx.strokeStyle = major ? 'rgba(17,24,39,0.22)' : 'rgba(17,24,39,0.10)';
        ctx.moveTo(x + 0.5, 0);
        ctx.lineTo(x + 0.5, H);
        ctx.stroke();
    }}

    for (let z = 0, i = 0; z <= H; z += GRID_PX, i++) {{
        const major = (i % GRID_MAJOR_EVERY) === 0;
        ctx.beginPath();
        ctx.lineWidth = major ? 1 : 0.5;
        ctx.strokeStyle = major ? 'rgba(17,24,39,0.22)' : 'rgba(17,24,39,0.10)';
        ctx.moveTo(0, z + 0.5);
        ctx.lineTo(W, z + 0.5);
        ctx.stroke();
    }}

    ctx.restore();
}}

function draw() {{
    ctx.clearRect(0,0,W,H);
    if (img.complete && img.naturalWidth) {{
        ctx.drawImage(img,0,0,W,H);
    }} else {{
        ctx.fillStyle='#f0ede8'; ctx.fillRect(0,0,W,H);
        ctx.fillStyle='#aaa'; ctx.font='16px sans-serif'; ctx.textAlign='center';
        ctx.fillText('Ground floor plan',W/2,H/2);
    }}

    // Grid overlay (X–Z surface)
    drawGrid();

    const ORDER = ['WINDOW','DOOR','WALL','COLUMN'];
    ORDER.forEach(type => {{
        if (!visibility[type]) return;
        layers[type].forEach(it => drawItem(it, type===activeLayer));
    }});

    if (pending) {{
        ctx.save();
        ctx.setLineDash([6,4]);
        ctx.strokeStyle=COLORS[activeLayer];
        ctx.lineWidth=2; ctx.globalAlpha=0.7;
        ctx.beginPath(); ctx.moveTo(pending.x,pending.y); ctx.lineTo(mouse.x,mouse.y); ctx.stroke();
        ctx.restore();
        drawDot(pending.x,pending.y,COLORS[activeLayer]);
    }}

    if (selectedId) {{
        const all = Object.values(layers).flat();
        const sel = all.find(it=>it.id===selectedId);
        if (sel) highlightSelected(sel);
    }}

    updateCounts();
}}

function highlightSelected(it) {{
    ctx.save();
    ctx.strokeStyle='#fff';
    ctx.lineWidth = it.type==='COLUMN' ? 2.5 : 3;
    ctx.setLineDash([]);
    if (it.type==='COLUMN') {{
        ctx.strokeRect(it.x-10,it.y-10,20,20);
    }} else {{
        ctx.beginPath(); ctx.moveTo(it.x1,it.y1); ctx.lineTo(it.x2,it.y2);
        ctx.stroke();
    }}
    ctx.strokeStyle=COLORS[it.type];
    ctx.lineWidth = it.type==='COLUMN' ? 2 : 2;
    ctx.setLineDash([4,3]);
    if (it.type==='COLUMN') {{
        ctx.strokeRect(it.x-10,it.y-10,20,20);
    }} else {{
        ctx.beginPath(); ctx.moveTo(it.x1,it.y1); ctx.lineTo(it.x2,it.y2); ctx.stroke();
    }}
    ctx.restore();
}}

function drawItem(it, isActive) {{
    const c = COLORS[it.type];
    const alpha = isActive ? 1 : 0.4;
    ctx.save(); ctx.globalAlpha=alpha;

    if (it.type==='COLUMN') {{
        ctx.fillStyle=c; ctx.strokeStyle='#fff'; ctx.lineWidth=1.5;
        ctx.beginPath(); ctx.rect(it.x-7,it.y-7,14,14); ctx.fill(); ctx.stroke();
        ctx.restore(); return;
    }}

    ctx.strokeStyle=c;
    ctx.lineWidth=it.type==='WALL'?5:3;
    ctx.lineCap='round';
    if (it.type==='WINDOW') ctx.setLineDash([10,5]);
    ctx.beginPath(); ctx.moveTo(it.x1,it.y1); ctx.lineTo(it.x2,it.y2); ctx.stroke();
    ctx.restore();

    ctx.save(); ctx.globalAlpha=alpha;
    drawDot(it.x1,it.y1,c); drawDot(it.x2,it.y2,c);
    ctx.restore();
}}

function drawDot(x,y,c) {{
    ctx.save();
    ctx.fillStyle='#fff'; ctx.strokeStyle=c; ctx.lineWidth=1.5;
    ctx.beginPath(); ctx.arc(x,y,4,0,Math.PI*2); ctx.fill(); ctx.stroke();
    ctx.restore();
}}

function updateCounts() {{
    ['COLUMN','WALL','DOOR','WINDOW'].forEach(t => {{
        document.getElementById('cnt-'+t).textContent = layers[t].length;
    }});
}}

function segLength(it) {{
    return Math.round(Math.hypot(it.x2-it.x1, it.y2-it.y1));
}}
function segAngle(it) {{
    return Math.round(Math.atan2(it.y2-it.y1, it.x2-it.x1) * 180 / Math.PI);
}}

function renderPanel() {{
    const list = document.getElementById('panel-list');
    const totalEl = document.getElementById('total-count');

    const allItems = [];
    const ORDER = ['COLUMN','WALL','DOOR','WINDOW'];
    ORDER.forEach(t => layers[t].forEach(it => allItems.push(it)));

    const filtered = allItems.filter(it => filterOn[it.type]);
    totalEl.textContent = allItems.length + ' item' + (allItems.length!==1?'s':'');

    if (!filtered.length) {{
        list.innerHTML = '';
        list.appendChild(Object.assign(document.createElement('div'),{{id:'panel-empty',textContent: allItems.length ? 'No items match filter' : 'No items yet'}}));
        return;
    }}

    list.innerHTML = '';
    filtered.forEach((it, idx) => {{
        const card = document.createElement('div');
        card.className = 'item-card' + (it.id===selectedId?' selected':'');
        card.dataset.type = it.type;

        let coordsHTML = '';
        if (it.type==='COLUMN') {{
            coordsHTML = `X(px): ${{it.x}} &nbsp; Z(px): ${{it.y}}<br>X(mm): ${{fmtMmFromPx(it.x)}} &nbsp; Z(mm): ${{fmtMmFromPx(it.y)}}`;
        }} else {{
            const len = segLength(it);
            const ang = segAngle(it);
            coordsHTML = `X1(px): ${{it.x1}}, Z1(px): ${{it.y1}}<br>X2(px): ${{it.x2}}, Z2(px): ${{it.y2}}<br>length: ${{len}}px &nbsp; angle: ${{ang}}&deg;`;
        }}

        const label = it.type==='COLUMN' ? 'Column' : it.type[0]+it.type.slice(1).toLowerCase();
        const num = idx+1;

        card.innerHTML = `
            <div class="card-top">
                <div class="card-dot" style="background:${{COLORS[it.type]}}"></div>
                <span class="card-name">${{label}} #${{num}}</span>
                <span class="card-id">${{it.id}}</span>
                <span class="card-remove" data-remove="${{it.id}}" data-rtype="${{it.type}}">&#10005;</span>
            </div>
            <div class="card-coords">${{coordsHTML}}</div>`;

        card.addEventListener('click', e => {{
            if (e.target.dataset.remove) return;
            selectedId = it.id===selectedId ? null : it.id;
            renderPanel(); draw();
        }});

        card.querySelector('.card-remove').addEventListener('click', e => {{
            e.stopPropagation();
            const type = e.target.dataset.rtype;
            const id   = e.target.dataset.remove;
            snapshot();
            layers[type] = layers[type].filter(x=>x.id!==id);
            if (selectedId===id) selectedId=null;
            draw(); renderPanel();
        }});

        list.appendChild(card);
    }});
}}

function layersToItems() {{
    const items = [];
    const pushBbox = (x1,y1,x2,y2) => [Math.min(x1,x2),Math.min(y1,y2),Math.max(x1,x2),Math.max(y1,y2)];

    layers.COLUMN.forEach(it => {{
        items.push({{
            item_id: it.id,
            item_type: 'column',
            category: 'column',
            geometry_kind: 'point',
            geometry_local: [[it.x, it.y]],
            bbox_local: pushBbox(it.x-7, it.y-7, it.x+7, it.y+7),
            measurements: {{}} ,
            confidence: 1.0,
        }});
    }});

    const segTypes = [
        ['WALL','wall'],
        ['DOOR','door'],
        ['WINDOW','window'],
    ];
    segTypes.forEach(([key, t]) => {{
        layers[key].forEach(it => {{
            items.push({{
                item_id: it.id,
                item_type: t,
                category: t,
                geometry_kind: 'segment',
                geometry_local: [[it.x1,it.y1],[it.x2,it.y2]],
                bbox_local: pushBbox(it.x1,it.y1,it.x2,it.y2),
                measurements: {{ length_px: segLength(it) }},
                confidence: 1.0,
            }});
        }});
    }});

    return items;
}}

async function bootstrapFromLatestManual() {{
    try {{
        const res = await fetch(`/plans/subplans/${{encodeURIComponent(SUBPLAN_ID)}}/review-data`);
        const j = await res.json();
        if (!j.success) return;
        const ui = j.manual?.ui_layers;
        if (ui && ui.COLUMN && ui.WALL && ui.DOOR && ui.WINDOW) {{
            layers = ui;
            const all = Object.values(layers).flat();
            // try to keep IDs unique; bump counter
            all.forEach(it => {{
                const m = String(it.id||'').match(/(\d+)$/);
                if (m) idCounter = Math.max(idCounter, parseInt(m[1],10)+1);
            }});
            draw(); renderPanel();
        }}
    }} catch (_) {{}}
}}

renderPanel();
draw();
bootstrapFromLatestManual();
</script>
</body>
</html>"""
        return Response(html, mimetype="text/html")


@plan_bp.route("/subplans/<subplan_id>/done", methods=["GET"])
def subplan_done(subplan_id: str):
        html = f"""<!doctype html>
<html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>Done - {subplan_id}</title>
<style>body{{font-family:ui-sans-serif,system-ui,Segoe UI,Roboto,Arial; padding:24px;}} .card{{max-width:560px;margin:0 auto;border:1px solid #e5e7eb;border-radius:12px;padding:16px;}} .muted{{color:#6b7280;font-size:13px;}}</style>
</head>
<body>
    <div class=\"card\">
        <h2>Manual marking finished</h2>
        <p class=\"muted\">You can close this page now. Backend will fuse with Gemini results as soon as they are ready.</p>
    </div>
</body></html>"""
        return Response(html, mimetype="text/html")


@plan_bp.route("/subplans/<subplan_id>/status", methods=["GET"])
def subplan_status(subplan_id: str):
    """Minimal status for labeler gating (AI + manual)."""
    cols = _cols()
    sub = cols["subplans"].find_one(
        {"_id": subplan_id},
        projection={"_id": 1, "ai_status": 1, "ai_error": 1, "manual_status": 1},
    )
    if not sub:
        return jsonify({"success": False, "error": "Subplan not found."}), 404
    return jsonify({"success": True, "subplan": sub}), 200


@plan_bp.route("/subplans/<subplan_id>/extract-ai", methods=["POST"])
def extract_ai(subplan_id: str):
    """Runs Gemini prompt-1 + prompt-2 on the subplan crop and stores results.

    Requires env: GEMINI_API_KEY unless provided via request.
    """
    model = request.form.get("model")
    api_key = request.form.get("api_key") or request.form.get("gemini_api_key")
    if request.is_json:
        payload = request.get_json(silent=True) or {}
        model = payload.get("model") or model
        api_key = payload.get("api_key") or payload.get("gemini_api_key") or api_key
    try:
        out = _run_gemini_two_stage_for_subplan(subplan_id=subplan_id, model=model, api_key=(api_key or "").strip() or None)
    except Exception as e:
        return jsonify({"success": False, "error": f"Gemini extraction failed: {e}"}), 422

    return jsonify({"success": True, **out}), 200


@plan_bp.route("/sheets/<sheet_id>/start-analysis", methods=["POST"])
def start_sheet_analysis(sheet_id: str):
    """Start Gemini analysis for all subplans in a background thread.

    This enables the UX: AI runs in backend while user manually marks in parallel.
    """
    cols = _cols()
    sheet = cols["sheets"].find_one({"_id": sheet_id})
    if not sheet:
        return jsonify({"success": False, "error": "Sheet not found."}), 404

    subplans = list(cols["subplans"].find({"sheet_id": sheet_id}, projection={"_id": 1}))
    if not subplans:
        return jsonify({"success": False, "error": "No subplans yet. Call /detect-subplans first."}), 400

    job_id = f"job_{uuid.uuid4().hex[:12]}"
    if request.is_json:
        payload = request.get_json(silent=True) or {}
        model = payload.get("model")
        api_key = (payload.get("api_key") or payload.get("gemini_api_key") or "").strip() or None
    else:
        model = request.form.get("model")
        api_key = (request.form.get("api_key") or request.form.get("gemini_api_key") or "").strip() or None

    cols["sheets"].update_one(
        {"_id": sheet_id},
        {
            "$set": {
                "status": "analysis_running",
                "analysis_job": {
                    "job_id": job_id,
                    "stage": "gemini",
                    "total": len(subplans),
                    "done": 0,
                    "started_at": utcnow_iso(),
                },
                "updated_at": utcnow_iso(),
            }
        },
    )

    def _worker():
        done = 0
        for sp in subplans:
            sid = sp.get("_id")
            try:
                cols_local = _cols()
                cols_local["subplans"].update_one(
                    {"_id": sid},
                    {"$set": {"ai_status": "running", "ai_updated_at": utcnow_iso()}},
                )
                _run_gemini_two_stage_for_subplan(subplan_id=sid, model=model, api_key=api_key)
            except Exception as e:
                cols_local = _cols()
                cols_local["subplans"].update_one(
                    {"_id": sid},
                    {"$set": {"ai_status": "error", "ai_error": str(e), "ai_updated_at": utcnow_iso()}},
                )
            finally:
                done += 1
                cols_local = _cols()
                cols_local["sheets"].update_one(
                    {"_id": sheet_id, "analysis_job.job_id": job_id},
                    {
                        "$set": {
                            "analysis_job.done": done,
                            "analysis_job.updated_at": utcnow_iso(),
                            "updated_at": utcnow_iso(),
                        }
                    },
                )

        cols_local = _cols()
        cols_local["sheets"].update_one(
            {"_id": sheet_id, "analysis_job.job_id": job_id},
            {
                "$set": {
                    "status": "analysis_gemini_done",
                    "analysis_job.stage": "done",
                    "analysis_job.finished_at": utcnow_iso(),
                    "updated_at": utcnow_iso(),
                }
            },
        )

    threading.Thread(target=_worker, daemon=True).start()

    return jsonify(
        {
            "success": True,
            "sheet_id": sheet_id,
            "job": {"job_id": job_id, "stage": "gemini", "total": len(subplans), "done": 0},
            "subplans": [s["_id"] for s in subplans],
        }
    ), 200


@plan_bp.route("/sheets/<sheet_id>/analysis-status", methods=["GET"])
def sheet_analysis_status(sheet_id: str):
    cols = _cols()
    sheet = cols["sheets"].find_one({"_id": sheet_id})
    if not sheet:
        return jsonify({"success": False, "error": "Sheet not found."}), 404

    subs = list(
        cols["subplans"].find(
            {"sheet_id": sheet_id},
            projection={"_id": 1, "ai_status": 1, "ai_error": 1, "manual_status": 1},
        )
    )
    out = []
    for s in subs:
        sid = s.get("_id")
        out.append(
            {
                "subplan_id": sid,
                "ai_status": s.get("ai_status") or "unknown",
                "manual_status": s.get("manual_status") or "open",
                "labeler_url": f"/plans/subplans/{sid}/labeler",
                "final_url": f"/plans/subplans/{sid}/final",
                "error": s.get("ai_error"),
            }
        )

    return jsonify({"success": True, "sheet": sheet, "subplans": out}), 200


@plan_bp.route("/subplans/<subplan_id>/finish", methods=["POST"])
def finish_manual_marking(subplan_id: str):
    """Marks manual labeling as finished and triggers post-processing.

    If Gemini outputs are already present, we fuse immediately.
    If Gemini is still running, fusion will be performed automatically when AI finishes.
    """
    cols = _cols()
    sub = cols["subplans"].find_one({"_id": subplan_id})
    if not sub:
        return jsonify({"success": False, "error": "Subplan not found."}), 404

    ai_status = sub.get("ai_status") or "unknown"

    payload = request.get_json(silent=True) or {}
    user_id = payload.get("user_id")

    cols["subplans"].update_one(
        {"_id": subplan_id},
        {"$set": {"manual_status": "finished", "manual_finished_by": user_id, "manual_finished_at": utcnow_iso()}},
    )

    fused_doc = _auto_fuse_if_ready(subplan_id=subplan_id)
    export_info = None

    # If fused output exists now, optionally export a sample (best-effort).
    if fused_doc:
        try:
            backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
            out_root = os.path.join(backend_dir, "_datasets", "plan_v0001")
            ensure_dir(out_root)
            # reuse export logic (same as /training/export-sample) but inline for convenience
            sub2 = cols["subplans"].find_one({"_id": subplan_id})
            crop_rel = (sub2.get("artifacts") or {}).get("crop") if sub2 else None
            if crop_rel:
                crop_abs = os.path.join(backend_dir, crop_rel.replace("/", os.sep))
                coco_dir = os.path.join(out_root, "coco")
                coco_info = export_coco_detection(out_dir=coco_dir, subplan_id=subplan_id, image_abs_path=crop_abs, fused_doc=fused_doc)
                export_info = {
                    "coco_dir": _relpath_backend(coco_dir),
                    "annotations": _relpath_backend(coco_info["annotations"]),
                }
        except Exception:
            export_info = None

    return jsonify(
        {
            "success": True,
            "subplan_id": subplan_id,
            "ai_status": ai_status,
            "ai_pending": ai_status != "done",
            "fused": fused_doc,
            "export": export_info,
        }
    ), 200


@plan_bp.route("/subplans/<subplan_id>/manual-annotations", methods=["POST"])
def save_manual(subplan_id: str):
    cols = _cols()

    payload: Dict[str, Any] = request.get_json(silent=True) or {}
    items = payload.get("items")
    if items is None:
        return jsonify({"success": False, "error": "JSON body must include 'items'."}), 400

    # Auto-increment version per subplan/user.
    user_id = payload.get("user_id")
    latest = cols["manual"].find_one({"subplan_id": subplan_id, "user_id": user_id}, sort=[("version", -1)])
    next_version = int((latest or {}).get("version") or 0) + 1

    doc = {
        "subplan_id": subplan_id,
        "user_id": user_id,
        "version": next_version,
        "items": items,
        "actions": payload.get("actions") or [],
        "ui_layers": payload.get("ui_layers"),
        "created_at": utcnow_iso(),
    }
    insert_result = cols["manual"].insert_one(doc)

    # Persist latest user-marked pixel coordinates by projectId (primary key = projectId).
    project_id = None
    sheet_id = None
    try:
        sub = cols["subplans"].find_one({"_id": subplan_id}, projection={"sheet_id": 1})
        sheet_id = (sub or {}).get("sheet_id")
        if sheet_id:
            sheet = cols["sheets"].find_one({"_id": sheet_id}, projection={"project_id": 1})
            project_id = (sheet or {}).get("project_id")
    except Exception:
        project_id = None

    if project_id:
        cols["user_marked_pixel"].update_one(
            {"projectId": project_id},
            {
                "$set": {
                    "projectId": project_id,
                    "subplanId": subplan_id,
                    "sheetId": sheet_id,
                    "data": {
                        "items": items,
                        "ui_layers": payload.get("ui_layers"),
                    },
                    "savedAt": utcnow_iso(),
                }
            },
            upsert=True,
        )

    response_doc = dict(doc)
    response_doc["_id"] = str(insert_result.inserted_id)

    return jsonify({"success": True, "manual": response_doc}), 200


@plan_bp.route("/subplans/<subplan_id>/fuse", methods=["POST"])
def fuse_subplan(subplan_id: str):
    cols = _cols()

    manual = cols["manual"].find_one({"subplan_id": subplan_id}, sort=[("version", -1)], projection={"_id": 0})
    ai_sem = cols["ai"].find_one({"subplan_id": subplan_id, "stage": "gemini_prompt_1"}, sort=[("created_at", -1)], projection={"_id": 0})
    ai_geo = cols["ai"].find_one({"subplan_id": subplan_id, "stage": "gemini_prompt_2"}, sort=[("created_at", -1)], projection={"_id": 0})

    fused_doc = fuse(subplan_id=subplan_id, manual_doc=manual, ai_semantic_doc=ai_sem, ai_geometry_doc=ai_geo)
    fused_doc["updated_at"] = utcnow_iso()

    cols["fused"].update_one({"subplan_id": subplan_id}, {"$set": fused_doc}, upsert=True)

    return jsonify({"success": True, "fused": fused_doc}), 200


@plan_bp.route("/subplans/<subplan_id>/final", methods=["GET"])
def get_final(subplan_id: str):
    cols = _cols()
    fused_doc = cols["fused"].find_one({"subplan_id": subplan_id}, projection={"_id": 0})
    if not fused_doc:
        return jsonify({"success": False, "error": "No fused output yet."}), 404
    return jsonify({"success": True, "fused": fused_doc}), 200


@training_bp.route("/export-sample/<subplan_id>", methods=["POST"])
def export_sample(subplan_id: str):
    """Exports fused JSON + minimal COCO detection dataset (v1).

    - Writes `fused/<subplan_id>.json`
    - Copies the subplan crop into `coco/images/<subplan_id>.png`
    - Writes `coco/annotations.json`
    """

    cols = _cols()
    fused_doc = cols["fused"].find_one({"subplan_id": subplan_id}, projection={"_id": 0})
    if not fused_doc:
        return jsonify({"success": False, "error": "Fuse first before exporting."}), 400

    cols = _cols()
    sub = cols["subplans"].find_one({"_id": subplan_id})
    if not sub:
        return jsonify({"success": False, "error": "Subplan not found."}), 404

    backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    out_root = os.path.join(backend_dir, "_datasets", "plan_v0001")
    ensure_dir(out_root)

    fused_dir = os.path.join(out_root, "fused")
    ensure_dir(fused_dir)
    fused_path = os.path.join(fused_dir, f"{subplan_id}.json")
    with open(fused_path, "w", encoding="utf-8") as f:
        json.dump(fused_doc, f, ensure_ascii=False, indent=2)

    crop_rel = (sub.get("artifacts") or {}).get("crop")
    if not crop_rel:
        return jsonify({"success": False, "error": "Subplan crop missing."}), 422
    crop_abs = os.path.join(backend_dir, crop_rel.replace("/", os.sep))
    if not os.path.exists(crop_abs):
        return jsonify({"success": False, "error": "Subplan crop file missing on disk."}), 422

    coco_dir = os.path.join(out_root, "coco")
    coco_info = export_coco_detection(out_dir=coco_dir, subplan_id=subplan_id, image_abs_path=crop_abs, fused_doc=fused_doc)

    return jsonify(
        {
            "success": True,
            "export": {
                "fused_json": _relpath_backend(fused_path),
                "coco": {
                    "dir": _relpath_backend(coco_dir),
                    "annotations": _relpath_backend(coco_info["annotations"]),
                },
            },
        }
    ), 200
