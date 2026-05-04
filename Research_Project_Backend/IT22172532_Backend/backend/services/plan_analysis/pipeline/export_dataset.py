from __future__ import annotations

import json
import os
import shutil
from typing import Any, Dict, List, Tuple


CATEGORY_MAP = {
    "door": 1,
    "window": 2,
    "column": 3,
    "wall": 4,
    "room": 5,
}


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _bbox_xyxy_to_xywh(b: List[float] | Tuple[float, float, float, float]):
    x1, y1, x2, y2 = b
    return [float(x1), float(y1), float(max(0.0, x2 - x1)), float(max(0.0, y2 - y1))]


def export_coco_detection(
    *,
    out_dir: str,
    subplan_id: str,
    image_abs_path: str,
    fused_doc: Dict[str, Any],
) -> Dict[str, Any]:
    """Writes a minimal COCO detection export.

    Requires `bbox_local` for items. Unknown categories are ignored.
    """

    ensure_dir(out_dir)
    images_dir = os.path.join(out_dir, "images")
    ensure_dir(images_dir)

    # Copy image
    img_name = f"{subplan_id}.png"
    img_out = os.path.join(images_dir, img_name)
    shutil.copyfile(image_abs_path, img_out)

    # Image size is not guaranteed in fused_doc, so caller should add it later if needed.
    coco = {
        "images": [{"id": 1, "file_name": img_name}],
        "annotations": [],
        "categories": [{"id": v, "name": k} for k, v in CATEGORY_MAP.items()],
    }

    ann_id = 1
    for it in fused_doc.get("items", []):
        cat = it.get("category") or it.get("item_type")
        if cat not in CATEGORY_MAP:
            continue
        bbox = it.get("bbox_local") or it.get("rough_bbox")
        if not bbox:
            continue
        xywh = _bbox_xyxy_to_xywh(bbox)
        coco["annotations"].append(
            {
                "id": ann_id,
                "image_id": 1,
                "category_id": CATEGORY_MAP[cat],
                "bbox": xywh,
                "area": float(xywh[2] * xywh[3]),
                "iscrowd": 0,
            }
        )
        ann_id += 1

    ann_path = os.path.join(out_dir, "annotations.json")
    with open(ann_path, "w", encoding="utf-8") as f:
        json.dump(coco, f, ensure_ascii=False, indent=2)

    return {"images_dir": images_dir, "annotations": ann_path}
