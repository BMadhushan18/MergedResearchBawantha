"""
BOQ File Parser — extracts BOQ items from PDF and Excel uploads.

Supports:
  - .xlsx / .xls  via openpyxl / pandas
  - .pdf          via pdfplumber (text extraction + heuristic row parsing)
"""

import re
import io
import logging
from typing import List, Optional, Tuple
from models.schemas import BOQItem

logger = logging.getLogger(__name__)


# ─── Excel Parsing ───────────────────────────────────────────────────

def parse_excel(file_bytes: bytes) -> List[BOQItem]:
    """Parse BOQ from Excel file bytes. Returns list of BOQItem."""
    import pandas as pd

    # Try Excel first, then fall back to CSV for text-based spreadsheet uploads.
    try:
        df = pd.read_excel(io.BytesIO(file_bytes), header=None)
    except Exception:
        df = pd.read_csv(io.BytesIO(file_bytes), header=None)
    items = []

    # Try to auto-detect header row
    header_row = _find_header_row(df)
    if header_row is not None:
        df.columns = df.iloc[header_row]
        df = df.iloc[header_row + 1:].reset_index(drop=True)
        df.columns = [str(c).lower().strip() for c in df.columns]
        items = _extract_from_dataframe(df)
    else:
        # Raw scan: look for rows with description + numeric values
        items = _raw_scan_excel(df)

    logger.info(f"Excel parsed: {len(items)} BOQ items found")
    return items


def _find_header_row(df) -> Optional[int]:
    """Look for a row containing common BOQ column headers."""
    header_keywords = ["description", "item", "quantity", "unit", "rate", "amount", "no", "qty"]
    for i, row in df.iterrows():
        row_text = " ".join(str(v).lower() for v in row.values if v is not None)
        matches = sum(1 for kw in header_keywords if kw in row_text)
        if matches >= 3:
            return int(i)
    return None


def _extract_from_dataframe(df) -> List[BOQItem]:
    items = []
    col_map = _map_columns(list(df.columns))

    desc_col = col_map.get("description")
    qty_col = col_map.get("quantity")
    unit_col = col_map.get("unit")
    rate_col = col_map.get("unit_rate")
    amount_col = col_map.get("amount")

    if desc_col is None or qty_col is None:
        return _raw_scan_excel(df)

    for _, row in df.iterrows():
        desc = str(row.get(desc_col, "") or "").strip()
        if not desc or len(desc) < 3:
            continue

        qty = _to_float(row.get(qty_col))
        if qty is None or qty <= 0:
            continue

        items.append(BOQItem(
            description=desc,
            unit=str(row.get(unit_col, "") or "").strip() if unit_col else None,
            quantity=qty,
            unit_rate=_to_float(row.get(rate_col)) if rate_col else None,
            amount=_to_float(row.get(amount_col)) if amount_col else None,
        ))

    return items


def _map_columns(columns: List[str]) -> dict:
    """Map normalized column names to their actual names."""
    def normalize(value: str) -> str:
        return re.sub(r"\s+", " ", str(value).lower().strip())

    normalized_columns = [(col, normalize(col)) for col in columns]
    mapping = {}

    exact_patterns = {
        "description": ["description", "item description", "work description", "particulars"],
        "quantity": ["quantity", "qty", "qty.", "amount (qty)"],
        "unit": ["unit", "uom", "unit of measure"],
        "unit_rate": ["unit rate", "rate", "rate-cost", "unit_rate", "price", "unit price"],
        "amount": ["amount", "total amount", "total", "value"],
    }
    fallback_patterns = {
        "description": ["desc", "description", "particulars", "details", "scope of work", "work description", "item desc"],
        "quantity": ["quantity", "qty", "nos", "no.", "no", "amount (qty)"],
        "unit": ["unit", "uom", "measure"],
        "unit_rate": ["unit rate", "rate-cost", "rate", "price", "unit price", "cost per"],
        "amount": ["amount", "total amount", "bill amount", "value", "net amount", "line total"],
    }

    for field, keywords in exact_patterns.items():
        for original, normalized in normalized_columns:
            if normalized in keywords:
                mapping[field] = original
                break

    for field, keywords in fallback_patterns.items():
        if field in mapping:
            continue
        for original, normalized in normalized_columns:
            if any(keyword in normalized for keyword in keywords):
                mapping[field] = original
                break

    return mapping


def _raw_scan_excel(df) -> List[BOQItem]:
    """Fallback: scan every row for a text cell followed by a number."""
    items = []
    for _, row in df.iterrows():
        values = [v for v in row.values if v is not None]
        if len(values) < 2:
            continue
        desc = str(values[0]).strip()
        if not desc or len(desc) < 4 or _is_number(desc):
            continue
        # Find first numeric value in the row as quantity
        qty = None
        for v in values[1:]:
            qty = _to_float(v)
            if qty and qty > 0:
                break
        if qty:
            items.append(BOQItem(description=desc, quantity=qty))
    return items


# ─── PDF Parsing ─────────────────────────────────────────────────────

def parse_pdf(file_bytes: bytes) -> List[BOQItem]:
    """Parse BOQ from PDF file bytes using pdfplumber."""
    try:
        import pdfplumber
    except ImportError:
        raise ImportError("pdfplumber is required for PDF parsing. Run: pip install pdfplumber")

    items = []
    with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
        for page in pdf.pages:
            # Try table extraction first
            tables = page.extract_tables()
            for table in tables:
                table_items = _parse_pdf_table(table)
                items.extend(table_items)

            # If no tables found, try text line parsing
            if not tables:
                text = page.extract_text() or ""
                line_items = _parse_pdf_text(text)
                items.extend(line_items)

    # Deduplicate by description
    seen = set()
    unique_items = []
    for item in items:
        key = item.description.lower().strip()
        if key not in seen and len(key) > 3:
            seen.add(key)
            unique_items.append(item)

    logger.info(f"PDF parsed: {len(unique_items)} BOQ items found")
    return unique_items


def _parse_pdf_table(table: list) -> List[BOQItem]:
    if not table or len(table) < 2:
        return []

    items = []
    # Detect header row
    header = [str(c or "").lower().strip() for c in table[0]]
    col_map = _map_columns(header)

    desc_idx = _index_from_map(col_map, "description", header)
    qty_idx = _index_from_map(col_map, "quantity", header)
    unit_idx = _index_from_map(col_map, "unit", header)
    rate_idx = _index_from_map(col_map, "unit_rate", header)
    amount_idx = _index_from_map(col_map, "amount", header)

    for row in table[1:]:
        if not row:
            continue
        desc = str(row[desc_idx] or "").strip() if desc_idx is not None and desc_idx < len(row) else ""
        if not desc or len(desc) < 3:
            continue
        qty = _to_float(row[qty_idx]) if qty_idx is not None and qty_idx < len(row) else None
        if not qty or qty <= 0:
            # Fallback: scan row for any number
            for cell in row:
                qty = _to_float(cell)
                if qty and qty > 0:
                    break

        if qty and qty > 0:
            items.append(BOQItem(
                description=desc,
                unit=str(row[unit_idx] or "").strip() if unit_idx is not None and unit_idx < len(row) else None,
                quantity=qty,
                unit_rate=_to_float(row[rate_idx]) if rate_idx is not None and rate_idx < len(row) else None,
                amount=_to_float(row[amount_idx]) if amount_idx is not None and amount_idx < len(row) else None,
            ))
    return items


def _parse_pdf_text(text: str) -> List[BOQItem]:
    """Line-by-line heuristic parsing for unstructured PDF text."""
    items = []
    lines = text.split("\n")
    for line in lines:
        line = line.strip()
        if not line or len(line) < 5:
            continue
        numbers = re.findall(r'\b\d+(?:\.\d+)?\b', line)
        if not numbers:
            continue
        # First non-number segment is description
        desc_part = re.split(r'\b\d+(?:\.\d+)?\b', line)[0].strip()
        if len(desc_part) < 4:
            continue
        qty = float(numbers[0])
        if qty <= 0:
            continue
        rate = float(numbers[1]) if len(numbers) > 1 else None
        amount = float(numbers[-1]) if len(numbers) > 2 else None
        items.append(BOQItem(description=desc_part, quantity=qty, unit_rate=rate, amount=amount))
    return items


# ─── Utilities ───────────────────────────────────────────────────────

def _to_float(value) -> Optional[float]:
    if value is None:
        return None
    try:
        cleaned = str(value).replace(",", "").strip()
        f = float(cleaned)
        return f if not (f != f) else None  # NaN check
    except (ValueError, TypeError):
        return None


def _is_number(s: str) -> bool:
    try:
        float(s.replace(",", ""))
        return True
    except ValueError:
        return False


def _index_from_map(col_map: dict, field: str, header: list) -> Optional[int]:
    col_name = col_map.get(field)
    if col_name and col_name in header:
        return header.index(col_name)
    return None
