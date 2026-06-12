from booking_cascade.grounding import GroundingConfig, ground, load_spa_data
from booking_cascade.schema import SlotUpdate, SlotValue


def _spa(spa_data_path):
    return load_spa_data(spa_data_path)


def test_load_spa_data(spa_data_path):
    spa = _spa(spa_data_path)

    assert "Trần Thu Hương" in spa.staff_names()
    assert "massage toàn thân" in spa.service_types
    assert spa.opening_hours["friday"].open == "09:00"
    assert spa.opening_hours["friday"].close == "20:00"
    assert "monday" not in spa.opening_hours
    assert spa.default_service_duration_minutes == 60


def test_staff_name_auto_corrected_silently(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={"staff_name": SlotValue(value="Hương", confidence=0.9, source_span="Hương")}
    )

    result = ground(update, spa, GroundingConfig())

    assert result.slot_update.slots["staff_name"].value == "Trần Thu Hương"
    assert result.slot_update.needs_confirmation == {}
    assert result.warnings == []


def test_staff_name_proposes_confirmation_for_medium_score(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={"staff_name": SlotValue(value="chị Hương", confidence=0.9, source_span="chị Hương")}
    )

    result = ground(update, spa, GroundingConfig())

    assert result.slot_update.slots["staff_name"].value == "Trần Thu Hương"
    assert "staff_name" in result.slot_update.needs_confirmation
    assert "Trần Thu Hương" in result.slot_update.needs_confirmation["staff_name"]


def test_staff_name_rejected_for_low_score(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={"staff_name": SlotValue(value="cô Tuyết", confidence=0.9, source_span="cô Tuyết")}
    )

    result = ground(update, spa, GroundingConfig())

    assert "staff_name" not in result.slot_update.slots
    assert result.warnings
    assert "cô Tuyết" in result.warnings[0]


def test_unique_service_suggests_staff_with_confirmation(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={
            "service_type": SlotValue(
                value="chăm sóc da mặt", confidence=0.9, source_span="chăm sóc da mặt"
            ),
            "appointment_date": SlotValue(value="2026-06-13", confidence=0.9, source_span="ngày mai"),
        }
    )

    result = ground(update, spa, GroundingConfig())

    assert result.slot_update.slots["staff_name"].value == "Nguyễn Mai Lan"
    # The service itself stays a real slot (unlike a transient hint).
    assert result.slot_update.slots["service_type"].value == "chăm sóc da mặt"
    assert "staff_name" in result.slot_update.needs_confirmation


def test_service_with_multiple_specialists_does_not_suggest_staff(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={
            "service_type": SlotValue(
                value="massage toàn thân", confidence=0.9, source_span="massage toàn thân"
            )
        }
    )

    result = ground(update, spa, GroundingConfig())

    assert "staff_name" not in result.slot_update.slots


def test_no_staff_suggestion_when_staff_already_requested(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={
            "staff_name": SlotValue(value="Quỳnh Anh", confidence=0.9, source_span="Quỳnh Anh"),
            "service_type": SlotValue(
                value="chăm sóc da mặt", confidence=0.9, source_span="chăm sóc da mặt"
            ),
        }
    )

    result = ground(update, spa, GroundingConfig())

    assert result.slot_update.slots["staff_name"].value == "Phạm Quỳnh Anh"


def test_service_type_passes_through_when_already_canonical(spa_data_path):
    spa = _spa(spa_data_path)
    update = SlotUpdate(
        slots={"service_type": SlotValue(value="làm móng", confidence=0.9, source_span="làm móng")}
    )

    result = ground(update, spa, GroundingConfig())

    assert result.slot_update.slots["service_type"].value == "làm móng"


def test_grounding_correction_is_logged(spa_data_path, tmp_path):
    spa = _spa(spa_data_path)
    log_path = tmp_path / "grounding.jsonl"
    config = GroundingConfig(grounding_log_path=str(log_path))
    update = SlotUpdate(
        slots={"staff_name": SlotValue(value="Hương", confidence=0.9, source_span="Hương")}
    )

    ground(update, spa, config)

    assert log_path.exists()
    lines = log_path.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 1
