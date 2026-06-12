"""Stateless entity-extraction service + JSON recording.

Shared by the CLI demo (``examples/demo_conversation.py``) and the HTTP API
(``booking_cascade.api``): run intent detection + the fast path on a single
text, normalize the result, and optionally record it to a JSON file.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Optional

from booking_cascade import fast_path
from booking_cascade.intent import detect_intent
from booking_cascade.normalize import normalize_slot_update


class NoEntitiesModel:
    """Fallback when the GLiNER model can't be loaded: NER finds nothing,
    but regex-extracted phone/email entities still work."""

    def predict_entities(self, text, labels, threshold=0.5):
        return []


def load_model_with_fallback(
    model_name: str,
    notify: Callable[[str], None] = print,
    device: str = fast_path.DEFAULT_DEVICE,
) -> tuple[fast_path.EntityModel, bool]:
    """Load the GLiNER model, falling back to ``NoEntitiesModel`` if the
    package is missing or the first-time download fails (no internet...).

    Returns ``(model, loaded)`` where ``loaded`` is False for the fallback.
    """
    try:
        return fast_path.load_model(model_name, device), True
    except ImportError:
        notify(
            "(!) Chưa cài thư viện 'gliner' -- chỉ trích xuất được số điện "
            'thoại/email bằng regex. Cài đầy đủ bằng: pip install -e ".[dev]"'
        )
    except Exception as exc:  # network/cache errors from huggingface_hub etc.
        notify(
            f"(!) Không tải được mô hình GLiNER ({type(exc).__name__}) -- chỉ "
            "trích xuất được số điện thoại/email bằng regex.\n"
            "    Mô hình cần internet để tải về lần đầu (sau đó được cache lại)."
        )
    return NoEntitiesModel(), False


def extract_entities(
    text: str,
    model: fast_path.EntityModel,
    config: fast_path.FastPathConfig,
    reference: Optional[datetime] = None,
    source: str = "text",
) -> dict[str, Any]:
    """Extract + normalize entities from ``text`` into a recordable dict."""
    reference = reference or datetime.now()
    intent_result = detect_intent(text)
    extraction = fast_path.extract(text, intent_result.intent, config, model=model)
    normalized, warnings = normalize_slot_update(extraction.slot_update, reference)
    slots = {
        name: {
            "value": sv.value,
            "confidence": round(sv.confidence, 4),
            "source_span": sv.source_span,
        }
        for name, sv in normalized.slots.items()
    }

    return {
        "source": source,
        "timestamp": reference.isoformat(timespec="seconds"),
        "text": text,
        "intent": intent_result.intent,
        "entities": [
            {
                "text": e["text"],
                "label": e["label"],
                "score": round(float(e["score"]), 4),
                "start": e["start"],
                "end": e["end"],
            }
            for e in extraction.raw_entities
        ],
        "slots": slots,
        "extracted_fields": {name: slot["value"] for name, slot in slots.items()},
        "warnings": warnings,
    }


def record_extraction(log_path: Path, record: dict[str, Any]) -> None:
    """Append ``record`` to the JSON array stored at ``log_path``."""
    records: list = []
    if log_path.exists():
        try:
            existing = json.loads(log_path.read_text(encoding="utf-8"))
            if isinstance(existing, list):
                records = existing
        except json.JSONDecodeError:
            pass  # corrupt/legacy file: start a fresh array
    records.append(record)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(
        json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8"
    )
