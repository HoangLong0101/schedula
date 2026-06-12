"""Fast path: GLiNER zero-shot NER + deterministic slot-filling rules.

Vietnamese spa edition: the multilingual GLiNER model extracts person/date/
time/service/duration spans with Vietnamese labels, while phone numbers and
emails are extracted deterministically with regexes (far more reliable than
NER for those).

The GLiNER model is loaded once (and cached) the first time it's needed.
For tests, any object exposing ``predict_entities(text, labels, threshold)``
-> ``list[dict]`` (matching GLiNER's output shape) can be passed in via the
``model`` parameter, so the heavy ``gliner``/``torch`` stack never needs to
be imported in unit tests.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Optional, Protocol

from booking_cascade.normalize import EMAIL_RE, PHONE_RE
from booking_cascade.schema import ExtractionResult, Intent, SlotUpdate, SlotValue

DEFAULT_GLINER_MODEL = "urchade/gliner_multi-v2.1"
DEFAULT_THRESHOLD = 0.45
# "auto" -> CUDA when available, else CPU. Also accepts explicit torch
# device strings ("cuda", "cuda:1", "cpu").
DEFAULT_DEVICE = "auto"

# Vietnamese NER labels -- must match the labels configured in config.yaml.
LABEL_PERSON = "tên người"
LABEL_DATE = "ngày"
LABEL_TIME = "giờ"
LABEL_SERVICE = "dịch vụ spa"
LABEL_DURATION = "thời lượng"
# Synthetic labels for regex-extracted entities (not sent to GLiNER).
LABEL_PHONE = "số điện thoại"
LABEL_EMAIL = "email"

DEFAULT_LABELS: tuple[str, ...] = (
    LABEL_PERSON,
    LABEL_DATE,
    LABEL_TIME,
    LABEL_SERVICE,
    LABEL_DURATION,
)


class EntityModel(Protocol):
    """Anything shaped like ``GLiNER.predict_entities`` -- real or fake."""

    def predict_entities(
        self, text: str, labels: list[str], threshold: float = 0.5
    ) -> list[dict[str, Any]]: ...


@dataclass(frozen=True)
class FastPathConfig:
    gliner_model: str = DEFAULT_GLINER_MODEL
    entity_confidence_threshold: float = DEFAULT_THRESHOLD
    labels: tuple[str, ...] = field(default_factory=lambda: DEFAULT_LABELS)
    device: str = DEFAULT_DEVICE

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "FastPathConfig":
        return cls(
            gliner_model=data.get("gliner_model", DEFAULT_GLINER_MODEL),
            entity_confidence_threshold=data.get(
                "entity_confidence_threshold", DEFAULT_THRESHOLD
            ),
            labels=tuple(data.get("labels", DEFAULT_LABELS)),
            device=data.get("device", DEFAULT_DEVICE),
        )


def resolve_device(device: str = DEFAULT_DEVICE) -> str:
    """Resolve a configured device string to a concrete torch device.

    "auto" picks CUDA when a usable GPU + CUDA torch build is present,
    otherwise CPU. Explicit values ("cuda", "cuda:1", "cpu") pass through.
    """
    if device != "auto":
        return device
    try:
        import torch

        return "cuda" if torch.cuda.is_available() else "cpu"
    except ImportError:
        return "cpu"


_MODEL_CACHE: dict[tuple[str, str], EntityModel] = {}


def load_model(model_name: str, device: str = DEFAULT_DEVICE) -> EntityModel:
    """Load and cache a GLiNER model by name, on the configured device.

    The ``gliner``/``torch`` import is deferred to this function so the
    rest of the codebase (and the test suite, via dependency injection of a
    fake model) never needs those heavy dependencies installed.
    """
    resolved = resolve_device(device)
    key = (model_name, resolved)
    if key not in _MODEL_CACHE:
        from gliner import GLiNER

        model = GLiNER.from_pretrained(model_name)
        model = model.to(resolved)
        model.eval()
        _MODEL_CACHE[key] = model
    return _MODEL_CACHE[key]


# A person mention is the spa staff member (not the customer) when a staff
# marker appears in or just before the span: "với chị Hương", "kỹ thuật
# viên Lan"... Otherwise the person is the customer ("tên em là Ngọc").
_STAFF_MARKER_RE = re.compile(
    r"(?:kỹ thuật viên|ktv|nhân viên|chuyên viên"
    r"|(?:với|do|chọn) (?:chị|anh|cô|chú|bạn|em))\b",
    re.IGNORECASE,
)
_MY_APPOINTMENT_RE = re.compile(
    r"\b(?:lịch|hẹn|buổi)\b.{0,40}?\bcủa (?:tôi|mình|em)\b", re.IGNORECASE
)
_STAFF_MARKER_LOOKBEHIND_CHARS = 25


def _has_staff_marker_nearby(message: str, entity: dict[str, Any]) -> bool:
    """True if a staff marker appears in or just before ``entity``.

    The window includes the entity span itself, since markers like
    "với chị" can straddle the entity boundary ("với [chị Hương]").
    """
    window_start = max(0, entity["start"] - _STAFF_MARKER_LOOKBEHIND_CHARS)
    window = message[window_start : entity["end"]]
    return bool(_STAFF_MARKER_RE.search(window))


def _split_reschedule_pair(
    message: str, sorted_entities: list[dict[str, Any]]
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Pick (from, to) out of two date/time entities for a reschedule turn.

    The entity that falls inside a "lịch/hẹn ... của tôi/mình" span is the
    one being moved *from*; otherwise the first entity in the sentence is
    treated as the "from" anchor.
    """
    first, second = sorted_entities
    my_appointment = _MY_APPOINTMENT_RE.search(message)
    if my_appointment:
        span = my_appointment.span()
        if span[0] <= first["start"] < span[1]:
            return first, second
        if span[0] <= second["start"] < span[1]:
            return second, first
    return first, second


# Confidence ceiling applied to slots resolved only via the two-entity
# reschedule heuristic -- low enough to push the gate's confidence check
# (default threshold 0.6) so the slow path can confirm.
_RESCHEDULE_HEURISTIC_CONFIDENCE_CAP = 0.5


def _assign_date_or_time_slots(
    message: str,
    entities: list[dict[str, Any]],
    intent: Intent,
    slots: dict[str, SlotValue],
    ambiguity_flags: list[str],
    *,
    primary_slot: str,
    secondary_slot: str,
    multi_flag: str,
    pair_flag: str,
) -> None:
    if not entities:
        return

    if len(entities) == 1:
        entity = entities[0]
        slots[primary_slot] = SlotValue(
            value=entity["text"], confidence=entity["score"], source_span=entity["text"]
        )
        return

    if len(entities) == 2 and intent == "reschedule":
        sorted_entities = sorted(entities, key=lambda e: e["start"])
        from_entity, to_entity = _split_reschedule_pair(message, sorted_entities)
        slots[secondary_slot] = SlotValue(
            value=from_entity["text"],
            confidence=min(from_entity["score"], _RESCHEDULE_HEURISTIC_CONFIDENCE_CAP),
            source_span=from_entity["text"],
        )
        slots[primary_slot] = SlotValue(
            value=to_entity["text"],
            confidence=min(to_entity["score"], _RESCHEDULE_HEURISTIC_CONFIDENCE_CAP),
            source_span=to_entity["text"],
        )
        ambiguity_flags.append(pair_flag)
        return

    # Two entities outside a reschedule turn, or more than two entities:
    # roles are unclear -- let the gate escalate.
    ambiguity_flags.append(multi_flag)


# "60 phút" / "1 tiếng" / "tiếng rưỡi" / "nửa tiếng" / "1.5 giờ"
_HALF_HOUR_RE = re.compile(r"\bnửa (?:tiếng|giờ)\b", re.IGNORECASE)
_HOUR_AND_HALF_RE = re.compile(r"\b(\d+)?\s*(?:tiếng|giờ) rưỡi\b", re.IGNORECASE)
_HOURS_RE = re.compile(r"(\d+(?:[.,]\d+)?)\s*(?:tiếng|giờ)\b", re.IGNORECASE)
_MINUTES_RE = re.compile(r"(\d+)\s*phút\b", re.IGNORECASE)


def _parse_duration_minutes(text: str) -> Optional[int]:
    if _HALF_HOUR_RE.search(text):
        return 30
    hour_and_half = _HOUR_AND_HALF_RE.search(text)
    if hour_and_half:
        hours = int(hour_and_half.group(1)) if hour_and_half.group(1) else 1
        return hours * 60 + 30
    hours_match = _HOURS_RE.search(text)
    if hours_match:
        return int(float(hours_match.group(1).replace(",", ".")) * 60)
    minutes_match = _MINUTES_RE.search(text)
    if minutes_match:
        return int(minutes_match.group(1))
    return None


def _overlaps_any(entity: dict[str, Any], others: list[dict[str, Any]]) -> bool:
    return any(
        entity["start"] < other["end"] and other["start"] < entity["end"]
        for other in others
    )


def _extract_contact_entities(message: str) -> list[dict[str, Any]]:
    """Regex-extract phone numbers and emails as synthetic entities."""
    entities: list[dict[str, Any]] = []
    phone_match = PHONE_RE.search(message)
    if phone_match:
        entities.append(
            {
                "text": phone_match.group(0),
                "label": LABEL_PHONE,
                "score": 1.0,
                "start": phone_match.start(),
                "end": phone_match.end(),
            }
        )
    email_match = EMAIL_RE.search(message)
    if email_match:
        entities.append(
            {
                "text": email_match.group(0),
                "label": LABEL_EMAIL,
                "score": 1.0,
                "start": email_match.start(),
                "end": email_match.end(),
            }
        )
    return entities


def extract(
    message: str,
    intent: Intent,
    config: Optional[FastPathConfig] = None,
    model: Optional[EntityModel] = None,
) -> ExtractionResult:
    """Run GLiNER NER + rule-based slot assignment for one message.

    Returns raw text spans for date/time/service slots; normalization
    (relative dates, Vietnamese times, service canonicalization, phone/email
    formats) happens later in the pipeline, in normalize.py.
    """
    config = config or FastPathConfig()
    if model is None:
        model = load_model(config.gliner_model, config.device)

    ner_entities = model.predict_entities(
        message, list(config.labels), threshold=config.entity_confidence_threshold
    )
    contact_entities = _extract_contact_entities(message)
    # Regex-found phone/email spans are authoritative: drop NER entities that
    # overlap them (e.g. the local part of an email mislabeled as a name).
    ner_entities = [e for e in ner_entities if not _overlaps_any(e, contact_entities)]
    entities = [*ner_entities, *contact_entities]

    slots: dict[str, SlotValue] = {}
    ambiguity_flags: list[str] = []

    persons = [e for e in entities if e["label"] == LABEL_PERSON]
    for person in persons:
        target = "staff_name" if _has_staff_marker_nearby(message, person) else "customer_name"
        if target not in slots:
            slots[target] = SlotValue(
                value=person["text"], confidence=person["score"], source_span=person["text"]
            )

    dates = [e for e in entities if e["label"] == LABEL_DATE]
    _assign_date_or_time_slots(
        message,
        dates,
        intent,
        slots,
        ambiguity_flags,
        primary_slot="appointment_date",
        secondary_slot="reschedule_from_date",
        multi_flag="multiple_dates_unclear_role",
        pair_flag="two_dates_reschedule_heuristic",
    )

    times = [e for e in entities if e["label"] == LABEL_TIME]
    _assign_date_or_time_slots(
        message,
        times,
        intent,
        slots,
        ambiguity_flags,
        primary_slot="appointment_time",
        secondary_slot="reschedule_from_time",
        multi_flag="multiple_times_unclear_role",
        pair_flag="two_times_reschedule_heuristic",
    )

    services = [e for e in entities if e["label"] == LABEL_SERVICE]
    if services:
        best = max(services, key=lambda e: e["score"])
        slots["service_type"] = SlotValue(
            value=best["text"], confidence=best["score"], source_span=best["text"]
        )

    durations = [e for e in entities if e["label"] == LABEL_DURATION]
    if durations:
        best = max(durations, key=lambda e: e["score"])
        minutes = _parse_duration_minutes(best["text"])
        if minutes is not None:
            slots["duration_minutes"] = SlotValue(
                value=minutes, confidence=best["score"], source_span=best["text"]
            )

    for entity in contact_entities:
        slot_name = "phone" if entity["label"] == LABEL_PHONE else "email"
        slots[slot_name] = SlotValue(
            value=entity["text"], confidence=entity["score"], source_span=entity["text"]
        )

    slot_update = SlotUpdate(
        intent=intent, slots=slots, ambiguity_flags=ambiguity_flags, raw_text=message
    )
    return ExtractionResult(slot_update=slot_update, raw_entities=entities, path="fast")
