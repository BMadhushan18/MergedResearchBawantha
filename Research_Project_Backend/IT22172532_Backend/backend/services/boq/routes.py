"""BOQ computation routes."""

import datetime
import math
import re
from flask import Blueprint, jsonify

from core.auth import get_current_uid
from database.connection import (
    boqReport_col,
    buildingstructure_col,
    materials_col,
    structuralframe_col,
    walling_col,
)
from core.errors import err


boq_bp = Blueprint("boq", __name__)


def _dim_to_m(raw, fallback=0.0):
    if isinstance(raw, (int, float)):
        return float(raw)
    text = str(raw or "").strip().lower()
    if not text:
        return fallback
    m = re.search(r"-?\d+(?:\.\d+)?", text)
    if not m:
        return fallback
    val = float(m.group())
    if "mm" in text:
        return val / 1000
    if "cm" in text:
        return val / 100
    if "ft" in text:
        return val * 0.3048
    if "in" in text:
        return val * 0.0254
    return val


def _dim_to_m_u(raw, units, fallback=0.0):
    if isinstance(raw, (int, float)):
        val = float(raw)
        if units in ("ft", "feet"):
            return val * 0.3048
        if units in ("in", "inch", "inches"):
            return val * 0.0254
        return val
    return _dim_to_m(raw, fallback)


def _area_to_m2(raw):
    if isinstance(raw, (int, float)):
        return float(raw)
    text = str(raw or "").strip().lower()
    if not text:
        return 0.0
    m = re.search(r"\d+(?:\.\d+)?", text)
    if not m:
        return 0.0
    val = float(m.group())
    if "sq ft" in text or "ft2" in text or "ft^2" in text:
        return val * 0.092903
    return val


def _mat_info(mats_by_name, mat_name):
    doc = mats_by_name.get(mat_name.lower())
    if not doc:
        return ("-", "-")
    brands = doc.get("brands", [])
    sizes = doc.get("sizes", [])
    return (brands[0] if brands else "-", sizes[0] if sizes else "-")


def _boq_row(mat_name, unit, qty, size, brand):
    return {"materialName": mat_name, "unit": unit, "quantity": qty, "size": size, "brand": brand}


def _extract_walling_m(doc):
    if not doc:
        return {"count": 0, "total_length": 0.0, "total_area": 0.0, "total_volume": 0.0}
    data = doc.get("data", doc)
    units = (data.get("output") or {}).get("units", "m") if isinstance(data, dict) else "m"
    gf = data.get("groundFloor") if isinstance(data, dict) else None
    default_h_raw = (data.get("output") or {}).get("defaultWallHeight")
    default_h = _dim_to_m_u(default_h_raw, units, 0.0) if default_h_raw is not None else 0.0
    walls = gf.get("walls") if isinstance(gf, dict) else None
    if not walls or not isinstance(walls, dict):
        return {"count": 0, "total_length": 0.0, "total_area": 0.0, "total_volume": 0.0}
    count, total_l, total_a, total_v = 0, 0.0, 0.0, 0.0
    for wall in walls.values():
        if not isinstance(wall, dict):
            continue
        l = _dim_to_m_u(wall.get("length"), units, 0)
        h_raw = wall.get("height")
        h = _dim_to_m_u(h_raw, units, 0) if h_raw is not None else default_h
        t = _dim_to_m_u(wall.get("width"), units, 0.115)
        if l <= 0 or h <= 0:
            continue
        count += 1
        total_l += l
        total_a += l * h
        total_v += l * h * t
    return {"count": count, "total_length": total_l, "total_area": total_a, "total_volume": total_v}


def _extract_column_m(doc):
    if not doc:
        return {"count": 0, "total_volume": 0.0, "formwork_area": 0.0}
    data = doc.get("data", doc)
    units = (data.get("output") or {}).get("units", "m") if isinstance(data, dict) else "m"
    default_h_raw = (data.get("output") or {}).get("columnHeight")
    default_h = _dim_to_m_u(default_h_raw, units, 0.0) if default_h_raw is not None else 0.0
    gf = data.get("groundFloor") if isinstance(data, dict) else None
    cols = gf.get("columns") if isinstance(gf, dict) else None
    if not cols or not isinstance(cols, dict):
        return {"count": 0, "total_volume": 0.0, "formwork_area": 0.0}
    count, total_v, fw_a = 0, 0.0, 0.0
    for col in cols.values():
        if not isinstance(col, dict):
            continue
        w = _dim_to_m_u(col.get("width"), units, 0.225)
        d = _dim_to_m_u(col.get("length"), units, 0.225)
        h_raw = col.get("height")
        h = _dim_to_m_u(h_raw, units, 0) if h_raw is not None else default_h
        if h <= 0:
            continue
        count += 1
        total_v += w * d * h
        fw_a += 2 * (w + d) * h
    return {"count": count, "total_volume": total_v, "formwork_area": fw_a}


def _extract_floor_area(doc):
    if not doc:
        return 0.0
    data = doc.get("data", doc)
    output = data.get("output") if isinstance(data, dict) else None
    raw = output.get("floorAreaReported") if isinstance(output, dict) else None
    return _area_to_m2(raw)


def _boq_foundation(wall_m, col_m, floor_area, mats, bs_doc=None):
    rows = []
    eff_l = wall_m["total_length"]
    if eff_l <= 0 and floor_area > 0:
        eff_l = math.sqrt(floor_area) * 4

    found_doc = None
    ftype = "rc_strip"
    if bs_doc:
        bs_data = bs_doc.get("data", bs_doc) or {}
        found_doc = bs_data.get("foundation") if isinstance(bs_data, dict) else None
        if found_doc and isinstance(found_doc, dict):
            ft = str(found_doc.get("type", "")).lower()
            if "rubble" in ft or "masonry" in ft:
                ftype = "rubble_masonry"

    if ftype == "rubble_masonry" and found_doc:
        rm = found_doc.get("rubbleMasonry", {}) or {}
        lc = found_doc.get("leanConcrete", {}) or {}
        cf = found_doc.get("columnFooting", {}) or {}

        fw_m = float(rm.get("footingWidth_m", 0.381))
        fd_m = float(rm.get("footingDepth_m", 0.914))
        rm_vol = eff_l * fw_m * fd_m * 1.05

        if rm_vol > 0.1:
            b_c, s_c = _mat_info(mats, "Cement (OPC)")
            rb_b, rb_s = _mat_info(mats, "Rubble Stone")
            rows.append(_boq_row("Cement (OPC) - Rubble Mortar", "bag",
                                float(max(1, round(rm_vol * 2.5))),
                                s_c or "50 kg", b_c or "INSEE"))
            rows.append(_boq_row("Rubble Stone", "m3",
                                round(rm_vol * 1.20, 2),
                                rb_s or "Hard granite", rb_b or "-"))
            rows.append(_boq_row("River Sand - Rubble Mortar", "m3",
                                round(rm_vol * 0.35, 2), "Coarse Grade", "-"))

        lc_w_m = float(lc.get("width_m", 0.457))
        lc_t_m = float(lc.get("thickness_m", 0.076))
        lc_vol = eff_l * lc_w_m * lc_t_m * 1.10
        if lc_vol > 0.05:
            b_c, s_c = _mat_info(mats, "Cement (OPC)")
            rows.append(_boq_row("Cement (OPC) - Lean Concrete (1:3:6)", "bag",
                                float(max(1, round(lc_vol * 4.5))),
                                s_c or "50 kg", b_c or "INSEE"))
            rows.append(_boq_row("River Sand - Lean Concrete", "m3",
                                round(lc_vol * 0.33, 2), "Coarse Grade", "-"))
            rows.append(_boq_row("Coarse Aggregate - Lean Concrete", "m3",
                                round(lc_vol * 0.66, 2), "40 mm", "-"))

        cf_sz_m = float(cf.get("size_m", 0.914))
        cf_dp_m = float(cf.get("depth_m", 0.305))
        n_cols = int(cf.get("count", col_m["count"])) or col_m["count"]
        cf_vol = n_cols * cf_sz_m * cf_sz_m * cf_dp_m * 1.10
        if cf_vol > 0.05:
            b_c, s_c = _mat_info(mats, "Cement (OPC)")
            rows.append(_boq_row("Cement (OPC) - Column Footing (Grade 25)", "bag",
                                float(max(1, round(cf_vol * 7.5))),
                                s_c or "50 kg", b_c or "INSEE"))
            rows.append(_boq_row("River Sand - Column Footing", "m3",
                                round(cf_vol * 0.44, 2), "Coarse Grade", "-"))
            rows.append(_boq_row("Coarse Aggregate - Column Footing", "m3",
                                round(cf_vol * 0.88, 2), "20 mm", "-"))
            cf_steel = n_cols * 4 * (2 * cf_sz_m + 0.30) * 0.888
            b12, s12 = _mat_info(mats, "Steel Rebar Y12")
            b6, s6 = _mat_info(mats, "Steel Rebar Y10")
            if cf_steel > 0.1:
                rows.append(_boq_row("Steel Rebar Y12 - Column Footing", "kg",
                                    round(cf_steel, 1), s12 or "12 m", b12 or "Taian"))
                rows.append(_boq_row("Steel Rebar Y10 - Links (R6)", "kg",
                                    round(cf_steel * 0.15, 1), s6 or "6 m", b6 or "Taian"))

    else:
        fc_vol = (eff_l * 0.60 * 0.25) + (col_m["count"] * 0.60 * 0.60 * 0.30)
        if fc_vol > 0.01:
            fc = fc_vol * 1.10
            b, s = _mat_info(mats, "Cement (OPC)")
            rows.append(_boq_row("Cement (OPC)", "bag", float(max(1, round(fc * 7.5))), s or "50 kg", b or "INSEE"))
            rows.append(_boq_row("River Sand", "m3", round(fc * 0.44, 2), "Coarse Grade", "-"))
            rows.append(_boq_row("Coarse Aggregate", "m3", round(fc * 0.88, 2), "20 mm", "-"))

        steel_kg = eff_l * 2 * 0.888 + col_m["count"] * 4 * 0.60 * 0.888
        if steel_kg > 0.1:
            b12, s12 = _mat_info(mats, "Steel Rebar Y12")
            b10, s10 = _mat_info(mats, "Steel Rebar Y10")
            bw_b, bw_s = _mat_info(mats, "Binding Wire")
            links_kg = steel_kg * 0.15
            rows.append(_boq_row("Steel Rebar Y12", "kg", round(steel_kg, 1), s12 or "12 m length", b12 or "Taian"))
            rows.append(_boq_row("Steel Rebar Y10", "kg", round(links_kg, 1), s10 or "12 m length", b10 or "Taian"))
            rows.append(_boq_row("Binding Wire", "kg", round((steel_kg + links_kg) * 0.01, 2), bw_s or "1 kg roll", bw_b or "-"))

    dpm_a = eff_l * 0.70
    if dpm_a > 0.5:
        rows.append(_boq_row("Polythene Sheet", "m2", round(dpm_a, 1), "250 um (1000 gauge)", "-"))
    return rows


def _boq_structural(col_m, mats):
    rows = []
    if col_m["total_volume"] <= 0.01:
        return rows
    cv = col_m["total_volume"] * 1.10
    b, s = _mat_info(mats, "Cement (OPC)")
    rows.append(_boq_row("Cement (OPC)", "bag", float(max(1, round(cv * 8.2))), s or "50 kg", b or "INSEE"))
    rows.append(_boq_row("River Sand", "m3", round(cv * 0.41, 2), "Coarse Grade", "-"))
    rows.append(_boq_row("Coarse Aggregate", "m3", round(cv * 0.82, 2), "20 mm", "-"))

    main_kg = round(col_m["total_volume"] * 100, 1)
    link_kg = round(col_m["total_volume"] * 20, 1)
    b16, s16 = _mat_info(mats, "Steel Rebar Y16")
    b10, s10 = _mat_info(mats, "Steel Rebar Y10")
    bw_b, bw_s = _mat_info(mats, "Binding Wire")
    if main_kg > 0.1:
        rows.append(_boq_row("Steel Rebar Y16", "kg", main_kg, s16 or "12 m length", b16 or "Taian"))
    if link_kg > 0.1:
        rows.append(_boq_row("Steel Rebar Y10", "kg", link_kg, s10 or "12 m length", b10 or "Taian"))
    total_steel = main_kg + link_kg
    if total_steel > 0.1:
        rows.append(_boq_row("Binding Wire", "kg", round(total_steel * 0.01, 2), bw_s or "1 kg roll", bw_b or "-"))

    fw = col_m["formwork_area"]
    if fw > 0.1:
        rows.append(_boq_row("Formwork Timber", "m2", round(fw, 1), "3/4\" Plywood (8x4 ft)", "-"))
        rows.append(_boq_row("Mild Steel Nails", "kg", round(fw * 0.15, 1), "3\" (75 mm)", "-"))
    return rows


def _boq_walling(wall_m, mats):
    rows = []
    if wall_m["total_area"] <= 0.01:
        return rows
    wa = wall_m["total_area"]
    wv = wall_m["total_volume"]
    wl = wall_m["total_length"]

    blocks = max(1, round(wa * 12.5 * 1.05))
    bk_b, bk_s = _mat_info(mats, "Hollow Concrete Blocks")
    rows.append(_boq_row("Hollow Concrete Blocks", "No.", float(blocks),
                         bk_s or "6\" (150x200x400 mm)", bk_b or "-"))

    m_vol = wv * 0.30
    if m_vol > 0.01:
        b_c, s_c = _mat_info(mats, "Cement (OPC)")
        rows.append(_boq_row("Cement (OPC) - Wall Mortar", "bag",
                             float(max(1, round(m_vol * 5))), s_c or "50 kg", b_c or "INSEE"))
        rows.append(_boq_row("River Sand - Wall Mortar", "m3",
                             round(m_vol * 1.0, 2), "Fine Grade", "-"))

    if wl > 0.5:
        dpc_b, dpc_s = _mat_info(mats, "DPC Sheet")
        rows.append(_boq_row("DPC Sheet", "m", round(wl, 1),
                             dpc_s or "300 mm wide", dpc_b or "Rhino"))

    p_area = wa * 2.0
    p_vol = p_area * 0.015
    b_c, s_c = _mat_info(mats, "Cement (OPC)")
    fs_b, fs_s = _mat_info(mats, "Fine Sand")
    rows.append(_boq_row("Cement (OPC) - Plaster", "bag",
                         float(max(1, round(p_vol * 5))), s_c or "50 kg", b_c or "INSEE"))
    rows.append(_boq_row("Fine Sand - Plaster", "m3",
                         round(p_vol, 2), fs_s or "Fine Grade", fs_b or "-"))

    wp_bags = max(1, round(p_area * 0.5 / 5))
    wp_b, wp_s = _mat_info(mats, "Wall Putty")
    rows.append(_boq_row("Wall Putty", "bag", float(wp_bags),
                         wp_s or "5 kg", wp_b or "Dulux"))
    return rows


def _boq_flooring(floor_area, mats):
    rows = []
    if floor_area <= 0.1:
        return rows
    t_b, t_s = _mat_info(mats, "Floor Tiles")
    rows.append(_boq_row("Floor Tiles", "m2", round(floor_area * 1.05, 1),
                         t_s or "60x60 cm", t_b or "Rocell"))
    adh_b, adh_s = _mat_info(mats, "Tile Adhesive")
    rows.append(_boq_row("Tile Adhesive", "bag",
                         float(max(1, math.ceil(floor_area / 5))),
                         adh_s or "20 kg bag", adh_b or "Lanwa"))
    tg_b, tg_s = _mat_info(mats, "Tile Grout")
    rows.append(_boq_row("Tile Grout", "kg", round(floor_area * 0.3, 1),
                         tg_s or "5 kg", tg_b or "Lanwa"))
    return rows


@boq_bp.route("/boq/<pid>", methods=["GET"])
def get_boq(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    bs_doc = buildingstructure_col.find_one({"projectId": pid})
    sf_doc = structuralframe_col.find_one({"projectId": pid})
    wa_doc = walling_col.find_one({"projectId": pid})

    mat_docs = list(
        materials_col.find(
            {},
            {"_id": 0, "name": 1, "name_lower": 1, "brands": 1, "sizes": 1, "unitPrice": 1},
        )
    )
    mats = {d.get("name_lower", d.get("name", "").lower()): d for d in mat_docs}
    mat_prices = {
        d.get("name_lower", d.get("name", "").lower()): float(d.get("unitPrice") or 0)
        for d in mat_docs
    }

    wall_m = _extract_walling_m(wa_doc)
    col_m = _extract_column_m(sf_doc)
    fa = _extract_floor_area(bs_doc)

    has_data = (wall_m["total_area"] > 0 or col_m["total_volume"] > 0 or fa > 0)
    if not has_data:
        return jsonify({
            "sections": [],
            "hasData": False,
            "message": "No extracted measurement data found for this project. Please extract plan measurements first.",
        }), 200

    sections = []
    f_rows = _boq_foundation(wall_m, col_m, fa, mats, bs_doc=bs_doc)
    if f_rows:
        sections.append({"section": "Foundation", "rows": f_rows})

    s_rows = _boq_structural(col_m, mats)
    if s_rows:
        sections.append({"section": "Structural Frame", "rows": s_rows})

    w_rows = _boq_walling(wall_m, mats)
    if w_rows:
        sections.append({"section": "Walling", "rows": w_rows})

    fl_rows = _boq_flooring(fa, mats)
    if fl_rows:
        sections.append({"section": "Flooring", "rows": fl_rows})

    grand_total = 0.0
    for sec in sections:
        sec_total = 0.0
        for row in sec["rows"]:
            base_name = row["materialName"].split("-")[0].strip()
            up = mat_prices.get(base_name.lower(), 0.0)
            cost = round((row.get("quantity") or 0) * up, 2)
            row["unitPrice"] = up
            row["totalMaterialCost"] = cost
            sec_total += cost
        sec["sectionTotal"] = round(sec_total, 2)
        grand_total += sec_total
    grand_total = round(grand_total, 2)

    metrics = {
        "wallCount": wall_m["count"],
        "totalWallLength": round(wall_m["total_length"], 2),
        "totalWallArea": round(wall_m["total_area"], 2),
        "columnCount": col_m["count"],
        "totalColVolume": round(col_m["total_volume"], 2),
        "floorArea": round(fa, 2),
    }

    now = datetime.datetime.utcnow().isoformat()
    boqReport_col.update_one(
        {"projectId": pid},
        {
            "$set": {
                "projectId": pid,
                "sections": sections,
                "grandTotal": grand_total,
                "metrics": metrics,
                "hasData": True,
                "updatedAt": now,
            },
            "$setOnInsert": {"createdAt": now},
        },
        upsert=True,
    )

    return jsonify({
        "sections": sections,
        "hasData": True,
        "grandTotal": grand_total,
        "metrics": metrics,
    }), 200
