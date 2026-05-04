"""
bawanthaModel/comprehensive_cv.py
==================================
Comprehensive Computer Vision Analysis Pipeline.

Pipeline
--------
1. Decode the incoming bytes into a NumPy BGR image.
2. Pre-process:
   - Convert to grayscale
   - Bilateral filter (noise reduction while preserving edges)
   - Gaussian blur (smooth out minor artefacts)
3. Edge detection — Canny (adaptive thresholds via Otsu's method).
4. Morphological closing to connect broken edge segments.
5. Find contours (RETR_TREE for hierarchical detection).
6. Shape analysis:
   - Approximate contours to polygons
   - Classify shapes (triangle, quadrilateral, pentagon, etc.)
   - Calculate shape properties (area, perimeter, aspect ratio)
7. Corner detection using Harris corner detector.
8. Draw all detections on annotated image.
9. Encode results as JPEG bytes (base64-safe).
"""

import cv2
import numpy as np
import base64
import time
from typing import Tuple, List, Dict, Any


class ComprehensiveCV:
    """
    Comprehensive CV engine: edges + shapes + corners.

    Parameters
    ----------
    min_area : float
        Minimum contour area (in pixels²) to keep. Defaults to 50.
    canny_low : int | None
        Lower Canny threshold. Pass None to auto-derive via Otsu.
    canny_high : int | None
        Upper Canny threshold. Pass None to auto-derive via Otsu.
    blur_ksize : int
        Gaussian blur kernel size (must be odd). Default 5.
    harris_block_size : int
        Harris corner detection block size. Default 2.
    harris_ksize : int
        Harris corner detection aperture size. Default 3.
    harris_k : float
        Harris corner detection sensitivity. Default 0.04.
    corner_threshold : float
        Minimum corner response threshold (0-1). Default 0.01.
    """

    def __init__(
        self,
        min_area: float = 50.0,
        canny_low: int | None = None,
        canny_high: int | None = None,
        blur_ksize: int = 5,
        harris_block_size: int = 2,
        harris_ksize: int = 3,
        harris_k: float = 0.04,
        corner_threshold: float = 0.01,
    ):
        self.min_area = min_area
        self.canny_low = canny_low
        self.canny_high = canny_high
        self.blur_ksize = blur_ksize if blur_ksize % 2 == 1 else blur_ksize + 1
        self.harris_block_size = harris_block_size
        self.harris_ksize = harris_ksize
        self.harris_k = harris_k
        self.corner_threshold = corner_threshold

    # ------------------------------------------------------------------ #
    # Public API
    # ------------------------------------------------------------------ #

    def analyze(self, image_bytes: bytes) -> dict:
        """
        Run the full CV analysis pipeline on raw image bytes.

        Returns
        -------
        dict with keys:
            success              : bool
            processing_time      : float (seconds)
            image_size           : dict {width, height}
            edges                : dict {count, image_b64}
            shapes               : dict {count, shapes_list, image_b64}
            corners              : dict {count, corners_list, image_b64}
            hough                : dict {count, lines_list, image_b64}
            combined             : dict {image_b64}  # all detections overlaid
            error                : str (only present on failure)
        """
        t0 = time.perf_counter()
        try:
            original = self._decode_image(image_bytes)
            gray, blurred = self._preprocess(original)
            edges = self._canny(blurred, gray)
            edges_cleaned = self._morphological_close(edges)
            contours = self._find_contours(edges_cleaned)

            # Shape analysis
            shapes_info, shapes_annotated = self._analyze_shapes(original, contours)

            # Corner detection
            corners_info, corners_annotated = self._detect_corners(gray)

            # Hough line detection
            hough_info, hough_annotated = self._detect_hough_lines_method(edges_cleaned, "probabilistic")

            # Combined visualization
            combined = self._create_combined_view(original, edges_cleaned, shapes_info, corners_info, hough_info)

            h, w = original.shape[:2]
            return {
                "success": True,
                "processing_time": round(time.perf_counter() - t0, 4),
                "image_size": {"width": w, "height": h},
                "edges": {
                    "count": len(contours),
                    "image_b64": self._encode_b64(cv2.cvtColor(edges_cleaned, cv2.COLOR_GRAY2BGR)),
                },
                "shapes": {
                    "count": len(shapes_info),
                    "shapes": shapes_info,
                    "image_b64": self._encode_b64(shapes_annotated),
                },
                "corners": {
                    "count": len(corners_info),
                    "corners": corners_info,
                    "image_b64": self._encode_b64(corners_annotated),
                },
                "hough": {
                    "count": len(hough_info),
                    "lines": hough_info,
                    "image_b64": self._encode_b64(hough_annotated),
                },
                "combined": {
                    "image_b64": self._encode_b64(combined),
                },
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
        bilateral = cv2.bilateralFilter(gray, d=9, sigmaColor=75, sigmaSpace=75)
        blurred = cv2.GaussianBlur(bilateral, (self.blur_ksize, self.blur_ksize), 0)
        return gray, blurred

    def _canny(self, blurred: np.ndarray, gray: np.ndarray) -> np.ndarray:
        if self.canny_low is None or self.canny_high is None:
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
        return [c for c in contours if cv2.contourArea(c) >= self.min_area]

    def _analyze_shapes(self, original: np.ndarray, contours) -> Tuple[List[Dict], np.ndarray]:
        annotated = original.copy()
        shapes = []

        for i, contour in enumerate(contours):
            # Approximate the contour to a polygon
            epsilon = 0.04 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)

            # Get bounding box
            x, y, w, h = cv2.boundingRect(approx)
            aspect_ratio = float(w) / h if h > 0 else 0

            # Classify shape based on number of vertices
            num_vertices = len(approx)
            shape_name = self._classify_shape(num_vertices, aspect_ratio)

            # Calculate properties
            area = cv2.contourArea(contour)
            perimeter = cv2.arcLength(contour, True)

            # Get centroid
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
            else:
                cx, cy = x + w//2, y + h//2

            # Draw shape
            cv2.drawContours(annotated, [approx], -1, (0, 255, 0), 2)  # Green for shapes
            cv2.putText(annotated, f"{shape_name}", (cx - 20, cy),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

            shapes.append({
                "id": i + 1,
                "shape": shape_name,
                "vertices": num_vertices,
                "area": round(area, 2),
                "perimeter": round(perimeter, 2),
                "aspect_ratio": round(aspect_ratio, 2),
                "centroid": [cx, cy],
                "bounding_box": [x, y, w, h],
            })

        return shapes, annotated

    @staticmethod
    def _classify_shape(num_vertices: int, aspect_ratio: float) -> str:
        if num_vertices == 3:
            return "Triangle"
        elif num_vertices == 4:
            if 0.95 <= aspect_ratio <= 1.05:
                return "Square"
            else:
                return "Rectangle"
        elif num_vertices == 5:
            return "Pentagon"
        elif num_vertices == 6:
            return "Hexagon"
        elif num_vertices >= 7:
            return "Circle/Ellipse"  # Approximation for high vertex count
        else:
            return f"{num_vertices}-gon"

    def _detect_corners(self, gray: np.ndarray) -> Tuple[List[Dict], np.ndarray]:
        # Harris corner detection
        gray_float = np.float32(gray)
        harris_response = cv2.cornerHarris(
            gray_float,
            self.harris_block_size,
            self.harris_ksize,
            self.harris_k
        )

        # Dilate to mark corners
        harris_response = cv2.dilate(harris_response, None)

        # Threshold for corner detection
        threshold = self.corner_threshold * harris_response.max()
        corner_mask = harris_response > threshold

        # Find corner coordinates
        corners = []
        annotated = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

        corner_coords = np.where(corner_mask)
        for y, x in zip(corner_coords[0], corner_coords[1]):
            corners.append({
                "id": len(corners) + 1,
                "position": [int(x), int(y)],
                "response": float(harris_response[y, x]),
            })
            # Draw corner as red circle
            cv2.circle(annotated, (x, y), 3, (0, 0, 255), -1)

        return corners, annotated

    def _detect_hough_lines(self, edges: np.ndarray) -> Tuple[List[Dict], np.ndarray]:
        # Hough line transform
        lines = cv2.HoughLinesP(edges, 1, np.pi/180, threshold=50, minLineLength=50, maxLineGap=10)
        
        lines_info = []
        annotated = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
        
        if lines is not None:
            for i, line in enumerate(lines):
                x1, y1, x2, y2 = line[0]
                lines_info.append({
                    "id": i + 1,
                    "start": [int(x1), int(y1)],
                    "end": [int(x2), int(y2)],
                    "length": round(np.sqrt((x2-x1)**2 + (y2-y1)**2), 2),
                })
                # Draw line in yellow
                cv2.line(annotated, (x1, y1), (x2, y2), (0, 255, 255), 2)
        
        return lines_info, annotated

    def _create_combined_view(self, original: np.ndarray, edges: np.ndarray,
                             shapes: List[Dict], corners: List[Dict], hough_lines: List[Dict]) -> np.ndarray:
        # Start with original image
        combined = original.copy()

        # Overlay edges in blue
        edges_colored = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
        edges_colored[:, :, 0] = 0  # Remove red
        edges_colored[:, :, 2] = 0  # Remove blue, keep green? Wait, make it cyan
        edges_colored[:, :, 1] = edges  # Green channel
        combined = cv2.addWeighted(combined, 0.8, edges_colored, 0.2, 0)

        # Draw shape contours in green
        for shape in shapes:
            # We don't have the approx contours here, so skip detailed drawing
            # Just mark centroids
            cx, cy = shape["centroid"]
            cv2.circle(combined, (cx, cy), 5, (0, 255, 0), -1)
            cv2.putText(combined, shape["shape"][:3], (cx - 10, cy - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 0), 1)

        # Draw corners in red
        for corner in corners:
            x, y = corner["position"]
            cv2.circle(combined, (x, y), 3, (0, 0, 255), -1)

        # Draw hough lines in yellow
        for line in hough_lines:
            x1, y1 = line["start"]
            x2, y2 = line["end"]
            cv2.line(combined, (x1, y1), (x2, y2), (0, 255, 255), 1)

        return combined

    # ------------------------------------------------------------------ #
    # Hough Line Transform Analysis
    # ------------------------------------------------------------------ #

    def analyze_hough(self, image_bytes: bytes, method: str = "probabilistic") -> dict:
        """
        Run Hough line transform analysis on raw image bytes.

        Parameters
        ----------
        image_bytes : bytes
            Raw image data
        method : str
            'probabilistic' or 'standard'

        Returns
        -------
        dict with analysis results
        """
        t0 = time.perf_counter()
        try:
            original = self._decode_image(image_bytes)
            gray, _ = self._preprocess(original)
            edges = self._canny(gray, gray)
            edges_cleaned = self._morphological_close(edges)

            lines_info, annotated = self._detect_hough_lines_method(edges_cleaned, method)

            h, w = original.shape[:2]
            return {
                "success": True,
                "processing_time": round(time.perf_counter() - t0, 4),
                "method": method,
                "count": len(lines_info),
                "lines": lines_info,
                "original_b64": self._encode_b64(original),
                "image_b64": self._encode_b64(annotated),
            }
        except Exception as exc:
            return {
                "success": False,
                "error": str(exc),
                "processing_time": round(time.perf_counter() - t0, 4),
            }

    def _detect_hough_lines_method(self, edges: np.ndarray, method: str) -> Tuple[List[Dict], np.ndarray]:
        """
        Detect lines using specified Hough method.
        """
        annotated = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
        lines_info = []

        if method == "probabilistic":
            lines = cv2.HoughLinesP(edges, 1, np.pi/180, threshold=50, minLineLength=50, maxLineGap=10)
            if lines is not None:
                for i, line in enumerate(lines):
                    x1, y1, x2, y2 = line[0]
                    x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
                    lines_info.append({
                        "id": i + 1,
                        "start": [x1, y1],
                        "end": [x2, y2],
                        "length": round(float(np.sqrt((x2-x1)**2 + (y2-y1)**2)), 2),
                    })
                    cv2.line(annotated, (x1, y1), (x2, y2), (0, 255, 255), 2)
        else:  # standard
            lines = cv2.HoughLines(edges, 1, np.pi/180, threshold=100)
            if lines is not None:
                for i, line in enumerate(lines):
                    rho, theta = float(line[0][0]), float(line[0][1])
                    a = np.cos(theta)
                    b = np.sin(theta)
                    x0 = a * rho
                    y0 = b * rho
                    x1 = int(x0 + 1000 * (-b))
                    y1 = int(y0 + 1000 * (a))
                    x2 = int(x0 - 1000 * (-b))
                    y2 = int(y0 - 1000 * (a))

                    lines_info.append({
                        "id": i + 1,
                        "rho": round(rho, 2),
                        "theta": round(theta, 4),
                        "start": [x1, y1],
                        "end": [x2, y2],
                        "length": round(float(np.sqrt((x2-x1)**2 + (y2-y1)**2)), 2),
                    })
                    cv2.line(annotated, (x1, y1), (x2, y2), (0, 255, 255), 2)

        return lines_info, annotated

    @staticmethod
    def _encode_b64(bgr: np.ndarray) -> str:
        success, buf = cv2.imencode(".jpg", bgr, [cv2.IMWRITE_JPEG_QUALITY, 90])
        if not success:
            raise RuntimeError("Failed to encode result image as JPEG.")
        return base64.b64encode(buf.tobytes()).decode("utf-8")
