from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class BOQItem(BaseModel):
    description: str = ""
    unit: Optional[str] = None
    quantity: float = 0.0
    unit_rate: Optional[float] = None
    amount: Optional[float] = None


class BOQUploadRequest(BaseModel):
    project_id: str
    project_name: str
    project_type: str = "Residential"
    site_location: str = "Colombo"
    total_floor_area_sqft: int = 3000
    number_of_floors: int = 1
    building_complexity_index: float = 6.0
    working_days: int = 5


class BOQTextPredictRequest(BOQUploadRequest):
    boq_items: List[Dict[str, Any]] = Field(default_factory=list)


class VehicleResult(BaseModel):
    vehicle_type: str
    vehicle_count: int
    vehicle_purpose: str
    vehicle_hourly_cost_rs: int
    vehicle_daily_rental_rs: int
    vehicle_fuel_lph: float
    vehicle_total_daily_cost_rs: int


class MachineryResult(BaseModel):
    machinery_type: str
    machinery_count: int
    machinery_purpose: str
    machinery_hourly_cost_rs: int
    machinery_daily_rental_rs: int
    machinery_fuel_lph: float
    machinery_total_daily_cost_rs: int


class LabourGangResult(BaseModel):
    mason_count: int = 0
    carpenter_count: int = 0
    bar_bender_count: int = 0
    plasterer_count: int = 0
    tiler_count: int = 0
    roofer_count: int = 0
    painter_count: int = 0
    mixer_operator_count: int = 0
    vibrator_operator_count: int = 0
    semi_skilled_labourer_count: int = 0
    general_labourer_count: int = 0
    cleaning_labourer_count: int = 0
    foreman_count: int = 0
    survey_assistant_count: int = 0
    total_skilled: int = 0
    total_semi_skilled: int = 0
    total_unskilled: int = 0
    total_gang: int = 0
    labour_daily_cost_rs: int = 0


class FuelAnalysis(BaseModel):
    vehicle_fuel_lph_total: float
    machinery_fuel_lph_total: float
    total_fuel_lph: float
    total_fuel_per_day_litres: float
    fuel_cost_per_day_rs: float
    efficiency_rating: str


class CostSummary(BaseModel):
    vehicle_daily_cost_rs: int
    machinery_daily_cost_rs: int
    labour_daily_cost_rs: int
    total_daily_cost_rs: int
    working_days: int
    task_total_cost_rs: int


class WasteRecommendation(BaseModel):
    category: str
    recommendation: str
    estimated_saving_pct: float


class TaskPrediction(BaseModel):
    task_sequence: int
    task_name: str
    boq_description: str
    boq_amount_rs: int
    vehicle: VehicleResult
    machinery: MachineryResult
    labour: LabourGangResult
    fuel: FuelAnalysis
    cost_summary: CostSummary


class ProjectTotals(BaseModel):
    total_vehicle_cost_rs: int
    total_machinery_cost_rs: int
    total_labour_cost_rs: int
    total_daily_cost_rs: int
    grand_total_cost_rs: int
    total_gang_headcount_peak: int
    peak_task: str
    average_fuel_per_day_litres: float
    boq_total_rs: int


class PredictionResponse(BaseModel):
    project_id: str
    project_name: str
    project_type: str
    site_location: str
    total_floor_area_sqft: int
    number_of_floors: int
    building_complexity_index: float
    working_days: int
    tasks_detected: int
    confidence_score: float
    predicted_at: str
    tasks: List[TaskPrediction]
    project_totals: ProjectTotals
    waste_recommendations: List[WasteRecommendation]


class ModelStatusResponse(BaseModel):
    shared_feature_pipeline: bool
    model_1_vehicle: bool
    model_2_machinery: bool
    model_3_labour: bool
    all_loaded: bool
