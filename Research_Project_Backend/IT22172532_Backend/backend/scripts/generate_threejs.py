#!/usr/bin/env python3
"""
Generate Three.js 3D HTML for:
  - Kandy Super Center  (ground floor, from real measurements)
  - Gampaha Project     (ground floor, standard residential layout)

Stores HTML strings in MongoDB:  threejs collection, field: "foundation"
Run:  python generate_threejs.py
"""

import os
import sys
from datetime import datetime, timezone
from pymongo import MongoClient

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from config.settings import DB_NAME, MONGO_URI
KANDY_PID   = "0c962b2f-b9f0-4132-a44e-e44e569b35a8"
GAMPAHA_PID = "69b1aeb32f1cbc7d3a305d29"

FT = 0.3048          # feet → metres

def ft(*vals):
    return tuple(round(v * FT, 4) for v in vals) if len(vals) > 1 else round(vals[0] * FT, 4)


# ─────────────────────────────────────────────────────────────────────────────
# HTML TEMPLATE BUILDER
# ─────────────────────────────────────────────────────────────────────────────

def build_scene_html(title, sub1, sub2, cam_x, cam_z, geometry_js):
    """Assemble a complete, self-contained Three.js scene as an HTML string."""

    cx = round(cam_x, 3)
    cz = round(cam_z, 3)

    # ── HEAD + CSS ────────────────────────────────────────────────────────────
    head = (
        "<!DOCTYPE html>\n"
        "<html lang='en'>\n"
        "<head>\n"
        "<meta charset='utf-8'>\n"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>\n"
        "<title>" + title + " - 3D Ground Floor</title>\n"
        "<style>\n"
        "* { margin:0; padding:0; box-sizing:border-box; }\n"
        "body { background:#0d1b2a; overflow:hidden;\n"
        "  font-family:'Segoe UI',Arial,sans-serif; }\n"
        "canvas { display:block; }\n"
        "#info {\n"
        "  position:fixed; top:16px; left:16px;\n"
        "  background:rgba(0,0,0,0.7); backdrop-filter:blur(10px);\n"
        "  color:#f0f0f0; padding:13px 17px; border-radius:11px;\n"
        "  border:1px solid rgba(255,255,255,0.12); max-width:275px;\n"
        "  pointer-events:none;\n"
        "}\n"
        ".pn { font-size:15px; font-weight:700; color:#ffd27a; letter-spacing:.5px; }\n"
        ".ps { font-size:12px; color:#90aab8; margin-top:3px; }\n"
        ".ph { font-size:11px; color:#4e6878; margin-top:8px; }\n"
        "#legend {\n"
        "  position:fixed; top:16px; right:16px;\n"
        "  background:rgba(0,0,0,0.7); backdrop-filter:blur(10px);\n"
        "  color:#ddd; padding:12px 15px; border-radius:11px;\n"
        "  border:1px solid rgba(255,255,255,0.12); font-size:12px;\n"
        "}\n"
        ".li { display:flex; align-items:center; gap:9px; margin-bottom:6px; }\n"
        ".li:last-child { margin-bottom:0; }\n"
        ".sw { width:14px; height:14px; border-radius:3px; flex-shrink:0; }\n"
        "#mat-panel {\n"
        "  position:fixed; bottom:20px; left:50%; transform:translateX(-50%);\n"
        "  display:flex; flex-wrap:wrap; justify-content:center; gap:8px;\n"
        "  background:rgba(0,0,0,0.78); backdrop-filter:blur(14px);\n"
        "  padding:13px 20px; border-radius:18px;\n"
        "  border:1px solid rgba(255,255,255,0.1);\n"
        "  box-shadow:0 4px 32px rgba(0,0,0,0.65);\n"
        "}\n"
        ".pl { width:100%; text-align:center; font-size:10px; color:#4e6878;\n"
        "  letter-spacing:1.8px; text-transform:uppercase; margin-bottom:4px; }\n"
        ".mb {\n"
        "  padding:8px 15px; border-radius:9px; border:2px solid transparent;\n"
        "  cursor:pointer; font-size:12px; font-weight:600; color:#fff;\n"
        "  text-shadow:0 1px 4px rgba(0,0,0,.55); min-width:85px;\n"
        "  transition:transform .15s, border-color .15s, box-shadow .15s;\n"
        "}\n"
        ".mb:hover { transform:translateY(-3px); box-shadow:0 5px 20px rgba(0,0,0,.5); }\n"
        ".mb.active { border-color:#ffd700; box-shadow:0 0 14px rgba(255,215,0,.45); }\n"
        "</style>\n"
        "</head>\n"
    )

    # ── BODY / PANELS ─────────────────────────────────────────────────────────
    body_html = (
        "<body>\n"
        "<div id='info'>\n"
        "  <div class='pn'>" + title.upper() + "</div>\n"
        "  <div class='ps'>" + sub1 + "</div>\n"
        "  <div class='ps'>" + sub2 + "</div>\n"
        "  <div class='ph'>Drag to orbit &middot; Scroll to zoom &middot; Right-drag to pan</div>\n"
        "</div>\n"
        "<div id='legend'>\n"
        "  <div class='li'><div class='sw' style='background:#a0522d'></div>External Walls</div>\n"
        "  <div class='li'><div class='sw' style='background:#c8a76b'></div>Internal Walls</div>\n"
        "  <div class='li'><div class='sw' style='background:#607080'></div>RC Columns</div>\n"
        "  <div class='li'><div class='sw' style='background:#8b7355'></div>Floor Slab</div>\n"
        "</div>\n"
        "<div id='mat-panel'>\n"
        "  <div class='pl'>Apply Material to Walls &amp; Floor</div>\n"
        "  <button class='mb active' data-type='bricks'   style='background:#8B4513'"
        "   onclick=\"applyMaterial('bricks')\">&#129746; Bricks</button>\n"
        "  <button class='mb'       data-type='tiles'    style='background:#848484'"
        "   onclick=\"applyMaterial('tiles')\">&#11036; Tiles</button>\n"
        "  <button class='mb'       data-type='paint'    style='background:#e8e0d0;color:#333'"
        "   onclick=\"applyMaterial('paint')\">&#127912; Paint</button>\n"
        "  <button class='mb'       data-type='putty'    style='background:#cfc0a0;color:#333'"
        "   onclick=\"applyMaterial('putty')\">&#128396; Putty</button>\n"
        "  <button class='mb'       data-type='concrete' style='background:#607d8b'"
        "   onclick=\"applyMaterial('concrete')\">&#127959; Concrete</button>\n"
        "  <button class='mb'       data-type='cement'   style='background:#455a64'"
        "   onclick=\"applyMaterial('cement')\">&#128295; Cement</button>\n"
        "</div>\n"
    )

    # ── SCRIPT PREAMBLE ───────────────────────────────────────────────────────
    script_start = (
        "<script type='module'>\n"
        "import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.158.0/build/three.module.js';\n"
        "import { OrbitControls } from 'https://cdn.jsdelivr.net/npm/three@0.158.0/examples/jsm/controls/OrbitControls.js';\n"
        "\n"
        "// ── Scene ────────────────────────────────────────────────────────────\n"
        "const scene = new THREE.Scene();\n"
        "scene.background = new THREE.Color(0x0d1b2a);\n"
        "scene.fog = new THREE.FogExp2(0x0d1b2a, 0.016);\n"
        "\n"
        "const camera = new THREE.PerspectiveCamera(45, innerWidth/innerHeight, 0.1, 300);\n"
        "camera.position.set(" + str(cx + 12) + ", 14, " + str(cz + 16) + ");\n"
        "\n"
        "const renderer = new THREE.WebGLRenderer({ antialias: true });\n"
        "renderer.setPixelRatio(Math.min(devicePixelRatio, 2));\n"
        "renderer.setSize(innerWidth, innerHeight);\n"
        "renderer.shadowMap.enabled = true;\n"
        "renderer.shadowMap.type = THREE.PCFSoftShadowMap;\n"
        "renderer.toneMapping = THREE.ACESFilmicToneMapping;\n"
        "renderer.toneMappingExposure = 1.1;\n"
        "document.body.appendChild(renderer.domElement);\n"
        "\n"
        "const controls = new OrbitControls(camera, renderer.domElement);\n"
        "controls.enableDamping = true;\n"
        "controls.dampingFactor = 0.06;\n"
        "controls.target.set(" + str(cx) + ", 1.5, " + str(cz) + ");\n"
        "controls.minDistance = 2;\n"
        "controls.maxDistance = 100;\n"
        "controls.maxPolarAngle = Math.PI * 0.82;\n"
        "\n"
        "// ── Lights ───────────────────────────────────────────────────────────\n"
        "scene.add(new THREE.AmbientLight(0x90aab8, 0.5));\n"
        "const sun = new THREE.DirectionalLight(0xfff4d6, 1.4);\n"
        "sun.position.set(15, 25, 10);\n"
        "sun.castShadow = true;\n"
        "sun.shadow.mapSize.set(2048, 2048);\n"
        "sun.shadow.camera.near = 0.5; sun.shadow.camera.far = 100;\n"
        "sun.shadow.camera.left = -30; sun.shadow.camera.right = 30;\n"
        "sun.shadow.camera.top = 30;   sun.shadow.camera.bottom = -30;\n"
        "sun.shadow.bias = -0.001;\n"
        "scene.add(sun);\n"
        "const fill = new THREE.DirectionalLight(0xaacce8, 0.35);\n"
        "fill.position.set(-10, 8, -6);\n"
        "scene.add(fill);\n"
        "\n"
        "// ── Material palette ─────────────────────────────────────────────────\n"
        "const MATS = {\n"
        "  bricks:   { wall:0xa0522d, iwall:0xc8906a, floor:0x8b7355, rough:0.92, metal:0.0  },\n"
        "  tiles:    { wall:0xb0b0b0, iwall:0xc8c8c8, floor:0xd0d0d0, rough:0.22, metal:0.06 },\n"
        "  paint:    { wall:0xfff8f0, iwall:0xfffff5, floor:0xeee8e0, rough:0.75, metal:0.0  },\n"
        "  putty:    { wall:0xe2d5be, iwall:0xede0cc, floor:0xd4c8b0, rough:0.88, metal:0.0  },\n"
        "  concrete: { wall:0x7b8d93, iwall:0x8fa0a8, floor:0x6d7a7f, rough:0.95, metal:0.0  },\n"
        "  cement:   { wall:0x4a5a62, iwall:0x566672, floor:0x3e4e56, rough:1.0,  metal:0.0  },\n"
        "};\n"
        "\n"
        "function mkMat(hex, r, m) {\n"
        "  return new THREE.MeshStandardMaterial({ color:hex, roughness:r||0.9, metalness:m||0 });\n"
        "}\n"
        "\n"
        "const wallMeshes = [], iWallMeshes = [], floorMeshes = [], colMeshes = [];\n"
        "\n"
        "// ── Geometry helpers ─────────────────────────────────────────────────\n"
        "function addWall(x0, z0, x1, z1, h, t, internal) {\n"
        "  const dx=x1-x0, dz=z1-z0, len=Math.sqrt(dx*dx+dz*dz);\n"
        "  if (len < 0.01) return;\n"
        "  const m = new THREE.Mesh(\n"
        "    new THREE.BoxGeometry(len, h, t),\n"
        "    mkMat(internal ? 0xc8a76b : 0xa0522d, 0.9, 0)\n"
        "  );\n"
        "  m.position.set((x0+x1)/2, h/2, (z0+z1)/2);\n"
        "  m.rotation.y = -Math.atan2(dz, dx);\n"
        "  m.castShadow = true; m.receiveShadow = true;\n"
        "  scene.add(m);\n"
        "  (internal ? iWallMeshes : wallMeshes).push(m);\n"
        "}\n"
        "\n"
        "function addColumn(x, z, w, d, h) {\n"
        "  const m = new THREE.Mesh(\n"
        "    new THREE.BoxGeometry(w, h, d),\n"
        "    mkMat(0x607080, 0.85, 0.05)\n"
        "  );\n"
        "  m.position.set(x, h/2, z);\n"
        "  m.castShadow = true; m.receiveShadow = true;\n"
        "  scene.add(m); colMeshes.push(m);\n"
        "}\n"
        "\n"
        "function addFloor(x0, z0, x1, z1) {\n"
        "  const m = new THREE.Mesh(\n"
        "    new THREE.BoxGeometry(x1-x0, 0.15, z1-z0),\n"
        "    mkMat(0x8b7355, 0.88, 0)\n"
        "  );\n"
        "  m.position.set((x0+x1)/2, -0.075, (z0+z1)/2);\n"
        "  m.receiveShadow = true;\n"
        "  scene.add(m); floorMeshes.push(m);\n"
        "}\n"
        "\n"
        "// ── Ground & grid ────────────────────────────────────────────────────\n"
        "const ground = new THREE.Mesh(\n"
        "  new THREE.PlaneGeometry(120, 120),\n"
        "  mkMat(0x141e28, 1.0, 0)\n"
        ");\n"
        "ground.rotation.x = -Math.PI/2;\n"
        "ground.position.set(" + str(cx) + ", -0.16, " + str(cz) + ");\n"
        "ground.receiveShadow = true;\n"
        "scene.add(ground);\n"
        "const grid = new THREE.GridHelper(120, 120, 0x1c2e3a, 0x1c2e3a);\n"
        "grid.position.set(" + str(cx) + ", -0.14, " + str(cz) + ");\n"
        "scene.add(grid);\n"
        "\n"
        "// ═══════════ BUILDING GEOMETRY ═══════════════════════════════════════\n"
    )

    # ── SCRIPT SUFFIX (material switcher + animation) ─────────────────────────
    script_end = (
        "\n"
        "// ── Material switcher ────────────────────────────────────────────────\n"
        "window.applyMaterial = function(type) {\n"
        "  document.querySelectorAll('.mb').forEach(b =>\n"
        "    b.classList.toggle('active', b.dataset.type === type)\n"
        "  );\n"
        "  const d = MATS[type]; if (!d) return;\n"
        "  wallMeshes.forEach(m => {\n"
        "    m.material.color.set(d.wall);\n"
        "    m.material.roughness = d.rough;\n"
        "    m.material.metalness = d.metal;\n"
        "    m.material.needsUpdate = true;\n"
        "  });\n"
        "  iWallMeshes.forEach(m => {\n"
        "    m.material.color.set(d.iwall);\n"
        "    m.material.roughness = d.rough * 0.95;\n"
        "    m.material.metalness = d.metal;\n"
        "    m.material.needsUpdate = true;\n"
        "  });\n"
        "  floorMeshes.forEach(m => {\n"
        "    m.material.color.set(d.floor);\n"
        "    m.material.roughness = d.rough;\n"
        "    m.material.metalness = d.metal;\n"
        "    m.material.needsUpdate = true;\n"
        "  });\n"
        "};\n"
        "\n"
        "// ── Animation loop ───────────────────────────────────────────────────\n"
        "(function animate() {\n"
        "  requestAnimationFrame(animate);\n"
        "  controls.update();\n"
        "  renderer.render(scene, camera);\n"
        "})();\n"
        "\n"
        "window.addEventListener('resize', () => {\n"
        "  camera.aspect = innerWidth/innerHeight;\n"
        "  camera.updateProjectionMatrix();\n"
        "  renderer.setSize(innerWidth, innerHeight);\n"
        "});\n"
        "</script>\n"
        "</body>\n"
        "</html>\n"
    )

    return head + body_html + script_start + geometry_js + script_end


# ─────────────────────────────────────────────────────────────────────────────
# KANDY SUPER CENTER — real measurements
# ─────────────────────────────────────────────────────────────────────────────

def generate_kandy_html():
    """
    Ground floor geometry from actual DB measurements:
      14 columns: C1-C12 on 3×4 grid (0/11.5/25.33 × 0/12/23/36 ft)
                  C13(33.42,0) C14(33.42,13) — garage extension
      Column size: 0.75ft × 0.75ft × 10ft
      External wall thickness: 0.75ft  Internal: 0.375ft
    """
    H    = ft(10.0)     # 3.048 m wall height
    EW   = ft(0.75)     # 0.2286 m ext-wall thickness
    IW   = ft(0.375)    # 0.1143 m int-wall thickness
    CS   = ft(0.75)     # column section

    # Key x/z coordinates in metres
    x0, x1, x2 = ft(0), ft(11.5), ft(25.33)
    x3          = ft(33.42)
    z0, z1, z2  = ft(0), ft(12.0), ft(23.0)
    z3          = ft(36.0)
    gz          = ft(13.0)      # garage z depth

    cam_x = (x3) / 2
    cam_z = (z3) / 2

    # Column list  [x, z] in metres
    cols = [
        [x0, z0], [x1, z0], [x2, z0],   # row 1 (north)
        [x0, z1], [x1, z1], [x2, z1],   # row 2
        [x0, z2], [x1, z2], [x2, z2],   # row 3
        [x0, z3], [x1, z3], [x2, z3],   # row 4 (south)
        [x3, z0], [x3, gz],              # garage
    ]
    cols_js = "[" + ",".join(f"[{c[0]},{c[1]}]" for c in cols) + "]"

    geom = (
        f"const H={H}, EW={EW}, IW={IW}, CS={CS};\n"
        "\n"
        "// ── Floor slabs ──────────────────────────────────────────────────────\n"
        f"addFloor(0, 0, {x2}, {z3});          // main building\n"
        f"addFloor({x2}, 0, {x3}, {gz});       // garage\n"
        "\n"
        "// ── External walls ───────────────────────────────────────────────────\n"
        f"addWall(0,0, {x2},0, H,EW, false);              // North main\n"
        f"addWall({x2},0, {x3},0, H,EW, false);           // Garage north\n"
        f"addWall({x3},0, {x3},{gz}, H,EW, false);        // Garage east\n"
        f"addWall({x3},{gz}, {x2},{gz}, H,EW, false);     // Garage south\n"
        f"addWall({x2},{gz}, {x2},{z3}, H,EW, false);     // East upper\n"
        f"addWall({x2},{z3}, 0,{z3}, H,EW, false);        // South wall\n"
        f"addWall(0,{z3}, 0,0, H,EW, false);              // West wall\n"
        "\n"
        "// ── Internal walls ───────────────────────────────────────────────────\n"
        f"addWall({x2},0, {x2},{gz}, H,IW, true);         // main/garage divider\n"
        f"addWall({x1},0, {x1},{z1}, H,IW, true);         // x=11.5 lower half\n"
        f"addWall({x1},{z1}, {x1},{z3}, H,IW, true);      // x=11.5 upper half\n"
        f"addWall(0,{z1}, {x1},{z1}, H,IW, true);         // z=12 west span\n"
        f"addWall({x1},{z1}, {x2},{z1}, H,IW, true);      // z=12 east span\n"
        f"addWall(0,{z2}, {x1},{z2}, H,IW, true);         // z=23 west span\n"
        f"addWall({x1},{z2}, {x2},{z2}, H,IW, true);      // z=23 east span\n"
        "\n"
        "// ── 14 Columns ───────────────────────────────────────────────────────\n"
        f"{cols_js}.forEach(([x,z]) => addColumn(x, z, CS, CS, H));\n"
    )

    return build_scene_html(
        title  = "Kandy Super Center",
        sub1   = "Ground Floor &middot; 1,738.87 sq ft",
        sub2   = "Pragathipura, Madiwela, Kotte",
        cam_x  = cam_x,
        cam_z  = cam_z,
        geometry_js = geom,
    )


# ─────────────────────────────────────────────────────────────────────────────
# GAMPAHA PROJECT — standard 2-bedroom residential layout (40 × 30 ft)
# ─────────────────────────────────────────────────────────────────────────────

def generate_gampaha_html():
    """
    Standard 2-bedroom residential ground floor.
    No measurements in DB, so we use a realistic 40 × 30 ft layout.
    """
    BW  = ft(40.0)      # building width  12.192 m
    BD  = ft(30.0)      # building depth   9.144 m
    H   = ft(10.0)
    EW  = ft(0.75)
    IW  = ft(0.375)
    CS  = ft(0.75)

    # Mid-points for internal partition walls
    mx  = round(BW / 2, 4)     # 6.096
    mz  = round(BD / 2, 4)     # 4.572
    cz1 = round(BD * 0.38, 4)  # corridor / landing zone

    cam_x = round(BW / 2, 3)
    cam_z = round(BD / 2, 3)

    # 9 columns: corners + mid-spans
    cols = [
        [0, 0], [mx, 0], [BW, 0],
        [0, mz], [mx, mz], [BW, mz],
        [0, BD], [mx, BD], [BW, BD],
    ]
    cols_js = "[" + ",".join(f"[{c[0]},{c[1]}]" for c in cols) + "]"

    geom = (
        f"const H={H}, EW={EW}, IW={IW}, CS={CS};\n"
        "\n"
        "// ── Floor slab ───────────────────────────────────────────────────────\n"
        f"addFloor(0, 0, {BW}, {BD});\n"
        "\n"
        "// ── External walls ───────────────────────────────────────────────────\n"
        f"addWall(0,0, {BW},0, H,EW, false);      // North\n"
        f"addWall({BW},0, {BW},{BD}, H,EW, false); // East\n"
        f"addWall({BW},{BD}, 0,{BD}, H,EW, false); // South\n"
        f"addWall(0,{BD}, 0,0, H,EW, false);       // West\n"
        "\n"
        "// ── Internal walls (2-bed layout) ─────────────────────────────────────\n"
        f"addWall(0,{cz1}, {BW},{cz1}, H,IW, true);   // corridor wall\n"
        f"addWall({mx},0, {mx},{cz1}, H,IW, true);    // bedroom divider\n"
        f"addWall({mx},{cz1}, {mx},{BD}, H,IW, true); // living/kitchen divider\n"
        "\n"
        "// ── 9 Columns ────────────────────────────────────────────────────────\n"
        f"{cols_js}.forEach(([x,z]) => addColumn(x, z, CS, CS, H));\n"
    )

    return build_scene_html(
        title  = "Gampaha Project",
        sub1   = "Ground Floor &middot; ~1,200 sq ft",
        sub2   = "Gampaha, Western Province",
        cam_x  = cam_x,
        cam_z  = cam_z,
        geometry_js = geom,
    )


# ─────────────────────────────────────────────────────────────────────────────
# MONGODB UPSERT
# ─────────────────────────────────────────────────────────────────────────────

def save_to_mongo(pid, html, label):
    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=15000)
    db     = client[DB_NAME]
    col    = db["threejs"]

    now = datetime.now(timezone.utc)
    result = col.update_one(
        {"projectId": pid},
        {
            "$set": {
                "foundation": html,
                "updatedAt":  now,
            },
            "$setOnInsert": {
                "projectId": pid,
                "createdAt": now,
            },
        },
        upsert=True,
    )
    client.close()

    if result.upserted_id:
        print(f"  [{label}] Inserted new threejs doc — id={result.upserted_id}")
    else:
        print(f"  [{label}] Updated existing threejs doc "
              f"(matched={result.matched_count}, modified={result.modified_count})")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Generating Three.js HTML ...\n")

    print("Building Kandy Super Center scene ...")
    kandy_html = generate_kandy_html()
    print(f"  OK — {len(kandy_html):,} chars")

    print("Building Gampaha Project scene ...")
    gampaha_html = generate_gampaha_html()
    print(f"  OK — {len(gampaha_html):,} chars")

    print("\nSaving to MongoDB ...")
    save_to_mongo(KANDY_PID,   kandy_html,   "Kandy")
    save_to_mongo(GAMPAHA_PID, gampaha_html, "Gampaha")

    print("\nDone. Both threejs foundation docs are stored in MongoDB.")
    print("Open the Flutter app, select a project, and tap '3D View → Foundation'.")
