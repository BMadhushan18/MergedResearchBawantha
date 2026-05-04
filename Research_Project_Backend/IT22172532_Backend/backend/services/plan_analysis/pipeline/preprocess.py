from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Optional, Tuple

import cv2
import numpy as np


@dataclass
class PreprocessResult:
    image_bgr: np.ndarray
    gray: np.ndarray
    binary: np.ndarray
    deskew_deg: float


def decode_image_bytes(data: bytes) -> np.ndarray:
    arr = np.frombuffer(data, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Unsupported image bytes (decode failed)")
    return img


def encode_png_bytes(img_bgr: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", img_bgr)
    if not ok:
        raise ValueError("Failed to encode PNG")
    return buf.tobytes()


def _estimate_deskew_deg(gray: np.ndarray) -> float:
    # Estimate small skew angles using Hough lines (robust for scanned docs).
    edges = cv2.Canny(gray, 60, 180, apertureSize=3)
    lines = cv2.HoughLines(edges, 1, np.pi / 180.0, threshold=180)
    if lines is None:
        return 0.0

    angles = []
    for rho_theta in lines[:200]:
        rho, theta = float(rho_theta[0][0]), float(rho_theta[0][1])
        # Convert normal angle to line angle.
        line_angle = theta - np.pi / 2
        deg = (line_angle * 180.0) / np.pi
        # Normalize to [-45, 45]
        while deg < -45:
            deg += 90
        while deg > 45:
            deg -= 90
        if abs(deg) <= 15:  # ignore strong diagonals
            angles.append(deg)

    if not angles:
        return 0.0

    # Use median to reject outliers.
    return float(np.median(np.array(angles)))


def _rotate(img: np.ndarray, deg: float) -> np.ndarray:
    if abs(deg) < 1e-3:
        return img
    h, w = img.shape[:2]
    center = (w / 2.0, h / 2.0)
    m = cv2.getRotationMatrix2D(center, deg, 1.0)
    cos = abs(m[0, 0])
    sin = abs(m[0, 1])

    new_w = int((h * sin) + (w * cos))
    new_h = int((h * cos) + (w * sin))
    m[0, 2] += (new_w / 2) - center[0]
    m[1, 2] += (new_h / 2) - center[1]

    return cv2.warpAffine(img, m, (new_w, new_h), flags=cv2.INTER_LINEAR, borderValue=(255, 255, 255))


def preprocess_plan_image(
    img_bgr: np.ndarray,
    *,
    max_dim: int = 3200,
    adaptive: bool = True,
) -> PreprocessResult:
    # Downscale for speed (keeps aspect ratio)
    h, w = img_bgr.shape[:2]
    scale = 1.0
    if max(h, w) > max_dim:
        scale = max_dim / float(max(h, w))
        img_bgr = cv2.resize(img_bgr, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)

    deskew_deg = _estimate_deskew_deg(gray)
    if abs(deskew_deg) > 0.1:
        img_bgr = _rotate(img_bgr, deskew_deg)
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (3, 3), 0)

    if adaptive:
        binary = cv2.adaptiveThreshold(
            gray,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            31,
            7,
        )
    else:
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Invert so ink is white for morphology operations
    inv = 255 - binary
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    inv = cv2.morphologyEx(inv, cv2.MORPH_OPEN, kernel, iterations=1)

    # Convert back to binary (ink=0, background=255)
    binary = 255 - inv

    return PreprocessResult(image_bgr=img_bgr, gray=gray, binary=binary, deskew_deg=float(deskew_deg))
