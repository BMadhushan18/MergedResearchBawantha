import os
import re
from datetime import datetime, timezone
from typing import Any, Dict, List

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

from models.schemas import ModelStatusResponse, PredictionResponse
from services import mongo_service
from services.cost_service import (
    compute_confidence_score,
    compute_project_totals,
    generate_waste_recommendations,
)
from services.feature_extractor import extract_task_features
from services.file_parser import parse_excel, parse_pdf
from services.model_service import models_loaded, predict_one_task
from services.procurement_service import build_procurement_pdf

router = APIRouter()

SUPPORTED_EXCEL = {".xlsx", ".xls", ".csv"}
SUPPORTED_PDF = {".pdf"}
SUPPORTED_TEXT = {".txt"}


class TextPredictionRequest(BaseModel):
    project_id: str
    site_location: str
    boq_text: str


class ReportPredictionRequest(BaseModel):
    project_id: str
    site_location: str


def _parse_text_boq(boq_text: str) -> List[dict]:
    items: List[dict] = []
    lines = [line.strip() for line in boq_text.splitlines() if line.strip()]
    for line in lines:
        amount = 0.0
        desc = line

        if "|" in line:
            parts = [p.strip() for p in line.split("|")]
            desc = parts[0]
            if len(parts) > 1:
                try:
                    amount = float(parts[1].replace(",", ""))
                except Exception:
                    amount = 0.0
        else:
            numbers = re.findall(r"\d+(?:\.\d+)?", line)
            if numbers:
                try:
                    amount = float(numbers[-1])
                except Exception:
                    amount = 0.0

        items.append(
            {
                "description": desc,
                "unit": "item",
                "quantity": 1.0,
                "amount": amount,
            }
        )

    if not items:
        raise HTTPException(status_code=422, detail="No valid BOQ text lines found")
    return items


def _parse_upload(file_name: str, file_bytes: bytes) -> List[dict]:
    suffix = os.path.splitext(file_name.lower())[1]
    if suffix in SUPPORTED_EXCEL:
        parsed = parse_excel(file_bytes)
        return [i.model_dump() for i in parsed]
    if suffix in SUPPORTED_PDF:
        parsed = parse_pdf(file_bytes)
        return [i.model_dump() for i in parsed]
    if suffix in SUPPORTED_TEXT:
        return _parse_text_boq(file_bytes.decode("utf-8", errors="ignore"))
    raise HTTPException(status_code=415, detail="Unsupported file type. Use .xlsx, .xls, .csv, .pdf, or .txt")


def _boq_items_from_report(project_id: str) -> List[dict]:
    report = mongo_service.get_latest_boq_report(project_id)
    if report is None:
        raise HTTPException(status_code=404, detail="No boqReport found for selected project")

    items: List[dict] = []
    sections = report.get("sections") or []
    for section in sections:
        section_name = str(section.get("section", "BOQ"))
        for row in section.get("rows", []) or []:
            description = f"{section_name} - {str(row.get('materialName', '')).strip()}".strip()
            quantity = float(row.get("quantity", 0) or 0)
            amount = float(row.get("totalMaterialCost", 0) or 0)
            items.append(
                {
                    "description": description,
                    "unit": str(row.get("unit", "item")),
                    "quantity": quantity,
                    "amount": amount,
                }
            )

    if not items:
        raise HTTPException(status_code=422, detail="Selected boqReport has no row data")
    return items


def _metadata_from_project(project_id: str, site_location: str) -> Dict[str, Any]:
    project = mongo_service.get_project_by_id(project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found in projects collection")

    return {
        "project_id": project["project_id"],
        "project_name": project["project_name"],
        "project_type": project["project_type"],
        "site_location": site_location,
        "total_floor_area_sqft": int(project.get("total_floor_area_sqft", 3000)),
        "number_of_floors": int(project.get("number_of_floors", 1)),
        "building_complexity_index": float(project.get("building_complexity_index", 6.0)),
        "working_days": int(project.get("working_days", 5)),
    }


def _build_prediction(metadata: Dict[str, Any], boq_items: List[dict]) -> Dict[str, Any]:
    if not models_loaded():
        raise HTTPException(status_code=503, detail="Model files are not loaded. Please try again later.")

    task_features = extract_task_features(boq_items, metadata)
    tasks: List[dict] = []

    for task in task_features:
        raw = predict_one_task(
            boq_description=task["boq_description"],
            project_type=task["project_type"],
            site_location=task["site_location"],
            total_floor_area_sqft=task["total_floor_area_sqft"],
            number_of_floors=task["number_of_floors"],
            building_complexity_index=task["building_complexity_index"],
            working_days=task["working_days"],
        )
        tasks.append(
            {
                "task_sequence": int(task["task_sequence"]),
                "task_name": str(task.get("task_name", "")),
                "boq_description": str(task.get("boq_description", "")),
                "boq_amount_rs": int(task.get("boq_amount_rs", 0)),
                "vehicle": raw["vehicle"],
                "machinery": raw["machinery"],
                "labour": raw["labour"],
                "fuel": raw["fuel"],
                "cost_summary": raw["cost_summary"],
            }
        )

    working_days = int(metadata.get("working_days", 5))
    totals = compute_project_totals(tasks, working_days)
    recommendations = generate_waste_recommendations(tasks)
    confidence = compute_confidence_score(float(metadata.get("building_complexity_index", 6.0)))

    response = {
        "project_id": str(metadata.get("project_id", "")),
        "project_name": str(metadata.get("project_name", "")),
        "project_type": str(metadata.get("project_type", "Residential")),
        "site_location": str(metadata.get("site_location", "Colombo")),
        "total_floor_area_sqft": int(metadata.get("total_floor_area_sqft", 3000)),
        "number_of_floors": int(metadata.get("number_of_floors", 1)),
        "building_complexity_index": float(metadata.get("building_complexity_index", 6.0)),
        "working_days": working_days,
        "tasks_detected": len(tasks),
        "confidence_score": confidence,
        "predicted_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "tasks": tasks,
        "project_totals": totals,
        "waste_recommendations": recommendations,
    }
    return PredictionResponse(**response).model_dump()


@router.post("/boq/upload", response_model=PredictionResponse)
async def upload_boq(
    file: UploadFile = File(...),
    project_id: str = Form(...),
    site_location: str = Form(...),
):
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")

    boq_items = _parse_upload(file.filename or "", file_bytes)
    metadata = _metadata_from_project(project_id=project_id, site_location=site_location)
    prediction = _build_prediction(metadata, boq_items)

    mongo_service.save_upload(
        project_id=metadata["project_id"],
        project_name=metadata["project_name"],
        project_type=metadata["project_type"],
        site_location=metadata["site_location"],
        file_name=file.filename or "upload",
        prediction=prediction,
    )
    return PredictionResponse(**prediction)


@router.post("/boq/predict/text", response_model=PredictionResponse)
async def predict_from_boq_text(payload: TextPredictionRequest):
    boq_items = _parse_text_boq(payload.boq_text)
    metadata = _metadata_from_project(project_id=payload.project_id, site_location=payload.site_location)
    prediction = _build_prediction(metadata, boq_items)

    mongo_service.save_upload(
        project_id=metadata["project_id"],
        project_name=metadata["project_name"],
        project_type=metadata["project_type"],
        site_location=metadata["site_location"],
        file_name="manual-text",
        prediction=prediction,
    )
    return PredictionResponse(**prediction)


@router.post("/boq/predict/from-report", response_model=PredictionResponse)
async def predict_from_boq_report(payload: ReportPredictionRequest):
    boq_items = _boq_items_from_report(payload.project_id)
    metadata = _metadata_from_project(project_id=payload.project_id, site_location=payload.site_location)
    prediction = _build_prediction(metadata, boq_items)

    mongo_service.save_upload(
        project_id=metadata["project_id"],
        project_name=metadata["project_name"],
        project_type=metadata["project_type"],
        site_location=metadata["site_location"],
        file_name="boqReport",
        prediction=prediction,
    )
    return PredictionResponse(**prediction)


@router.post("/predict/text", response_model=PredictionResponse)
async def predict_from_text_compat(payload: TextPredictionRequest):
    return await predict_from_boq_text(payload)


@router.get("/models/status", response_model=ModelStatusResponse)
async def model_status():
    base = os.path.join(os.path.dirname(__file__), "..", "ml_models")
    pipeline_exists = os.path.exists(os.path.join(base, "shared_feature_pipeline.pkl"))
    model_1_exists = os.path.exists(os.path.join(base, "model_1_vehicle.pkl"))
    model_2_exists = os.path.exists(os.path.join(base, "model_2_machinery.pkl"))
    model_3_exists = os.path.exists(os.path.join(base, "model_3_labour.pkl"))
    all_loaded = models_loaded() and pipeline_exists and model_1_exists and model_2_exists and model_3_exists
    return ModelStatusResponse(
        shared_feature_pipeline=pipeline_exists,
        model_1_vehicle=model_1_exists,
        model_2_machinery=model_2_exists,
        model_3_labour=model_3_exists,
        all_loaded=all_loaded,
    )


@router.post("/dashboard/save_prediction")
async def save_prediction(payload: Dict[str, Any]):
    prediction = payload.get("prediction") or {}
    project_id = str(payload.get("project_id") or prediction.get("project_id") or "")
    project_name = str(prediction.get("project_name", ""))
    project_type = str(prediction.get("project_type", ""))
    site_location = str(prediction.get("site_location", ""))

    if not project_id or not prediction:
        raise HTTPException(status_code=422, detail="project_id and prediction are required")

    saved = mongo_service.save_upload(
        project_id=project_id,
        project_name=project_name,
        project_type=project_type,
        site_location=site_location,
        file_name="dashboard-save",
        prediction=prediction,
    )
    return {"saved": bool(saved)}


@router.get("/dashboard/history/{project_id}")
async def dashboard_history(project_id: str):
    return mongo_service.get_project_history(project_id)


@router.get("/dashboard/history")
async def dashboard_history_all(limit: int = 500):
    return mongo_service.get_all_history(limit=limit)


@router.get("/dashboard/projects")
async def dashboard_projects():
    if not mongo_service.is_mongo_available():
        detail = mongo_service.get_mongo_error() or "MongoDB unavailable"
        raise HTTPException(status_code=503, detail=f"MongoDB unavailable: {detail}")

    projects = mongo_service.get_projects_catalog()
    return {
        "project_ids": [item["project_id"] for item in projects],
        "projects": projects,
    }


@router.get("/dashboard/summary/{project_id}")
async def dashboard_summary(project_id: str):
    history = mongo_service.get_project_history(project_id)
    if not history:
        raise HTTPException(status_code=404, detail="No predictions found for project")

    latest_prediction = history[0].get("prediction") or {}
    totals = latest_prediction.get("project_totals") or {}
    tasks_detected = int(latest_prediction.get("tasks_detected", 0))

    confidence_values: List[float] = []
    vehicle_types = set()
    machinery_types = set()
    for rec in history:
        pred = rec.get("prediction") or {}
        confidence_values.append(float(pred.get("confidence_score", 0.0)))
        for task in pred.get("tasks", []) or []:
            vehicle_types.add(str(task.get("vehicle", {}).get("vehicle_type", "")))
            machinery_types.add(str(task.get("machinery", {}).get("machinery_type", "")))

    avg_conf = sum(confidence_values) / len(confidence_values) if confidence_values else 0.0

    return {
        "project_id": project_id,
        "total_vehicle_cost": int(totals.get("total_vehicle_cost_rs", 0)),
        "total_machinery_cost": int(totals.get("total_machinery_cost_rs", 0)),
        "total_labour_cost": int(totals.get("total_labour_cost_rs", 0)),
        "total_project_cost": int(totals.get("grand_total_cost_rs", 0)),
        "average_confidence_score": round(avg_conf, 4),
        "total_gang_headcount": int(totals.get("total_gang_headcount_peak", 0)),
        "vehicle_types": sorted([v for v in vehicle_types if v]),
        "machinery_types": sorted([m for m in machinery_types if m]),
        "grand_total": int(totals.get("grand_total_cost_rs", 0)),
        "peak_gang": int(totals.get("total_gang_headcount_peak", 0)),
        "tasks_count": tasks_detected,
    }


@router.post("/generate_procurement_pdf")
async def generate_procurement_pdf(payload: Dict[str, Any]):
    project_id = str(payload.get("project_id", ""))
    if not project_id:
        raise HTTPException(status_code=422, detail="project_id is required")

    prediction = mongo_service.get_latest_prediction(project_id)
    if not prediction:
        raise HTTPException(status_code=404, detail="Prediction not found")

    pdf_bytes = build_procurement_pdf(prediction)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=procurement_{project_id}.pdf"},
    )
