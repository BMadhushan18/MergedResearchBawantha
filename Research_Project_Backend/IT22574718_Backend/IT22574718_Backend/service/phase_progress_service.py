import datetime
import math
from typing import Any


class PhaseProgressError(Exception):
    """Domain-level error for phase progress update failures."""

# Date parsing and numeric conversions
def parse_iso_date(value: Any) -> datetime.date | None:
    """Parse YYYY-MM-DD or ISO datetime text into a date."""
    if value is None:
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


# Convert date to ISO string or return None if value is None
def date_to_iso(value: datetime.date | None) -> str | None:
    return value.isoformat() if value is not None else None


# Convert any value to a non-negative float, using default if conversion fails
def _to_non_negative_number(value: Any, default: float = 0.0) -> float:
    try:
        numeric = float(value)
    except Exception:
        numeric = float(default)
    return max(numeric, 0.0)


# Recalculate phase duration and progress based on daily logs
def recalculate_phase_duration(
    phases_durations_col,
    phase_daily_logs_col,
    *,
    uid: str,
    pid: str,
    phase_id: str,
    ) -> dict[str, Any]:

    """
    Recalculate and persist summary progress fields in phase_durations.

    Rules implemented:
    - completedManHours = sum(dailyManHours where workedToday=true)
    - remainingManHours = max(totalEstimatedManHours - completedManHours, 0)
    - progressPercent = round((completedManHours / totalEstimatedManHours) * 100)
    - lastLogDate = latest worked log date
    - updatedEstimatedEndDate = lastLogDate + ceil(remaining / (laborCount * 8))
    - status priority follows business rules
    """

    # Fetch the phase duration document for the given uid/pid/phaseId
    filter_q = {"uid": uid, "pid": pid, "phaseId": phase_id}
    phase_doc = phases_durations_col.find_one(filter_q)
    if not phase_doc:
        raise PhaseProgressError("phase_durations document not found for this uid/pid/phaseId")

    total_estimated_man_hours = _to_non_negative_number(phase_doc.get("totalEstimatedManHours"), 0.0)

    planned_labor_count = int(_to_non_negative_number(phase_doc.get("laborCount"), 0.0))
    if planned_labor_count < 1:
        planned_labor_count = 1

    aggregate_rows = list(
        phase_daily_logs_col.aggregate(
            [
                {
                    "$match": {
                        "uid": uid,
                        "pid": pid,
                        "phaseId": phase_id,
                        "workedToday": True,
                    }
                },
                {
                    "$group": {
                        "_id": None,
                        "completedManHours": {"$sum": {"$ifNull": ["$dailyManHours", 0]}},
                        "lastLogDate": {"$max": "$logDate"},
                    }
                },
            ]
        )
    )

    if aggregate_rows:
        completed_man_hours = _to_non_negative_number(aggregate_rows[0].get("completedManHours"), 0.0)
        last_log_date = parse_iso_date(aggregate_rows[0].get("lastLogDate"))
    else:
        completed_man_hours = 0.0
        last_log_date = parse_iso_date(phase_doc.get("lastLogDate"))

    # Every non-working daily log (workedToday=false) delays expected completion by 1 day.
    skipped_days = phase_daily_logs_col.count_documents(
        {
            "uid": uid,
            "pid": pid,
            "phaseId": phase_id,
            "workedToday": False,
        }
    )

    remaining_man_hours = max(total_estimated_man_hours - completed_man_hours, 0.0)

    if total_estimated_man_hours > 0:
        progress_percent = int(round((completed_man_hours / total_estimated_man_hours) * 100.0))
    else:
        progress_percent = 0
    progress_percent = max(0, min(progress_percent, 100))

    planned_daily_capacity = planned_labor_count * 8
    remaining_days = math.ceil(remaining_man_hours / planned_daily_capacity) if planned_daily_capacity > 0 else 0

    if last_log_date is not None:
        updated_estimated_end_date = last_log_date + datetime.timedelta(days=remaining_days)
    else:
        updated_estimated_end_date = parse_iso_date(phase_doc.get("updatedEstimatedEndDate"))
        if updated_estimated_end_date is None:
            updated_estimated_end_date = parse_iso_date(phase_doc.get("initialEstimatedEndDate"))

    if updated_estimated_end_date is not None and skipped_days > 0:
        updated_estimated_end_date = updated_estimated_end_date + datetime.timedelta(days=int(skipped_days))

    is_completed = bool(phase_doc.get("isCompleted", False))

    if is_completed:
        status = "Completed"
    elif remaining_man_hours == 0 or (
        last_log_date is not None
        and updated_estimated_end_date is not None
        and last_log_date > updated_estimated_end_date
    ):
        status = "Delayed"
    elif completed_man_hours > 0:
        status = "In Progress"
    else:
        status = "Not Started"

    now = datetime.datetime.utcnow().isoformat()
    update_fields = {
        "completedManHours": completed_man_hours,
        "remainingManHours": remaining_man_hours,
        "progressPercent": progress_percent,
        "lastLogDate": date_to_iso(last_log_date),
        "updatedEstimatedEndDate": date_to_iso(updated_estimated_end_date),
        "status": status,
        "updatedAt": now,
    }

    phases_durations_col.update_one(filter_q, {"$set": update_fields})

    response_payload = dict(update_fields)
    response_payload["totalEstimatedManHours"] = total_estimated_man_hours
    response_payload["plannedDailyCapacity"] = planned_daily_capacity
    response_payload["remainingDays"] = remaining_days
    response_payload["skippedDays"] = int(skipped_days)
    response_payload["isCompleted"] = is_completed

    # Derived metrics are intentionally not stored in DB.
    additional_man_hours = max(completed_man_hours - total_estimated_man_hours, 0.0)
    actual_completed_date = parse_iso_date(phase_doc.get("actualCompletedDate"))
    completion_timing = None
    saved_days = 0
    extra_days = 0

    if (
        actual_completed_date is not None
        and updated_estimated_end_date is not None
    ):
        if actual_completed_date < updated_estimated_end_date:
            completion_timing = "completedEarly"
            saved_days = (updated_estimated_end_date - actual_completed_date).days
        elif actual_completed_date == updated_estimated_end_date:
            completion_timing = "completedOnTime"
        else:
            completion_timing = "completedLate"
            extra_days = (actual_completed_date - updated_estimated_end_date).days

    response_payload["derived"] = {
        "additionalManHours": additional_man_hours,
        "savedDays": saved_days,
        "extraDays": extra_days,
        "completionTiming": completion_timing,
    }
    return response_payload
