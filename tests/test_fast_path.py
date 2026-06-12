from booking_cascade.fast_path import (
    LABEL_DATE,
    LABEL_DURATION,
    LABEL_EMAIL,
    LABEL_PERSON,
    LABEL_PHONE,
    LABEL_SERVICE,
    LABEL_TIME,
    FastPathConfig,
    extract,
)
from tests._helpers import FakeGLiNERModel, make_entity


def test_person_with_staff_marker_becomes_staff_name():
    message = "Đặt lịch massage toàn thân với chị Hương thứ ba tuần sau lúc 3 giờ chiều"
    entities = [
        make_entity(message, "Hương", LABEL_PERSON, 0.95),
        make_entity(message, "thứ ba tuần sau", LABEL_DATE, 0.9),
        make_entity(message, "3 giờ chiều", LABEL_TIME, 0.9),
        make_entity(message, "massage toàn thân", LABEL_SERVICE, 0.85),
    ]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))
    slots = result.slot_update.slots

    assert slots["staff_name"].value == "Hương"
    assert slots["appointment_date"].value == "thứ ba tuần sau"
    assert slots["appointment_time"].value == "3 giờ chiều"
    assert slots["service_type"].value == "massage toàn thân"
    assert result.slot_update.ambiguity_flags == []
    assert result.raw_entities == entities


def test_person_without_staff_marker_becomes_customer_name():
    message = "Tên em là Ngọc, đặt lịch thứ ba tuần sau lúc 10 giờ sáng"
    entities = [
        make_entity(message, "Ngọc", LABEL_PERSON, 0.9),
        make_entity(message, "thứ ba tuần sau", LABEL_DATE, 0.9),
        make_entity(message, "10 giờ sáng", LABEL_TIME, 0.9),
    ]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))
    slots = result.slot_update.slots

    assert slots["customer_name"].value == "Ngọc"
    assert "staff_name" not in slots


def test_phone_and_email_extracted_by_regex_without_ner():
    message = "SĐT của mình là 0901 234 567, email ngoc.tran@gmail.com nhé"
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel([]))
    slots = result.slot_update.slots

    assert slots["phone"].value == "0901 234 567"
    assert slots["phone"].confidence == 1.0
    assert slots["email"].value == "ngoc.tran@gmail.com"
    labels = [e["label"] for e in result.raw_entities]
    assert LABEL_PHONE in labels
    assert LABEL_EMAIL in labels


def test_ner_entity_overlapping_email_span_is_dropped():
    # GLiNER sometimes labels the local part of an email as a person name;
    # the regex-found email span must win.
    message = "Email của mình là ngoc.tran@gmail.com nhé"
    entities = [make_entity(message, "ngoc.tran", LABEL_PERSON, 0.9)]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    assert "customer_name" not in result.slot_update.slots
    assert result.slot_update.slots["email"].value == "ngoc.tran@gmail.com"


def test_plus_84_phone_is_extracted():
    message = "Số mình +84 90 123 4567"
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel([]))

    assert result.slot_update.slots["phone"].value == "+84 90 123 4567"


def test_zero_entities_returns_empty_slot_update():
    message = "Mình muốn đặt lịch"
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel([]))

    assert result.slot_update.slots == {}
    assert result.slot_update.ambiguity_flags == []
    assert result.raw_entities == []


def test_two_dates_reschedule_resolves_from_and_to_with_low_confidence():
    message = "Dời lịch hẹn thứ năm của mình sang thứ sáu"
    entities = [
        make_entity(message, "thứ năm", LABEL_DATE, 0.9),
        make_entity(message, "thứ sáu", LABEL_DATE, 0.9),
    ]
    result = extract(message, "reschedule", FastPathConfig(), model=FakeGLiNERModel(entities))
    slots = result.slot_update.slots

    assert "two_dates_reschedule_heuristic" in result.slot_update.ambiguity_flags
    assert slots["reschedule_from_date"].value == "thứ năm"
    assert slots["appointment_date"].value == "thứ sáu"
    assert slots["reschedule_from_date"].confidence <= 0.5
    assert slots["appointment_date"].confidence <= 0.5


def test_two_dates_without_reschedule_intent_is_ambiguous():
    message = "Mình rảnh thứ ba hoặc thứ tư, đặt lịch giúp mình"
    entities = [
        make_entity(message, "thứ ba", LABEL_DATE, 0.9),
        make_entity(message, "thứ tư", LABEL_DATE, 0.9),
    ]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    assert "multiple_dates_unclear_role" in result.slot_update.ambiguity_flags
    assert "appointment_date" not in result.slot_update.slots
    assert "reschedule_from_date" not in result.slot_update.slots


def test_duration_phut_parsed_to_minutes():
    message = "Đặt massage toàn thân 90 phút"
    entities = [
        make_entity(message, "90 phút", LABEL_DURATION, 0.8),
        make_entity(message, "massage toàn thân", LABEL_SERVICE, 0.85),
    ]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    assert result.slot_update.slots["duration_minutes"].value == 90


def test_tieng_ruoi_duration():
    message = "Cho mình gói tiếng rưỡi nhé"
    entities = [make_entity(message, "tiếng rưỡi", LABEL_DURATION, 0.8)]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    assert result.slot_update.slots["duration_minutes"].value == 90


def test_nua_tieng_duration():
    message = "Làm nửa tiếng thôi"
    entities = [make_entity(message, "nửa tiếng", LABEL_DURATION, 0.8)]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    assert result.slot_update.slots["duration_minutes"].value == 30


def test_threshold_filters_low_confidence_entities():
    message = "Đặt lịch với chị Lan thứ sáu lúc 2 giờ chiều"
    entities = [
        make_entity(message, "Lan", LABEL_PERSON, 0.95),
        make_entity(message, "thứ sáu", LABEL_DATE, 0.9),
        make_entity(message, "2 giờ chiều", LABEL_TIME, 0.2),  # below default threshold
    ]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    assert "appointment_time" not in result.slot_update.slots
    assert result.slot_update.slots["staff_name"].value == "Lan"
