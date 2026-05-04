P1_VERSION = "p1_v2"
P2_VERSION = "p2_v2"
GF_VERSION = "gf_pick_v1"
COMBINED_V1_VERSION = "combined_v1"
PIXEL_COORD_V1_VERSION = "pixel_coord_v1"


PROMPT_1 = """You are extracting structured data from a single architectural sub-drawing (a crop from a full sheet).\n\nReturn ONLY valid JSON (no markdown, no commentary).\n\nCoordinate system (for this prompt only):\n- Use a normalized 0..1000 grid for rough bounding boxes.\n- rough_bbox = [x1,y1,x2,y2] with 0 <= x1 < x2 <= 1000, 0 <= y1 < y2 <= 1000.\n\nSubplan type must be one of:\n  floor_plan | roof_plan | section | elevation | site_plan | schedule_table | title_block | unknown\n\nFor each detected item return (required fields):\n- item_id: unique stable string within this response (e.g. \"it_1\", \"it_2\")\n- item_type: wall | door | window | column | room | stair | dimension_text | dimension_line | note | code_text | other\n- subtype: free text or null\n- label_text: free text or null\n- code_text: like D1/W8/FL if visible, else null\n- measurement_texts: list of raw strings exactly as seen (e.g. [\"14'-0\\\"\", \"230mm\"])\n- rough_bbox: [x1,y1,x2,y2]\n- confidence: 0..1\n\nIf this crop is a schedule table, return:\n- schedule_kind: door_window_schedule | other\n- rows: list of { code, size_text, width_text, height_text, description, confidence }\n\nOutput JSON shape (required):\n{\n  \"subplan_type\": \"floor_plan\",\n  \"title_text\": null,\n  \"items\": [],\n  \"schedule\": null,\n  \"notes\": []\n}\n"""


PROMPT_2_PREFIX = """You are given JSON extracted from a single architectural crop (prompt-1 output).\n\nReturn ONLY valid JSON.\n\nTask (prompt-2):\nFor each item in the given input, produce refined geometry + measurement estimates.\nThis is used to convert to pixel coordinates on the server (so output MUST stay in 0..1000 normalized coordinates).\n\nRules:\n- Do not invent new objects. Use the same item_id values.\n- If you cannot determine geometry/measurements for an item, still include it with null fields and low confidence.\n\nFor each item return:\n- item_id: same as input\n- item_type: copy from input\n- bbox_norm: [x1,y1,x2,y2] in 0..1000 (refined if possible, else copy rough_bbox)\n- geometry_kind: point | segment | bbox | poly | unknown\n- geometry_norm: list of [x,y] points in 0..1000 (e.g. for column use 1 point center; for wall use 2 points endpoints).\n- measurements: object with optional numeric estimates (use millimeters when possible):\n  {\"width_mm\": number|null, \"height_mm\": number|null, \"length_mm\": number|null, \"area_mm2\": number|null, \"confidence\": 0..1}\n- confidence: 0..1\n\nOutput JSON shape (required):\n{\n  \"items\": []\n}\n\nHere is the prompt-1 JSON input:\n"""


GROUND_FLOOR_PICK_PROMPT = """You are given multiple uploaded images of construction drawings (each image is a whole sheet photo/scan).

Task:
- Decide which image shows the GROUND FLOOR PLAN (the plan view of the ground floor).
- Do NOT pick roof plan, elevations, sections, site plan, schedules/tables, or title blocks.

Return ONLY valid JSON (no markdown, no commentary).

You will receive N images in order: image_0, image_1, ..., image_(N-1).

Output JSON shape (required):
{
	"ground_floor_index": 0,
	"confidence": 0.0,
	"reason": "short explanation",
	"per_image": [
		{"index": 0, "type": "floor_plan|roof_plan|section|elevation|site_plan|schedule_table|title_block|unknown", "confidence": 0.0}
	]
}

Rules:
- ground_floor_index MUST be an integer from 0..N-1.
- confidence MUST be 0..1.
- reason MUST be short.
- per_image MUST contain exactly N entries.
"""


COMBINED_GROUND_FLOOR_AND_MEASUREMENTS_PROMPT = """You are given multiple uploaded construction plan images.

TASK - Extract measurements from THREE sources in order of priority:

SOURCE 1 (HIGHEST PRIORITY): Schedule tables on the sheet
  - Door schedule table (look for columns: Mark/Code, Type, Size/Dimensions, Description, Material)
  - Window schedule table (look for columns: Mark/Code, Type, Size/Dimensions, Description, Material)
  - Finish/Material schedule table

SOURCE 2 (MEDIUM PRIORITY): Annotations/dimensions on floor plan
  - Read dimension callouts next to doors/windows (e.g., "4'-6\"" or "400mm")
  - Read door/window codes labeled on plan (D1, D2, W1, W2, etc.)

SOURCE 3 (LOWEST PRIORITY): Visual estimation from symbols
  - If dimension not visible, estimate from symbol size compared to reference elements

GROUND FLOOR IDENTIFICATION:
- Identify which image is the ground floor plan (look for "GROUND FLOOR PLAN" label)
- Ground floor will show door/window plan view symbols and room labels
- Ignore: elevations, sections, roof plans, site plans, schedules-only sheets

Output JSON structure (REQUIRED):
{
  "ground_floor_index": 0,
  "confidence": 0.95,
  "reason": "brief explanation",
  "per_image": [
    {"index": 0, "type": "floor_plan|roof_plan|section|elevation|site_plan|schedule_table|title_block|unknown", "confidence": 0.95}
  ],
  "doors": {
    "D1": {
      "width": "4'-6\"",
      "height": "9'-0\"",
      "material": "Timber Paneled Door",
      "location": "Left exterior wall, opening to Living area",
      "source": "schedule|annotation|visual",
      "confidence": 0.95
    },
    "D2": {"width": "3'-0\"", "height": "9'-0\"", "material": "Timber Paneled Door", "location": "Right exterior wall", "source": "schedule", "confidence": 0.95},
    "D3": {"width": "2'-9\"", "height": "7'-6\"", "material": "Aluminium Door", "location": "Interior passage", "source": "schedule", "confidence": 0.95}
  },
  "windows": {
    "FW": {"width": "13'-6\"", "height": "9'-0\"", "material": "Timber Glazed French Window", "location": "Left wall, Living area", "source": "schedule", "confidence": 0.95},
    "W1": {"width": "7'-0\"", "height": "6'-0\"", "material": "Timber Glazed Window", "location": "Kitchen area", "source": "schedule", "confidence": 0.95}
  },
  "walls": {
    "WALL_1": {"location": "north exterior", "length": "50'-0\"", "thickness": "12 inch", "material": "Double Brick", "type": "exterior"}
  },
  "columns": {
    "C1": {"size": "300x300mm", "material": "RCC", "location": "grid-reference or room", "notes": ""}
  },
  "finishing": [
    {"description": "ASBESTOS SHEET ROOF", "thickness": "...", "material": "Asbestos", "specification": "..."},
    {"description": "5 inch RCC SLAB", "thickness": "5 inch", "material": "Reinforced Concrete", "specification": "..."},
    {"description": "CONCRETE PAVING", "thickness": "3 inch", "material": "Concrete", "specification": "..."}
  ],
  "notes": ["Data extracted primarily from schedule tables", "Cross-referenced with floor plan annotations"]
}

CRITICAL RULES:
1. ALWAYS check for schedule tables first - they are the most reliable source
2. Extract EVERY door and window shown in schedules, even if not visible on plan
3. Include location (which wall/room) for every door and window
4. Keep dimensions in original format (e.g., "4'-6\"" not "4.5")
5. If dimension appears in both schedule AND plan annotation, confirm they match
6. Do NOT invent data - if unclear, mark as "UNCLEAR" or "NOT_FOUND"
7. Include source field for traceability (schedule|annotation|visual)
8. Return ONLY JSON. No markdown, no explanations.
"""


PIXEL_COORDINATES_EXTRACTION_PROMPT = """You are given construction plan images and one image is identified as the ground floor.

Task:
- Extract pixel coordinates for visible columns, doors, windows, and walls on the ground floor image.
- Return strict JSON only.

Output JSON schema (required):
{
	"ground_floor_index": 0,
	"items": {
		"columns": [{"id": "C1", "x": 100, "y": 200}],
		"walls": [{"id": "W1", "x1": 10, "y1": 20, "x2": 300, "y2": 20}],
		"doors": [{"id": "D1", "x1": 50, "y1": 80, "x2": 90, "y2": 80}],
		"windows": [{"id": "WIN1", "x1": 120, "y1": 220, "x2": 170, "y2": 220}]
	},
	"notes": []
}

Rules:
- Use integer pixel coordinates.
- Keep object IDs stable where possible.
- Return empty arrays when a category is not detected.
- Return ONLY JSON. No markdown.
"""
