"""
bawanthaModel/contour_detector.py
==================================
Computer-Vision contour detection pipeline.

Pipeline
--------
1. Decode the incoming bytes into a NumPy BGR image.
2. Pre-process:
   - Convert to grayscale
   - Bilateral filter  (noise reduction while preserving edges)
   - Gaussian blur     (smooth out minor artefacts)
3. Edge detection — Canny (adaptive thresholds via Otsu's method if not passed).
4. Morphological closing to connect broken edge segments.
5. Find external + nested contours (RETR_TREE).
6. Filter contours by minimum area to drop noise specks.
7. Draw coloured contours on a copy of the original image.
8. Encode result as JPEG bytes (base64-safe).
"""

import cv2
import numpy as np
import base64
import time
from typing import Tuple


class ContourDetector:
    """
    Stateless contour-detection engine.

    Parameters
    ----------
    min_area : float
        Minimum contour area (in pixels²) to keep.  Defaults to 50.
    canny_low : int | None
        Lower Canny threshold.  Pass None to auto-derive via Otsu.
    canny_high : int | None
        Upper Canny threshold.  Pass None to auto-derive via Otsu.
    blur_ksize : int
        Gaussian blur kernel size (must be odd).  Default 5.
    contour_color : tuple
        BGR colour used to draw contours.  Default cyan (0, 255, 255).
    contour_thickness : int
        Pixel thickness of drawn contour lines.  Default 2.
    """

    def __init__(
        self,
        min_area: float = 50.0,
        canny_low: int | None = None,
        canny_high: int | None = None,
        blur_ksize: int = 5,
        contour_color: Tuple[int, int, int] = (0, 255, 255),
        contour_thickness: int = 2,
    ):
        self.min_area = min_area
        self.canny_low = canny_low
        self.canny_high = canny_high
        # ensure kernel size is odd and >= 3
        self.blur_ksize = blur_ksize if blur_ksize % 2 == 1 else blur_ksize + 1
        self.contour_color = contour_color
        self.contour_thickness = contour_thickness

    # ------------------------------------------------------------------ #
    # Public API
    # ------------------------------------------------------------------ #

    def detect(self, image_bytes: bytes) -> dict:
        """
        Run the full detection pipeline on raw image bytes.

        Returns
        -------
        dict with keys:
            success          : bool
            contour_count    : int
            processed_image  : str  (base64-encoded JPEG)
            edge_map         : str  (base64-encoded grayscale Canny edge JPEG)
            processing_time  : float (seconds)
            image_size       : dict  {width, height}
            error            : str  (only present on failure)
        """
        t0 = time.perf_counter()
        try:
            original = self._decode_image(image_bytes)
            gray, blurred = self._preprocess(original)
            edges = self._canny(blurred, gray)
            edges = self._morphological_close(edges)
            contours = self._find_contours(edges)
            annotated = self._draw_contours(original, contours)

            h, w = original.shape[:2]
            return {
                "success": True,
                "contour_count": len(contours),
                "processed_image": self._encode_b64(annotated),
                "edge_map": self._encode_b64(cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)),
                "processing_time": round(time.perf_counter() - t0, 4),
                "image_size": {"width": w, "height": h},
            }
        except Exception as exc:
            return {
                "success": False,
                "error": str(exc),
                "processing_time": round(time.perf_counter() - t0, 4),
            }

    # ------------------------------------------------------------------ #
    # Internal helpers
    # ------------------------------------------------------------------ #

    @staticmethod
    def _decode_image(image_bytes: bytes) -> np.ndarray:
        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Could not decode image — unsupported format or corrupt file.")
        return img

    def _preprocess(self, bgr: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        # bilateral filter preserves edges better than a pure blur
        bilateral = cv2.bilateralFilter(gray, d=9, sigmaColor=75, sigmaSpace=75)
        blurred = cv2.GaussianBlur(bilateral, (self.blur_ksize, self.blur_ksize), 0)
        return gray, blurred

    def _canny(self, blurred: np.ndarray, gray: np.ndarray) -> np.ndarray:
        if self.canny_low is None or self.canny_high is None:
            # Otsu's threshold gives a good automatic mid-point
            otsu_thresh, _ = cv2.threshold(
                blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
            )
            low = max(1, int(0.5 * otsu_thresh))
            high = int(otsu_thresh)
        else:
            low, high = self.canny_low, self.canny_high
        return cv2.Canny(blurred, low, high)

    @staticmethod
    def _morphological_close(edges: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        return cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel)

    def _find_contours(self, edges: np.ndarray):
        contours, _ = cv2.findContours(
            edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE
        )
        # filter by minimum area
        return [c for c in contours if cv2.contourArea(c) >= self.min_area]

    def _draw_contours(self, bgr: np.ndarray, contours) -> np.ndarray:
        annotated = bgr.copy()
        cv2.drawContours(
            annotated, contours, -1, self.contour_color, self.contour_thickness
        )
        # overlay a semi-transparent filled version for visual depth
        overlay = annotated.copy()
        cv2.drawContours(overlay, contours, -1, self.contour_color, cv2.FILLED)
        cv2.addWeighted(overlay, 0.08, annotated, 0.92, 0, annotated)
        return annotated

    @staticmethod
    def _encode_b64(bgr: np.ndarray) -> str:
        success, buf = cv2.imencode(".jpg", bgr, [cv2.IMWRITE_JPEG_QUALITY, 90])
        if not success:
            raise RuntimeError("Failed to encode result image as JPEG.")
        return base64.b64encode(buf.tobytes()).decode("utf-8")
