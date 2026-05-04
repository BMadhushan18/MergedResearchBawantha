import logging
import os
from typing import Any, Dict

import joblib
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "ml_models")

_pipeline = None
_model_1 = None
_model_2 = None
_model_3 = None
_loaded = False

FUEL_PRICE_RS = 330
WORKING_HOURS_PER_DAY = 8
SKILL_LEVELS = ("Skilled Grade I", "Skilled Grade II", "Special Skilled", "Skilled")

LABOUR_COUNT_KEYS = (
    "mason_count",
    "carpenter_count",
    "bar_bender_count",
    "plasterer_count",
    "tiler_count",
    "roofer_count",
    "painter_count",
    "mixer_operator_count",
    "vibrator_operator_count",
    "semi_skilled_labourer_count",
    "general_labourer_count",
    "cleaning_labourer_count",
    "foreman_count",
    "survey_assistant_count",
)


def load_models() -> None:
    global _pipeline, _model_1, _model_2, _model_3, _loaded

    paths = {
        "shared_feature_pipeline": os.path.join(MODEL_DIR, "shared_feature_pipeline.pkl"),
        "model_1_vehicle": os.path.join(MODEL_DIR, "model_1_vehicle.pkl"),
        "model_2_machinery": os.path.join(MODEL_DIR, "model_2_machinery.pkl"),
        "model_3_labour": os.path.join(MODEL_DIR, "model_3_labour.pkl"),
    }

    missing = [name for name, path in paths.items() if not os.path.exists(path)]
    if missing:
        logger.warning("Missing model files: %s", ", ".join(missing))
        _pipeline = None
        _model_1 = None
        _model_2 = None
        _model_3 = None
        _loaded = False
        return

    try:
        _pipeline = joblib.load(paths["shared_feature_pipeline"])
        _model_1 = joblib.load(paths["model_1_vehicle"])
        _model_2 = joblib.load(paths["model_2_machinery"])
        _model_3 = joblib.load(paths["model_3_labour"])
        _loaded = True
    except Exception as exc:
        logger.warning("Model loading failed: %s", exc)
        _pipeline = None
        _model_1 = None
        _model_2 = None
        _model_3 = None
        _loaded = False


def models_loaded() -> bool:
    return _loaded


def _safe_int(value: Any) -> int:
    try:
        return int(round(float(value)))
    except Exception:
        return 0


def _safe_float(value: Any) -> float:
    try:
        return float(value)
    except Exception:
        return 0.0


def _decode_label(bundle: Dict[str, Any], encoded_value: Any) -> str:
    encoder = bundle.get("label_encoder")
    if encoder is None:
        return str(encoded_value)
    try:
        decoded = encoder.inverse_transform(np.array([encoded_value]))
        return str(decoded[0])
    except Exception:
        return str(encoded_value)


def _lookup(bundle: Dict[str, Any], key_str: str, key_int: int) -> Dict[str, Any]:
    table = bundle.get("lookup") or {}
    if key_str in table:
        return table.get(key_str, {})
    if key_int in table:
        return table.get(key_int, {})
    int_str = str(key_int)
    if int_str in table:
        return table.get(int_str, {})
    return {}


def _count_by_skill(labour_counts: Dict[str, int], col_to_labour: Dict[str, str], catalogue: Dict[str, Dict[str, Any]], skill_name: str) -> int:
    total = 0
    for col, count in labour_counts.items():
        role = col_to_labour.get(col, "")
        role_skill = str((catalogue.get(role) or {}).get("skill", ""))
        if skill_name == "SKILLED":
            if role_skill in SKILL_LEVELS:
                total += count
        elif role_skill == skill_name:
            total += count
    return total


def predict_one_task(
    boq_description: str,
    project_type: str,
    site_location: str,
    total_floor_area_sqft: int,
    number_of_floors: int,
    building_complexity_index: float,
    working_days: int = 5,
) -> dict:
    if not models_loaded():
        raise RuntimeError("Models are not loaded")

    inp = pd.DataFrame(
        [
            {
                "boq_description": (boq_description or "").lower().strip(),
                "project_type": (project_type or "").title(),
                "site_location": (site_location or "").title(),
                "total_floor_area_sqft": int(total_floor_area_sqft),
                "number_of_floors": int(number_of_floors),
                "building_complexity_index": float(building_complexity_index),
            }
        ]
    )
    x_mat = _pipeline.transform(inp)

    v_class_encoded = _safe_int(_model_1["classifier"].predict(x_mat)[0])
    v_type = _decode_label(_model_1, v_class_encoded)
    v_count = min(10, max(1, _safe_int(_model_1["regressor"].predict(x_mat)[0])))
    v_data = _lookup(_model_1, v_type, v_class_encoded)
    v_hourly = _safe_int(v_data.get("vehicle_hourly_cost", 0))
    v_daily = _safe_int(v_data.get("vehicle_daily_rental", 0))
    v_fuel = _safe_float(v_data.get("vehicle_fuel_lph", 0.0))
    v_purpose = str(v_data.get("vehicle_purpose", ""))
    v_total_cost = v_count * v_daily

    m_class_encoded = _safe_int(_model_2["classifier"].predict(x_mat)[0])
    m_type = _decode_label(_model_2, m_class_encoded)
    m_count = min(6, max(1, _safe_int(_model_2["regressor"].predict(x_mat)[0])))
    m_data = _lookup(_model_2, m_type, m_class_encoded)
    m_hourly = _safe_int(m_data.get("machinery_hourly_cost", 0))
    m_daily = _safe_int(m_data.get("machinery_daily_rental", 0))
    m_fuel = _safe_float(m_data.get("machinery_fuel_lph", 0.0))
    m_purpose = str(m_data.get("machinery_purpose", ""))
    m_total_cost = m_count * m_daily

    labour_targets = list(_model_3.get("labour_targets") or [])
    y_lab = _model_3["multioutput_regressor"].predict(x_mat)[0]
    lab_pred = dict(zip(labour_targets, y_lab))
    col_to_labour = _model_3.get("col_to_labour") or {}
    catalogue = _model_3.get("labour_catalogue") or {}

    labour_counts: Dict[str, int] = {key: 0 for key in LABOUR_COUNT_KEYS}
    labour_daily = 0
    for col, role in col_to_labour.items():
        if str(role).upper() == "COST":
            continue
        count = max(0, _safe_int(lab_pred.get(col, 0)))
        if col in labour_counts:
            labour_counts[col] = count
        role_meta = catalogue.get(role) or {}
        labour_daily += count * _safe_int(role_meta.get("rate", 0))

    total_skilled = _count_by_skill(labour_counts, col_to_labour, catalogue, "SKILLED")
    total_semi = _count_by_skill(labour_counts, col_to_labour, catalogue, "Semi-Skilled")
    total_un = _count_by_skill(labour_counts, col_to_labour, catalogue, "Unskilled")
    total_gang = total_skilled + total_semi + total_un

    vehicle_fuel_total = v_count * v_fuel
    machinery_fuel_total = m_count * m_fuel
    total_fuel_lph = vehicle_fuel_total + machinery_fuel_total
    total_fuel_per_day = total_fuel_lph * WORKING_HOURS_PER_DAY
    fuel_cost_per_day = total_fuel_per_day * FUEL_PRICE_RS

    if total_fuel_lph < 10:
        rating = "Excellent"
    elif total_fuel_lph < 20:
        rating = "Good"
    elif total_fuel_lph < 35:
        rating = "Fair"
    else:
        rating = "Needs Optimisation"

    total_daily = v_total_cost + m_total_cost + labour_daily

    return {
        "vehicle": {
            "vehicle_type": v_type,
            "vehicle_count": v_count,
            "vehicle_purpose": v_purpose,
            "vehicle_hourly_cost_rs": v_hourly,
            "vehicle_daily_rental_rs": v_daily,
            "vehicle_fuel_lph": v_fuel,
            "vehicle_total_daily_cost_rs": v_total_cost,
        },
        "machinery": {
            "machinery_type": m_type,
            "machinery_count": m_count,
            "machinery_purpose": m_purpose,
            "machinery_hourly_cost_rs": m_hourly,
            "machinery_daily_rental_rs": m_daily,
            "machinery_fuel_lph": m_fuel,
            "machinery_total_daily_cost_rs": m_total_cost,
        },
        "labour": {
            **labour_counts,
            "total_skilled": total_skilled,
            "total_semi_skilled": total_semi,
            "total_unskilled": total_un,
            "total_gang": total_gang,
            "labour_daily_cost_rs": labour_daily,
        },
        "fuel": {
            "vehicle_fuel_lph_total": round(vehicle_fuel_total, 2),
            "machinery_fuel_lph_total": round(machinery_fuel_total, 2),
            "total_fuel_lph": round(total_fuel_lph, 2),
            "total_fuel_per_day_litres": round(total_fuel_per_day, 2),
            "fuel_cost_per_day_rs": round(fuel_cost_per_day, 2),
            "efficiency_rating": rating,
        },
        "cost_summary": {
            "vehicle_daily_cost_rs": int(v_total_cost),
            "machinery_daily_cost_rs": int(m_total_cost),
            "labour_daily_cost_rs": int(labour_daily),
            "total_daily_cost_rs": int(total_daily),
            "working_days": int(working_days),
            "task_total_cost_rs": int(total_daily * working_days),
        },
    }
