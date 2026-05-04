/// AI prompt for the FINISHING layer — walls, partitions, tiles, room labels.
///
/// This is sent as the FOURTH turn in the multi-turn AI chat:
///   Turn 1 → AiApiPrompt    (images + structural analysis → JSON)
///   Turn 2 → model returns JSON
///   Turn 3 → FoundationApiPrompt (→ foundation HTML with columns/beams/slab)
///   Turn 4 → model returns foundation HTML
///   Turn 5 → FinishingApiPrompt  (foundation HTML → finishing HTML)  ← THIS
///
/// The previous foundation HTML (full Three.js document) is already in AI's
/// context as the model's last response. This prompt instructs AI to EXTEND
/// that exact HTML by adding walls, partitions, tiles and room labels.
///
/// Edit the [prompt] constant here to update the instruction at any time
/// without touching any other file.
class FinishingApiPrompt {
  FinishingApiPrompt._();

  static const String prompt = '''
You are a Three.js developer specialising in architectural visualisation.

CONTEXT: The previous response contains a complete Three.js HTML file with the structural skeleton (columns, beams, ground slab, foundation pads). The `structuralData` object and all builder functions are already defined in that file.

TASK: Extend that HTML file by adding the FINISHING layer — exterior walls, interior partition walls, wall tiles, and room labels. Return the COMPLETE updated HTML file with all original code preserved and new code added.

OUTPUT: Return ONLY a single complete standalone HTML file. No markdown. No explanation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT TO ADD — DO NOT REMOVE ANYTHING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Add a new section at the bottom of the <script>, after all existing builder calls:

  buildExteriorWalls();
  buildPartitionWalls();
  buildRoomLabels();

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 1 — READ THE FLOOR PLAN FOR ROOMS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the architectural plan images already seen:
- Identify every room/space on the ground floor:
    Living Room, Dining Room, Kitchen, Bedroom(s), Bathroom(s),
    Corridor/Passage, Store, Veranda, Garage — whatever is present.
- For each room note which column pairs form its boundary walls.
- Identify which walls are EXTERIOR (outer perimeter) and which are INTERIOR partitions.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 2 — EXTERIOR WALLS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Exterior walls run between the outermost column faces along the perimeter.
- For each perimeter column link (Ci → Cj) already in columnLinks[]:
    wallLength = link.distance
    wallHeight = structuralData.columnHeight
    wallThick  = 0.23   // 9" brick wall in metres
    midX = (Ci.x + Cj.x) / 2
    midZ = (Ci.z + Cj.z) / 2
    midY = wallHeight / 2
    rotation_Y = atan2(Cj.z - Ci.z, Cj.x - Ci.x)
- Material: brick texture using a canvas-generated repeating brick pattern
    (red/orange #b5651d with dark mortar lines #5a3e28, repeat every 0.6m).
- Leave openings for doors and windows if their positions are visible in the plan;
  otherwise use a full wall panel and mark "openings UNKNOWN" in the overlay.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 3 — INTERIOR PARTITION WALLS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Partition walls follow interior beam/column lines separating rooms.
- Same geometry logic as exterior walls but:
    wallThick = 0.115   // 4.5" half-brick partition
    Material: plain plaster #e8e0d0 (light cream)
- Each partition wall panel is a BoxGeometry:
    (wallLength, wallHeight, wallThick)
    positioned and rotated exactly like beams above.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 4 — WALL TILES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Apply tiles to the INTERIOR FACE of all walls (both exterior and partition).
- Tile band: from Y=0 to Y=1.2m (standard dado height).
- Tile material: canvas texture — white #f5f5f5 tiles with thin grey #cccccc grout lines,
    tile size 0.3m × 0.3m repeated.
- Add a thin (0.01m) tile panel mesh on the interior face of each wall, same
    length as the wall, height 1.2m, offset inward by (wallThick/2 + 0.005).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STEP 5 — ROOM LABELS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- For each identified room, create a floating canvas sprite label.
- Position: centre of the room's floor area, Y = 1.5m (eye level).
- Text: room name in bold (e.g. "Living Room", "Bedroom 1", "Kitchen").
- Font: 28px bold white text on semi-transparent dark background #00000099.
- Scale sprite to be readable from orbit camera distance.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DATA STRUCTURE — append to structuralData
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Add these keys to the existing structuralData object:

  finishing: {
    exteriorWallThick: 0.23,
    partitionWallThick: 0.115,
    tileHeight: 1.2,
    rooms: [
      // { name:"Living Room",  centerX:0, centerZ:0, floorW:3.6, floorD:4.2 },
      // { name:"Bedroom 1",    centerX:4, centerZ:0, floorW:3.0, floorD:3.5 },
      // { name:"Kitchen",      centerX:0, centerZ:4, floorW:2.4, floorD:3.0 },
    ],
    unknowns: []   // list any unreadable openings or room boundaries
  }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HELPER: CANVAS BRICK TEXTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function makeBrickTexture() {
  const c = document.createElement('canvas');
  c.width = 128; c.height = 64;
  const ctx = c.getContext('2d');
  ctx.fillStyle = '#b5651d'; ctx.fillRect(0,0,128,64);
  ctx.strokeStyle = '#5a3e28'; ctx.lineWidth = 3;
  // horizontal mortar lines
  [0, 21, 42, 63].forEach(y => { ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(128,y); ctx.stroke(); });
  // vertical brick joints (offset every row)
  [[0,64,21],[32,96,42]].forEach(([...xs, y2]) => {
    xs.forEach(x => { ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,y2); ctx.stroke(); });
  });
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(4, 3);
  return tex;
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HELPER: CANVAS TILE TEXTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function makeTileTexture() {
  const c = document.createElement('canvas');
  c.width = 64; c.height = 64;
  const ctx = c.getContext('2d');
  ctx.fillStyle = '#f5f5f5'; ctx.fillRect(0,0,64,64);
  ctx.strokeStyle = '#cccccc'; ctx.lineWidth = 2;
  ctx.strokeRect(1,1,62,62);
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(wallLength/0.3, 1.2/0.3);
  return tex;
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DEBUG OVERLAY — ADD TO EXISTING PANEL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Append to the existing overlay panel:
  - Rooms identified: count + names
  - Exterior walls: count
  - Partition walls: count
  - Any UNKNOWN openings

FALLBACK: unreadable room boundary or opening → skip it, mark UNKNOWN in overlay. Never crash.

Return ONLY the complete updated HTML document with ALL original code preserved.
''';
}