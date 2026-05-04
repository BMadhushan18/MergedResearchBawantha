from fastapi import APIRouter, HTTPException, BackgroundTasks, Query
from typing import Optional, List
from services.retrain_service import RetrainService
from services import mongo_service

router = APIRouter(prefix="/admin/retrain", tags=["Admin Retraining"])
retrain_service = RetrainService()

@router.get("/status")
async def get_status():
    """Returns current retraining status and progress."""
    status = retrain_service.get_status()
    # Add pending changes count
    status["pending_changes"] = mongo_service.get_pending_changes_count()
    return status

@router.post("/trigger")
async def trigger_retrain(
    background_tasks: BackgroundTasks,
    model: Optional[str] = Query(None, description="Specific model to retrain (vehicle/machinery/labour)")
):
    """Manually triggers a retraining job."""
    if retrain_service.status == "running":
        raise HTTPException(status_code=400, detail="Retraining is already in progress")
    
    background_tasks.add_task(retrain_service.run_retrain, "manual", model)
    return {"status": "success", "message": "Retraining job started in background"}

@router.get("/history")
async def get_history(limit: int = 20):
    """Returns the last retrain runs with metrics."""
    return mongo_service.get_retrain_history(limit)

@router.post("/cost-params/fuel")
async def update_fuel(fuel_type: str, value: float, background_tasks: BackgroundTasks):
    """Updates price for a specific fuel type and triggers auto-retrain queue."""
    mongo_service.update_fuel_price(fuel_type, value)
    await retrain_service.queue_retrain("fuel", f"{fuel_type} price updated to {value}")
    return {"status": "success", "message": f"{fuel_type} price updated. Retrain queued."}

@router.post("/cost-params/labour")
async def update_labour(role: str, rate: float, background_tasks: BackgroundTasks):
    """Updates labour rate and triggers auto-retrain queue."""
    mongo_service.update_labour_rate(role, rate)
    await retrain_service.queue_retrain("labour", f"Labour rate for {role} updated to {rate}")
    return {"status": "success", "message": "Labour rate updated. Retrain queued."}

@router.post("/cost-params/machinery")
async def update_machinery_cost(m_type: str, daily_rate: float, fuel_lph: float, background_tasks: BackgroundTasks):
    """Updates machinery daily rate and fuel L/hr."""
    # Assuming a collection machinery_catalogue or similar
    mongo_service._get_db()["machinery_catalogue"].update_one(
        {"type": m_type},
        {"$set": {"machinery_daily_rental": daily_rate, "machinery_fuel_lph": fuel_lph}},
        upsert=True
    )
    await retrain_service.queue_retrain("machinery", f"Machinery {m_type} costs updated")
    return {"status": "success", "message": "Machinery costs updated."}

@router.post("/records/vehicle")
async def add_vehicle_record(data: dict, background_tasks: BackgroundTasks):
    """Adds a new vehicle record to the training dataset."""
    mongo_service._get_db()["vehicle_records"].insert_one(data)
    await retrain_service.queue_retrain("vehicle", f"New vehicle record added: {data.get('vehicle_type')}")
    return {"status": "success", "message": "Vehicle record added."}

@router.post("/records/machinery")
async def add_machinery_record(data: dict, background_tasks: BackgroundTasks):
    """Adds a new machinery record to the training dataset."""
    mongo_service._get_db()["machinery_records"].insert_one(data)
    await retrain_service.queue_retrain("machinery", f"New machinery record added: {data.get('type')}")
    return {"status": "success", "message": "Machinery record added."}

@router.post("/records/material")
async def add_material_item(data: dict, background_tasks: BackgroundTasks):
    """Adds a new BOQ material item/keyword to the NLP vocabulary."""
    mongo_service._get_db()["materials"].insert_one(data)
    await retrain_service.queue_retrain("nlp", f"New material keyword added: {data.get('description')}")
    return {"status": "success", "message": "Material item added."}
