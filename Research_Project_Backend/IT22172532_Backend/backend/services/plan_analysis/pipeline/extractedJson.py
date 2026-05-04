"""Pre-created extracted measurement records for demo/offline analysis."""

from copy import deepcopy


MODEL_NAME = "gemini-2.0-flash-demo-hardcoded"


PROMPT_1_DATA = {
    "ground_floor_index": 0,
    "confidence": 0.97,
    "reason": "Ground floor plan identified from the uploaded construction drawing set; measurements are from the supplied plans, sections, and door/window schedule.",
    "per_image": [
        {"index": 0, "type": "floor_plan", "confidence": 0.97},
        {"index": 1, "type": "floor_plan", "confidence": 0.92},
        {"index": 2, "type": "section", "confidence": 0.95},
        {"index": 3, "type": "section", "confidence": 0.95},
        {"index": 4, "type": "roof_plan", "confidence": 0.9},
        {"index": 5, "type": "schedule_table", "confidence": 0.98},
    ],
    "walling": {
        "scaleText": '1/8" = 1\'-0"',
        "defaultWallHeight": "10'-0\"",
        "floorAreaReported": "1735.87 sq.ft.",
        "groundFloor": {
            "floorArea": {"value": 1735.87, "unit": "sq.ft", "source": "plan title"},
            "rooms": {
                "A": {"name": "Living & Dining", "source": "ground floor label"},
                "B": {"name": "Bedroom", "width": "13'-0\"", "depth": "11'-3\"", "source": "ground floor annotation"},
                "C": {"name": "Bedroom", "width": "17'-0\"", "depth": "14'-1\"", "source": "ground floor annotation"},
                "D": {"name": "Kitchen & Pantry", "width": "14'-0\"", "depth": "13'-6\"", "source": "ground floor annotation"},
                "GF_TOILET_1": {"name": "Toilet", "width": "6'-0\"", "depth": "5'-6\"", "source": "ground floor annotation"},
                "GF_TOILET_2": {"name": "Toilet", "width": "9'-6\"", "depth": "4'-10\"", "source": "ground floor annotation"},
                "LAUNDRY": {"name": "Laundry", "width": "7'-2\"", "depth": "4'-2\"", "source": "ground floor annotation"},
                "OPEN_TO_SKY": {"name": "Open to Sky", "width": "9'-0\"", "source": "ground floor annotation"},
                "COMPOST_BIN": {"name": "Compost Bin", "width": "16'-0\"", "source": "ground floor annotation"},
            },
            "walls": {
                "GF_NORTH_01": {"location": "north exterior, living/kitchen side", "length": "14'-0\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.9},
                "GF_NORTH_02": {"location": "north exterior, open-to-sky bay", "length": "9'-0\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.9},
                "GF_NORTH_03": {"location": "north exterior, bedroom C", "length": "17'-0\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.9},
                "GF_NORTH_04": {"location": "north exterior, bedroom B", "length": "13'-0\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.9},
                "GF_SOUTH_01": {"location": "south exterior, living frontage", "length": "25'-0\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.92},
                "GF_SOUTH_02": {"location": "south exterior, toilet bay", "length": "6'-0\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.88},
                "GF_SOUTH_03": {"location": "south exterior, laundry bay", "length": "7'-2\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.88},
                "GF_EAST_01": {"location": "east exterior near bedroom B/passage", "length": "13'-11\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.86},
                "GF_WEST_01": {"location": "west exterior living side", "length": "29'-6\"", "thickness": "9 inch", "material": "brick masonry", "type": "exterior", "source": "annotation", "confidence": 0.86},
                "GF_PARTITION_01": {"location": "kitchen to passage partition", "length": "3'-11\"", "thickness": "4.5 inch", "material": "brick partition", "type": "interior", "source": "annotation", "confidence": 0.82},
                "GF_PARTITION_02": {"location": "passage at laundry/toilet", "length": "3'-6\"", "thickness": "4.5 inch", "material": "brick partition", "type": "interior", "source": "annotation", "confidence": 0.82},
                "GF_PARTITION_03": {"location": "toilet divider", "length": "2'-8\"", "thickness": "4.5 inch", "material": "brick partition", "type": "interior", "source": "annotation", "confidence": 0.78},
            },
        },
        "upperFloor": {
            "floorArea": {"value": 1735.87, "unit": "sq.ft", "source": "upper floor title"},
            "rooms": {
                "F": {"name": "Master Bedroom", "width": "16'-1 1/2\"", "depth": "21'-8\"", "source": "upper floor annotation"},
                "G": {"name": "Bedroom", "width": "14'-0\"", "depth": "15'-10\"", "source": "upper floor annotation"},
                "H": {"name": "Bedroom", "width": "17'-0\"", "depth": "11'-3\"", "source": "upper floor annotation"},
                "I": {"name": "Pantry", "depth": "15'-9\"", "source": "upper floor annotation"},
                "E": {"name": "Lobby", "width": "8'-6\"", "source": "upper floor annotation"},
            },
            "walls": {
                "UF_NORTH_01": {"location": "upper north exterior left", "length": "14'-1\"", "height": "7'-0\"", "thickness": "9 inch", "type": "exterior", "source": "annotation", "confidence": 0.86},
                "UF_NORTH_02": {"location": "upper north exterior mid-left", "length": "10'-10 1/2\"", "thickness": "9 inch", "type": "exterior", "source": "annotation", "confidence": 0.84},
                "UF_NORTH_03": {"location": "upper north exterior bedroom G", "length": "14'-0\"", "thickness": "9 inch", "type": "exterior", "source": "annotation", "confidence": 0.86},
                "UF_NORTH_04": {"location": "upper north exterior open-to-sky", "length": "9'-0\"", "thickness": "9 inch", "type": "exterior", "source": "annotation", "confidence": 0.86},
                "UF_NORTH_05": {"location": "upper north exterior bedroom H", "length": "17'-0\"", "thickness": "9 inch", "type": "exterior", "source": "annotation", "confidence": 0.86},
                "UF_NORTH_06": {"location": "upper north exterior pantry", "length": "13'-0\"", "height": "7'-0\"", "thickness": "9 inch", "type": "exterior", "source": "annotation", "confidence": 0.82},
            },
        },
        "doors": {
            "D1": {"width": "4'-6\"", "height": "9'-0\"", "material": "Timber Paneled Door", "location": "Ground floor main entrance to Living & Dining", "source": "schedule", "confidence": 0.98},
            "D2": {"width": "3'-0\"", "height": "9'-0\"", "material": "Timber Paneled Door", "location": "Ground/upper external side doors", "source": "schedule", "confidence": 0.98},
            "D3": {"width": "2'-9\"", "height": "7'-6\"", "material": "Aluminium Door", "location": "Bedroom and internal room doors", "source": "schedule", "confidence": 0.98},
            "D4": {"width": "2'-6\"", "height": "6'-6\"", "material": "Aluminium Door", "location": "Toilet doors", "source": "schedule", "confidence": 0.98},
        },
        "windows": {
            "FW": {"width": "13'-6\"", "height": "9'-0\"", "material": "Timber Glazed French Window", "location": "French window openings", "source": "schedule", "confidence": 0.98},
            "FW1": {"width": "12'-0\"", "height": "9'-0\"", "material": "Timber Glazed French Window", "location": "Ground/upper frontage openings", "source": "schedule", "confidence": 0.98},
            "FW2": {"width": "9'-6\"", "height": "9'-0\"", "material": "Timber Glazed Door & Window", "location": "Balcony/opening set", "source": "schedule", "confidence": 0.98},
            "FW3": {"width": "10'-0\"", "height": "9'-0\"", "material": "Timber Glazed Door & Window", "location": "Living side opening", "source": "schedule", "confidence": 0.98},
            "FW4": {"width": "6'-0\"", "height": "9'-0\"", "material": "Timber Glazed Door & Window", "location": "Passage/frontage opening", "source": "schedule", "confidence": 0.98},
            "W5": {"width": "7'-0\"", "height": "6'-0\"", "material": "Timber Glazed Window", "location": "Open-to-sky / kitchen window", "source": "schedule", "confidence": 0.98},
            "W6": {"width": "6'-3\"", "height": "6'-0\"", "material": "Timber Glazed Window", "location": "Upper open-to-sky window", "source": "schedule", "confidence": 0.98},
            "W7": {"width": "3'-0\"", "height": "9'-0\"", "material": "Timber Glazed Window", "location": "Lower balcony/window opening", "source": "schedule", "confidence": 0.98},
            "W8": {"width": "6'-0\"", "height": "9'-0\"", "material": "Timber Glazed Window", "location": "Upper passage/frontage windows", "source": "schedule", "confidence": 0.98},
            "FL": {"width": "1'-6\"", "height": "4'-0\"", "material": "Timber Glazed Fanlight", "location": "Toilet/laundry fanlights", "source": "schedule", "confidence": 0.98},
        },
        "extractionWarnings": [
            "Some wall lengths are taken from readable annotations only; unlabelled irregular boundary lengths are not invented.",
            "Door and window dimensions are schedule-based and apply wherever the matching code appears on plan.",
        ],
    },
    "structuralFrame": {
        "groundFloor": {
            "floorAreaReported": "1735.87 sq.ft.",
            "columnHeight": "10'-0\" typical above slab; 11'-0\" lower level shown in sections",
            "slab": {
                "groundFloor": {"thickness": "5 inch", "material": "R.C.C. slab", "source": "sections X-X/Y-Y"},
                "upperFloor": {"thickness": "5 inch", "material": "R.C.C. slab", "source": "sections X-X/Y-Y"},
                "roofOrTerrace": {"thickness": "5 inch", "material": "R.C.C. slab", "source": "sections X-X/Y-Y"},
            },
            "columns": {
                "C1": {"width": 0.225, "length": 0.225, "height": 3.35, "size": "9x9 inch", "material": "RCC", "location": "living/dining left bay", "source": "visible structural mark", "confidence": 0.72},
                "C2": {"width": 0.225, "length": 0.225, "height": 3.35, "size": "9x9 inch", "material": "RCC", "location": "kitchen/living junction", "source": "visible structural mark", "confidence": 0.72},
                "C3": {"width": 0.225, "length": 0.225, "height": 3.05, "size": "9x9 inch", "material": "RCC", "location": "open-to-sky/toilet bay", "source": "visible structural mark", "confidence": 0.7},
                "C4": {"width": 0.225, "length": 0.225, "height": 3.05, "size": "9x9 inch", "material": "RCC", "location": "bedroom C/B divider", "source": "visible structural mark", "confidence": 0.7},
                "C5": {"width": 0.225, "length": 0.225, "height": 3.05, "size": "9x9 inch", "material": "RCC", "location": "east end passage/bedroom B", "source": "visible structural mark", "confidence": 0.7},
            },
            "beams": {
                "B1": {"span": "14'-0\"", "location": "north bay living/kitchen", "material": "RCC", "source": "plan grid annotation"},
                "B2": {"span": "9'-0\"", "location": "open-to-sky bay", "material": "RCC", "source": "plan grid annotation"},
                "B3": {"span": "17'-0\"", "location": "bedroom C bay", "material": "RCC", "source": "plan grid annotation"},
                "B4": {"span": "13'-0\"", "location": "bedroom B bay", "material": "RCC", "source": "plan grid annotation"},
            },
        },
        "totalColumns": 5,
        "notes": [
            "Column count is based on visible solid structural marks in the ground floor plan.",
            "Sections show 5 inch R.C.C. slabs and typical 10 ft wall/room height.",
        ],
    },
    "finishing": {
        "roof": [
            {"description": "Asbestos sheet roof", "material": "Asbestos sheet", "specification": "Sloped roof covering from sections", "source": "section labels", "confidence": 0.95},
            {"description": "Ridge tile", "material": "Ridge tile", "specification": "Roof ridge finish", "source": "section labels", "confidence": 0.95},
            {"description": "2x2 inch reepers", "material": "Timber", "specification": "Roof support members", "source": "section labels", "confidence": 0.95},
            {"description": "4x2 inch rafters", "material": "Timber", "specification": "Roof rafters", "source": "section labels", "confidence": 0.95},
            {"description": "4x3 inch wall plate", "material": "Timber", "specification": "Wall plate", "source": "section labels", "confidence": 0.95},
            {"description": "6x2 inch ridge plate", "material": "Timber", "specification": "Ridge plate", "source": "section labels", "confidence": 0.95},
        ],
        "flooring": [
            {"description": "3 inch thick concrete paving", "thickness": "3 inch", "material": "Concrete", "specification": "Ground floor paving over dry earth filling", "source": "section labels", "confidence": 0.96},
            {"description": "Dry earth filling", "material": "Earth fill", "specification": "Below ground floor paving", "source": "section labels", "confidence": 0.96},
        ],
        "slabs": [
            {"description": "5 inch thick R.C.C. slab", "thickness": "5 inch", "material": "Reinforced cement concrete", "specification": "Floor/roof slab shown in sections", "source": "section labels", "confidence": 0.96},
        ],
        "walls": [
            {"description": "7'-0\" high wall", "height": "7'-0\"", "material": "Masonry", "specification": "Low parapet/terrace walls shown in upper/roof plans", "source": "plan labels", "confidence": 0.88},
        ],
    },
    "notes": [
        "Pre-created extraction record generated from the supplied plan set.",
        "Dimensions retain original imperial format where shown on drawings.",
    ],
}


PIXEL_COORDINATES_DATA = {
    "ground_floor_index": 0,
    "items": {
        "columns": [
            {"id": "C1", "x": 190, "y": 455},
            {"id": "C2", "x": 410, "y": 432},
            {"id": "C3", "x": 565, "y": 468},
            {"id": "C4", "x": 735, "y": 455},
            {"id": "C5", "x": 890, "y": 500},
        ],
        "walls": [
            {"id": "GF_NORTH_01", "x1": 250, "y1": 250, "x2": 420, "y2": 300},
            {"id": "GF_NORTH_02", "x1": 420, "y1": 300, "x2": 520, "y2": 310},
            {"id": "GF_NORTH_03", "x1": 520, "y1": 310, "x2": 735, "y2": 350},
            {"id": "GF_NORTH_04", "x1": 735, "y1": 350, "x2": 890, "y2": 390},
            {"id": "GF_SOUTH_01", "x1": 55, "y1": 660, "x2": 390, "y2": 635},
            {"id": "GF_SOUTH_02", "x1": 390, "y1": 635, "x2": 470, "y2": 635},
            {"id": "GF_SOUTH_03", "x1": 470, "y1": 635, "x2": 590, "y2": 640},
            {"id": "GF_EAST_01", "x1": 900, "y1": 390, "x2": 900, "y2": 635},
            {"id": "GF_WEST_01", "x1": 60, "y1": 260, "x2": 60, "y2": 635},
        ],
        "doors": [
            {"id": "D1", "x1": 60, "y1": 390, "x2": 115, "y2": 390},
            {"id": "D2", "x1": 890, "y1": 560, "x2": 920, "y2": 600},
            {"id": "D3_A", "x1": 735, "y1": 535, "x2": 760, "y2": 565},
            {"id": "D3_B", "x1": 795, "y1": 535, "x2": 820, "y2": 565},
            {"id": "D4_A", "x1": 325, "y1": 540, "x2": 350, "y2": 570},
            {"id": "D4_B", "x1": 620, "y1": 505, "x2": 650, "y2": 535},
        ],
        "windows": [
            {"id": "FW", "x1": 670, "y1": 660, "x2": 735, "y2": 660},
            {"id": "FW1", "x1": 55, "y1": 635, "x2": 120, "y2": 635},
            {"id": "FW3", "x1": 58, "y1": 500, "x2": 58, "y2": 575},
            {"id": "FW4", "x1": 735, "y1": 645, "x2": 800, "y2": 645},
            {"id": "W5_A", "x1": 490, "y1": 365, "x2": 490, "y2": 445},
            {"id": "W5_B", "x1": 565, "y1": 365, "x2": 565, "y2": 445},
            {"id": "W7", "x1": 330, "y1": 635, "x2": 390, "y2": 635},
            {"id": "FL_A", "x1": 435, "y1": 635, "x2": 460, "y2": 635},
            {"id": "FL_B", "x1": 555, "y1": 510, "x2": 585, "y2": 510},
        ],
    },
    "notes": [
        "Pixel coordinates are approximate normalized positions for the supplied ground floor plan image.",
    ],
}


def prompt_1_data():
    return deepcopy(PROMPT_1_DATA)


def pixel_coordinates_data():
    return deepcopy(PIXEL_COORDINATES_DATA)
