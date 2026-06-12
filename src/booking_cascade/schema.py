"""Pydantic data models shared across the cascade.

``BookingState`` is the persistent, per-conversation dialogue state for a
spa booking. ``SlotUpdate`` is the partial, per-turn delta produced by the
fast or slow path. ``ExtractionResult`` wraps a ``SlotUpdate`` together with
path metadata (raw entities, which path produced it) for logging/debugging.
"""

from __future__ import annotations

from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

# Slot names that make up a spa booking. Order matters for follow-up
# priority (date before time before customer info, see followup.py).
SLOT_NAMES: tuple[str, ...] = (
    "appointment_date",
    "appointment_time",
    "customer_name",
    "phone",
    "email",
    "service_type",
    "staff_name",
    "duration_minutes",
    "notes",
    "reschedule_from_date",
    "reschedule_from_time",
)

# Slots that must be filled before a spa appointment can be booked.
REQUIRED_SLOTS: tuple[str, ...] = (
    "appointment_date",
    "appointment_time",
    "customer_name",
    "phone",
)

Provenance = Literal["fast", "slow", "user_confirmed"]
Intent = Literal["book", "reschedule", "cancel", "query"]


class SlotValue(BaseModel):
    """A single extracted slot value with confidence and provenance text."""

    value: Any
    confidence: float = 1.0
    source_span: str = ""


class SlotUpdate(BaseModel):
    """A partial update produced by either path for a single turn.

    Only slots actually mentioned in the turn are present in ``slots``.
    ``cleared_slots`` lists slots the user explicitly asked to unset
    (e.g. "kỹ thuật viên nào cũng được" -> clear staff_name).
    """

    intent: Optional[Intent] = None
    slots: dict[str, SlotValue] = Field(default_factory=dict)
    cleared_slots: list[str] = Field(default_factory=list)
    ambiguity_flags: list[str] = Field(default_factory=list)
    # Maps slot name -> confirmation question text, populated by grounding.
    needs_confirmation: dict[str, str] = Field(default_factory=dict)
    raw_text: str = ""

    def is_empty(self) -> bool:
        return not self.slots and not self.cleared_slots and self.intent is None


class ExtractionResult(BaseModel):
    """Output of a single extraction path (fast or slow)."""

    slot_update: SlotUpdate
    raw_entities: list[dict[str, Any]] = Field(default_factory=list)
    path: Literal["fast", "slow"]


class BookingState(BaseModel):
    """Persistent dialogue state, merged across turns by state.py."""

    intent: Optional[Intent] = None
    appointment_date: Optional[str] = None
    appointment_time: Optional[str] = None
    customer_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    service_type: Optional[str] = None
    staff_name: Optional[str] = None
    duration_minutes: Optional[int] = None
    notes: Optional[str] = None
    reschedule_from_date: Optional[str] = None
    reschedule_from_time: Optional[str] = None

    slot_confidence: dict[str, float] = Field(default_factory=dict)
    slot_provenance: dict[str, Provenance] = Field(default_factory=dict)
    warnings: list[str] = Field(default_factory=list)
    turn_count: int = 0

    def missing_required(self) -> list[str]:
        """Return required slots that are still unset."""
        return [slot for slot in REQUIRED_SLOTS if getattr(self, slot) is None]

    def is_bookable(self) -> bool:
        """True once every required slot has a value."""
        return not self.missing_required()
