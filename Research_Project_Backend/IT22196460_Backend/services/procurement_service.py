from io import BytesIO
from typing import Any, Dict, List

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

LABOUR_CATALOGUE = {
    "Mason": {"skill": "Skilled Grade I", "rate": 3200},
    "Carpenter": {"skill": "Skilled Grade I", "rate": 3200},
    "Bar Bender": {"skill": "Skilled Grade II", "rate": 2700},
    "Painter": {"skill": "Skilled", "rate": 3500},
    "Plasterer": {"skill": "Skilled Grade I", "rate": 3200},
    "Roofer": {"skill": "Skilled Grade I", "rate": 3200},
    "Tiler": {"skill": "Skilled Grade II", "rate": 2700},
    "Mixer Operator": {"skill": "Semi-Skilled", "rate": 2600},
    "Vibrator Operator": {"skill": "Semi-Skilled", "rate": 2600},
    "Semi-Skilled Labourer": {"skill": "Semi-Skilled", "rate": 2500},
    "General Labourer": {"skill": "Unskilled", "rate": 2400},
    "Cleaning Labourer": {"skill": "Unskilled", "rate": 2550},
    "Foreman": {"skill": "Skilled Grade I", "rate": 3200},
    "Survey Assistant": {"skill": "Semi-Skilled", "rate": 2600},
}

ROLE_MAP = {
    "mason_count": "Mason",
    "carpenter_count": "Carpenter",
    "bar_bender_count": "Bar Bender",
    "plasterer_count": "Plasterer",
    "tiler_count": "Tiler",
    "roofer_count": "Roofer",
    "painter_count": "Painter",
    "mixer_operator_count": "Mixer Operator",
    "vibrator_operator_count": "Vibrator Operator",
    "semi_skilled_labourer_count": "Semi-Skilled Labourer",
    "general_labourer_count": "General Labourer",
    "cleaning_labourer_count": "Cleaning Labourer",
    "foreman_count": "Foreman",
    "survey_assistant_count": "Survey Assistant",
}


def _table_style() -> TableStyle:
    return TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#f4f4f4")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ]
    )


def build_procurement_pdf(prediction: Dict[str, Any]) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=12 * mm,
        rightMargin=12 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
    )
    styles = getSampleStyleSheet()
    story: List[Any] = []

    project_name = str(prediction.get("project_name", ""))
    project_id = str(prediction.get("project_id", ""))
    story.append(Paragraph(f"SmartBOQ Procurement Report - {project_name} ({project_id})", styles["Title"]))
    story.append(Spacer(1, 8))

    tasks = prediction.get("tasks") or []

    story.append(Paragraph("Section 1 - Vehicle Requirements", styles["Heading3"]))
    vehicle_rows = [["Task", "Vehicle Type", "Qty", "Hourly (Rs.)", "Daily (Rs.)", "Fuel L/h", "Daily Total (Rs.)"]]
    for task in tasks:
        vehicle = task.get("vehicle", {})
        vehicle_rows.append(
            [
                str(task.get("task_name", "")),
                str(vehicle.get("vehicle_type", "")),
                int(vehicle.get("vehicle_count", 0)),
                int(vehicle.get("vehicle_hourly_cost_rs", 0)),
                int(vehicle.get("vehicle_daily_rental_rs", 0)),
                float(vehicle.get("vehicle_fuel_lph", 0.0)),
                int(vehicle.get("vehicle_total_daily_cost_rs", 0)),
            ]
        )
    vehicle_table = Table(vehicle_rows, repeatRows=1)
    vehicle_table.setStyle(_table_style())
    story.append(vehicle_table)
    story.append(Spacer(1, 8))

    story.append(Paragraph("Section 2 - Machinery Requirements", styles["Heading3"]))
    machinery_rows = [["Task", "Machinery Type", "Qty", "Hourly (Rs.)", "Daily (Rs.)", "Fuel L/h", "Daily Total (Rs.)"]]
    for task in tasks:
        machinery = task.get("machinery", {})
        machinery_rows.append(
            [
                str(task.get("task_name", "")),
                str(machinery.get("machinery_type", "")),
                int(machinery.get("machinery_count", 0)),
                int(machinery.get("machinery_hourly_cost_rs", 0)),
                int(machinery.get("machinery_daily_rental_rs", 0)),
                float(machinery.get("machinery_fuel_lph", 0.0)),
                int(machinery.get("machinery_total_daily_cost_rs", 0)),
            ]
        )
    machinery_table = Table(machinery_rows, repeatRows=1)
    machinery_table.setStyle(_table_style())
    story.append(machinery_table)
    story.append(Spacer(1, 8))

    story.append(Paragraph("Section 3 - Labour Requirements", styles["Heading3"]))
    labour_rows = [["Task", "Role", "Count", "Skill Level", "Rate/day", "Daily Cost (Rs.)"]]
    for task in tasks:
        labour = task.get("labour", {})
        for key, role in ROLE_MAP.items():
            count = int(labour.get(key, 0))
            if count <= 0:
                continue
            meta = LABOUR_CATALOGUE.get(role, {})
            rate = int(meta.get("rate", 0))
            labour_rows.append(
                [
                    str(task.get("task_name", "")),
                    role,
                    count,
                    str(meta.get("skill", "")),
                    rate,
                    count * rate,
                ]
            )
    labour_table = Table(labour_rows, repeatRows=1)
    labour_table.setStyle(_table_style())
    story.append(labour_table)
    story.append(Spacer(1, 8))

    totals = prediction.get("project_totals", {})
    story.append(Paragraph("Cost Summary", styles["Heading3"]))
    summary_rows = [
        ["Vehicle total", int(totals.get("total_vehicle_cost_rs", 0))],
        ["Machinery total", int(totals.get("total_machinery_cost_rs", 0))],
        ["Labour total", int(totals.get("total_labour_cost_rs", 0))],
        ["Grand total", int(totals.get("grand_total_cost_rs", 0))],
    ]
    summary_table = Table(summary_rows)
    summary_table.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTNAME", (0, 3), (-1, 3), "Helvetica-Bold"),
            ]
        )
    )
    story.append(summary_table)
    story.append(Spacer(1, 4))

    peak_gang = int(totals.get("total_gang_headcount_peak", 0))
    peak_task = str(totals.get("peak_task", ""))
    boq_value = int(totals.get("boq_total_rs", 0))
    confidence = float(prediction.get("confidence_score", 0.0)) * 100
    story.append(Paragraph(f"Peak gang: {peak_gang} persons on {peak_task}", styles["BodyText"]))
    story.append(Paragraph(f"BOQ value: Rs. {boq_value} | Confidence: {confidence:.2f}%", styles["BodyText"]))

    doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()
    return pdf_bytes
