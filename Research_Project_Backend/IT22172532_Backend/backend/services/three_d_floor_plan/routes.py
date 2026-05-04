"""3D Floor Plan — full-featured image-filter + Three.js 3D builder viewer."""

from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from flask import Blueprint, jsonify, make_response, request

three_d_floor_plan_bp = Blueprint(
    "three_d_floor_plan", __name__, url_prefix="/3d-floor-plan"
)

_ARTIFACTS = Path(__file__).parent.parent.parent / "_artifacts"


# ─── image helpers ─────────────────────────────────────────────────────────────

def _decode_data_url(data_url: str) -> np.ndarray:
    if "," in data_url:
        data_url = data_url.split(",", 1)[1]
    raw = base64.b64decode(data_url)
    arr = np.frombuffer(raw, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image")
    return img


def _encode_data_url(img: np.ndarray) -> str:
    ok, buf = cv2.imencode(".png", img)
    if not ok:
        raise ValueError("Could not encode image")
    return "data:image/png;base64," + base64.b64encode(buf.tobytes()).decode()


def _apply_filters(img: np.ndarray, params: dict[str, Any]) -> tuple[np.ndarray, int]:
    """Apply all requested adjustments and filters. Returns (result, removed_count)."""
    removed = 0
    out = img.copy()

    thickness = max(3, int(params.get("wall_thickness", 5)))
    if thickness % 2 == 0:
        thickness += 1

    # brightness / contrast
    brightness = int(params.get("brightness", 0))
    contrast = float(params.get("contrast", 1.0))
    if brightness != 0 or contrast != 1.0:
        out = cv2.convertScaleAbs(out, alpha=contrast, beta=brightness)

    # histogram equalization (Y channel of YUV so colour is preserved)
    if params.get("apply_histogram"):
        yuv = cv2.cvtColor(out, cv2.COLOR_BGR2YUV)
        yuv[:, :, 0] = cv2.equalizeHist(yuv[:, :, 0])
        out = cv2.cvtColor(yuv, cv2.COLOR_YUV2BGR)

    kernel = np.ones((thickness, thickness), np.uint8)

    if params.get("apply_min_filter"):
        out = cv2.erode(out, kernel)
    if params.get("apply_max_filter"):
        out = cv2.dilate(out, kernel)
    if params.get("apply_average_filter"):
        out = cv2.blur(out, (thickness, thickness))
    if params.get("apply_median_filter"):
        k = thickness if thickness % 2 == 1 else thickness + 1
        out = cv2.medianBlur(out, k)
    if params.get("apply_sharpen_filter"):
        sharp_k = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]])
        out = cv2.filter2D(out, -1, sharp_k)
    if params.get("apply_opening_filter"):
        out = cv2.morphologyEx(out, cv2.MORPH_OPEN, kernel)
    if params.get("apply_closing_filter"):
        out = cv2.morphologyEx(out, cv2.MORPH_CLOSE, kernel)
    if params.get("apply_erosion_filter"):
        out = cv2.erode(out, kernel)
    if params.get("apply_dilation_filter"):
        out = cv2.dilate(out, kernel)

    # text / dimension removal via connected-component analysis
    locked = params.get("locked_regions") or []
    if params.get("remove_text") or params.get("remove_dimensions"):
        blob_limit = int(params.get("blob_size_limit", 300))
        aspect_limit = float(params.get("aspect_limit", 8.0))
        gray = cv2.cvtColor(out, cv2.COLOR_BGR2GRAY)
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        n, _lbl, stats, _ = cv2.connectedComponentsWithStats(binary, 8, cv2.CV_32S)
        h_img, w_img = gray.shape

        lock_mask = np.zeros(gray.shape, dtype=np.uint8)
        for region in locked:
            if len(region) == 4:
                x1, y1, x2, y2 = [int(v) for v in region]
                top = max(0, min(y1, y2))
                bot = min(h_img, max(y1, y2))
                lft = max(0, min(x1, x2))
                rgt = min(w_img, max(x1, x2))
                if rgt > lft and bot > top:
                    lock_mask[top:bot, lft:rgt] = 255

        for i in range(1, n):
            area = int(stats[i, cv2.CC_STAT_AREA])
            bw = int(stats[i, cv2.CC_STAT_WIDTH])
            bh = int(stats[i, cv2.CC_STAT_HEIGHT])
            lft = int(stats[i, cv2.CC_STAT_LEFT])
            top = int(stats[i, cv2.CC_STAT_TOP])
            asp = max(bw, bh) / max(1, min(bw, bh))
            small = (
                (params.get("remove_text") and area < blob_limit and asp < aspect_limit)
                or (params.get("remove_dimensions") and area < int(blob_limit * 0.6) and asp < aspect_limit)
            )
            if small and not lock_mask[top:top + bh, lft:lft + bw].any():
                out[top:top + bh, lft:lft + bw] = (255, 255, 255)
                removed += 1

    # wall isolation — keep largest dark connected components
    if params.get("apply_wall_isolation"):
        gray = cv2.cvtColor(out, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (3, 3), 0)
        binary = cv2.adaptiveThreshold(
            blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 15, 6
        )
        binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
        n2, labels, stats2, _ = cv2.connectedComponentsWithStats(binary, 8)
        if n2 > 1:
            areas = sorted(
                [(int(stats2[i, cv2.CC_STAT_AREA]), i) for i in range(1, n2)],
                reverse=True,
            )
            total = sum(a for a, _ in areas)
            keep: set[int] = set()
            acc = 0
            for area, idx in areas:
                if total > 0 and acc / total >= 0.85:
                    break
                keep.add(idx)
                acc += area
            mask = np.isin(labels, list(keep)).astype(np.uint8)
            isolated = np.full_like(out, 255)
            isolated[mask == 1] = out[mask == 1]
            out = isolated

    return out, removed


# ─── endpoints ────────────────────────────────────────────────────────────────

@three_d_floor_plan_bp.route("/process-image", methods=["POST"])
def process_image_endpoint():
    """Apply image filters and return processed result as a data URL."""
    data = request.get_json(silent=True) or {}
    raw = data.get("image", "")
    if not raw:
        return jsonify({"error": "image is required"}), 400
    try:
        img = _decode_data_url(str(raw))
    except Exception as exc:
        return jsonify({"error": f"Bad image data: {exc}"}), 400
    result, removed = _apply_filters(img, data)
    return jsonify({"result": _encode_data_url(result), "removed_count": removed})


@three_d_floor_plan_bp.route("/<project_id>/image", methods=["POST"])
def save_project_image(project_id: str):
    """Persist a floor-plan image for a project (used by the plan pipeline)."""
    data = request.get_json(silent=True) or {}
    raw = data.get("image", "")
    if not raw:
        return jsonify({"error": "image is required"}), 400
    folder = _ARTIFACTS / project_id
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "floor_plan_3d.json").write_text(
        json.dumps({"image": str(raw), "filename": data.get("filename", "floor_plan.png")}),
        encoding="utf-8",
    )
    return jsonify({"ok": True})


@three_d_floor_plan_bp.route("/<project_id>/image", methods=["GET"])
def get_project_image(project_id: str):
    """Return the persisted floor-plan image for a project."""
    path = _ARTIFACTS / project_id / "floor_plan_3d.json"
    if not path.exists():
        return jsonify({"image": None}), 404
    return jsonify(json.loads(path.read_text(encoding="utf-8")))


@three_d_floor_plan_bp.route("/viewer", methods=["GET"])
def serve_viewer():
    """Serve the full-featured floor-plan filter + 3D builder viewer."""
    resp = make_response(_VIEWER_HTML)
    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    resp.headers["Cache-Control"] = "no-store"
    return resp


# ─── viewer HTML (index.html + main.js merged, API paths made relative) ────────

_VIEWER_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Floor Plan Filters + 3D Builder</title>
  <style>
    :root {
      --bg: #0b0d14;
      --panel: #171a25;
      --panel-2: #1e2331;
      --line: #2c3142;
      --text: #eef1ff;
      --muted: #97a0bb;
      --accent: #6f78ff;
      --accent-2: #4de3ae;
      --danger: #ff9090;
    }
    * { box-sizing: border-box; }
    html, body { margin: 0; min-height: 100%; background: radial-gradient(circle at top, #131827 0%, var(--bg) 58%); color: var(--text); font-family: Arial, sans-serif; }
    body::before {
      content: '';
      position: fixed;
      inset: 0;
      pointer-events: none;
      background-image: radial-gradient(rgba(255,255,255,0.04) 1px, transparent 1px);
      background-size: 24px 24px;
      opacity: 0.28;
    }
    .wrap { position: relative; z-index: 1; max-width: 1440px; margin: 0 auto; padding: 22px 18px 36px; }
    .hero { text-align: center; margin-bottom: 18px; }
    .hero h1 { margin: 10px 0 10px; font-size: clamp(28px, 5vw, 46px); line-height: 1; }
    .hero p { margin: 0 auto; max-width: 880px; color: var(--muted); line-height: 1.6; }
    .chips { display: flex; gap: 10px; flex-wrap: wrap; justify-content: center; margin: 16px 0 24px; }
    .chip { border: 1px solid var(--line); background: rgba(23,26,37,0.9); border-radius: 999px; padding: 10px 14px; font-size: 12px; color: var(--muted); }
    .chip.ok { color: var(--accent-2); border-color: rgba(77,227,174,.36); }
    .layout { display: grid; grid-template-columns: 420px 1fr; gap: 18px; align-items: start; }
    @media (max-width: 1080px) { .layout { grid-template-columns: 1fr; } }
    .sidebar, .panel { border: 1px solid var(--line); background: rgba(23,26,37,0.92); border-radius: 24px; box-shadow: 0 18px 50px rgba(0,0,0,.3); }
    .sidebar { padding: 16px; position: sticky; top: 14px; max-height: calc(100vh - 28px); overflow: auto; }
    .section + .section { margin-top: 16px; }
    .section-title { font-size: 12px; letter-spacing: 0.16em; color: var(--muted); text-transform: uppercase; margin-bottom: 10px; }
    .field, .toggle { border: 1px solid var(--line); border-radius: 18px; background: rgba(30,35,49,0.95); padding: 13px 14px; margin-bottom: 10px; }
    .upload { cursor: pointer; display: flex; justify-content: center; align-items: center; min-height: 58px; }
    .upload input { display: none; }
    .toggle-row { display: flex; justify-content: space-between; gap: 12px; align-items: center; }
    .switch { position: relative; width: 54px; height: 30px; border-radius: 999px; background: #2d3448; cursor: pointer; border: 1px solid var(--line); flex: 0 0 auto; }
    .switch input { display: none; }
    .switch span { position: absolute; top: 3px; left: 3px; width: 22px; height: 22px; border-radius: 50%; background: #dce1f7; transition: transform .18s ease; }
    .switch input:checked + span { transform: translateX(24px); background: white; }
    .range-label { display: flex; justify-content: space-between; gap: 10px; align-items: center; font-size: 13px; margin-bottom: 8px; }
    .value { color: var(--accent); font-weight: bold; }
    input[type='range'] { width: 100%; accent-color: var(--accent); }
    .btn-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .btn-row + .btn-row { margin-top: 10px; }
    button { border: none; border-radius: 14px; padding: 13px 14px; font-weight: bold; cursor: pointer; background: #2f3750; color: var(--text); }
    button.primary { background: linear-gradient(135deg, var(--accent), #4f9dff); }
    button.good { background: linear-gradient(135deg, var(--accent-2), #2fb4ff); color: #091217; }
    button:disabled { opacity: .45; cursor: not-allowed; }
    .main { display: grid; gap: 18px; }
    .preview-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
    @media (max-width: 880px) { .preview-grid { grid-template-columns: 1fr; } }
    .panel-head { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--line); padding: 15px 16px; }
    .panel-title { font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--muted); }
    .dot { width: 9px; height: 9px; border-radius: 50%; background: #434964; }
    .dot.on { background: var(--accent-2); box-shadow: 0 0 12px rgba(77,227,174,.9); }
    .pane { min-height: 340px; display: flex; align-items: center; justify-content: center; padding: 18px; }
    .pane img, .pane canvas { max-width: 100%; max-height: 720px; object-fit: contain; border-radius: 16px; background: white; }
    .empty { text-align: center; color: var(--muted); }
    .empty strong { color: var(--text); display: block; margin-bottom: 8px; }
    .status { min-height: 20px; color: var(--muted); font-size: 13px; text-align: center; }
    #threeViewer { height: 560px; position: relative; }
    #threeMount { position: absolute; inset: 0; }
    #binaryPreview { width: 100%; height: auto; max-height: 220px; image-rendering: pixelated; image-rendering: crisp-edges; background: #222; }
    .error { color: var(--danger); white-space: pre-line; font-size: 12px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <h1>Floor Plan Filters + 3D Builder</h1>
      <p>Apply brightness, contrast, morphological and spatial filters to isolate solid walls, then build the result as an interactive 3D pixel grid.</p>
    </div>

    <div class="chips">
      <div class="chip" id="backendChip">Backend: checking...</div>
      <div class="chip" id="fileChip">No image loaded</div>
      <div class="chip" id="summaryChip">3D not built</div>
    </div>

    <div class="layout">
      <aside class="sidebar">
        <div class="section">
          <div class="section-title">Image</div>
          <label class="field upload">
            <span>Upload floor plan image</span>
            <input id="fileInput" type="file" accept="image/*" />
          </label>
        </div>

        <div class="section">
          <div class="section-title">Connected components</div>
          <div class="toggle"><div class="toggle-row"><span>Remove text</span><label class="switch"><input id="removeText" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Remove dimensions</span><label class="switch"><input id="removeDims" type="checkbox" /><span></span></label></div></div>
          <div class="field"><div class="range-label"><span>Blob size</span><span class="value" id="blobSizeValue">300</span></div><input id="blobSize" type="range" min="40" max="1200" step="10" value="300" /></div>
          <div class="field"><div class="range-label"><span>Aspect limit</span><span class="value" id="aspectValue">8.0</span></div><input id="aspectMax" type="range" min="1" max="20" step="0.5" value="8" /></div>
        </div>

        <div class="section">
          <div class="section-title">Adjustments</div>
          <div class="toggle"><div class="toggle-row"><span>Histogram equalize</span><label class="switch"><input id="histEq" type="checkbox" /><span></span></label></div></div>
          <div class="field"><div class="range-label"><span>Brightness</span><span class="value" id="brightnessValue">0</span></div><input id="brightnessRange" type="range" min="-100" max="100" step="1" value="0" /></div>
          <div class="field"><div class="range-label"><span>Contrast</span><span class="value" id="contrastValue">1.0</span></div><input id="contrastRange" type="range" min="0.1" max="3" step="0.1" value="1.0" /></div>
        </div>

        <div class="section">
          <div class="section-title">Filters</div>
          <div class="toggle"><div class="toggle-row"><span>Min filter</span><label class="switch"><input id="minFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Max filter</span><label class="switch"><input id="maxFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Average filter</span><label class="switch"><input id="averageFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Median filter</span><label class="switch"><input id="medianFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Sharpen filter</span><label class="switch"><input id="sharpenFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Opening</span><label class="switch"><input id="openingFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Closing</span><label class="switch"><input id="closingFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Erosion</span><label class="switch"><input id="erosionFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Dilation</span><label class="switch"><input id="dilationFilter" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Isolate solid walls</span><label class="switch"><input id="wallIsolation" type="checkbox" /><span></span></label></div></div>
          <div class="field"><div class="range-label"><span>Wall thickness</span><span class="value" id="wallThicknessValue">5</span></div><input id="wallThickness" type="range" min="3" max="25" step="2" value="5" /></div>
        </div>

        <div class="section">
          <div class="section-title">3D conversion</div>
          <div class="field"><div class="range-label"><span>Binary threshold</span><span class="value" id="binaryThresholdValue">50</span></div><input id="binaryThreshold" type="range" min="0" max="255" step="1" value="50" /></div>
          <div class="field"><div class="range-label"><span>Black pixel color</span></div><input id="blackColor" type="color" value="#111111" style="width:100%;height:36px;border:none;background:transparent;cursor:pointer;" /></div>
          <div class="field"><div class="range-label"><span>Pixel cell size</span><span class="value" id="pixelSizeValue">1.00</span></div><input id="pixelSize" type="range" min="0.25" max="4" step="0.25" value="1" /></div>
          <div class="field"><div class="range-label"><span>Black Y height</span><span class="value" id="blackHeightValue">255</span></div><input id="blackHeight" type="range" min="1" max="400" step="1" value="255" /></div>
          <div class="field"><div class="range-label"><span>255 Y height</span><span class="value" id="whiteHeightValue">10</span></div><input id="whiteHeight" type="range" min="0" max="100" step="1" value="10" /></div>
          <div class="toggle"><div class="toggle-row"><span>Show 255 pixels</span><label class="switch"><input id="showWhite" type="checkbox" /><span></span></label></div></div>
          <div class="toggle"><div class="toggle-row"><span>Show grid lines</span><label class="switch"><input id="showGrid" type="checkbox" checked /><span></span></label></div></div>
        </div>

        <div class="section">
          <div class="btn-row">
            <button class="primary" id="apply2DBtn" disabled>Apply 2D processing</button>
            <button class="good" id="build3DBtn" disabled>Build 3D</button>
          </div>
          <div class="btn-row">
            <button id="saveCurrentBtn" disabled>Save current as base</button>
            <button id="undoBtn" disabled>Undo</button>
          </div>
          <div class="btn-row">
            <button id="downloadBtn" disabled>Download current</button>
            <button id="resetCameraBtn" disabled>Reset camera</button>
          </div>
        </div>
      </aside>

      <main class="main">
        <div class="preview-grid">
          <div class="panel">
            <div class="panel-head"><div class="panel-title">Original</div><div class="dot on"></div></div>
            <div class="pane" id="originalPane"><div class="empty"><strong>No image loaded</strong>Upload a plan image to preview it here.</div></div>
          </div>
          <div class="panel">
            <div class="panel-head"><div class="panel-title">Current processed image</div><div class="dot" id="resultDot"></div></div>
            <div class="pane" id="resultPane"><div class="empty"><strong>Waiting for output</strong>Apply processing to see the filtered image here.</div></div>
          </div>
        </div>

        <div class="panel">
          <div class="panel-head"><div class="panel-title">Binary preview for 3D</div><div class="dot on"></div></div>
          <div class="pane"><canvas id="binaryPreview"></canvas></div>
        </div>

        <div class="panel">
          <div class="panel-head"><div class="panel-title">3D view</div><div class="dot" id="threeDot"></div></div>
          <div id="threeViewer"><div id="threeMount"></div></div>
        </div>

        <div class="panel" style="padding:16px;">
          <div class="status" id="status"></div>
          <div class="error" id="errorBox"></div>
        </div>
      </main>
    </div>
  </div>

  <script>
const elements = {
  fileInput: document.getElementById('fileInput'),
  backendChip: document.getElementById('backendChip'),
  fileChip: document.getElementById('fileChip'),
  summaryChip: document.getElementById('summaryChip'),
  status: document.getElementById('status'),
  errorBox: document.getElementById('errorBox'),
  originalPane: document.getElementById('originalPane'),
  resultPane: document.getElementById('resultPane'),
  resultDot: document.getElementById('resultDot'),
  threeDot: document.getElementById('threeDot'),
  binaryPreview: document.getElementById('binaryPreview'),
  apply2DBtn: document.getElementById('apply2DBtn'),
  build3DBtn: document.getElementById('build3DBtn'),
  saveCurrentBtn: document.getElementById('saveCurrentBtn'),
  undoBtn: document.getElementById('undoBtn'),
  downloadBtn: document.getElementById('downloadBtn'),
  resetCameraBtn: document.getElementById('resetCameraBtn'),
  removeText: document.getElementById('removeText'),
  removeDims: document.getElementById('removeDims'),
  blobSize: document.getElementById('blobSize'),
  blobSizeValue: document.getElementById('blobSizeValue'),
  aspectMax: document.getElementById('aspectMax'),
  aspectValue: document.getElementById('aspectValue'),
  histEq: document.getElementById('histEq'),
  brightnessRange: document.getElementById('brightnessRange'),
  brightnessValue: document.getElementById('brightnessValue'),
  contrastRange: document.getElementById('contrastRange'),
  contrastValue: document.getElementById('contrastValue'),
  minFilter: document.getElementById('minFilter'),
  maxFilter: document.getElementById('maxFilter'),
  averageFilter: document.getElementById('averageFilter'),
  medianFilter: document.getElementById('medianFilter'),
  sharpenFilter: document.getElementById('sharpenFilter'),
  openingFilter: document.getElementById('openingFilter'),
  closingFilter: document.getElementById('closingFilter'),
  erosionFilter: document.getElementById('erosionFilter'),
  dilationFilter: document.getElementById('dilationFilter'),
  wallIsolation: document.getElementById('wallIsolation'),
  wallThickness: document.getElementById('wallThickness'),
  wallThicknessValue: document.getElementById('wallThicknessValue'),
  binaryThreshold: document.getElementById('binaryThreshold'),
  binaryThresholdValue: document.getElementById('binaryThresholdValue'),
  blackColor: document.getElementById('blackColor'),
  pixelSize: document.getElementById('pixelSize'),
  pixelSizeValue: document.getElementById('pixelSizeValue'),
  blackHeight: document.getElementById('blackHeight'),
  blackHeightValue: document.getElementById('blackHeightValue'),
  whiteHeight: document.getElementById('whiteHeight'),
  whiteHeightValue: document.getElementById('whiteHeightValue'),
  showWhite: document.getElementById('showWhite'),
  showGrid: document.getElementById('showGrid'),
  threeMount: document.getElementById('threeMount')
};

const state = {
  originalImage: null,
  currentImage: null,
  historyStack: [],
  autoApplyTimer: null,
  isProcessing2D: false,
  pendingAutoApply: false,
  has3DView: false,
  THREE: null,
  scene: null,
  camera: null,
  renderer: null,
  pixelGroup: null,
  gridGroup: null,
  axes: null,
  binaryData: null,
  isDragging: false,
  dragMode: 'rotate',
  lastMouseX: 0,
  lastMouseY: 0,
  orbitYaw: Math.PI / 4,
  orbitPitch: 0.95,
  orbitRadius: 500,
  targetX: 0,
  targetY: 40,
  targetZ: 0,
  lockedRegions: []
};

function setStatus(message) {
  elements.status.textContent = message || '';
}

function showError(message) {
  elements.errorBox.textContent = message || '';
}

function clearError() {
  elements.errorBox.textContent = '';
}

function updateValueLabels() {
  elements.blobSizeValue.textContent = elements.blobSize.value;
  elements.aspectValue.textContent = Number(elements.aspectMax.value).toFixed(1);
  elements.brightnessValue.textContent = elements.brightnessRange.value;
  elements.contrastValue.textContent = Number(elements.contrastRange.value).toFixed(1);
  elements.wallThicknessValue.textContent = elements.wallThickness.value;
  elements.binaryThresholdValue.textContent = elements.binaryThreshold.value;
  elements.pixelSizeValue.textContent = Number(elements.pixelSize.value).toFixed(2);
  elements.blackHeightValue.textContent = elements.blackHeight.value;
  elements.whiteHeightValue.textContent = elements.whiteHeight.value;
}

function setPaneImage(pane, src) {
  pane.innerHTML = '';
  const image = document.createElement('img');
  image.src = src;
  pane.appendChild(image);
}

function setPaneLoading(pane, label) {
  pane.innerHTML = `<div class="empty"><strong>${label}</strong>Working...</div>`;
}

function fileToDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error('Could not read image file.'));
    reader.readAsDataURL(file);
  });
}

async function checkBackend() {
  try {
    const response = await fetch('/health');
    if (!response.ok) throw new Error('Health check failed');
    elements.backendChip.textContent = 'Backend: online';
    elements.backendChip.classList.add('ok');
  } catch (error) {
    elements.backendChip.textContent = 'Backend: offline';
    elements.backendChip.classList.remove('ok');
  }
}

function bindUi() {
  const labelInputs = [
    elements.blobSize, elements.aspectMax, elements.brightnessRange,
    elements.contrastRange, elements.wallThickness, elements.binaryThreshold,
    elements.pixelSize, elements.blackHeight, elements.whiteHeight
  ];
  labelInputs.forEach((input) => input.addEventListener('input', updateValueLabels));

  const autoApplySliders = [
    elements.blobSize, elements.aspectMax, elements.brightnessRange,
    elements.contrastRange, elements.wallThickness
  ];
  autoApplySliders.forEach((input) => input.addEventListener('input', scheduleAutoApply));

  const autoApplyToggles = [
    elements.removeText, elements.removeDims, elements.histEq,
    elements.minFilter, elements.maxFilter, elements.averageFilter,
    elements.medianFilter, elements.sharpenFilter, elements.openingFilter,
    elements.closingFilter, elements.erosionFilter, elements.dilationFilter,
    elements.wallIsolation
  ];
  autoApplyToggles.forEach((input) => input.addEventListener('change', scheduleAutoApply));

  elements.fileInput.addEventListener('change', async (event) => {
    const file = event.target.files && event.target.files[0];
    if (!file) return;
    clearError();
    try {
      const dataUrl = await fileToDataUrl(file);
      state.originalImage = dataUrl;
      state.currentImage = dataUrl;
      state.historyStack = [];
      state.lockedRegions = [];
      elements.fileChip.textContent = file.name;
      elements.summaryChip.textContent = '2D loaded, 3D not built';
      setPaneImage(elements.originalPane, dataUrl);
      setPaneImage(elements.resultPane, dataUrl);
      elements.resultDot.classList.add('on');
      elements.apply2DBtn.disabled = false;
      elements.build3DBtn.disabled = false;
      elements.saveCurrentBtn.disabled = false;
      elements.downloadBtn.disabled = false;
      elements.undoBtn.disabled = true;
      state.has3DView = false;
      elements.threeDot.classList.remove('on');
      elements.resetCameraBtn.disabled = true;
      setStatus('Image loaded. Apply filters or build 3D.');
      await updateBinaryPreviewFromCurrent();
    } catch (error) {
      showError(error.message);
    }
  });

  elements.apply2DBtn.addEventListener('click', apply2DProcessing);
  elements.build3DBtn.addEventListener('click', build3DFromCurrent);
  elements.undoBtn.addEventListener('click', undoImage);
  elements.saveCurrentBtn.addEventListener('click', saveCurrentAsBase);
  elements.downloadBtn.addEventListener('click', downloadCurrent);
  elements.resetCameraBtn.addEventListener('click', () => {
    if (state.binaryData) fitCameraToData(state.binaryData, Number(elements.blackHeight.value));
    else resetCamera();
  });
  elements.binaryThreshold.addEventListener('input', () => updateBinaryPreviewFromCurrent());
  elements.showWhite.addEventListener('change', () => state.binaryData && render3D(state.binaryData));
  elements.showGrid.addEventListener('change', () => state.binaryData && render3D(state.binaryData));
  elements.blackColor.addEventListener('input', () => state.binaryData && render3D(state.binaryData));
  elements.pixelSize.addEventListener('input', () => state.binaryData && render3D(state.binaryData));
  elements.blackHeight.addEventListener('input', () => state.binaryData && render3D(state.binaryData));
  elements.whiteHeight.addEventListener('input', () => state.binaryData && render3D(state.binaryData));
}

function scheduleAutoApply() {
  if (!state.currentImage && !state.originalImage) return;
  if (state.autoApplyTimer) window.clearTimeout(state.autoApplyTimer);
  state.autoApplyTimer = window.setTimeout(() => {
    state.autoApplyTimer = null;
    apply2DProcessing({ isAuto: true });
  }, 350);
}

function collectProcessingPayload(sourceImage = null) {
  return {
    image: sourceImage || state.currentImage || state.originalImage,
    remove_text: elements.removeText.checked,
    remove_dimensions: elements.removeDims.checked,
    blob_size_limit: Number(elements.blobSize.value),
    aspect_limit: Number(elements.aspectMax.value),
    brightness: Number(elements.brightnessRange.value),
    contrast: Number(elements.contrastRange.value),
    apply_histogram: elements.histEq.checked,
    apply_min_filter: elements.minFilter.checked,
    apply_max_filter: elements.maxFilter.checked,
    apply_average_filter: elements.averageFilter.checked,
    apply_median_filter: elements.medianFilter.checked,
    apply_sharpen_filter: elements.sharpenFilter.checked,
    apply_opening_filter: elements.openingFilter.checked,
    apply_closing_filter: elements.closingFilter.checked,
    apply_erosion_filter: elements.erosionFilter.checked,
    apply_dilation_filter: elements.dilationFilter.checked,
    apply_wall_isolation: elements.wallIsolation.checked,
    wall_thickness: Number(elements.wallThickness.value),
    locked_regions: state.lockedRegions
  };
}

async function apply2DProcessing(options = {}) {
  const isAuto = Boolean(options && options.isAuto);
  if (!state.currentImage && !state.originalImage) return;
  if (state.isProcessing2D) {
    if (isAuto) state.pendingAutoApply = true;
    return;
  }
  state.isProcessing2D = true;
  clearError();
  setStatus(isAuto ? 'Applying changes...' : 'Applying 2D processing...');
  if (!isAuto) setPaneLoading(elements.resultPane, 'Processing image');
  elements.apply2DBtn.disabled = true;
  try {
    const sourceImage = isAuto ? (state.originalImage || state.currentImage) : null;
    const response = await fetch('/3d-floor-plan/process-image', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(collectProcessingPayload(sourceImage))
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Processing failed');
    if (!isAuto) {
      state.historyStack.push(state.currentImage || state.originalImage);
    }
    state.currentImage = data.result;
    setPaneImage(elements.resultPane, state.currentImage);
    elements.resultDot.classList.add('on');
    elements.undoBtn.disabled = state.historyStack.length === 0;
    elements.downloadBtn.disabled = false;
    elements.saveCurrentBtn.disabled = false;
    elements.build3DBtn.disabled = false;
    const removedCount = data.removed_count ?? 0;
    elements.summaryChip.textContent = `2D ready - removed ${removedCount}`;
    setStatus(`2D processing complete. Removed ${removedCount} component${removedCount === 1 ? '' : 's'}.`);
    await updateBinaryPreviewFromCurrent();
    if (state.has3DView && state.binaryData) {
      render3D(state.binaryData);
    }
  } catch (error) {
    showError(error.message);
    setPaneImage(elements.resultPane, state.currentImage || state.originalImage);
  } finally {
    state.isProcessing2D = false;
    elements.apply2DBtn.disabled = false;
    if (state.pendingAutoApply) {
      state.pendingAutoApply = false;
      apply2DProcessing({ isAuto: true });
    }
  }
}

async function undoImage() {
  if (!state.historyStack.length) return;
  state.currentImage = state.historyStack.pop();
  setPaneImage(elements.resultPane, state.currentImage);
  elements.undoBtn.disabled = state.historyStack.length === 0;
  elements.summaryChip.textContent = 'Undo applied';
  setStatus('Reverted to previous image state.');
  try {
    await updateBinaryPreviewFromCurrent();
    if (state.has3DView && state.binaryData) render3D(state.binaryData);
  } catch (error) {
    showError(error.message);
  }
}

function saveCurrentAsBase() {
  const imageToSave = state.currentImage || state.originalImage;
  if (!imageToSave) return;
  state.originalImage = imageToSave;
  state.currentImage = imageToSave;
  state.historyStack = [];
  elements.undoBtn.disabled = true;
  setPaneImage(elements.originalPane, state.originalImage);
  elements.summaryChip.textContent = 'Saved current image as base';
  setStatus('Current image saved as the new base image.');
}

function downloadCurrent() {
  if (!state.currentImage && !state.originalImage) return;
  const a = document.createElement('a');
  a.href = state.currentImage || state.originalImage;
  a.download = 'processed-floor-plan.png';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

function dataUrlToImage(dataUrl) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('Could not load current image for 3D preview.'));
    image.src = dataUrl;
  });
}

function imageToBinaryData(image, threshold) {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  canvas.width = image.width;
  canvas.height = image.height;
  ctx.drawImage(image, 0, 0);
  const raw = ctx.getImageData(0, 0, image.width, image.height).data;
  const binary = new Uint8Array(image.width * image.height);
  let blackCount = 0;
  let whiteCount = 0;
  for (let i = 0, p = 0; i < raw.length; i += 4, p++) {
    const r = raw[i], g = raw[i + 1], b = raw[i + 2], a = raw[i + 3];
    let gray = 255;
    if (a > 0) gray = 0.299 * r + 0.587 * g + 0.114 * b;
    const value = gray < threshold ? 0 : 255;
    binary[p] = value;
    if (value === 0) blackCount += 1; else whiteCount += 1;
  }
  return { width: image.width, height: image.height, binary, blackCount, whiteCount };
}

function drawBinaryPreview(binaryData) {
  const canvas = elements.binaryPreview;
  const ctx = canvas.getContext('2d');
  canvas.width = binaryData.width;
  canvas.height = binaryData.height;
  const imageData = ctx.createImageData(binaryData.width, binaryData.height);
  for (let i = 0, p = 0; p < binaryData.binary.length; p++, i += 4) {
    const value = binaryData.binary[p];
    imageData.data[i] = value;
    imageData.data[i + 1] = value;
    imageData.data[i + 2] = value;
    imageData.data[i + 3] = 255;
  }
  ctx.putImageData(imageData, 0, 0);
}

async function updateBinaryPreviewFromCurrent() {
  if (!state.currentImage && !state.originalImage) return;
  try {
    const image = await dataUrlToImage(state.currentImage || state.originalImage);
    state.binaryData = imageToBinaryData(image, Number(elements.binaryThreshold.value));
    drawBinaryPreview(state.binaryData);
  } catch (error) {
    showError(error.message);
  }
}

async function build3DFromCurrent() {
  clearError();
  if (!state.currentImage && !state.originalImage) return;
  try {
    setStatus('Building 3D view...');
    await ensureThreeReady();
    await updateBinaryPreviewFromCurrent();
    render3D(state.binaryData);
    state.has3DView = true;
    elements.threeDot.classList.add('on');
    elements.resetCameraBtn.disabled = false;
    elements.summaryChip.textContent = `3D ready - ${state.binaryData.blackCount} black pixels`;
    setStatus('3D view updated. Drag left mouse to rotate, right mouse to pan, mouse wheel to zoom.');
  } catch (error) {
    showError(error.message);
  }
}

function toError(value, fallbackMessage) {
  if (value instanceof Error) return value;
  return new Error(fallbackMessage || 'Unknown error');
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error(`Failed to load script: ${src}`));
    document.head.appendChild(script);
  });
}

async function ensureThreeReady() {
  if (state.THREE) return;
  const sources = [
    'https://cdnjs.cloudflare.com/ajax/libs/three.js/r160/three.min.js',
    'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.min.js',
    'https://unpkg.com/three@0.160.0/build/three.min.js'
  ];
  let lastError = null;
  for (const src of sources) {
    try {
      await loadScript(src);
      if (window.THREE) { state.THREE = window.THREE; initThreeScene(); return; }
    } catch (error) { lastError = error; }
  }
  throw toError(lastError, 'Could not load Three.js. Internet access is required for the 3D part.');
}

function initThreeScene() {
  const THREE = state.THREE;
  state.scene = new THREE.Scene();
  state.scene.background = new THREE.Color(0x0b0b0b);
  state.camera = new THREE.PerspectiveCamera(60, 1, 0.1, 1000000);
  state.renderer = new THREE.WebGLRenderer({ antialias: true });
  state.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  elements.threeMount.innerHTML = '';
  elements.threeMount.appendChild(state.renderer.domElement);
  const ambient = new THREE.AmbientLight(0xffffff, 1.1);
  const lightA = new THREE.DirectionalLight(0xffffff, 0.9);
  const lightB = new THREE.DirectionalLight(0xffffff, 0.55);
  lightA.position.set(300, 400, 200);
  lightB.position.set(-250, 180, -180);
  state.scene.add(ambient, lightA, lightB);
  state.axes = new THREE.AxesHelper(200);
  state.scene.add(state.axes);
  attachCustomControls();
  onResize();
  window.addEventListener('resize', onResize);
  animate();
  resetCamera();
}

function onResize() {
  if (!state.camera || !state.renderer) return;
  const rect = document.getElementById('threeViewer').getBoundingClientRect();
  const width = Math.max(320, rect.width);
  const height = Math.max(320, rect.height);
  state.camera.aspect = width / height;
  state.camera.updateProjectionMatrix();
  state.renderer.setSize(width, height);
}

function attachCustomControls() {
  const canvas = state.renderer.domElement;
  canvas.oncontextmenu = (event) => event.preventDefault();
  canvas.addEventListener('mousedown', (event) => {
    state.isDragging = true;
    state.dragMode = event.button === 2 ? 'pan' : 'rotate';
    state.lastMouseX = event.clientX;
    state.lastMouseY = event.clientY;
  });
  window.addEventListener('mouseup', () => { state.isDragging = false; });
  window.addEventListener('mousemove', (event) => {
    if (!state.isDragging) return;
    const dx = event.clientX - state.lastMouseX;
    const dy = event.clientY - state.lastMouseY;
    state.lastMouseX = event.clientX;
    state.lastMouseY = event.clientY;
    if (state.dragMode === 'rotate') {
      state.orbitYaw -= dx * 0.01;
      state.orbitPitch -= dy * 0.01;
      state.orbitPitch = Math.max(0.08, Math.min(Math.PI - 0.08, state.orbitPitch));
    } else {
      const panScale = Math.max(1, state.orbitRadius * 0.0015);
      state.targetX -= dx * panScale;
      state.targetZ -= dy * panScale;
    }
    updateCameraPosition();
  });
  canvas.addEventListener('wheel', (event) => {
    event.preventDefault();
    state.orbitRadius *= event.deltaY > 0 ? 1.12 : 0.9;
    state.orbitRadius = Math.max(10, Math.min(300000, state.orbitRadius));
    updateCameraPosition();
  }, { passive: false });
}

function updateCameraPosition() {
  if (!state.camera) return;
  const sinPitch = Math.sin(state.orbitPitch);
  const x = state.targetX + state.orbitRadius * sinPitch * Math.cos(state.orbitYaw);
  const y = state.targetY + state.orbitRadius * Math.cos(state.orbitPitch);
  const z = state.targetZ + state.orbitRadius * sinPitch * Math.sin(state.orbitYaw);
  state.camera.position.set(x, y, z);
  state.camera.lookAt(state.targetX, state.targetY, state.targetZ);
}

function resetCamera() {
  state.orbitYaw = Math.PI / 4;
  state.orbitPitch = 0.95;
  state.orbitRadius = 500;
  state.targetX = 0;
  state.targetY = 40;
  state.targetZ = 0;
  updateCameraPosition();
}

function fitCameraToData(binaryData, blackHeight) {
  const pixelSize = Number(elements.pixelSize.value);
  const widthWorld = binaryData.width * pixelSize;
  const depthWorld = binaryData.height * pixelSize;
  const maxSide = Math.max(widthWorld, depthWorld, blackHeight);
  state.orbitRadius = Math.max(60, maxSide * 1.4);
  state.targetX = 0;
  state.targetY = Math.max(20, blackHeight * 0.25);
  state.targetZ = 0;
  if (state.axes) state.axes.scale.setScalar(Math.max(40, maxSide * 0.15));
  updateCameraPosition();
}

function disposeObject(root) {
  if (!root) return;
  root.traverse((child) => {
    if (child.geometry) child.geometry.dispose();
    if (child.material) {
      if (Array.isArray(child.material)) child.material.forEach((mat) => mat.dispose());
      else child.material.dispose();
    }
  });
  state.scene && state.scene.remove(root);
}

function render3D(binaryData) {
  if (!state.scene || !binaryData) return;
  disposeObject(state.pixelGroup);
  disposeObject(state.gridGroup);
  state.pixelGroup = null;
  state.gridGroup = null;
  const THREE = state.THREE;
  const pixelSize = Number(elements.pixelSize.value);
  const blackHeight = Number(elements.blackHeight.value);
  const whiteHeight = Number(elements.whiteHeight.value);
  const showWhite = elements.showWhite.checked;
  const widthWorld = binaryData.width * pixelSize;
  const depthWorld = binaryData.height * pixelSize;
  const offsetX = widthWorld / 2;
  const offsetZ = depthWorld / 2;
  const blackGeo = new THREE.BoxGeometry(pixelSize, Math.max(0.01, blackHeight), pixelSize);
  const blackMat = new THREE.MeshStandardMaterial({ color: elements.blackColor.value || '#111111' });
  const blackMesh = binaryData.blackCount > 0
    ? new THREE.InstancedMesh(blackGeo, blackMat, binaryData.blackCount)
    : null;
  if (blackMesh) blackMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  let whiteMesh = null;
  if (showWhite && binaryData.whiteCount > 0) {
    const whiteGeo = new THREE.BoxGeometry(pixelSize, Math.max(0.01, whiteHeight), pixelSize);
    const whiteMat = new THREE.MeshStandardMaterial({ color: 0xffffff, transparent: true, opacity: 0.12 });
    whiteMesh = new THREE.InstancedMesh(whiteGeo, whiteMat, binaryData.whiteCount);
    whiteMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  }
  const dummy = new THREE.Object3D();
  let blackIndex = 0;
  let whiteIndex = 0;
  for (let z = 0; z < binaryData.height; z++) {
    for (let x = 0; x < binaryData.width; x++) {
      const value = binaryData.binary[z * binaryData.width + x];
      const px = x * pixelSize - offsetX + pixelSize / 2;
      const pz = z * pixelSize - offsetZ + pixelSize / 2;
      if (value === 0 && blackMesh) {
        dummy.position.set(px, blackHeight / 2, pz);
        dummy.updateMatrix();
        blackMesh.setMatrixAt(blackIndex++, dummy.matrix);
      } else if (value !== 0 && whiteMesh) {
        dummy.position.set(px, whiteHeight / 2, pz);
        dummy.updateMatrix();
        whiteMesh.setMatrixAt(whiteIndex++, dummy.matrix);
      }
    }
  }
  if (blackMesh) blackMesh.instanceMatrix.needsUpdate = true;
  if (whiteMesh) whiteMesh.instanceMatrix.needsUpdate = true;
  const pixelGroup = new THREE.Group();
  if (blackMesh) pixelGroup.add(blackMesh);
  if (whiteMesh) pixelGroup.add(whiteMesh);
  state.pixelGroup = pixelGroup;
  state.scene.add(pixelGroup);
  state.gridGroup = createGrid(widthWorld, depthWorld, binaryData.width, binaryData.height, pixelSize);
  state.scene.add(state.gridGroup);
  fitCameraToData(binaryData, blackHeight);
  elements.summaryChip.textContent = `${binaryData.width}x${binaryData.height} - black ${binaryData.blackCount} - white ${binaryData.whiteCount}`;
}

function createGrid(widthWorld, depthWorld, widthPixels, heightPixels, pixelSize) {
  const THREE = state.THREE;
  const group = new THREE.Group();
  const halfW = widthWorld / 2;
  const halfD = depthWorld / 2;
  const borderMat = new THREE.LineBasicMaterial({ color: 0x6fa8ff });
  const borderPts = [
    new THREE.Vector3(-halfW, 0, -halfD), new THREE.Vector3(halfW, 0, -halfD),
    new THREE.Vector3(halfW, 0, halfD), new THREE.Vector3(-halfW, 0, halfD),
    new THREE.Vector3(-halfW, 0, -halfD)
  ];
  group.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(borderPts), borderMat));
  if (!elements.showGrid.checked) return group;
  const maxLines = 120;
  const stepX = Math.max(1, Math.ceil(widthPixels / maxLines));
  const stepZ = Math.max(1, Math.ceil(heightPixels / maxLines));
  const lineMat = new THREE.LineBasicMaterial({ color: 0x2a3d52, transparent: true, opacity: 0.8 });
  for (let x = 0; x <= widthPixels; x += stepX) {
    const wx = -halfW + x * pixelSize;
    group.add(new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(wx, 0, -halfD), new THREE.Vector3(wx, 0, halfD)]),
      lineMat
    ));
  }
  for (let z = 0; z <= heightPixels; z += stepZ) {
    const wz = -halfD + z * pixelSize;
    group.add(new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(-halfW, 0, wz), new THREE.Vector3(halfW, 0, wz)]),
      lineMat
    ));
  }
  return group;
}

function animate() {
  requestAnimationFrame(animate);
  if (state.renderer && state.scene && state.camera) {
    state.renderer.render(state.scene, state.camera);
  }
}

async function autoLoadProjectImage() {
  const params = new URLSearchParams(window.location.search);
  const projectId = params.get('project_id');
  if (!projectId) return;
  try {
    const resp = await fetch(`/3d-floor-plan/${projectId}/image`);
    if (!resp.ok) return;
    const data = await resp.json();
    if (!data || !data.image) return;
    clearError();
    state.originalImage = data.image;
    state.currentImage = data.image;
    state.historyStack = [];
    state.lockedRegions = [];
    elements.fileChip.textContent = data.filename || 'Floor plan';
    elements.summaryChip.textContent = '2D loaded from project';
    setPaneImage(elements.originalPane, data.image);
    setPaneImage(elements.resultPane, data.image);
    elements.resultDot.classList.add('on');
    elements.apply2DBtn.disabled = false;
    elements.build3DBtn.disabled = false;
    elements.saveCurrentBtn.disabled = false;
    elements.downloadBtn.disabled = false;
    elements.undoBtn.disabled = true;
    state.has3DView = false;
    elements.threeDot.classList.remove('on');
    elements.resetCameraBtn.disabled = true;
    setStatus('Project floor plan loaded. Build 3D or apply filters first.');
    await updateBinaryPreviewFromCurrent();
    await build3DFromCurrent();
  } catch (e) {
    // non-fatal — user can still upload manually
  }
}

updateValueLabels();
bindUi();
checkBackend();
setStatus('Upload an image to start.');
autoLoadProjectImage();
  </script>
</body>
</html>"""
