# Smart Logistics Optimization — Python Backend

FastAPI backend for BOQ-based construction resource prediction.

Current runtime behavior on this machine:
- `machinery` predictions use the trained ML model.
- `labor` predictions use the trained ML model.
- `vehicle` predictions currently fall back to heuristics because the vehicle pickle is 2.95 GB and cannot be loaded within available RAM.

## Project Structure

```
boq_backend/
├── main.py                         # FastAPI app entry point
├── requirements.txt
├── ml_models/                      # ← Place your .pkl files here
│   ├── boq_vehicle_prediction_model.pkl
│   ├── labor_prediction_model.pkl
│   └── machinery_prediction_model.pkl
├── models/
│   └── schemas.py                  # Pydantic request/response models
├── routers/
│   └── prediction.py               # API route handlers
├── services/
│   ├── feature_extractor.py        # BOQ → ML feature vector
│   ├── model_service.py            # .pkl loader + predict helpers
│   ├── file_parser.py              # PDF / Excel parsing
│   └── cost_service.py             # Cost estimation + recommendations
└── utils/
    └── lifecycle.py                # App startup/shutdown hooks
```

## Setup

```bash
# 1. Create virtual environment
python -m venv venv

# Linux / macOS
source venv/bin/activate

# Windows PowerShell
.\venv\Scripts\Activate.ps1

# 2. Install dependencies
python -m pip install -r requirements.txt

# 3. Place your trained models in ml_models/
cp /path/to/boq_vehicle_prediction_model.pkl   ml_models/
cp /path/to/labor_prediction_model.pkl          ml_models/
cp /path/to/machinery_prediction_model.pkl      ml_models/

# 4. Run the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: http://localhost:8000/docs

---

## API Endpoints

### POST `/api/v1/predict/text`
Submit BOQ as JSON.

**Request body:**
```json
{
  "project_name": "New Hospital Block",
  "project_type": "building",
  "project_duration_days": 180,
  "site_location": "Kandy",
  "total_floor_area_sqft": 50000,
  "number_of_floors": 3,
  "building_complexity_index": 7,
  "items": [
    {
      "description": "Concrete Grade 25 for columns",
      "unit": "m3",
      "quantity": 150,
      "unit_rate": 42000
    },
    {
      "description": "Steel reinforcement Y16",
      "unit": "kg",
      "quantity": 8500,
      "unit_rate": 220
    },
    {
      "description": "Earthwork excavation for foundation",
      "unit": "m3",
      "quantity": 600,
      "unit_rate": 1800
    }
  ]
}
```

**Response:**
```json
{
  "project_name": "New Hospital Block",
  "total_boq_amount": 8565000.0,
  "total_quantity": 9250.0,
  "item_count": 3,
  "vehicles": {
    "light_vehicles": 3,
    "medium_trucks": 4,
    "heavy_trucks": 5,
    "concrete_mixers": 3,
    "tipper_trucks": 6,
    "total_vehicles": 21,
    "estimated_trips_per_day": 52
  },
  "labor": {
    "unskilled_workers": 68,
    "semi_skilled_workers": 43,
    "skilled_workers": 34,
    "supervisors": 13,
    "engineers": 4,
    "total_headcount": 162,
    "peak_daily_requirement": 194
  },
  "machinery": {
    "excavators": 2,
    "bulldozers": 1,
    "cranes": 1,
    "concrete_pumps": 2,
    "compactors": 1,
    "scaffolding_sets": 4,
    "estimated_machinery_hours_per_day": 72.5,
    "total_equipment_units": 11
  },
  "cost_estimate": {
    "vehicle_cost_lkr": 33390000.0,
    "labor_cost_lkr": 209340000.0,
    "machinery_cost_lkr": 128070000.0,
    "total_logistics_cost_lkr": 370800000.0,
    "currency": "LKR"
  },
  "waste_recommendations": [...],
  "prediction_sources": {
    "vehicle": "fallback: load_failed: MemoryError (2.95 GB model)",
    "labor": "model",
    "machinery": "model"
  },
  "confidence_score": 0.515,
  "model_version": "1.0.0"
}
```

---

### POST `/api/v1/predict/file`
Upload BOQ as PDF or Excel.

**Form fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| file | File | ✅ | .xlsx, .xls, or .pdf |
| project_name | string | ❌ | Project name |
| project_type | string | ❌ | building / road / bridge / civil |
| project_duration_days | int | ❌ | Duration in days |
| site_location | string | ❌ | City in Sri Lanka |
| total_floor_area_sqft | float | ❌ | Total built area used by the ML models |
| number_of_floors | int | ❌ | Building height proxy used by the ML models |
| building_complexity_index | float | ❌ | Complexity score from 1 to 10 |

---

### GET `/api/v1/models/status`
Check if ML models are loaded or using fallback heuristics.

---

## Model Output Format

The backend supports two model output formats:

**Multi-output** (preferred): Model returns an array per resource type
- Vehicle: `[light, medium, heavy, mixer, tipper]`
- Labor: `[unskilled, semi_skilled, skilled, supervisors, engineers]`
- Machinery: `[excavators, bulldozers, cranes, pumps, compactors, scaffolding]`

**Single-output**: Model returns a single total count — the backend
distributes it across categories using project-weighted heuristics.

If a `.pkl` file is missing or fails to load, the backend uses built-in
heuristics so the API remains functional instead of failing the request.

The backend now returns a `prediction_sources` object in every prediction
response so clients can tell which sections came from trained models and
which sections used fallback logic.

The trained models expect per-item project context, including
`total_floor_area_sqft`, `number_of_floors`, and
`building_complexity_index`.

For model loading reliability, keep the runtime `scikit-learn` version in
sync with the version used when the `.pkl` files were created.

## Troubleshooting

- If `pip install -r requirements.txt` fails inside the virtual environment,
  use `python -m pip install -r requirements.txt` instead of `pip`.
- If `/api/v1/models/status` reports `fallback (heuristic)`, verify that:
  - the `.pkl` files exist in `ml_models/`
  - the runtime package versions match the training environment
  - there is enough free RAM to load the model artifact
- If the vehicle model reports `MemoryError`, that is currently a machine
  capacity issue rather than an API bug. Reducing the model size or adding
  more available RAM is required to run that model directly.

---

## Flutter Integration Notes

For file upload from Flutter:
```dart
var request = http.MultipartRequest(
  'POST',
  Uri.parse('$baseUrl/api/v1/predict/file'),
);
request.fields['project_name'] = 'My Project';
request.fields['project_type'] = 'building';
request.fields['project_duration_days'] = '180';
request.fields['site_location'] = 'Colombo';
request.files.add(await http.MultipartFile.fromPath('file', filePath));
var response = await request.send();
```
