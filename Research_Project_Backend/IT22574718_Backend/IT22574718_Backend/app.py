"""
IT22574718 Backend Module
Run: python app.py
Port: 8003
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
import jwt
import datetime
import math

from service.duration_service import (
    FoundationDurationService,
    WallDurationService,
    RoofingDurationService,
    DoorWindowDurationService,
    PlasteringDurationService,
    FlooringDurationService,
    PaintingDurationService,
)
from service.phase_progress_service import recalculate_phase_duration, PhaseProgressError
try:
    from backend.IT22574718_Backend.config import (
        FOUNDATION_MODEL_PATH,
        WALL_MODEL_PATH,
        ROOFING_MODEL_PATH,
        DOOR_WINDOW_MODEL_PATH,
        PLASTERING_MODEL_PATH,
        FLOORING_MODEL_PATH,
        PAINTING_MODEL_PATH,
    )
except ModuleNotFoundError:
    from config import (
        FOUNDATION_MODEL_PATH,
        WALL_MODEL_PATH,
        ROOFING_MODEL_PATH,
        DOOR_WINDOW_MODEL_PATH,
        PLASTERING_MODEL_PATH,
        FLOORING_MODEL_PATH,
        PAINTING_MODEL_PATH,
    )

app = Flask(__name__)
CORS(app)

# ─── Config ───────────────────────────────────────────────────────────────────
MONGO_URI = "mongodb+srv://smartConstructiondb:admin123@smartconstructioncluste.fmhajos.mongodb.net/"
DB_NAME = "smartConstructionDB"
JWT_SECRET = "scms_jwt_secret_2026_changeme"
JWT_EXPIRY_DAYS = 30
PORT = 8003   

# ─── MongoDB connection ───────────────────────────────────────────────────────
client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=10000)
db = client[DB_NAME]

phases_durations_col = db["phase_durations"]
phase_daily_logs_col = db["phase_daily_logs"]
boq_report_col = db["boqReport"]
boq_predictions_col = db["boq_predictions"]

# prevent duplicate records.

phases_durations_col.create_index([("uid", 1), ("pid", 1), ("phaseId", 1)], unique=True)

phase_daily_logs_col.create_index([("uid", 1), ("pid", 1), ("phaseId", 1), ("logDate", 1)],unique=True,)

# ─── Services ─────────────────────────────────────────────────────────────────
foundation_service = FoundationDurationService(FOUNDATION_MODEL_PATH)
wall_service = WallDurationService(WALL_MODEL_PATH)
roofing_service = RoofingDurationService(ROOFING_MODEL_PATH)
door_window_service = DoorWindowDurationService(DOOR_WINDOW_MODEL_PATH)
plastering_service = PlasteringDurationService(PLASTERING_MODEL_PATH)
flooring_service = FlooringDurationService(FLOORING_MODEL_PATH)
painting_service = PaintingDurationService(PAINTING_MODEL_PATH)


# ─── Helpers ──────────────────────────────────────────────────────────────────
def verify_token(token: str):
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def get_current_uid():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[7:]
    payload = verify_token(token)
    return payload["uid"] if payload else None


def bson_to_dict(doc):
    if doc is None:
        return {}
    d = dict(doc)
    if "_id" in d:
        d["_id"] = str(d["_id"])
    return d


def err(msg: str, code: int = 400):
    return jsonify({"error": msg}), code


def parse_iso_date(value):
    if not value:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        if len(text) == 10:
            return datetime.date.fromisoformat(text)
        return datetime.datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except Exception:
        return None


def date_to_iso(value):
    if value is None:
        return None
    return value.isoformat()


# ─── Health Check───────────────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    try:
        client.admin.command("ping")
        return jsonify({
            "status": "ok",
            "module": "IT22574718_Backend",
            "db": DB_NAME,
            "mongo": "connected"
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "detail": str(e)}), 500
    

# ─── BOQ Report Material Cost ───────────────────────────────────────
@app.route("/boq-report/grand-total/<pid>", methods=["GET"])
def get_boq_report_grand_total(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    project_id = str(pid).strip()
    if not project_id:
        return err("pid is required", 400)

    try:
        doc = boq_report_col.find_one(
            {"projectId": project_id},
            sort=[("updatedAt", -1), ("createdAt", -1)],
        )
        if not doc:
            return err("boqReport not found for project", 404)

        value = doc.get("grandTotal", 0)
        try:
            grand_total = float(value)
        except Exception:
            return err("Invalid grandTotal value in boqReport", 500)

        return jsonify(
            {
                "projectId": project_id,
                "grandTotal": grand_total,
            }
        ), 200
    except Exception as e:
        return err(str(e), 400)


# ─── BOQ Prediction Cost Breakdown ──────────────────────────────────────────
@app.route("/boq-predictions/costs/<pid>", methods=["GET"])
def get_boq_prediction_costs(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    project_id = str(pid).strip()
    if not project_id:
        return err("pid is required", 400)

    try:
        doc = boq_predictions_col.find_one(
            {"$or": [{"project_id": project_id}, {"projectId": project_id}]},
            sort=[("updatedAt", -1), ("createdAt", -1)],
        )
        if not doc:
            return err("boq_predictions not found for project", 404)

        prediction_root = doc.get("prediction") or doc.get("predictions") or {}
        project_totals = prediction_root.get("project_totals") or doc.get("project_totals") or {}
        cost_estimate = prediction_root.get("cost_estimate") or doc.get("cost_estimate") or {}

        def to_float(value):
            try:
                return float(value)
            except Exception:
                return 0.0

        labor_cost = to_float(
            project_totals.get("total_labour_cost_rs")
            or project_totals.get("total_labor_cost_rs")
            or cost_estimate.get("labor_cost_lkr")
            or cost_estimate.get("labour_cost_lkr")
        )
        machinery_cost = to_float(
            project_totals.get("total_machinery_cost_rs")
            or cost_estimate.get("machinery_cost_lkr")
        )
        vehicle_cost = to_float(
            project_totals.get("total_vehicle_cost_rs")
            or cost_estimate.get("vehicle_cost_lkr")
        )
        return jsonify(
            {
                "projectId": project_id,
                "total_labour_cost_rs": labor_cost,
                "total_machinery_cost_rs": machinery_cost,
                "total_vehicle_cost_rs": vehicle_cost,
                "labor_cost_lkr": labor_cost,
                "machinery_cost_lkr": machinery_cost,
                "vehicle_cost_lkr": vehicle_cost,
            }
        ), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Foundation Prediction ────────────────────────────────────────────────────
@app.route("/ml/predict-foundation", methods=["POST"])
def predict_foundation():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = foundation_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Wall Prediction ──────────────────────────────────────────────────────────
@app.route("/ml/predict-wall", methods=["POST"])
def predict_wall():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = wall_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Roof Prediction ──────────────────────────────────────────────────────────
@app.route("/ml/predict-roof", methods=["POST"])
def predict_roof():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = roofing_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Door/Window Prediction ───────────────────────────────────────────────────
@app.route("/ml/predict-door-window", methods=["POST"])
def predict_door_window():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = door_window_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Plastering Prediction ────────────────────────────────────────────────────
@app.route("/ml/predict-plastering", methods=["POST"])
def predict_plastering():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = plastering_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Flooring Prediction ──────────────────────────────────────────────────────
@app.route("/ml/predict-flooring", methods=["POST"])
def predict_flooring():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = flooring_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Painting Prediction ──────────────────────────────────────────────────────
@app.route("/ml/predict-painting", methods=["POST"])
def predict_painting():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    try:
        duration_days = painting_service.predict(body)
        return jsonify({"duration_days": duration_days}), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Save Phase Duration ─────────────

@app.route("/phase-durations/save", methods=["POST"])

def save_phase_duration():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}

    required_fields = ["pid", "phaseId", "phaseName", "durationDays", "laborCount"]
    missing = [f for f in required_fields if f not in body]
    if missing:
        return err(f"Missing fields: {missing}", 400)

    pid = str(body["pid"]).strip()
    phase_id = str(body["phaseId"]).strip()
    phase_name = str(body["phaseName"]).strip()

    try:
        duration_days = int(body["durationDays"])
        labor_count = int(body["laborCount"])
    except Exception:
        return err("durationDays and laborCount must be integers", 400)

    duration_days = max(duration_days, 1)
    labor_count = max(labor_count, 1)

    # check existing doc
    now = datetime.datetime.utcnow().isoformat()
    existing_doc = phases_durations_col.find_one({"uid": uid, "pid": pid, "phaseId": phase_id})

    # check existing doc lastlogdate
    last_log_date = parse_iso_date(body.get("lastLogDate"))
    if last_log_date is None and existing_doc:
        last_log_date = parse_iso_date(existing_doc.get("lastLogDate"))
    if last_log_date is None:
        latest_phase_log = phase_daily_logs_col.find_one(
            {"uid": uid, "pid": pid, "phaseId": phase_id},
            sort=[("logDate", -1), ("updatedAt", -1)],
        )
        if latest_phase_log:
            last_log_date = parse_iso_date(latest_phase_log.get("logDate"))

    total_estimated_man_hours = labor_count * 8 * duration_days
 
    start_date = parse_iso_date(body.get("startDate"))
    if start_date is None and existing_doc:
        start_date = parse_iso_date(existing_doc.get("startDate"))


    initial_estimated_end_date = None
    if start_date is not None:
        initial_estimated_end_date = start_date + datetime.timedelta(days=max(duration_days - 1, 0))

    try:
        completed_man_hours = float(
            body.get(
                "completedManHours",
                existing_doc.get("completedManHours", 0) if existing_doc else 0,
            )
        )
    except Exception:
        return err("completedManHours must be a number", 400)

    raw_is_completed = body.get(
        "isCompleted",
        existing_doc.get("isCompleted", False) if existing_doc else False,
    )
    if isinstance(raw_is_completed, bool):
        is_completed = raw_is_completed
    elif isinstance(raw_is_completed, str):
        is_completed = raw_is_completed.strip().lower() in ["true", "1", "yes"]
    else:
        is_completed = bool(raw_is_completed)

    actual_completed_date_input = body.get("actualCompletedDate")
    if actual_completed_date_input is None and existing_doc:
        actual_completed_date = parse_iso_date(existing_doc.get("actualCompletedDate"))
    else:
        actual_completed_date = parse_iso_date(actual_completed_date_input)

    if not is_completed:
        actual_completed_date = None

    completed_man_hours = max(0.0, min(completed_man_hours, float(total_estimated_man_hours)))
    remaining_man_hours = max(0.0, float(total_estimated_man_hours) - completed_man_hours)

    progress_percent = 0.0
    if total_estimated_man_hours > 0:
        progress_percent = (completed_man_hours / float(total_estimated_man_hours)) * 100.0
    progress_percent = max(0.0, min(progress_percent, 100.0))

    updated_end_date_input = parse_iso_date(body.get("updatedEstimatedEndDate"))
    if updated_end_date_input is None and existing_doc:
        updated_end_date_input = parse_iso_date(existing_doc.get("updatedEstimatedEndDate"))

    if updated_end_date_input is not None:
        updated_estimated_end_date = updated_end_date_input
    elif start_date is None:
        updated_estimated_end_date = None
    else:
        remaining_days = math.ceil(remaining_man_hours / (labor_count * 8)) if labor_count > 0 else duration_days
        updated_estimated_end_date = datetime.datetime.utcnow().date() + datetime.timedelta(days=remaining_days)

    status = (body.get("status") or (existing_doc.get("status") if existing_doc else "")).strip().lower()
    if not status:
        if is_completed:
            status = "completed"
        elif progress_percent >= 100.0:
            status = "completed"
        elif progress_percent > 0.0:
            status = "in_progress"
        else:
            status = "pending"

    filter_q = {"uid": uid, "pid": pid, "phaseId": phase_id}

    update_doc = {
        "$set": {
            "uid": uid,
            "pid": pid,
            "phaseId": phase_id,
            "phaseName": phase_name,
            "durationDays": duration_days,
            "laborCount": labor_count,
            "totalEstimatedManHours": total_estimated_man_hours,
            "startDate": date_to_iso(start_date),
            "initialEstimatedEndDate": date_to_iso(initial_estimated_end_date),
            "completedManHours": completed_man_hours,
            "remainingManHours": remaining_man_hours,
            "progressPercent": round(progress_percent, 2),
            "updatedEstimatedEndDate": date_to_iso(updated_estimated_end_date),
            "lastLogDate": date_to_iso(last_log_date),
            "status": status,
            "isCompleted": is_completed,
            "actualCompletedDate": date_to_iso(actual_completed_date),
            "updatedAt": now,
        },
        "$setOnInsert": {
            "createdAt": now,
        }
    }

    try:
        phases_durations_col.update_one(filter_q, update_doc, upsert=True)
        return jsonify({"saved": True}), 200
    except Exception as e:
        return err(str(e), 400)


# List Phase Durations for a project
@app.route("/phase-durations/<pid>", methods=["GET"])
def list_phase_durations(pid):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    docs = list(phases_durations_col.find({"uid": uid, "pid": str(pid)}))
    return jsonify([bson_to_dict(d) for d in docs]), 200

# Mark phase as completed with actual completed date (completed earlier or later than the estimated end date).
@app.route("/phase-durations/complete", methods=["POST"])
def complete_phase_duration():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}
    pid = str(body.get("pid", "")).strip()
    phase_id = str(body.get("phaseId", "")).strip()

    if not pid or not phase_id:
        return err("pid and phaseId are required", 400)

    actual_completed_date = parse_iso_date(body.get("actualCompletedDate"))
    if actual_completed_date is None:
        actual_completed_date = datetime.datetime.utcnow().date()

    filter_q = {"uid": uid, "pid": pid, "phaseId": phase_id}
    existing_doc = phases_durations_col.find_one(filter_q)
    if not existing_doc:
        return err("phase_durations document not found", 404)

    now = datetime.datetime.utcnow().isoformat()
    update_result = phases_durations_col.update_one(
        filter_q,
        {
            "$set": {
                "isCompleted": True,
                "actualCompletedDate": date_to_iso(actual_completed_date),
                "status": "Completed",
                "progressPercent": 100,
                "remainingManHours": 0,
                "updatedAt": now,
            }
        },
    )

    if update_result.matched_count == 0:
        return err("phase_durations document not found", 404)

    updated = phases_durations_col.find_one(filter_q)
    return jsonify({"updated": True, "phaseDuration": bson_to_dict(updated)}), 200


# ─── Save Phase Daily Log ─────────────────────────────────────────────────
@app.route("/phase-daily-logs/save", methods=["POST"])

def save_phase_daily_log():
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    body = request.json or {}

    required_fields = ["pid", "phaseId", "phaseName", "logDate", "workedToday"]
    missing = [f for f in required_fields if f not in body]
    if missing:
        return err(f"Missing fields: {missing}", 400)

    pid = str(body.get("pid", "")).strip()
    phase_id = str(body.get("phaseId", "")).strip()
    phase_name = str(body.get("phaseName", "")).strip()
    log_date = parse_iso_date(body.get("logDate"))

    if not pid or not phase_id or not phase_name:
        return err("pid, phaseId and phaseName are required", 400)
    if log_date is None:
        return err("Invalid logDate. Expected YYYY-MM-DD or ISO date.", 400)

    worked_today = bool(body.get("workedToday"))


    if worked_today:
        work_type = (body.get("workType") or "").strip()
        if work_type and work_type not in ["Full Day", "Half Day"]:
            return err("workType must be 'Full Day' or 'Half Day'", 400)

        try:
            labor_count = max(0, int(body.get("laborCount", 0)))
            default_hours = 8 if work_type == "Full Day" else 4 if work_type == "Half Day" else 0
            hours_per_labor = max(0, int(body.get("hoursPerLabor", default_hours)))
        except Exception:
            return err("laborCount and hoursPerLabor must be integers", 400)


        daily_man_hours = labor_count * hours_per_labor
        skip_reason = None

    else:
        labor_count = 0
        work_type = None
        hours_per_labor = 0
        daily_man_hours = 0
        skip_reason = body.get("skipReason")
        if skip_reason is not None:
            skip_reason = str(skip_reason).strip() or None

    now = datetime.datetime.utcnow().isoformat()
    filter_q = {
        "uid": uid,
        "pid": pid,
        "phaseId": phase_id,
        "logDate": date_to_iso(log_date),
    }


    update_doc = {
        "$set": {
            "uid": uid,
            "pid": pid,
            "phaseId": phase_id,
            "phaseName": phase_name,
            "logDate": date_to_iso(log_date),
            "workedToday": worked_today,
            "laborCount": labor_count,
            "workType": work_type,
            "hoursPerLabor": hours_per_labor,
            "dailyManHours": daily_man_hours,
            "skipReason": skip_reason,
            "updatedAt": now,
        },
        "$setOnInsert": {
            "createdAt": now,
        },
    }

    try:
        phase_daily_logs_col.update_one(filter_q, update_doc, upsert=True)

        summary = recalculate_phase_duration(
            phases_durations_col,
            phase_daily_logs_col,
            uid=uid,
            pid=pid,
            phase_id=phase_id,
        )

        return jsonify({
            "saved": True,
            "dailyLog": {
                "uid": uid,
                "pid": pid,
                "phaseId": phase_id,
                "phaseName": phase_name,
                "logDate": date_to_iso(log_date),
                "workedToday": worked_today,
                "laborCount": labor_count,
                "hoursPerLabor": hours_per_labor,
                "workType": work_type,
                "dailyManHours": daily_man_hours,
                "skipReason": skip_reason,
            },
            "phaseDuration": summary,
        }), 200
    except PhaseProgressError as e:
        return err(str(e), 404)
    except Exception as e:
        return err(str(e), 400)


# ─── Get Recent Phase Daily Logs ─────────────────────────────────────────────
@app.route("/phase-daily-logs/recent/<pid>/<phase_id>", methods=["GET"])

def get_recent_phase_daily_logs(pid, phase_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    pid = str(pid).strip()
    phase_id = str(phase_id).strip()
    if not pid or not phase_id:
        return err("pid and phase_id are required", 400)

    try:
        limit = int(request.args.get("limit", 7))
    except Exception:
        limit = 7

    limit = max(1, min(limit, 50))

    try:
        docs = list(
            phase_daily_logs_col.find(
                {
                    "uid": uid,
                    "pid": pid,
                    "phaseId": phase_id,
                }
            )
            .sort([("logDate", -1), ("updatedAt", -1)])
            .limit(limit)
        )
        return jsonify([bson_to_dict(d) for d in docs]), 200
    except Exception as e:
        return err(str(e), 400)


# ─── Get Completed Phase Days Count ─────────────────────────────────────────
@app.route("/phase-daily-logs/completed-days/<pid>/<phase_id>", methods=["GET"])

def get_completed_phase_days(pid, phase_id):
    uid = get_current_uid()
    if not uid:
        return err("Unauthorized", 401)

    pid = str(pid).strip()
    phase_id = str(phase_id).strip()
    if not pid or not phase_id:
        return err("pid and phase_id are required", 400)

    try:
        completed_days = phase_daily_logs_col.count_documents(
            {
                "uid": uid,
                "pid": pid,
                "phaseId": phase_id,
                "workedToday": True,
            }
        )
        return jsonify({"completedDays": int(completed_days)}), 200
    except Exception as e:
        return err(str(e), 400)


if __name__ == "__main__":
    import sys
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    print("\nIT22574718 Backend Module")
    print(f"   DB  : {DB_NAME}")
    print(f"   URL : http://0.0.0.0:{PORT}")
    print(f"   Health: http://localhost:{PORT}/health\n")
    app.run(host="0.0.0.0", port=PORT, debug=True, use_reloader=False)