from __future__ import annotations

import base64
import os
from typing import Dict, List, Tuple

import cv2
import numpy as np
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from numpy.lib.stride_tricks import sliding_window_view

app = Flask(__name__, static_folder=".")
CORS(app)


def base64_to_cv2(base64_str: str) -> np.ndarray | None:
    """Convert a base64 image string into an OpenCV BGR image."""
    if "," in base64_str:
        base64_str = base64_str.split(",", 1)[1]
    img_bytes = base64.b64decode(base64_str)
    np_arr = np.frombuffer(img_bytes, np.uint8)
    return cv2.imdecode(np_arr, cv2.IMREAD_COLOR)


def cv2_to_base64(img: np.ndarray) -> str:
    """Convert an OpenCV image into a base64 PNG data URL."""
    ok, buffer = cv2.imencode(".png", img)
    if not ok:
        raise RuntimeError("Failed to encode image")
    encoded = base64.b64encode(buffer).decode("utf-8")
    return f"data:image/png;base64,{encoded}"


def remove_components_from_image(
    img: np.ndarray,
    remove_text: bool,
    remove_dimensions: bool,
    blob_size_limit: int,
    aspect_limit: float,
    locked_regions: List[List[int]] | None = None,
) -> Tuple[np.ndarray, int]:
    """Remove small text-like connected components by painting them white."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

    count, labels, stats, centroids = cv2.connectedComponentsWithStats(binary, 8, cv2.CV_32S)

    result = img.copy()
    removed_count = 0
    lock_mask = np.zeros(gray.shape, dtype=np.uint8)

    if locked_regions:
        height, width = gray.shape
        for region in locked_regions:
            if not isinstance(region, list) or len(region) != 4:
                continue

            x1, y1, x2, y2 = [int(value) for value in region]
            left = max(0, min(x1, x2))
            right = min(width, max(x1, x2))
            top = max(0, min(y1, y2))
            bottom = min(height, max(y1, y2))

            if right <= left or bottom <= top:
                continue

            lock_mask[top:bottom, left:right] = 255

    for index in range(1, count):
        area = int(stats[index, cv2.CC_STAT_AREA])
        width = int(stats[index, cv2.CC_STAT_WIDTH])
        height = int(stats[index, cv2.CC_STAT_HEIGHT])
        left = int(stats[index, cv2.CC_STAT_LEFT])
        top = int(stats[index, cv2.CC_STAT_TOP])

        shortest_side = max(1, min(width, height))
        aspect = max(width, height) / float(shortest_side)

        is_text_blob = remove_text and area < blob_size_limit and aspect < aspect_limit
        is_dimension_blob = remove_dimensions and area < int(blob_size_limit * 0.6) and aspect < aspect_limit

        if lock_mask[top : top + height, left : left + width].any():
            # Keep detected-column areas unchanged in subsequent processing.
            continue

        if is_text_blob or is_dimension_blob:
            result[top : top + height, left : left + width] = (255, 255, 255)
            removed_count += 1

    return result, removed_count


def apply_post_filters(
    img: np.ndarray,
    apply_opening_filter: bool,
    apply_closing_filter: bool,
    apply_erosion_filter: bool,
    apply_dilation_filter: bool,
    apply_min_filter: bool,
    apply_max_filter: bool,
    apply_average_filter: bool,
    apply_midpoint_filter: bool,
    apply_median_filter: bool,
    apply_alpha_trim_filter: bool,
    alpha_trim_value: int,
    apply_negative_filter: bool,
    apply_log_transform: bool,
    apply_bw_only: bool,
    apply_sharpen_filter: bool,
    apply_wall_isolation: bool = False,
    wall_thickness: int = 5,
) -> np.ndarray:
    """Apply optional post-filters to the cleaned image."""
    result = img.copy()
    
    if apply_wall_isolation:
        # 1. Convert to grayscale
        gray = cv2.cvtColor(result, cv2.COLOR_BGR2GRAY)
        # 2. Binarize so dark lines (walls/doors) become white (foreground)
        _, binary = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY_INV)
        # 3. Create a structuring element based on the chosen wall thickness
        k_size = max(3, wall_thickness)
        iso_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k_size, k_size))
        # 4. Morphological Opening removes all white areas (lines) thinner than the kernel
        opened = cv2.morphologyEx(binary, cv2.MORPH_OPEN, iso_kernel)
        # 5. Invert back: makes walls black, background white
        inv_opened = cv2.bitwise_not(opened)
        result = cv2.cvtColor(inv_opened, cv2.COLOR_GRAY2BGR)

    kernel = np.ones((3, 3), np.uint8)

    if apply_opening_filter:
        result = cv2.morphologyEx(result, cv2.MORPH_OPEN, kernel)

    if apply_closing_filter:
        result = cv2.morphologyEx(result, cv2.MORPH_CLOSE, kernel)

    if apply_erosion_filter:
        result = cv2.erode(result, kernel, iterations=1)

    if apply_dilation_filter:
        result = cv2.dilate(result, kernel, iterations=1)

    if apply_min_filter:
        result = cv2.erode(result, kernel, iterations=1)

    if apply_max_filter:
        result = cv2.dilate(result, kernel, iterations=1)

    if apply_average_filter:
        result = cv2.blur(result, (3, 3))

    if apply_midpoint_filter:
        eroded = cv2.erode(result, kernel, iterations=1)
        dilated = cv2.dilate(result, kernel, iterations=1)
        result = cv2.addWeighted(eroded, 0.5, dilated, 0.5, 0)

    if apply_median_filter:
        result = cv2.medianBlur(result, 3)

    if apply_alpha_trim_filter:
        trim = max(0, int(alpha_trim_value))
        result = alpha_trimmed_mean_filter(result, kernel_size=3, trim=trim)

    if apply_negative_filter:
        result = cv2.bitwise_not(result)

    if apply_log_transform:
        result = log_transform(result)

    if apply_bw_only:
        gray = cv2.cvtColor(result, cv2.COLOR_BGR2GRAY)
        _, binary = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
        result = cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR)

    if apply_sharpen_filter:
        sharpen_kernel = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]])
        result = cv2.filter2D(result, -1, sharpen_kernel)

    return result


def alpha_trimmed_mean_filter(img: np.ndarray, kernel_size: int = 3, trim: int = 1) -> np.ndarray:
    """Apply an alpha-trimmed mean filter to a color image."""
    if kernel_size % 2 == 0:
        raise ValueError("kernel_size must be odd")

    trim = max(0, min(trim, (kernel_size * kernel_size - 1) // 2))
    if trim == 0:
        return cv2.blur(img, (kernel_size, kernel_size))

    pad = kernel_size // 2
    padded = cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_REFLECT)
    channels = []

    for channel_index in range(padded.shape[2]):
        channel = padded[:, :, channel_index]
        windows = sliding_window_view(channel, (kernel_size, kernel_size))
        flattened = windows.reshape(windows.shape[0], windows.shape[1], kernel_size * kernel_size)
        sorted_values = np.sort(flattened, axis=2)
        trimmed_values = sorted_values[:, :, trim : kernel_size * kernel_size - trim]
        channel_result = trimmed_values.mean(axis=2)
        channels.append(channel_result.astype(np.uint8))

    return cv2.merge(channels)


def log_transform(img: np.ndarray) -> np.ndarray:
    """Apply log transform to enhance darker details."""
    float_image = img.astype(np.float32)
    log_image = np.log1p(float_image)
    normalized = cv2.normalize(log_image, None, 0, 255, cv2.NORM_MINMAX)
    return normalized.astype(np.uint8)


def apply_basic_adjustments(
    img: np.ndarray,
    brightness: float,
    contrast: float,
    apply_histogram: bool,
) -> np.ndarray:
    """Apply histogram, brightness, and contrast adjustments before component removal."""
    result = img.copy()

    if apply_histogram:
        lab = cv2.cvtColor(result, cv2.COLOR_BGR2LAB)
        l_channel, a, b = cv2.split(lab)
        cl = cv2.equalizeHist(l_channel)
        merged = cv2.merge((cl, a, b))
        result = cv2.cvtColor(merged, cv2.COLOR_LAB2BGR)

    if brightness != 0 or contrast != 1.0:
        result = cv2.convertScaleAbs(result, alpha=contrast, beta=brightness)

    return result


@app.route("/")
def index() -> object:
    return send_from_directory(".", "index.html")


@app.route("/health")
def health() -> object:
    return jsonify({"status": "ok"})


@app.route("/api/remove-components", methods=["POST"])
@app.route("/api/process-image", methods=["POST"])
def remove_components() -> object:
    try:
        data: Dict[str, object] | None = request.get_json(silent=True)
        if not data or "image" not in data:
            return jsonify({"error": "No image provided"}), 400

        img = base64_to_cv2(str(data["image"]))
        if img is None:
            return jsonify({"error": "Failed to decode image"}), 400

        remove_text = bool(data.get("remove_text", True))
        remove_dimensions = bool(data.get("remove_dimensions", False))
        blob_size_limit = int(data.get("blob_size_limit", 300))
        aspect_limit = float(data.get("aspect_limit", 8))
        brightness = float(data.get("brightness", 0))
        contrast = float(data.get("contrast", 1.0))
        apply_histogram = bool(data.get("apply_histogram", False))
        apply_opening_filter = bool(data.get("apply_opening_filter", False))
        apply_closing_filter = bool(data.get("apply_closing_filter", False))
        apply_erosion_filter = bool(data.get("apply_erosion_filter", False))
        apply_dilation_filter = bool(data.get("apply_dilation_filter", False))
        apply_min_filter = bool(data.get("apply_min_filter", False))
        apply_max_filter = bool(data.get("apply_max_filter", False))
        apply_average_filter = bool(data.get("apply_average_filter", False))
        apply_midpoint_filter = bool(data.get("apply_midpoint_filter", False))
        apply_median_filter = bool(data.get("apply_median_filter", False))
        apply_alpha_trim_filter = bool(data.get("apply_alpha_trim_filter", False))
        alpha_trim_value = int(data.get("alpha_trim_value", 1))
        apply_negative_filter = bool(data.get("apply_negative_filter", False))
        apply_log_transform = bool(data.get("apply_log_transform", False))
        apply_bw_only = bool(data.get("apply_bw_only", False))
        apply_sharpen_filter = bool(data.get("apply_sharpen_filter", False))
        apply_wall_isolation = bool(data.get("apply_wall_isolation", False))
        wall_thickness = int(data.get("wall_thickness", 5))
        locked_regions = data.get("locked_regions", [])
        if not isinstance(locked_regions, list):
            locked_regions = []

        adjusted_img = apply_basic_adjustments(
            img,
            brightness=brightness,
            contrast=contrast,
            apply_histogram=apply_histogram,
        )

        result_img, removed_count = remove_components_from_image(
            adjusted_img,
            remove_text=remove_text,
            remove_dimensions=remove_dimensions,
            blob_size_limit=blob_size_limit,
            aspect_limit=aspect_limit,
            locked_regions=locked_regions,
        )
        result_img = apply_post_filters(
            result_img,
            apply_opening_filter=apply_opening_filter,
            apply_closing_filter=apply_closing_filter,
            apply_erosion_filter=apply_erosion_filter,
            apply_dilation_filter=apply_dilation_filter,
            apply_min_filter=apply_min_filter,
            apply_max_filter=apply_max_filter,
            apply_average_filter=apply_average_filter,
            apply_midpoint_filter=apply_midpoint_filter,
            apply_median_filter=apply_median_filter,
            apply_alpha_trim_filter=apply_alpha_trim_filter,
            alpha_trim_value=alpha_trim_value,
            apply_negative_filter=apply_negative_filter,
            apply_log_transform=apply_log_transform,
            apply_bw_only=apply_bw_only,
            apply_sharpen_filter=apply_sharpen_filter,
            apply_wall_isolation=apply_wall_isolation,
            wall_thickness=wall_thickness,
        )
        result_b64 = cv2_to_base64(result_img)

        return jsonify(
            {
                "result": result_b64,
                "removed_count": removed_count,
                "settings": {
                    "remove_text": remove_text,
                    "remove_dimensions": remove_dimensions,
                    "blob_size_limit": blob_size_limit,
                    "aspect_limit": aspect_limit,
                    "brightness": brightness,
                    "contrast": contrast,
                    "apply_histogram": apply_histogram,
                    "apply_opening_filter": apply_opening_filter,
                    "apply_closing_filter": apply_closing_filter,
                    "apply_erosion_filter": apply_erosion_filter,
                    "apply_dilation_filter": apply_dilation_filter,
                    "apply_min_filter": apply_min_filter,
                    "apply_max_filter": apply_max_filter,
                    "apply_average_filter": apply_average_filter,
                    "apply_midpoint_filter": apply_midpoint_filter,
                    "apply_median_filter": apply_median_filter,
                    "apply_alpha_trim_filter": apply_alpha_trim_filter,
                    "alpha_trim_value": alpha_trim_value,
                    "apply_negative_filter": apply_negative_filter,
                    "apply_log_transform": apply_log_transform,
                    "apply_bw_only": apply_bw_only,
                    "apply_wall_isolation": apply_wall_isolation,
                    "wall_thickness": wall_thickness,
                    "locked_regions_count": len(locked_regions),
                },
            }
        )

    except Exception as error:
        return jsonify({"error": str(error)}), 500


@app.route("/api/adjust-image", methods=["POST"])
def adjust_image():
    try:
        data = request.json
        if not data or "image" not in data:
            return jsonify({"error": "No image data provided"}), 400

        img = base64_to_cv2(data["image"])
        brightness = float(data.get("brightness", 0))
        contrast = float(data.get("contrast", 1.0))
        apply_histogram = bool(data.get("apply_histogram", False))

        img = apply_basic_adjustments(
            img,
            brightness=brightness,
            contrast=contrast,
            apply_histogram=apply_histogram,
        )

        result_b64 = cv2_to_base64(img)
        return jsonify({"result": result_b64})

    except Exception as error:
        return jsonify({"error": str(error)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8010"))
    print(f"OpenCV component-removal backend running at http://localhost:{port}")
    app.run(debug=True, port=port)
