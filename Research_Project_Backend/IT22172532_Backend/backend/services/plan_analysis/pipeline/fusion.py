"""Fusion engine (v1.1)

Goal: produce a single fused output per subplan that combines:
- Gemini prompt outputs (semantic + geometry)
- manual annotations

Rules (v1.1):
1) Manual-only items are added.
2) If manual and AI match (same category + similar bbox/centroid), merge into one item.
3) If manual conflicts with AI, manual overrides.
4) AI-only items are kept but marked `needs_review`.

This is still heuristic and intentionally lightweight.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple


def _bbox_xyxy(item: Dict[str, Any]) -> Optional[Tuple[float, float, float, float]]:
    b = item.get("bbox_local") or item.get("bbox") or item.get("rough_bbox")
    if not b or len(b) != 4:
        return None
    x1, y1, x2, y2 = [float(v) for v in b]
    if x2 <= x1 or y2 <= y1:
        return None
    return (x1, y1, x2, y2)


def _centroid(item: Dict[str, Any]) -> Optional[Tuple[float, float]]:
    b = _bbox_xyxy(item)
    if b:
        x1, y1, x2, y2 = b
        return ((x1 + x2) / 2.0, (y1 + y2) / 2.0)
    pts = item.get("geometry_local")
    if isinstance(pts, list) and pts and isinstance(pts[0], list) and len(pts[0]) >= 2:
        xs = [float(p[0]) for p in pts if isinstance(p, list) and len(p) >= 2]
        ys = [float(p[1]) for p in pts if isinstance(p, list) and len(p) >= 2]
        if xs and ys:
            return (sum(xs) / len(xs), sum(ys) / len(ys))
    return None


def _iou(a: Tuple[float, float, float, float], b: Tuple[float, float, float, float]) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    union = area_a + area_b - inter
    return float(inter / union) if union > 0 else 0.0


def _dist(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    dx = a[0] - b[0]
    dy = a[1] - b[1]
    return float((dx * dx + dy * dy) ** 0.5)


def _category(item: Dict[str, Any]) -> str:
    return str(item.get("category") or item.get("item_type") or "other").strip().lower()


def _match_score(man: Dict[str, Any], ai: Dict[str, Any]) -> float:
    if _category(man) != _category(ai):
        return 0.0
    mb = _bbox_xyxy(man)
    ab = _bbox_xyxy(ai)
    if mb and ab:
        return _iou(mb, ab)
    mc = _centroid(man)
    ac = _centroid(ai)
    if mc and ac:
        d = _dist(mc, ac)
        # Normalize: 0px -> 1.0 ; 50px -> ~0
        return max(0.0, 1.0 - (d / 50.0))
    return 0.0


def _merge_items(man: Dict[str, Any], ai: Dict[str, Any]) -> Dict[str, Any]:
    # Manual geometry/type wins. Keep AI values as provenance metadata.
    merged = dict(ai)
    merged.update(man)

    # If both provide numeric measurements and they are very close, average.
    m_meas = man.get("measurements") if isinstance(man.get("measurements"), dict) else {}
    a_meas = ai.get("measurements") if isinstance(ai.get("measurements"), dict) else {}
    out_meas: Dict[str, Any] = {}

    def _is_num(v: Any) -> bool:
        return isinstance(v, (int, float)) and v == v  # not NaN

    def _avg_if_close(mv: Any, av: Any, *, rel_tol: float = 0.10):
        if not (_is_num(mv) and _is_num(av)):
            return mv if mv is not None else av
        denom = max(abs(float(mv)), abs(float(av)), 1.0)
        if abs(float(mv) - float(av)) / denom <= rel_tol:
            return (float(mv) + float(av)) / 2.0
        return mv

    keys = set(a_meas.keys()) | set(m_meas.keys())
    for k in keys:
        mv = m_meas.get(k)
        av = a_meas.get(k)
        # Only average for same-unit numeric channels (mm/mm2/pixels, etc).
        out_meas[k] = _avg_if_close(mv, av)

    if out_meas:
        merged["measurements"] = out_meas

    merged["source_status"] = "merged"
    merged["sources"] = {
        "manual": {"present": True},
        "gemini": {"present": True, "confidence": ai.get("confidence")},
    }
    return merged


def fuse(
    *,
    subplan_id: str,
    manual_doc: Optional[Dict[str, Any]],
    ai_semantic_doc: Optional[Dict[str, Any]],
    ai_geometry_doc: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    manual_items: List[Dict[str, Any]] = []
    if manual_doc and manual_doc.get("items"):
        manual_items = list(manual_doc.get("items") or [])

    ai_items: List[Dict[str, Any]] = []
    if ai_geometry_doc and ai_geometry_doc.get("items"):
        ai_items = list(ai_geometry_doc.get("items") or [])
    elif ai_semantic_doc and ai_semantic_doc.get("items"):
        ai_items = list(ai_semantic_doc.get("items") or [])

    if not manual_items and not ai_items:
        return {
            "subplan_id": subplan_id,
            "items": [],
            "source_status": "empty",
            "final_confidence": 0.0,
            "provenance": {
                "manual_version": None,
                "ai_semantic": bool(ai_semantic_doc),
                "ai_geometry": bool(ai_geometry_doc),
            },
        }

    # If no manual, keep AI-only as needs_review.
    if not manual_items and ai_items:
        out_items = []
        for it in ai_items:
            it2 = dict(it)
            it2["source_status"] = "needs_review"
            it2["sources"] = {"gemini": {"present": True, "confidence": it.get("confidence")}}
            out_items.append(it2)
        return {
            "subplan_id": subplan_id,
            "items": out_items,
            "source_status": "gemini_only",
            "final_confidence": 0.6,
            "provenance": {
                "manual_version": None,
                "ai_semantic": bool(ai_semantic_doc),
                "ai_geometry": bool(ai_geometry_doc),
            },
        }

    # Match manual to AI
    matched_ai = set()
    fused_items: List[Dict[str, Any]] = []
    for man in manual_items:
        best_j = -1
        best_score = 0.0
        for j, ai in enumerate(ai_items):
            if j in matched_ai:
                continue
            s = _match_score(man, ai)
            if s > best_score:
                best_score = s
                best_j = j

        if best_j >= 0 and best_score >= 0.85:
            matched_ai.add(best_j)
            fused_items.append(_merge_items(man, ai_items[best_j]))
        else:
            it = dict(man)
            it["source_status"] = "manual_only" if not ai_items else "manual_override"
            it["sources"] = {"manual": {"present": True}}
            fused_items.append(it)

    # Add remaining AI-only items
    for j, ai in enumerate(ai_items):
        if j in matched_ai:
            continue
        it2 = dict(ai)
        it2["source_status"] = "needs_review"
        it2["sources"] = {"gemini": {"present": True, "confidence": ai.get("confidence")}}
        fused_items.append(it2)

    # Overall confidence heuristic
    overall = 0.8
    if manual_items:
        overall = 0.95
    if ai_items and not manual_items:
        overall = 0.6

    return {
        "subplan_id": subplan_id,
        "items": fused_items,
        "source_status": "fused",
        "final_confidence": overall,
        "provenance": {
            "manual_version": manual_doc.get("version") if manual_doc else None,
            "ai_semantic": bool(ai_semantic_doc),
            "ai_geometry": bool(ai_geometry_doc),
        },
    }
