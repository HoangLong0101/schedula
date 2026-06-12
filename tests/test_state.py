from booking_cascade.schema import BookingState, SlotUpdate, SlotValue
from booking_cascade.state import merge_slot_update


def test_merge_into_empty_state_sets_values_confidence_and_provenance():
    state = BookingState()
    update = SlotUpdate(
        intent="book",
        slots={
            "appointment_date": SlotValue(
                value="2026-06-16", confidence=0.9, source_span="thứ ba tuần sau"
            ),
            "appointment_time": SlotValue(value="15:00", confidence=0.9, source_span="3 giờ chiều"),
            "customer_name": SlotValue(value="Ngọc", confidence=0.9, source_span="Ngọc"),
            "phone": SlotValue(value="0901234567", confidence=1.0, source_span="0901234567"),
        },
    )

    new_state = merge_slot_update(state, update, provenance="fast")

    assert new_state.intent == "book"
    assert new_state.appointment_date == "2026-06-16"
    assert new_state.appointment_time == "15:00"
    assert new_state.customer_name == "Ngọc"
    assert new_state.phone == "0901234567"
    assert new_state.slot_confidence["appointment_date"] == 0.9
    assert new_state.slot_provenance["appointment_date"] == "fast"
    assert new_state.turn_count == 1
    # original state is untouched
    assert state.appointment_date is None
    assert state.turn_count == 0


def test_correction_overwrites_only_the_targeted_slot():
    state = BookingState(
        appointment_date="2026-06-13",
        appointment_time="14:00",
        customer_name="Ngọc",
        phone="0901234567",
        slot_confidence={"appointment_date": 0.9, "appointment_time": 0.9},
        slot_provenance={"appointment_date": "fast", "appointment_time": "fast"},
        turn_count=1,
    )
    correction = SlotUpdate(
        slots={"appointment_time": SlotValue(value="16:00", confidence=0.9, source_span="4 giờ chiều")}
    )

    new_state = merge_slot_update(state, correction, provenance="fast")

    assert new_state.appointment_time == "16:00"
    assert new_state.appointment_date == "2026-06-13"
    assert new_state.customer_name == "Ngọc"
    assert new_state.phone == "0901234567"
    assert new_state.turn_count == 2


def test_explicit_slot_clearing():
    state = BookingState(
        staff_name="Trần Thu Hương",
        slot_confidence={"staff_name": 0.9},
        slot_provenance={"staff_name": "fast"},
    )
    update = SlotUpdate(cleared_slots=["staff_name"])

    new_state = merge_slot_update(state, update, provenance="user_confirmed")

    assert new_state.staff_name is None
    assert "staff_name" not in new_state.slot_confidence
    assert "staff_name" not in new_state.slot_provenance


def test_unknown_slot_names_are_ignored():
    state = BookingState()
    update = SlotUpdate(
        slots={"hang_thanh_vien": SlotValue(value="vàng", confidence=0.9, source_span="vàng")}
    )

    new_state = merge_slot_update(state, update, provenance="fast")

    assert new_state.slot_confidence == {}
    assert new_state.turn_count == 1


def test_merge_without_intent_preserves_existing_intent():
    state = BookingState(intent="reschedule")
    update = SlotUpdate(
        slots={"appointment_time": SlotValue(value="16:00", confidence=0.9, source_span="4 giờ chiều")}
    )

    new_state = merge_slot_update(state, update, provenance="fast")

    assert new_state.intent == "reschedule"
