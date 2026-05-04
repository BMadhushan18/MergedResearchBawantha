"""pixelCordinatesExtractingPrompts.py

Prompt set for extracting building part pixel coordinates from provided plan images.
"""

groudFloorpixelCordinatesExtractingPrompts = r'''
ROLE
You are an expert CAD analysis and image processing specialist.
Your job: for a given set of building plan images AND a previously generated measurement JSON, return pixel coordinates ONLY for GROUND FLOOR COLUMNS using the SAME column IDs.

CRITICAL CONTEXT (FOREIGN KEY)
- You will be given `measurement_json` from the previous step (measurement extraction).
- Treat every ground-floor column key in that JSON as a foreign key.
- Output must ONLY contain `part_id` + `coordinates` so it can be stored in MongoDB as (part_id, coordinates).
- Do NOT invent new IDs. Do NOT rename IDs.

COORDINATE SYSTEM (IMPORTANT)
- Use image pixel coordinates with the TOP-LEFT corner as (0,0).
- X increases to the right; Y increases downward.
- All coordinate values must be integers.

INPUT
- One or more image file references in {image_list}
- Images may include: floor plans, sections, elevations, schedules.

PREVIOUS STEP OUTPUT (MUST USE)
measurement_json:
{measurement_json}

REQUIREMENTS
1) Determine the list of columns to locate ONLY from `measurement_json["ground_floor"]["columns"]`.
   - Use the object keys as the `part_id` (e.g., "column1", "column2", ...).
   - Ignore walls, doors, windows, roof, and any non-ground-floor content.

2) Locate each ground-floor column on the ground-floor floor plan image.
   - Use visual signature: solid black/shaded square/rectangle symbols.
   - If multiple images exist, choose the one that clearly contains the ground-floor plan.

3) For each column, return a bounding box in pixels:
   - `bbox` = [x1, y1, x2, y2]
   - (x1,y1) = top-left of the column symbol; (x2,y2) = bottom-right
   - Ensure x1 < x2 and y1 < y2

OUTPUT FORMAT (STRICT: JSON only)
Return VALID JSON ONLY. Do not include any keys other than `parts`.

{{
  "parts": [
    {{"part_id": "column1", "coordinates": {{"image": "image1.png", "bbox": [x1, y1, x2, y2]}}}},
    {{"part_id": "column2", "coordinates": {{"image": "image1.png", "bbox": [x1, y1, x2, y2]}}}}
  ]
}}

GUIDANCE
- Include EVERY ground-floor column key from the measurement JSON exactly once.
- If a column cannot be found, set "coordinates" to null.
- Avoid any text outside the JSON.

IMAGES
{image_list}
'''