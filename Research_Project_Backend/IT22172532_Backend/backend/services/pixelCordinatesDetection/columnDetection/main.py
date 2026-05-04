import os
import sys
import json
from typing import Optional
from fastapi import FastAPI, UploadFile, File, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from PIL import Image
import numpy as np
import io
import cv2
import base64
import base64

app = FastAPI(
    title="Column Detection API",
    version="0.1.0",
    description="Upload a building plan image and detect pixel coordinates of ground floor columns",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "column-detection"}

class DetectionResponse(BaseModel):
    parts: list
    processed_image_b64: str


def _detect_columns_from_image_bytes(image_data: bytes, filename: str) -> tuple[list, str]:
    image = Image.open(io.BytesIO(image_data)).convert("RGB")
    image_np = np.array(image)

    # Convert to BGR for OpenCV
    img_bgr = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)

    # 1. Grayscale
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # 2. Threshold (default: 14, mode: inverse)
    _, thresh = cv2.threshold(gray, 14, 255, cv2.THRESH_BINARY_INV)

    # 3. Morphology (default: open, kernel: 7, iterations: 1)
    kernel = np.ones((7, 7), np.uint8)
    morph = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)

    # 4. Blob Detection
    contours, _ = cv2.findContours(morph, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    parts = []
    part_idx = 1

    # Default filters from HTML
    min_area = 50
    max_area = 5000
    aspect_tolerance = 4.0

    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        # Using exact contour area (pixel count) to match the HTML JS logic
        area = cv2.contourArea(cnt)

        # If contour area is zero (e.g. perfectly horizontal/vertical line), fallback to bounding box area
        if area == 0:
            area = w * h

        aspect = max(w / max(1, h), h / max(1, w))

        if min_area <= area <= max_area and aspect <= aspect_tolerance:
            parts.append(
                {
                    "part_id": f"column{part_idx}",
                    "coordinates": {"image": filename, "bbox": [int(x), int(y), int(x + w), int(y + h)]},
                }
            )

            # Draw bounding box (Red) and ID
            cv2.rectangle(img_bgr, (x, y), (x + w, y + h), (0, 0, 255), 2)
            cv2.rectangle(img_bgr, (x, max(0, y - 14)), (x + 18, y), (0, 0, 255), -1)
            cv2.putText(
                img_bgr,
                str(part_idx),
                (x + 4, max(11, y - 3)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.4,
                (255, 255, 255),
                1,
            )

            part_idx += 1

    processed_image_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    processed_image = Image.fromarray(processed_image_rgb)

    buffer = io.BytesIO()
    processed_image.save(buffer, format="PNG")
    processed_image_b64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

    return parts, processed_image_b64


@app.post("/api/detect-columns", response_model=DetectionResponse)
async def detect_columns(
    plan_image: UploadFile = File(...),
    pixel_to_meter: float = 0.1,
    grid_step_pixels: int = 20,
):
        image_data = await plan_image.read()
        parts, processed_image_b64 = _detect_columns_from_image_bytes(image_data, plan_image.filename)
        return DetectionResponse(parts=parts, processed_image_b64=processed_image_b64)


@app.post("/api/threejs-view", response_class=HTMLResponse)
async def threejs_view(plan_image: UploadFile = File(...)):
        """Generate a ready-to-open Three.js HTML view from a plan image upload."""

        image_data = await plan_image.read()
        parts, _processed_image_b64 = _detect_columns_from_image_bytes(image_data, plan_image.filename)

        columns = []
        for part in parts:
                bbox = part["coordinates"]["bbox"]
                center_x = (bbox[0] + bbox[2]) / 2.0
                center_y = (bbox[1] + bbox[3]) / 2.0
                columns.append({"x": center_x / 50.0, "z": center_y / 50.0})

        columns_json = json.dumps(columns)

        html_content = f"""<!doctype html>
<html>
<head>
    <meta charset=\"utf-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>3D Column Visualization</title>
    <style>
        html, body {{ margin: 0; padding: 0; height: 100%; overflow: hidden; }}
        canvas {{ display: block; }}
    </style>
</head>
<body>
    <script src=\"https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js\"></script>
    <script>
        const columns = {columns_json};

        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0xf0f0f0);

        const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        camera.position.set(50, 50, 50);

        const renderer = new THREE.WebGLRenderer({{ antialias: true }});
        renderer.setSize(window.innerWidth, window.innerHeight);
        document.body.appendChild(renderer.domElement);

        const ambientLight = new THREE.AmbientLight(0x404040, 0.6);
        scene.add(ambientLight);

        const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight.position.set(50, 50, 25);
        scene.add(directionalLight);

        const planeGeometry = new THREE.PlaneGeometry(200, 200);
        const planeMaterial = new THREE.MeshLambertMaterial({{ color: 0xcccccc }});
        const plane = new THREE.Mesh(planeGeometry, planeMaterial);
        plane.rotation.x = -Math.PI / 2;
        plane.position.y = 0;
        scene.add(plane);

        const gridHelper = new THREE.GridHelper(200, 20, 0x888888, 0xcccccc);
        scene.add(gridHelper);

        const columnGeometry = new THREE.BoxGeometry(2, 15, 2);
        const columnMaterial = new THREE.MeshLambertMaterial({{ color: 0x666666 }});

        columns.forEach((c) => {{
            const mesh = new THREE.Mesh(columnGeometry, columnMaterial);
            mesh.position.set(c.x, 7.5, c.z);
            scene.add(mesh);
        }});

        function onWindowResize() {{
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        }}
        window.addEventListener('resize', onWindowResize);

        function animate() {{
            requestAnimationFrame(animate);
            camera.lookAt(0, 0, 0);
            renderer.render(scene, camera);
        }}
        animate();
    </script>
</body>
</html>"""

        return HTMLResponse(content=html_content)


class Detection3DResponse(BaseModel):
    parts: list
    processed_image_b64: str


@app.post("/api/get-3d-data", response_model=Detection3DResponse)
async def get_3d_data(
    detection_results: list = Body(...),
):
    # Convert detection results to 3D data
    # Each column has fixed dimensions: height=15, width=2, length=2
    columns_3d = []
    
    for result in detection_results:
        bbox = result['coordinates']['bbox']
        # Calculate center position from bbox [x1, y1, x2, y2]
        center_x = (bbox[0] + bbox[2]) / 2.0
        center_y = (bbox[1] + bbox[3]) / 2.0
        
        # Scale pixel coordinates to 3D space
        pos_x = center_x / 50.0
        pos_z = center_y / 50.0
        
        columns_3d.append({
            "part_id": result['part_id'],
            "position": {
                "x": pos_x,
                "y": 7.5,  # Half of height (15/2)
                "z": pos_z
            },
            "dimensions": {
                "width": 2,
                "height": 15,
                "depth": 2
            }
        })
    
    return Detection3DResponse(parts=columns_3d, processed_image_b64="")