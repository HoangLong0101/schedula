"""Dialogue state tracker: merge a per-turn ``SlotUpdate`` into ``BookingState``.

New values overwrite old ones for the same slot (so a correction turn like
"à không, đổi lại 4 giờ chiều" cleanly overwrites just ``appointment_time``).
Explicit clears (e.g. "kỹ thuật viên nào cũng được") remove a slot's value
and its confidence/provenance entries.
"""

from __future__ import annotations

from booking_cascade.schema import SLOT_NAMES, BookingState, Provenance, SlotUpdate


def merge_slot_update(
    state: BookingState, slot_update: SlotUpdate, provenance: Provenance
) -> BookingState:
    """Return a new ``BookingState`` with ``slot_update`` applied.

    ``provenance`` ("fast"/"slow"/"user_confirmed") is recorded for every
    slot the update touches.
    """
    updated = state.model_copy(deep=True)

    if slot_update.intent is not None:
        updated.intent = slot_update.intent

    for slot_name, slot_value in slot_update.slots.items():
        if slot_name not in SLOT_NAMES:
            continue
        setattr(updated, slot_name, slot_value.value)
        updated.slot_confidence[slot_name] = slot_value.confidence
        updated.slot_provenance[slot_name] = provenance

    for slot_name in slot_update.cleared_slots:
        if slot_name not in SLOT_NAMES:
            continue
        setattr(updated, slot_name, None)
        updated.slot_confidence.pop(slot_name, None)
        updated.slot_provenance.pop(slot_name, None)

    updated.turn_count += 1
    return updated
