from typing import Dict, List


def compute_project_totals(tasks: List[dict], working_days: int) -> Dict[str, object]:
    total_vehicle = 0
    total_machinery = 0
    total_labour = 0
    total_daily = 0
    grand_total = 0
    peak_gang = 0
    peak_task = ""
    fuel_per_day_sum = 0.0
    boq_total = 0

    for task in tasks:
        cost = task.get("cost_summary", {})
        labour = task.get("labour", {})
        fuel = task.get("fuel", {})

        task_vehicle = int(cost.get("vehicle_daily_cost_rs", 0))
        task_machinery = int(cost.get("machinery_daily_cost_rs", 0))
        task_labour = int(cost.get("labour_daily_cost_rs", 0))
        task_daily = int(cost.get("total_daily_cost_rs", 0))
        task_total = int(cost.get("task_total_cost_rs", task_daily * working_days))

        total_vehicle += task_vehicle
        total_machinery += task_machinery
        total_labour += task_labour
        total_daily += task_daily
        grand_total += task_total

        gang = int(labour.get("total_gang", 0))
        if gang > peak_gang:
            peak_gang = gang
            peak_task = str(task.get("task_name", ""))

        fuel_per_day_sum += float(fuel.get("total_fuel_per_day_litres", 0.0))
        boq_total += int(task.get("boq_amount_rs", 0))

    avg_fuel_per_day = round(fuel_per_day_sum / len(tasks), 2) if tasks else 0.0

    return {
        "total_vehicle_cost_rs": int(total_vehicle),
        "total_machinery_cost_rs": int(total_machinery),
        "total_labour_cost_rs": int(total_labour),
        "total_daily_cost_rs": int(total_daily),
        "grand_total_cost_rs": int(grand_total),
        "total_gang_headcount_peak": int(peak_gang),
        "peak_task": peak_task,
        "average_fuel_per_day_litres": avg_fuel_per_day,
        "boq_total_rs": int(boq_total),
    }


def generate_waste_recommendations(tasks: List[dict]) -> List[dict]:
    if not tasks:
        return [
            {
                "category": "Vehicle Utilisation",
                "recommendation": "Pre-schedule vehicle dispatch to eliminate idle waiting between phases.",
                "estimated_saving_pct": 10.0,
            },
            {
                "category": "Machinery Idle Time",
                "recommendation": "Stagger machinery deployment across adjacent tasks to prevent idle time.",
                "estimated_saving_pct": 12.0,
            },
            {
                "category": "Labour Allocation",
                "recommendation": "Cross-train semi-skilled workers to reduce transition delays between tasks.",
                "estimated_saving_pct": 6.0,
            },
            {
                "category": "Fuel Efficiency",
                "recommendation": "Maintain current fuel protocols. Schedule equipment servicing before project start.",
                "estimated_saving_pct": 8.0,
            },
        ]

    vehicle_by_type: Dict[str, List[str]] = {}
    for task in tasks:
        vehicle_type = str(task.get("vehicle", {}).get("vehicle_type", ""))
        if not vehicle_type:
            continue
        vehicle_by_type.setdefault(vehicle_type, []).append(str(task.get("task_name", "")))

    shared_vehicle_rec = "Pre-schedule vehicle dispatch to eliminate idle waiting between phases."
    shared_vehicle_pct = 10.0
    for vehicle_type, task_names in vehicle_by_type.items():
        if len(task_names) >= 2:
            shared_vehicle_rec = (
                f"Coordinate {vehicle_type} trips across tasks {task_names[0]} and {task_names[1]} to reduce idle time."
            )
            shared_vehicle_pct = 14.0
            break

    max_machinery_task = max(tasks, key=lambda t: int(t.get("machinery", {}).get("machinery_count", 0)))
    max_machinery_type = str(max_machinery_task.get("machinery", {}).get("machinery_type", "machinery"))
    max_machinery_name = str(max_machinery_task.get("task_name", "task"))
    max_machinery_count = int(max_machinery_task.get("machinery", {}).get("machinery_count", 0))
    machinery_pct = min(18.0, max(12.0, 12.0 + max_machinery_count))

    peak_gang_task = max(tasks, key=lambda t: int(t.get("labour", {}).get("total_gang", 0)))
    peak_gang_value = int(peak_gang_task.get("labour", {}).get("total_gang", 0))
    peak_gang_name = str(peak_gang_task.get("task_name", "task"))
    if peak_gang_value > 35:
        labour_rec = f"Peak gang of {peak_gang_value} in '{peak_gang_name}' creates supervision risk. Split into sub-gangs."
        labour_pct = 12.0
    else:
        labour_rec = "Cross-train semi-skilled workers to reduce transition delays between tasks."
        labour_pct = 8.0

    high_fuel_count = sum(
        1
        for t in tasks
        if str(t.get("fuel", {}).get("efficiency_rating", "")) in {"Needs Optimisation", "Fair"}
    )
    if high_fuel_count >= 2:
        fuel_pct = min(20.0, max(8.0, 8.0 + (high_fuel_count * 2.0)))
        fuel_rec = f"{high_fuel_count} tasks rated high fuel consumption. Engine-off idle policy could save {fuel_pct:.1f}%."
    else:
        fuel_pct = 9.0
        fuel_rec = "Maintain current fuel protocols. Schedule equipment servicing before project start."

    return [
        {
            "category": "Vehicle Utilisation",
            "recommendation": shared_vehicle_rec,
            "estimated_saving_pct": round(shared_vehicle_pct, 1),
        },
        {
            "category": "Machinery Idle Time",
            "recommendation": f"Stagger {max_machinery_type} deployment in '{max_machinery_name}' with adjacent tasks to prevent idle time.",
            "estimated_saving_pct": round(machinery_pct, 1),
        },
        {
            "category": "Labour Allocation",
            "recommendation": labour_rec,
            "estimated_saving_pct": round(labour_pct, 1),
        },
        {
            "category": "Fuel Efficiency",
            "recommendation": fuel_rec,
            "estimated_saving_pct": round(fuel_pct, 1),
        },
    ]


def compute_confidence_score(building_complexity_index: float) -> float:
    score = 0.82 + (10.0 - float(building_complexity_index)) * 0.015
    score = max(0.75, min(0.98, score))
    return round(score, 4)
