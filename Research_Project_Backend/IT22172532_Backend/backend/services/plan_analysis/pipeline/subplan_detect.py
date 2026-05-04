from __future__ import annotations

from dataclasses import dataclass
from typing import List, Tuple

import cv2
import numpy as np


@dataclass
class SubplanCandidate:
    bbox: Tuple[int, int, int, int]  # x1,y1,x2,y2 in image coords
    confidence: float


def _iou(a: Tuple[int, int, int, int], b: Tuple[int, int, int, int]) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, ix2 - ix1), max(0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    area_a = max(0, ax2 - ax1) * max(0, ay2 - ay1)
    area_b = max(0, bx2 - bx1) * max(0, by2 - by1)
    union = area_a + area_b - inter
    return float(inter / union) if union > 0 else 0.0


def _merge_boxes(boxes: List[Tuple[int, int, int, int]], iou_thr: float = 0.25) -> List[Tuple[int, int, int, int]]:
    # Greedy merge for overlapping boxes.
    boxes = boxes[:]
    merged = True
    while merged:
        merged = False
        out: List[Tuple[int, int, int, int]] = []
        used = [False] * len(boxes)
        for i in range(len(boxes)):
            if used[i]:
                continue
            x1, y1, x2, y2 = boxes[i]
            used[i] = True
            for j in range(i + 1, len(boxes)):
                if used[j]:
                    continue
                if _iou((x1, y1, x2, y2), boxes[j]) >= iou_thr:
                    bx1, by1, bx2, by2 = boxes[j]
                    x1, y1 = min(x1, bx1), min(y1, by1)
                    x2, y2 = max(x2, bx2), max(y2, by2)
                    used[j] = True
                    merged = True
            out.append((x1, y1, x2, y2))
        boxes = out
    return boxes


def detect_subplans(binary: np.ndarray, *, min_area_ratio: float = 0.03, max_candidates: int = 12) -> List[SubplanCandidate]:
    """Detect sub-drawing rectangles on a compound sheet.

    Input is a binary image with background=255.
    This is a heuristic v1 designed for printed sheets.
    """

    h, w = binary.shape[:2]
    sheet_area = float(h * w)

    inv = 255 - binary

    # Connect nearby components so each subplan becomes a single blob.
    k = cv2.getStructuringElement(cv2.MORPH_RECT, (25, 25))
    closed = cv2.morphologyEx(inv, cv2.MORPH_CLOSE, k, iterations=1)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    boxes: List[Tuple[int, int, int, int]] = []
    for c in contours:
        x, y, bw, bh = cv2.boundingRect(c)
        area = float(bw * bh)
        if area / sheet_area < min_area_ratio:
            continue
        # Reject huge boxes that are basically the whole page (we'll add fallback later)
        if area / sheet_area > 0.98:
            continue
        pad = 6
        x1 = max(0, x - pad)
        y1 = max(0, y - pad)
        x2 = min(w, x + bw + pad)
        y2 = min(h, y + bh + pad)
        boxes.append((x1, y1, x2, y2))

    if not boxes:
        # Fallback: single full sheet
        return [SubplanCandidate(bbox=(0, 0, w, h), confidence=0.1)]

    boxes = _merge_boxes(boxes, iou_thr=0.15)
    # Sort: top-to-bottom, left-to-right
    boxes.sort(key=lambda b: (b[1], b[0]))

    candidates: List[SubplanCandidate] = []
    for b in boxes[:max_candidates]:
        x1, y1, x2, y2 = b
        area = float((x2 - x1) * (y2 - y1))
        conf = min(0.95, max(0.2, area / sheet_area))
        candidates.append(SubplanCandidate(bbox=b, confidence=float(conf)))

    return candidates
