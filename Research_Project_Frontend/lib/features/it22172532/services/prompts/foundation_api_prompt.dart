/// Hardcoded AI prompt for extracting column measurements and distances
/// from architectural blueprint images.
///
/// This is sent as the SECOND turn in a multi-turn AI chat — the first
/// turn already contains the building-plan images and the structural-analysis
/// prompt ([AiApiPrompt.prompt]).  AI therefore already "sees" the
/// images and its own JSON analysis before receiving this instruction.
///
/// Edit the [prompt] constant here to update the instruction at any time
/// without touching any other file.
class FoundationApiPrompt {
  FoundationApiPrompt._();

  static const String prompt = '''
You are a structural engineer analysing architectural blueprint images.

INPUT: Architectural blueprint images of a building (ground floor structural plan + section drawings).

SCOPE: Ground floor LIVING ROOM and DINING ROOM area columns ONLY.
Ignore all other rooms (kitchen, bedrooms, bathrooms, garage, verandah, staircase, etc.).
Ignore beams, slabs, upper floors, roof, and finishes.

OUTPUT: Return ONLY a single valid JSON object. No markdown fences. No explanation. No extra text before or after the JSON.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 1 — IDENTIFY & MEASURE COLUMNS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Locate every ground floor column (shown as solid black squares/rectangles in the plan).
- For each column extract in METRES:
    height  → floor-to-floor height from section drawing  (e.g. 11'-0" = 3.35 m)
    width   → cross-section dimension along plan X axis   (e.g. 9"     = 0.225 m)
    length  → cross-section dimension along plan Y axis   (e.g. 9"     = 0.225 m)
- If a value cannot be read from the drawing, use a safe engineering default and record it as null.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 2 — ASSIGN COORDINATES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Label columns C1, C2, C3 … starting from the bottom-left outermost column going
  row by row left-to-right, then bottom-to-top (reading order on the plan).
- C1 is the origin: coordinate = { "x": 0, "y": 0, "z": 0 }.
- For every other column measure its real-world CENTER position relative to C1:
    x → horizontal distance (East +, West -)  in metres
    y → always 0  (all column bases sit at ground level)
    z → vertical plan distance (South +, North -)  in metres

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 3 — CALCULATE ALL PAIR DISTANCES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For EVERY unique pair (Ci → Cj) where i < j — this means ALL combinations,
not only adjacent neighbours.

  Example: 4 columns → 6 pairs: C1-C2, C1-C3, C1-C4, C2-C3, C2-C4, C3-C4
  Example: 6 columns → 15 pairs (every combination must appear)

For each pair:
    x_dist = Cj.x - Ci.x   (positive → Cj is to the right of Ci)
    y_dist = Cj.z - Ci.z   (positive → Cj is below  Ci on plan,
                             using plan Y which maps to world Z)

IMPORTANT: Do NOT skip non-adjacent pairs. Every (i, j) combination where i < j
must have its own entry in the distances array.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REQUIRED JSON SCHEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{
  "columns": [
    {
      "id":         "C1",
      "height":     <number | null>,   // metres
      "width":      <number | null>,   // metres (X cross-section)
      "length":     <number | null>,   // metres (Y cross-section)
      "coordinate": { "x": 0, "y": 0, "z": 0 }
    },
    {
      "id":         "C2",
      "height":     <number | null>,
      "width":      <number | null>,
      "length":     <number | null>,
      "coordinate": { "x": <number>, "y": 0, "z": <number> }
    }
    // … one object per column found
  ],

  "distances": [
    { "from": "C1", "to": "C2", "x_dist": <number>, "y_dist": <number> },
    { "from": "C1", "to": "C3", "x_dist": <number>, "y_dist": <number> },
    { "from": "C1", "to": "C4", "x_dist": <number>, "y_dist": <number> },
    { "from": "C2", "to": "C3", "x_dist": <number>, "y_dist": <number> },
    { "from": "C2", "to": "C4", "x_dist": <number>, "y_dist": <number> },
    { "from": "C3", "to": "C4", "x_dist": <number>, "y_dist": <number> }
    // … every Ci→Cj combination where i < j MUST be present
    // total entries = n*(n-1)/2  where n = number of columns
  ]
}

RULES:
- All numeric values in METRES, rounded to 3 decimal places.
- Use null (not a string) for any value that cannot be determined from the drawings.
- Do NOT add any extra keys, comments, or prose inside the JSON.
- Return the JSON object directly — no code block, no markdown.
''';
}