from booking_cascade.grounding import load_spa_data
from booking_cascade.schema import BookingState
from booking_cascade.validate import validate


def _spa(spa_data_path):
    return load_spa_data(spa_data_path)


def test_valid_state_is_unchanged(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    state = BookingState(
        appointment_date="2026-06-16",  # Tuesday
        appointment_time="10:00",
        customer_name="Ngọc",
        phone="0901234567",
        email="ngoc.tran@gmail.com",
        staff_name="Nguyễn Mai Lan",
    )

    result = validate(state, spa, reference_datetime)

    assert result.warnings == []
    assert result.appointment_date == "2026-06-16"
    assert result.appointment_time == "10:00"
    assert result.staff_name == "Nguyễn Mai Lan"
    assert result.phone == "0901234567"


def test_unknown_staff_is_cleared(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    state = BookingState(
        appointment_date="2026-06-16",
        appointment_time="10:00",
        staff_name="cô Tuyết",
        slot_confidence={"staff_name": 0.9},
        slot_provenance={"staff_name": "fast"},
    )

    result = validate(state, spa, reference_datetime)

    assert result.staff_name is None
    assert "staff_name" not in result.slot_confidence
    assert any("cô Tuyết" in w for w in result.warnings)


def test_invalid_phone_is_cleared(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    state = BookingState(phone="12345", slot_confidence={"phone": 1.0})

    result = validate(state, spa, reference_datetime)

    assert result.phone is None
    assert any("không hợp lệ" in w for w in result.warnings)


def test_invalid_email_is_cleared(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    state = BookingState(email="khong-phai-email")

    result = validate(state, spa, reference_datetime)

    assert result.email is None
    assert any("Email" in w for w in result.warnings)


def test_past_date_clears_date_and_time(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    state = BookingState(appointment_date="2026-06-01", appointment_time="10:00")

    result = validate(state, spa, reference_datetime)

    assert result.appointment_date is None
    assert result.appointment_time is None
    assert any("đã qua" in w for w in result.warnings)


def test_time_outside_opening_hours_is_cleared(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    # Sunday hours are 09:00-18:00
    state = BookingState(appointment_date="2026-06-14", appointment_time="19:00")

    result = validate(state, spa, reference_datetime)

    assert result.appointment_date == "2026-06-14"
    assert result.appointment_time is None
    assert any("ngoài giờ mở cửa" in w for w in result.warnings)


def test_closed_day_clears_time(spa_data_path, reference_datetime):
    spa = _spa(spa_data_path)
    # Monday: spa is closed
    state = BookingState(appointment_date="2026-06-15", appointment_time="10:00")

    result = validate(state, spa, reference_datetime)

    assert result.appointment_time is None
    assert any("đóng cửa" in w for w in result.warnings)
