from collections import OrderedDict
from typing import Dict, List


TASK_RULES = (
    ("Site Clearing", ("site clear", "demolit", "clear site")),
    ("Foundation Excavation", ("excavat", "earthwork", "earth work")),
    ("PCC Bed", ("pcc", "plain cement concrete", "lean concrete", "blinding")),
    ("RCC Footing", ("rcc", "reinforced", "pad footing", "strip footing", "raft foundation")),
    ("Brick Masonry", ("brick", "block masonry", "brickwork", "blockwork")),
    ("Formwork", ("formwork", "shuttering", "centering")),
    ("Roof Slab", ("roof slab", "floor slab", "suspended slab", "rcc slab")),
    ("Internal Plastering", ("internal plaster", "internal render")),
    ("External Plastering", ("external plaster", "external render", "facade")),
    ("Tiling", ("tile", "tiling", "floor finish", "floor tiles")),
)


def _to_int(value: object, default: int) -> int:
    try:
        return int(float(value))
    except Exception:
        return default


def _to_float(value: object, default: float) -> float:
    try:
        return float(value)
    except Exception:
        return default


def _guess_task(description: str) -> str:
    desc = (description or "").lower()
    for task_name, keywords in TASK_RULES:
        if any(keyword in desc for keyword in keywords):
            return task_name
    return ""


def _estimate_area_sqft(boq_items: List[dict]) -> int:
    area = 0.0
    for item in boq_items:
        unit = str(item.get("unit", "")).strip().lower()
        qty = _to_float(item.get("quantity", 0.0), 0.0)
        if qty <= 0:
            continue
        if unit in {"sqft", "sft"}:
            area += qty
        elif unit == "m2":
            area += qty * 10.764
    if area <= 0:
        return 3000
    return int(round(area))


def extract_task_features(
    boq_items: List[dict],
    project_metadata: dict,
) -> List[dict]:
    grouped: "OrderedDict[str, dict]" = OrderedDict()

    for item in boq_items:
        desc = str(item.get("description", "")).strip()
        if not desc:
            continue
        task_key = _guess_task(desc)
        if not task_key:
            continue

        amount = _to_float(item.get("amount", 0.0), 0.0)
        if task_key not in grouped:
            grouped[task_key] = {
                "task_name": task_key,
                "boq_description": desc,
                "boq_amount_rs": 0.0,
            }
        grouped[task_key]["boq_amount_rs"] += amount

    floor_area = _to_int(project_metadata.get("total_floor_area_sqft", 0), 0)
    if floor_area <= 0:
        floor_area = _estimate_area_sqft(boq_items)

    base_meta = {
        "project_type": str(project_metadata.get("project_type", "Residential")),
        "site_location": str(project_metadata.get("site_location", "Colombo")),
        "total_floor_area_sqft": floor_area,
        "number_of_floors": _to_int(project_metadata.get("number_of_floors", 1), 1),
        "building_complexity_index": _to_float(project_metadata.get("building_complexity_index", 6.0), 6.0),
        "working_days": _to_int(project_metadata.get("working_days", 5), 5),
    }

    result: List[dict] = []
    if grouped:
        seq = 1
        for _, data in grouped.items():
            result.append(
                {
                    **base_meta,
                    "task_name": data["task_name"],
                    "boq_description": data["boq_description"],
                    "boq_amount_rs": int(round(data["boq_amount_rs"])),
                    "task_sequence": seq,
                }
            )
            seq += 1
        return result

    fallback_desc = str(project_metadata.get("task_name", "Foundation Excavation"))
    return [
        {
            **base_meta,
            "task_name": "Foundation Excavation",
            "boq_description": fallback_desc,
            "boq_amount_rs": 0,
            "task_sequence": 1,
        }
    ]
