from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from typing import Optional
from inference_sdk import InferenceHTTPClient
import cv2
import numpy as np

app = FastAPI(title="Big Surface Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

CLIENT = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="jV7wST2cwZRkZahxmZEC"
)
MODEL_ID = "cubicasa5k-2-qpmsa/3"


def bbox_to_contour(region: np.ndarray,
                    bx1: int, by1: int, bx2: int, by2: int,
                    off_x: int, off_y: int) -> list:
    """
    Given a bounding box inside `region`, extract the dominant object contour
    and return its points in full-image coordinates.
    Falls back to the rectangle corners if contour extraction fails.
    """
    fallback = [
        [bx1 + off_x, by1 + off_y],
        [bx2 + off_x, by1 + off_y],
        [bx2 + off_x, by2 + off_y],
        [bx1 + off_x, by2 + off_y],
    ]

    crop = region[by1:by2, bx1:bx2]
    ch, cw = crop.shape[:2]
    if cw < 5 or ch < 5:
        return fallback

    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)

    # Enhance contrast
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    # Edge detection
    blurred = cv2.GaussianBlur(enhanced, (5, 5), 0)
    edges   = cv2.Canny(blurred, 20, 80)

    # Close small gaps
    kernel  = np.ones((3, 3), np.uint8)
    dilated = cv2.dilate(edges, kernel, iterations=2)

    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return fallback

    # Largest contour = main object
    c       = max(contours, key=cv2.contourArea)
    epsilon = 0.008 * cv2.arcLength(c, True)
    approx  = cv2.approxPolyDP(c, epsilon, True)

    points = [
        [int(p[0][0]) + bx1 + off_x, int(p[0][1]) + by1 + off_y]
        for p in approx
    ]
    return points if len(points) >= 3 else fallback


@app.get("/")
async def root():
    return FileResponse("index.html")


@app.post("/detect")
async def detect(
    file: UploadFile = File(...),
    sel_x: Optional[int] = Form(None),
    sel_y: Optional[int] = Form(None),
    sel_w: Optional[int] = Form(None),
    sel_h: Optional[int] = Form(None),
    class_filter: Optional[str] = Form(None),   # door | window | wall | None=all
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an image.")

    data = await file.read()
    nparr = np.frombuffer(data, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Could not decode image.")

    full_h, full_w = img.shape[:2]

    # Crop to user selection if provided
    has_selection = all(v is not None for v in [sel_x, sel_y, sel_w, sel_h])
    if has_selection:
        x1 = max(0, sel_x)
        y1 = max(0, sel_y)
        x2 = min(full_w, sel_x + sel_w)
        y2 = min(full_h, sel_y + sel_h)
        region = img[y1:y2, x1:x2]
        offset_x, offset_y = x1, y1
    else:
        region = img
        offset_x, offset_y = 0, 0

    rh, rw = region.shape[:2]
    if rw == 0 or rh == 0:
        raise HTTPException(status_code=400, detail="Selected region is empty.")

    # Convert BGR (OpenCV) → RGB before passing to the SDK
    region_rgb = cv2.cvtColor(region, cv2.COLOR_BGR2RGB)

    # Call Roboflow via inference_sdk
    rf_result   = CLIENT.infer(region_rgb, model_id=MODEL_ID)
    predictions = rf_result.get("predictions", [])

    objects = []
    for pred in predictions:
        raw_pts = pred.get("points", [])
        if raw_pts:
            # Model returned segmentation polygon — use directly
            points = [[int(p["x"]) + offset_x, int(p["y"]) + offset_y] for p in raw_pts]
        else:
            # Model returned a bounding box — extract actual contour from that crop
            cx  = pred.get("x", 0)
            cy  = pred.get("y", 0)
            bw  = pred.get("width", 0)
            bh  = pred.get("height", 0)
            # bbox coords in region space (before offset)
            bx1 = max(0, int(cx - bw / 2))
            by1 = max(0, int(cy - bh / 2))
            bx2 = min(rw,  int(cx + bw / 2))
            by2 = min(rh,  int(cy + bh / 2))
            points = bbox_to_contour(region, bx1, by1, bx2, by2, offset_x, offset_y)

        objects.append({
            "class":      pred.get("class", "unknown"),
            "confidence": round(pred.get("confidence", 0), 3),
            "points":     points,
        })

    # Filter by requested class (if specified)
    if class_filter:
        objects = [o for o in objects if o["class"].lower() == class_filter.lower()]

    return {
        "image_width":  full_w,
        "image_height": full_h,
        "object_count": len(objects),
        "objects":      objects,
        "selection":    {"x": offset_x, "y": offset_y, "w": rw, "h": rh} if has_selection else None,
    }
