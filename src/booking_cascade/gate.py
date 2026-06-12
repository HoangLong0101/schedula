"""Confidence gate: decide whether the fast-path result can be trusted.

Escalates to the slow path when any of several signals suggest the fast
path's extraction is unreliable. Every escalation (with its reasons) is
logged as a JSON line -- this is future fine-tuning/training data.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional

from booking_cascade.fast_path import LABEL_DATE
from booking_cascade.normalize import normalize_date, normalize_time
from booking_cascade.schema import ExtractionResult

DEFAULT_MIN_SLOT_CONFIDENCE = 0.6

DEFAULT_NEGATION_MARKERS: tuple[str, ...] = (
    "không phải",
    "à không",
    "à mà",
    "thay vào đó",
    "thật ra",
    "thực ra",
    "đổi lại",
    "nhầm",
)

DEFAULT_CONTEXT_REFERENCE_MARKERS: tuple[str, ...] = (
    "như cũ",
    "như lần trước",
    "giống lần trước",
    "như mọi khi",
    "như hôm trước",
)

# Date/time slots that, if present, are checked for normalization failures.
_DATE_SLOTS: tuple[str, ...] = ("appointment_date", "reschedule_from_date")
_TIME_SLOTS: tuple[str, ...] = ("appointment_time", "reschedule_from_time")


@dataclass(frozen=True)
class GateConfig:
    min_slot_confidence: float = DEFAULT_MIN_SLOT_CONFIDENCE
    negation_markers: tuple[str, ...] = field(
        default_factory=lambda: DEFAULT_NEGATION_MARKERS
    )
    context_reference_markers: tuple[str, ...] = field(
        default_factory=lambda: DEFAULT_CONTEXT_REFERENCE_MARKERS
    )
    escalation_log_path: Optional[str] = None

    @classmethod
    def from_dict(
        cls, gate_data: dict, escalation_log_path: Optional[str] = None
    ) -> "GateConfig":
        return cls(
            min_slot_confidence=gate_data.get(
                "min_slot_confidence", DEFAULT_MIN_SLOT_CONFIDENCE
            ),
            negation_markers=tuple(
                gate_data.get("negation_markers", DEFAULT_NEGATION_MARKERS)
            ),
            context_reference_markers=tuple(
                gate_data.get(
                    "context_reference_markers", DEFAULT_CONTEXT_REFERENCE_MARKERS
                )
            ),
            escalation_log_path=escalation_log_path,
        )


@dataclass(frozen=True)
class GateDecision:
    escalate: bool
    reasons: list[str]


def _marker_in_text(marker: str, text_lower: str) -> bool:
    pattern = r"\b" + re.escape(marker) + r"\b"
    return re.search(pattern, text_lower) is not None


def evaluate(
    message: str,
    extraction_result: ExtractionResult,
    reference: datetime,
    config: Optional[GateConfig] = None,
) -> GateDecision:
    """Decide whether ``extraction_result`` needs slow-path confirmation."""
    config = config or GateConfig()
    slot_update = extraction_result.slot_update
    text_lower = message.lower()
    reasons: list[str] = []

    for slot_name, slot_value in slot_update.slots.items():
        if slot_value.confidence < config.min_slot_confidence:
            reasons.append(f"low_confidence:{slot_name}")

    for flag in slot_update.ambiguity_flags:
        reasons.append(f"ambiguity:{flag}")

    for slot_name in _DATE_SLOTS:
        slot_value = slot_update.slots.get(slot_name)
        if slot_value is not None:
            result = normalize_date(str(slot_value.value), reference)
            if not result.success:
                reasons.append(f"normalization_failure:{slot_name}")

    for slot_name in _TIME_SLOTS:
        slot_value = slot_update.slots.get(slot_name)
        if slot_value is not None:
            result = normalize_time(str(slot_value.value))
            if not result.success:
                reasons.append(f"normalization_failure:{slot_name}")

    for marker in config.negation_markers:
        if _marker_in_text(marker, text_lower):
            reasons.append(f"negation_marker:{marker}")

    for marker in config.context_reference_markers:
        if _marker_in_text(marker, text_lower):
            reasons.append(f"context_reference:{marker}")

    if slot_update.intent == "reschedule":
        date_entities = [e for e in extraction_result.raw_entities if e["label"] == LABEL_DATE]
        if len(date_entities) == 1:
            reasons.append("reschedule_single_date")

    if not extraction_result.raw_entities and slot_update.intent in ("book", "reschedule"):
        reasons.append("zero_entities")

    decision = GateDecision(escalate=bool(reasons), reasons=reasons)
    if decision.escalate:
        _log_escalation(message, extraction_result, decision, config)
    return decision


def _log_escalation(
    message: str,
    extraction_result: ExtractionResult,
    decision: GateDecision,
    config: GateConfig,
) -> None:
    if not config.escalation_log_path:
        return
    path = Path(config.escalation_log_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    slot_update = extraction_result.slot_update
    record = {
        "message": message,
        "intent": slot_update.intent,
        "reasons": decision.reasons,
        "slots": {name: sv.value for name, sv in slot_update.slots.items()},
    }
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")
