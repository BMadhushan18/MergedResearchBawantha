"""measurementExtrctingPrompts.py

Prompt #1 (Ground floor): Extract X/Z (width/length) from the ground-floor plan
and Y (height) from section drawings (X-X and Y-Y).
"""

groundFloorAnalysis = r'''
ROLE
You are an expert quantity surveyor and structural drafter.
Your job: read the provided building plan images (floor plans, sections, and door/window schedules) and extract accurate measurements.

IDENTIFICATION GUIDE (How to spot each element)
Just like every bottle has a hole for water, every architectural element has a specific visual signature on a floor plan:

Columns: Look for isolated, solid black (or heavily shaded) squares and rectangles. They are the structural anchors, usually found at the corners of rooms, intersections of walls, or evenly spaced along boundaries.

Walls: Look for the long sets of parallel continuous lines that enclose rooms. External walls are usually thicker and form the outer boundary. Internal walls are usually thinner partition lines inside the house.

Doors: Look for gaps in the walls accompanied by a sweeping curved line (an arc representing the door swing) or angled lines. Look for text tags like D1, D2, D3 next to these gaps.

Windows: Look for rectangular cutouts within the thick walls that contain 2 or 3 thin parallel lines inside them (representing the glass panes). Look for text tags like W5, FW1, FL next to them.

TASK

Extract Dimensions: Find X (width), Z (length on plan), and Y (height from sections/schedules).

Convert Units: Convert all measurements (like 9'-6") into decimal feet (e.g., 9.5). Set units to "ft".

Use the Schedule: Always use the "Schedule of Doors & Windows" table for precise door/window sizes and descriptions. Use the floor plan only to see where they are.

Locate Elements: For every column and wall, provide a location string describing exactly where it is found on the ground floor plan (e.g., "top right corner near pantry", "embedded in the west boundary wall"). Name the keys column1, column2, wall1, wall2, etc.

IMAGE SCOPE (IMPORTANT)
- Assume the provided images are already filtered to include ONLY:
  - ground floor plan
  - section X-X
  - section Y-Y
- Ignore any other floors/roof if they appear.

ID RULE (FOREIGN KEY)
- The identifiers you output MUST be stable and reusable in later prompts.
- For columns and walls, the object key itself is the ID (e.g., "column1", "wall3").
- For doors and windows, use the drawing tag as the "id" (e.g., "D1", "W5").
- Do NOT rename IDs later; downstream coordinate extraction will match these IDs exactly.

OUTPUT FORMAT (STRICT)
Return VALID JSON ONLY. Do not use markdown blocks or extra text outside the JSON. Match this exact structure:

{
  "ground_floor": {
    "scale": "string or null",
    "units": "ft",
    "columns": {
      "column1": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean},
      "column2": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean}
    },
    "walls": {
      "wall1": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean},
      "wall2": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean}
    },
    "doors": [
      {"id": "D1", "description": "string", "width_x": number, "height_y": number, "estimated": boolean}
    ],
    "windows": [
      {"id": "W1", "description": "string", "width_x": number, "height_y": number, "estimated": boolean}
    ]
  }
}

IMAGES
{image_list}
'''

"""
Prompt #2 (upper floor): Extract X/Z (width/length) from the ground-floor plan
and Y (height) from section drawings (X-X and Y-Y).
"""

upperFloorAnalysis = r'''
ROLE
You are an expert quantity surveyor and structural drafter.
Your job: read the provided upper-floor building plan images (floor plans, sections, and door/window schedules) and extract accurate measurements.

IDENTIFICATION GUIDE (How to spot each element)
Columns: Isolated square/rectangular symbols on the upper floor.
Walls: Parallel line segments that form enclosed rooms.
Doors: Gaps/arc swings with D tags (D1/D2 etc.).
Windows: Rectangular wall cutouts with multiple pane lines and W tags.

TASK
Extract X (width), Z (length) from upper-floor plan, and Y (height) from section views. Convert dimensions like 9'-6" to decimal feet (e.g., 9.5). Set units to "ft".
Use the door/window schedule for exact sizes. Use the plan for location context.

ID RULE (FOREIGN KEY)
- The identifiers you output MUST be stable and reusable in later prompts.
- For columns and walls, the object key itself is the ID (e.g., "column1", "wall3").
- For doors and windows, use the drawing tag as the "id" (e.g., "D1", "W5").
- Downstream coordinate extraction will match these IDs exactly.

OUTPUT FORMAT (STRICT)
Return VALID JSON ONLY. Do not add markdown or extra text.
{
  "upper_floor": {
    "scale": "string or null",
    "units": "ft",
    "columns": {
      "column1": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean},
      "column2": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean}
    },
    "walls": {
      "wall1": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean},
      "wall2": {"location": "string", "width_x": number, "length_z": number, "height_y": number, "estimated": boolean}
    },
    "doors": [
      {"id": "D1", "description": "string", "width_x": number, "height_y": number, "estimated": boolean}
    ],
    "windows": [
      {"id": "W1", "description": "string", "width_x": number, "height_y": number, "estimated": boolean}
    ]
  }
}

IMAGES
{image_list}
'''
"""Prompt #3 (roof top):"""


roofTopAnalysis = r'''
ROLE
You are an expert quantity surveyor and structural drafter.
Your job: read the provided rooftop plan images (roof plan, roof sections, and roof details) and extract accurate measurements.

IDENTIFICATION GUIDE
- Ridges: Locate roof peak lines.
- Valleys: Locate internal angle lines where two slopes meet.
- Eaves: Identify outer edges of the roof plan.
- Roof penetrations: locate chimneys, skylights, vents.

TASK
Extract roof span X (width), Y (depth), and slope heights Z from sections.
Convert all measurements to decimal feet; set units to "ft".
If slope is in degree or rise/run, convert to decimal ft height.

OUTPUT FORMAT (STRICT)
Return VALID JSON ONLY:
{
  "roof": {
    "scale": "string or null",
    "units": "ft",
    "ridges": [{"id": "ridge1", "length_x": number, "height_z": number, "estimated": boolean}],
    "valleys": [{"id": "valley1", "length_x": number, "estimated": boolean}],
    "eaves": [{"id": "eave1", "length_x": number, "estimated": boolean}],
    "penetrations": [{"id": "skylight1", "type": "skylight"|"chimney"|"vent", "width_x": number, "length_z": number, "estimated": boolean}]
  }
}

IMAGES
{image_list}
'''
