"""Ground extracted staff/service mentions against the spa roster.

Loads ``data/spa.yaml`` and fuzzy-matches (via rapidfuzz) extracted
``staff_name`` values against the staff roster:

- score >= ``staff_auto_correct_score``: silently corrected to the roster
  spelling.
- ``staff_confirm_score`` <= score < ``staff_auto_correct_score``:
  proposed via ``needs_confirmation`` ("Ý anh/chị là ... phải không ạ?").
- score < ``staff_confirm_score``: rejected with a warning.

A ``service_type`` mention (e.g. "chăm sóc da mặt") is matched against the
service menu; if exactly one staff member performs that service and no
staff was requested, that staff member is proposed with a confirmation
prompt.

Every correction/proposal is logged as a JSON line for future fine-tuning.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional, Union

import yaml
from rapidfuzz import fuzz, process

from booking_cascade.schema import SlotUpdate, SlotValue

DEFAULT_STAFF_AUTO_CORRECT_SCORE = 90
DEFAULT_STAFF_CONFIRM_SCORE = 70
DEFAULT_SERVICE_MATCH_SCORE = 80


@dataclass(frozen=True)
class Staff:
    name: str
    services: tuple[str, ...]


@dataclass(frozen=True)
class OpeningHours:
    open: str
    close: str


@dataclass(frozen=True)
class SpaData:
    staff: tuple[Staff, ...]
    service_types: tuple[str, ...]
    opening_hours: dict[str, OpeningHours]
    default_service_duration_minutes: int

    def staff_names(self) -> tuple[str, ...]:
        return tuple(member.name for member in self.staff)


def load_spa_data(path: Union[str, Path]) -> SpaData:
    with open(path, encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}

    staff = tuple(
        Staff(
            name=entry["name"],
            services=tuple(s.lower() for s in entry.get("services", [])),
        )
        for entry in raw.get("staff", [])
    )
    service_types = tuple(raw.get("service_types", []))
    opening_hours = {
        day: OpeningHours(open=hours["open"], close=hours["close"])
        for day, hours in (raw.get("opening_hours") or {}).items()
    }
    default_service_duration_minutes = raw.get("default_service_duration_minutes", 60)
    return SpaData(
        staff=staff,
        service_types=service_types,
        opening_hours=opening_hours,
        default_service_duration_minutes=default_service_duration_minutes,
    )


@dataclass(frozen=True)
class GroundingConfig:
    staff_auto_correct_score: float = DEFAULT_STAFF_AUTO_CORRECT_SCORE
    staff_confirm_score: float = DEFAULT_STAFF_CONFIRM_SCORE
    service_match_score: float = DEFAULT_SERVICE_MATCH_SCORE
    grounding_log_path: Optional[str] = None

    @classmethod
    def from_dict(
        cls, grounding_data: dict, grounding_log_path: Optional[str] = None
    ) -> "GroundingConfig":
        return cls(
            staff_auto_correct_score=grounding_data.get(
                "staff_auto_correct_score", DEFAULT_STAFF_AUTO_CORRECT_SCORE
            ),
            staff_confirm_score=grounding_data.get(
                "staff_confirm_score", DEFAULT_STAFF_CONFIRM_SCORE
            ),
            service_match_score=grounding_data.get(
                "service_match_score", DEFAULT_SERVICE_MATCH_SCORE
            ),
            grounding_log_path=grounding_log_path,
        )


@dataclass(frozen=True)
class GroundingResult:
    slot_update: SlotUpdate
    warnings: list[str] = field(default_factory=list)


def _log_correction(record: dict[str, Any], log_path: Optional[str]) -> None:
    if not log_path:
        return
    path = Path(log_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def _unknown_staff_warning(raw_name: str) -> str:
    return f"'{raw_name}' không có trong danh sách kỹ thuật viên của spa."


def _ground_staff_name(
    raw_name: str, spa_data: SpaData, config: GroundingConfig
) -> tuple[Optional[str], Optional[str], Optional[str], Optional[float]]:
    """Returns (resolved_name, confirmation_question, warning, score)."""
    names = spa_data.staff_names()
    if not names:
        return None, None, _unknown_staff_warning(raw_name), None

    match = process.extractOne(raw_name, names, scorer=fuzz.token_set_ratio)
    if match is None:
        return None, None, _unknown_staff_warning(raw_name), None

    matched_name, score, _ = match
    if score >= config.staff_auto_correct_score:
        return matched_name, None, None, score
    if score >= config.staff_confirm_score:
        return (
            matched_name,
            f"Ý anh/chị là kỹ thuật viên {matched_name} phải không ạ?",
            None,
            score,
        )
    return None, None, _unknown_staff_warning(raw_name), score


def _resolve_staff_by_service(
    service_text: str, spa_data: SpaData, config: GroundingConfig
) -> tuple[Optional[str], Optional[str]]:
    """If exactly one staff member performs a service matching
    ``service_text``, return (staff_name, confirmation_question);
    otherwise (None, None).
    """
    matched_staff: list[str] = []
    for member in spa_data.staff:
        if not member.services:
            continue
        best = process.extractOne(
            service_text.lower(), member.services, scorer=fuzz.token_set_ratio
        )
        if best is not None and best[1] >= config.service_match_score:
            matched_staff.append(member.name)

    unique = list(dict.fromkeys(matched_staff))
    if len(unique) == 1:
        staff_name = unique[0]
        return (
            staff_name,
            f"Bên em có kỹ thuật viên {staff_name} làm dịch vụ này. "
            "Anh/chị đặt với bạn ấy nhé?",
        )
    return None, None


def _ground_service_type(
    raw_service: str, spa_data: SpaData, config: GroundingConfig
) -> Optional[str]:
    if raw_service in spa_data.service_types:
        return raw_service
    if not spa_data.service_types:
        return None
    match = process.extractOne(
        raw_service, spa_data.service_types, scorer=fuzz.token_set_ratio
    )
    if match is not None and match[1] >= config.staff_auto_correct_score:
        return match[0]
    return None


def ground(
    slot_update: SlotUpdate, spa_data: SpaData, config: Optional[GroundingConfig] = None
) -> GroundingResult:
    """Fuzzy-correct/confirm staff names, canonicalize service types against
    the spa menu, and suggest a staff member when the requested service has
    exactly one specialist.
    """
    config = config or GroundingConfig()
    slots = dict(slot_update.slots)
    needs_confirmation = dict(slot_update.needs_confirmation)
    warnings: list[str] = []

    if "staff_name" in slots:
        raw_name = str(slots["staff_name"].value)
        resolved, question, warning, score = _ground_staff_name(raw_name, spa_data, config)
        if resolved is not None:
            if resolved != raw_name:
                _log_correction(
                    {"type": "staff_name", "raw": raw_name, "resolved": resolved, "score": score},
                    config.grounding_log_path,
                )
            slots["staff_name"] = slots["staff_name"].model_copy(update={"value": resolved})
            if question:
                needs_confirmation["staff_name"] = question
        else:
            del slots["staff_name"]
            if warning:
                warnings.append(warning)
                _log_correction(
                    {"type": "staff_name", "raw": raw_name, "resolved": None, "score": score},
                    config.grounding_log_path,
                )

    if "service_type" in slots:
        raw_service = str(slots["service_type"].value)
        resolved_service = _ground_service_type(raw_service, spa_data, config)
        if resolved_service is not None and resolved_service != raw_service:
            slots["service_type"] = slots["service_type"].model_copy(
                update={"value": resolved_service}
            )
            _log_correction(
                {"type": "service_type", "raw": raw_service, "resolved": resolved_service},
                config.grounding_log_path,
            )

    if "service_type" in slots and "staff_name" not in slots:
        service_value = slots["service_type"]
        service_text = str(service_value.value)
        resolved_staff, question = _resolve_staff_by_service(service_text, spa_data, config)
        if resolved_staff is not None:
            slots["staff_name"] = SlotValue(
                value=resolved_staff,
                confidence=service_value.confidence,
                source_span=service_value.source_span,
            )
            if question:
                needs_confirmation["staff_name"] = question
            _log_correction(
                {"type": "service_resolution", "raw": service_text, "resolved": resolved_staff},
                config.grounding_log_path,
            )

    new_slot_update = slot_update.model_copy(
        update={"slots": slots, "needs_confirmation": needs_confirmation}
    )
    return GroundingResult(slot_update=new_slot_update, warnings=warnings)
