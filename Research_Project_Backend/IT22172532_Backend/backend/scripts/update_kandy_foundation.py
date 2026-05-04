"""
Update kandy super center buildingstructure with complete rubble masonry
foundation measurements extracted from the plan images.

Foundation details from drawings:
  Column footing : 3'-0" × 3'-0", 4 Nos. Y12 + R6 @7"ctrs + Y10 @7" both ways
  Wall foundation: 1:6 Cement Masonry Rubble, 9" wall, 1'-3" wide footing
  Lean concrete  : 1:3:6 (1"), 3" thick, ~1'-6" wide
  DPC at ground level
"""
import os
import sys
from datetime import datetime

from pymongo import MongoClient

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from config.settings import DB_NAME, MONGO_URI

client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=15000)
db = client[DB_NAME]

PID = "0c962b2f-b9f0-4132-a44e-e44e569b35a8"   # kandy super center

# ── Foundation data (all values in both ft and metres for BOQ engine) ──────────
foundation = {
    "type": "Rubble Masonry + RC Column Footings",

    # 1:6 Cement Masonry Rubble wall foundation
    "rubbleMasonry": {
        "mix": "1:6 Cement Masonry Rubble",
        "wallWidth_ft": 0.75,           "wallWidth_m": 0.229,   # 9"
        "footingWidth_ft": 1.25,        "footingWidth_m": 0.381,# 1'-3"
        "footingDepth_ft": 3.0,         "footingDepth_m": 0.914,# 3'-0"
        "dpc": "D.P.C. at ground level",
    },

    # 1:3:6 Lean Concrete base under rubble
    "leanConcrete": {
        "mix": "1:3:6 (1\")",
        "thickness_ft": 0.25,           "thickness_m": 0.076,   # 3"
        "width_ft": 1.5,                "width_m": 0.457,       # 1'-6"
    },

    # RC column pad footings
    "columnFooting": {
        "size_ft": 3.0,                 "size_m": 0.914,        # 3'-0" × 3'-0"
        "depth_ft": 1.0,                "depth_m": 0.305,       # 1'-0" depth
        "reinforcement": "4 Nos. Y12 main + R6 links @7\" ctrs + Y10 @7\" Crs both ways",
        "massConcreteBase": True,
        "count": 14,
    },

    "extractionSource": "Column footing detail + wall foundation section drawings",
}

# Also add floorAreaReported (needed by _extract_floor_area for BOQ flooring)
result = db["buildingstructure"].update_one(
    {"projectId": PID},
    {"$set": {
        "data.foundation": foundation,
        "data.output.floorAreaReported": "1738.87 sq ft",
        "savedAt": datetime.utcnow().isoformat(),
    }}
)
print(f"buildingstructure updated: matched={result.matched_count}, modified={result.modified_count}")

# Verify
doc = db["buildingstructure"].find_one({"projectId": PID})
if doc:
    d = doc.get("data", {})
    fd = d.get("foundation", {})
    print("\n=== FOUNDATION STORED ===")
    print(json.dumps(fd, indent=2, default=str))
    print("\nfloorAreaReported:", d.get("output", {}).get("floorAreaReported"))

# ── Quick BOQ preview using same logic as backend ─────────────────────────────
import math

w_doc = db["walling"].find_one({"projectId": PID})
sf_doc = db["structuralframe"].find_one({"projectId": PID})

def ft_to_m(v): return float(v) * 0.3048
def compute():
    walls = w_doc["data"]["groundFloor"]["walls"]
    dh = w_doc["data"]["output"]["defaultWallHeight"]  # 10.0 ft
    eff_l = sum(w["length"] * 0.3048 for w in walls.values())
    n_cols = sf_doc["data"]["output"]["totalColumns"]

    # Rubble masonry volume: length × footing_width × footing_depth (all metres)
    fw_m = foundation["rubbleMasonry"]["footingWidth_m"]    # 0.381
    fd_m = foundation["rubbleMasonry"]["footingDepth_m"]    # 0.914
    rm_vol = eff_l * fw_m * fd_m * 1.05

    # Lean concrete
    lc_w = foundation["leanConcrete"]["width_m"]            # 0.457
    lc_t = foundation["leanConcrete"]["thickness_m"]        # 0.076
    lc_vol = eff_l * lc_w * lc_t * 1.10

    # Column footings (RC pad)
    cf_sz = foundation["columnFooting"]["size_m"]           # 0.914
    cf_dp = foundation["columnFooting"]["depth_m"]          # 0.305
    cf_vol = n_cols * cf_sz * cf_sz * cf_dp * 1.10

    print(f"\n--- Foundation BOQ Preview ---")
    print(f"Total wall length        : {eff_l:.2f} m")
    print(f"Rubble masonry volume    : {rm_vol:.2f} m³  (+5% waste)")
    print(f"  Cement (1:6 mortar)    : {math.ceil(rm_vol * 2.5)} bags")
    print(f"  Rubble stone           : {round(rm_vol * 1.20, 2)} m³")
    print(f"  River sand             : {round(rm_vol * 0.35, 2)} m³")
    print(f"Lean concrete volume     : {lc_vol:.3f} m³  (+10% waste)")
    print(f"  Cement (1:3:6)         : {math.ceil(lc_vol * 4.5)} bags")
    print(f"  River sand             : {round(lc_vol * 0.33, 2)} m³")
    print(f"  Coarse aggregate (40mm): {round(lc_vol * 0.66, 2)} m³")
    print(f"Column footing volume    : {cf_vol:.3f} m³  (14 pads, +10% waste)")
    print(f"  Cement Grade-25        : {math.ceil(cf_vol * 7.5)} bags")
    print(f"  River sand             : {round(cf_vol * 0.44, 2)} m³")
    print(f"  Coarse aggregate (20mm): {round(cf_vol * 0.88, 2)} m³")
    cf_steel = n_cols * 4 * (2 * cf_sz + 0.30) * 0.888
    print(f"  Steel Y12 (main bars)  : {round(cf_steel, 1)} kg")
    print(f"  Steel Y10/R6 (links)   : {round(cf_steel * 0.15, 1)} kg")
    polythene = eff_l * 0.70
    print(f"Polythene sheet (DPC)    : {round(polythene, 1)} m²")

compute()
