import json

from booking_cascade.fast_path import (
    LABEL_DATE,
    LABEL_PERSON,
    LABEL_SERVICE,
    LABEL_TIME,
    FastPathConfig,
    extract,
)
from booking_cascade.gate import GateConfig, evaluate
from booking_cascade.schema import ExtractionResult, SlotUpdate, SlotValue
from tests._helpers import FakeGLiNERModel, make_entity


def test_clean_extraction_does_not_escalate(reference_datetime):
    message = (
        "Đặt lịch massage toàn thân với chị Hương thứ ba tuần sau "
        "lúc 3 giờ chiều, sđt 0901234567"
    )
    entities = [
        make_entity(message, "Hương", LABEL_PERSON, 0.95),
        make_entity(message, "thứ ba tuần sau", LABEL_DATE, 0.9),
        make_entity(message, "3 giờ chiều", LABEL_TIME, 0.9),
        make_entity(message, "massage toàn thân", LABEL_SERVICE, 0.85),
    ]
    result = extract(message, "book", FastPathConfig(), model=FakeGLiNERModel(entities))

    decision = evaluate(message, result, reference_datetime)

    assert decision.escalate is False
    assert decision.reasons == []


def test_low_confidence_slot_escalates(reference_datetime):
    slot_update = SlotUpdate(
        intent="book",
        slots={
            "appointment_date": SlotValue(
                value="thứ ba tuần sau", confidence=0.5, source_span="thứ ba tuần sau"
            )
        },
    )
    result = ExtractionResult(
        slot_update=slot_update,
        raw_entities=[
            {"label": LABEL_DATE, "text": "thứ ba tuần sau", "score": 0.5, "start": 0, "end": 15}
        ],
        path="fast",
    )

    decision = evaluate("tin nhắn nào đó", result, reference_datetime)

    assert decision.escalate is True
    assert "low_confidence:appointment_date" in decision.reasons


def test_ambiguity_flag_escalates(reference_datetime):
    slot_update = SlotUpdate(intent="book", ambiguity_flags=["multiple_dates_unclear_role"])
    result = ExtractionResult(
        slot_update=slot_update,
        raw_entities=[
            {"label": LABEL_DATE, "text": "thứ ba", "score": 0.9, "start": 10, "end": 16},
            {"label": LABEL_DATE, "text": "thứ tư", "score": 0.9, "start": 22, "end": 28},
        ],
        path="fast",
    )

    decision = evaluate("Mình rảnh thứ ba hoặc thứ tư", result, reference_datetime)

    assert decision.escalate is True
    assert "ambiguity:multiple_dates_unclear_role" in decision.reasons


def test_normalization_failure_on_past_date_escalates(reference_datetime):
    slot_update = SlotUpdate(
        intent="book",
        slots={"appointment_date": SlotValue(value="hôm qua", confidence=0.9, source_span="hôm qua")},
    )
    result = ExtractionResult(
        slot_update=slot_update,
        raw_entities=[{"label": LABEL_DATE, "text": "hôm qua", "score": 0.9, "start": 0, "end": 7}],
        path="fast",
    )

    decision = evaluate("đặt giúp mình hôm qua", result, reference_datetime)

    assert decision.escalate is True
    assert "normalization_failure:appointment_date" in decision.reasons


def test_normalization_failure_on_ambiguous_time_escalates(reference_datetime):
    slot_update = SlotUpdate(
        intent="book",
        slots={"appointment_time": SlotValue(value="8 giờ", confidence=0.9, source_span="8 giờ")},
    )
    result = ExtractionResult(
        slot_update=slot_update,
        raw_entities=[{"label": LABEL_TIME, "text": "8 giờ", "score": 0.9, "start": 0, "end": 5}],
        path="fast",
    )

    decision = evaluate("mình tới lúc 8 giờ được không", result, reference_datetime)

    assert decision.escalate is True
    assert "normalization_failure:appointment_time" in decision.reasons


def test_negation_marker_escalates(reference_datetime):
    slot_update = SlotUpdate(
        intent="book",
        slots={"appointment_time": SlotValue(value="16:00", confidence=0.9, source_span="4 giờ chiều")},
    )
    result = ExtractionResult(
        slot_update=slot_update,
        raw_entities=[{"label": LABEL_TIME, "text": "4 giờ chiều", "score": 0.9, "start": 0, "end": 11}],
        path="fast",
    )

    decision = evaluate("à không, đổi lại 4 giờ chiều", result, reference_datetime)

    assert decision.escalate is True
    assert "negation_marker:à không" in decision.reasons
    assert "negation_marker:đổi lại" in decision.reasons


def test_context_reference_marker_escalates(reference_datetime):
    slot_update = SlotUpdate(intent="book")
    result = ExtractionResult(slot_update=slot_update, raw_entities=[], path="fast")

    decision = evaluate("đặt giờ như cũ, giống lần trước nhé", result, reference_datetime)

    assert decision.escalate is True
    assert "context_reference:như cũ" in decision.reasons
    assert "context_reference:giống lần trước" in decision.reasons


def test_reschedule_with_single_date_escalates(reference_datetime):
    slot_update = SlotUpdate(
        intent="reschedule",
        slots={"appointment_date": SlotValue(value="thứ sáu", confidence=0.9, source_span="thứ sáu")},
    )
    result = ExtractionResult(
        slot_update=slot_update,
        raw_entities=[{"label": LABEL_DATE, "text": "thứ sáu", "score": 0.9, "start": 0, "end": 7}],
        path="fast",
    )

    decision = evaluate("Dời lịch của mình sang thứ sáu", result, reference_datetime)

    assert decision.escalate is True
    assert "reschedule_single_date" in decision.reasons


def test_zero_entities_with_book_intent_escalates(reference_datetime):
    slot_update = SlotUpdate(intent="book")
    result = ExtractionResult(slot_update=slot_update, raw_entities=[], path="fast")

    decision = evaluate("Mình muốn đặt lịch", result, reference_datetime)

    assert decision.escalate is True
    assert "zero_entities" in decision.reasons


def test_zero_entities_with_query_intent_does_not_escalate(reference_datetime):
    slot_update = SlotUpdate(intent="query")
    result = ExtractionResult(slot_update=slot_update, raw_entities=[], path="fast")

    decision = evaluate("Spa mở cửa lúc nào vậy", result, reference_datetime)

    assert decision.escalate is False


def test_escalation_is_logged_as_jsonl(reference_datetime, tmp_path):
    log_path = tmp_path / "escalations.jsonl"
    config = GateConfig(escalation_log_path=str(log_path))
    slot_update = SlotUpdate(intent="book")
    result = ExtractionResult(slot_update=slot_update, raw_entities=[], path="fast")

    evaluate("Mình muốn đặt lịch", result, reference_datetime, config)

    lines = log_path.read_text(encoding="utf-8").strip().splitlines()
    assert len(lines) == 1
    record = json.loads(lines[0])
    assert record["message"] == "Mình muốn đặt lịch"
    assert "zero_entities" in record["reasons"]


def test_no_log_written_when_no_escalation(reference_datetime, tmp_path):
    log_path = tmp_path / "escalations.jsonl"
    config = GateConfig(escalation_log_path=str(log_path))
    slot_update = SlotUpdate(intent="query")
    result = ExtractionResult(slot_update=slot_update, raw_entities=[], path="fast")

    evaluate("Spa mở cửa lúc nào vậy", result, reference_datetime, config)

    assert not log_path.exists()
