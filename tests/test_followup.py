from booking_cascade.followup import generate_followup
from booking_cascade.schema import BookingState, SlotUpdate


def test_asks_for_date_when_missing():
    state = BookingState(intent="book")
    reply = generate_followup(state)
    assert "ngày nào" in reply


def test_asks_for_time_when_date_known():
    state = BookingState(intent="book", appointment_date="2026-06-16")
    reply = generate_followup(state)
    assert "mấy giờ" in reply
    assert "2026-06-16" in reply


def test_asks_for_customer_name_when_datetime_known():
    state = BookingState(
        intent="book", appointment_date="2026-06-16", appointment_time="15:00"
    )
    reply = generate_followup(state)
    assert "tên" in reply


def test_asks_for_phone_when_name_known():
    state = BookingState(
        intent="book",
        appointment_date="2026-06-16",
        appointment_time="15:00",
        customer_name="Ngọc",
    )
    reply = generate_followup(state)
    assert "số điện thoại" in reply


def test_bookable_state_produces_confirmation_summary():
    state = BookingState(
        intent="book",
        appointment_date="2026-06-16",
        appointment_time="15:00",
        customer_name="Ngọc",
        phone="0901234567",
        email="ngoc.tran@gmail.com",
        service_type="massage toàn thân",
        staff_name="Trần Thu Hương",
    )
    reply = generate_followup(state)
    assert "2026-06-16" in reply
    assert "15:00" in reply
    assert "Ngọc" in reply
    assert "0901234567" in reply
    assert "ngoc.tran@gmail.com" in reply
    assert "massage toàn thân" in reply
    assert "Trần Thu Hương" in reply


def test_reschedule_summary_mentions_from_and_to():
    state = BookingState(
        intent="reschedule",
        appointment_date="2026-06-19",
        appointment_time="14:00",
        customer_name="Ngọc",
        phone="0901234567",
        reschedule_from_date="2026-06-18",
        reschedule_from_time="14:00",
    )
    reply = generate_followup(state)
    assert "2026-06-18" in reply
    assert "2026-06-19" in reply


def test_cancel_summary():
    state = BookingState(
        intent="cancel",
        appointment_date="2026-06-16",
        appointment_time="15:00",
        customer_name="Ngọc",
        phone="0901234567",
    )
    reply = generate_followup(state)
    assert "hủy" in reply
    assert "2026-06-16" in reply


def test_grounding_confirmation_takes_priority_over_missing_slots():
    state = BookingState(intent="book")
    slot_update = SlotUpdate(
        needs_confirmation={
            "staff_name": "Ý anh/chị là kỹ thuật viên Trần Thu Hương phải không ạ?"
        }
    )
    reply = generate_followup(state, slot_update)
    assert reply == "Ý anh/chị là kỹ thuật viên Trần Thu Hương phải không ạ?"


def test_warnings_are_prepended():
    state = BookingState(intent="book", warnings=["Ngày 2026-06-01 đã qua rồi."])
    reply = generate_followup(state)
    assert reply.startswith("Ngày 2026-06-01 đã qua rồi.")
    assert "ngày nào" in reply
