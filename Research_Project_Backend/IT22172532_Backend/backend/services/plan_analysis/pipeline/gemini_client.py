from __future__ import annotations

import base64
import json
import os
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Sequence, Tuple


@dataclass
class GeminiResponse:
    model: str
    raw: Dict[str, Any]
    text: str


def _extract_text(resp: Dict[str, Any]) -> str:
    # Generative Language API typically returns:
    # { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
    candidates = resp.get("candidates") or []
    if not candidates:
        return ""
    content = (candidates[0] or {}).get("content") or {}
    parts = content.get("parts") or []
    if not parts:
        return ""
    return (parts[0] or {}).get("text") or ""


def generate_json_from_image(
    *,
    prompt: str,
    image_bytes: bytes,
    mime_type: str,
    model: Optional[str] = None,
    api_key: Optional[str] = None,
    temperature: float = 0.2,
    timeout_s: int = 120,
) -> GeminiResponse:
    api_key = api_key or os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not set in environment")

    used_model = model or os.getenv("GEMINI_MODEL") or "gemini-2.5-flash"

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{used_model}:generateContent?key={api_key}"
    b64 = base64.b64encode(image_bytes).decode("utf-8")

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {"inline_data": {"mime_type": mime_type, "data": b64}},
                ],
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": temperature,
        },
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=timeout_s) as r:
        raw_bytes = r.read()

    raw = json.loads(raw_bytes.decode("utf-8"))
    text = _extract_text(raw)

    return GeminiResponse(model=used_model, raw=raw, text=text)


def generate_json_from_images(
    *,
    prompt: str,
    images: Sequence[Tuple[bytes, str]],
    model: Optional[str] = None,
    api_key: Optional[str] = None,
    temperature: float = 0.2,
    timeout_s: int = 180,
) -> GeminiResponse:
    """Generate strict JSON from a prompt + multiple images.

    Uses the Gemini REST API and sends all images as separate inline_data parts.
    """

    api_key = api_key or os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not set in environment")

    used_model = model or os.getenv("GEMINI_MODEL") or "gemini-2.5-flash"

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{used_model}:generateContent?key={api_key}"

    parts: List[Dict[str, Any]] = [{"text": prompt}]
    for (image_bytes, mime_type) in images:
        b64 = base64.b64encode(image_bytes).decode("utf-8")
        parts.append({"inline_data": {"mime_type": mime_type, "data": b64}})

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": parts,
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": temperature,
        },
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=timeout_s) as r:
        raw_bytes = r.read()

    raw = json.loads(raw_bytes.decode("utf-8"))
    text = _extract_text(raw)

    return GeminiResponse(model=used_model, raw=raw, text=text)
