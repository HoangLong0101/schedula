"""End-to-end multi-turn pipeline tests (Vietnamese spa conversations).

Each scenario drives ``BookingPipeline.process_turn`` turn-by-turn with a
``ScriptedGLiNERModel`` (canned entities per message) and, where the gate is
expected to escalate, a ``FakeOllamaClient`` (canned LLM responses). The slow
path (Ollama) is never actually called.
"""

from __future__ import annotations

import json

from booking_cascade.fast_path import LABEL_DATE, LABEL_PERSON, LABEL_SERVICE, LABEL_TIME
from booking_cascade.pipeline import BookingPipeline
from booking_cascade.schema import BookingState
from tests._helpers import FakeOllamaClient, ScriptedGLiNERModel, make_entity


def _pipeline(spa_data_path, entities_by_text, responses=None):
    model = ScriptedGLiNERModel(entities_by_text)
    client = FakeOllamaClient(responses=responses) if responses is not None else None
    return BookingPipeline(
        config={}, spa_data_path=spa_data_path, fast_path_model=model, ollama_client=client
    )


def test_scenario_1_single_turn_complete_booking(spa_data_path, reference_datetime):
    message = (
        "Đặt lịch massage toàn thân với chị Hương thứ ba tuần sau lúc "
        "3 giờ chiều, tên em là Ngọc, sđt 0901234567"
    )
    entities = [
        make_entity(message, "Hương", LABEL_PERSON, 0.95),
        make_entity(message, "Ngọc", LABEL_PERSON, 0.9),
        make_entity(message, "thứ ba tuần sau", LABEL_DATE, 0.9),
        make_entity(message, "3 giờ chiều", LABEL_TIME, 0.9),
        make_entity(message, "massage toàn thân", LABEL_SERVICE, 0.85),
    ]
    pipeline = _pipeline(spa_data_path, {message: entities})

    result = pipeline.process_turn(message, BookingState(), reference=reference_datetime)

    assert result.path == "fast"
    assert result.state.appointment_date == "2026-06-16"
    assert result.state.appointment_time == "15:00"
    assert result.state.staff_name == "Trần Thu Hương"
    assert result.state.customer_name == "Ngọc"
    assert result.state.phone == "0901234567"
    assert result.state.service_type == "massage toàn thân"
    assert result.state.is_bookable()
    assert "2026-06-16" in result.reply
    assert "15:00" in result.reply
    assert "Trần Thu Hương" in result.reply
    assert "Ngọc" in result.reply
    assert "0901234567" in result.reply


def test_scenario_2_multi_turn_slot_filling(spa_data_path, reference_datetime):
    msg1 = "Mình muốn đặt lịch"
    msg2 = "thứ ba tuần sau"
    msg3 = "3 giờ chiều"
    msg4 = "Tên mình là Ngọc, số 0901234567"
    entities_by_text = {
        msg1: [],
        msg2: [make_entity(msg2, "thứ ba tuần sau", LABEL_DATE, 0.9)],
        msg3: [make_entity(msg3, "3 giờ chiều", LABEL_TIME, 0.9)],
        msg4: [make_entity(msg4, "Ngọc", LABEL_PERSON, 0.9)],
    }
    responses = [json.dumps({"intent": "book", "slots": {}})]
    pipeline = _pipeline(spa_data_path, entities_by_text, responses=responses)

    result1 = pipeline.process_turn(msg1, BookingState(), reference=reference_datetime)
    assert result1.path == "slow"
    assert "zero_entities" in result1.gate_reasons
    assert "ngày nào" in result1.reply

    result2 = pipeline.process_turn(msg2, result1.state, reference=reference_datetime)
    assert result2.path == "fast"
    assert result2.state.appointment_date == "2026-06-16"
    assert "mấy giờ" in result2.reply
    assert "2026-06-16" in result2.reply

    result3 = pipeline.process_turn(msg3, result2.state, reference=reference_datetime)
    assert result3.path == "fast"
    assert result3.state.appointment_time == "15:00"
    assert "tên" in result3.reply

    result4 = pipeline.process_turn(msg4, result3.state, reference=reference_datetime)
    assert result4.path == "fast"
    assert result4.state.customer_name == "Ngọc"
    assert result4.state.phone == "0901234567"
    assert result4.state.is_bookable()
    assert "2026-06-16" in result4.reply
    assert "15:00" in result4.reply


def test_scenario_3_reschedule_escalates_and_resolves_from_to(spa_data_path, reference_datetime):
    message = "Dời lịch hẹn thứ năm của mình sang thứ sáu"
    entities = [
        make_entity(message, "thứ năm", LABEL_DATE, 0.9),
        make_entity(message, "thứ sáu", LABEL_DATE, 0.9),
    ]
    responses = [
        json.dumps(
            {
                "intent": "reschedule",
                "slots": {
                    "reschedule_from_date": {
                        "value": "2026-06-18",
                        "confidence": 0.95,
                        "source_span": "thứ năm",
                    },
                    "appointment_date": {
                        "value": "2026-06-19",
                        "confidence": 0.95,
                        "source_span": "thứ sáu",
                    },
                },
            },
            ensure_ascii=False,
        )
    ]
    pipeline = _pipeline(spa_data_path, {message: entities}, responses=responses)

    result = pipeline.process_turn(message, BookingState(), reference=reference_datetime)

    assert result.path == "slow"
    assert "ambiguity:two_dates_reschedule_heuristic" in result.gate_reasons
    assert result.state.intent == "reschedule"
    assert result.state.reschedule_from_date == "2026-06-18"
    assert result.state.appointment_date == "2026-06-19"
    assert "2026-06-19" in result.reply


def test_scenario_4_correction_overwrites_only_time(spa_data_path, reference_datetime):
    msg1 = (
        "Đặt lịch massage toàn thân ngày mai lúc 2 giờ chiều, "
        "tên em là Ngọc, sđt 0901234567"
    )
    msg2 = "à không, đổi lại 4 giờ chiều giúp em"
    entities_by_text = {
        msg1: [
            make_entity(msg1, "Ngọc", LABEL_PERSON, 0.95),
            make_entity(msg1, "ngày mai", LABEL_DATE, 0.9),
            make_entity(msg1, "2 giờ chiều", LABEL_TIME, 0.9),
            make_entity(msg1, "massage toàn thân", LABEL_SERVICE, 0.85),
        ],
        msg2: [make_entity(msg2, "4 giờ chiều", LABEL_TIME, 0.9)],
    }
    responses = [
        json.dumps(
            {
                "intent": "book",
                "slots": {
                    "appointment_time": {
                        "value": "16:00",
                        "confidence": 0.95,
                        "source_span": "4 giờ chiều",
                    }
                },
            },
            ensure_ascii=False,
        )
    ]
    pipeline = _pipeline(spa_data_path, entities_by_text, responses=responses)

    result1 = pipeline.process_turn(msg1, BookingState(), reference=reference_datetime)
    assert result1.path == "fast"
    assert result1.state.appointment_date == "2026-06-13"
    assert result1.state.appointment_time == "14:00"
    assert result1.state.customer_name == "Ngọc"
    assert result1.state.phone == "0901234567"

    result2 = pipeline.process_turn(msg2, result1.state, reference=reference_datetime)
    assert result2.path == "slow"
    assert "negation_marker:à không" in result2.gate_reasons
    assert result2.state.appointment_time == "16:00"
    assert result2.state.appointment_date == "2026-06-13"
    assert result2.state.customer_name == "Ngọc"
    assert result2.state.phone == "0901234567"


def test_scenario_5_fuzzy_staff_name_asks_for_confirmation(spa_data_path, reference_datetime):
    message = "Đặt lịch với chị Hương ngày mai lúc 10 giờ sáng"
    entities = [
        make_entity(message, "chị Hương", LABEL_PERSON, 0.95),
        make_entity(message, "ngày mai", LABEL_DATE, 0.9),
        make_entity(message, "10 giờ sáng", LABEL_TIME, 0.9),
    ]
    pipeline = _pipeline(spa_data_path, {message: entities})

    result = pipeline.process_turn(message, BookingState(), reference=reference_datetime)

    assert result.path == "fast"
    assert result.state.staff_name == "Trần Thu Hương"
    assert result.reply == "Ý anh/chị là kỹ thuật viên Trần Thu Hương phải không ạ?"


def test_scenario_6_service_suggestion_and_ambiguous_time(spa_data_path, reference_datetime):
    message = "Mai cho mình làm chăm sóc da mặt lúc 8 giờ được không?"
    entities = [
        make_entity(message, "Mai", LABEL_DATE, 0.9),
        make_entity(message, "chăm sóc da mặt", LABEL_SERVICE, 0.9),
        make_entity(message, "8 giờ", LABEL_TIME, 0.7),
    ]
    responses = [
        json.dumps(
            {
                "intent": "book",
                "slots": {
                    "appointment_date": {
                        "value": "2026-06-13",
                        "confidence": 0.95,
                        "source_span": "Mai",
                    },
                    "service_type": {
                        "value": "chăm sóc da mặt",
                        "confidence": 0.9,
                        "source_span": "chăm sóc da mặt",
                    },
                },
                "needs_confirmation": {
                    "appointment_time": "Anh/chị muốn 8 giờ sáng hay 8 giờ tối ạ?"
                },
            },
            ensure_ascii=False,
        )
    ]
    pipeline = _pipeline(spa_data_path, {message: entities}, responses=responses)

    result = pipeline.process_turn(message, BookingState(), reference=reference_datetime)

    assert result.path == "slow"
    assert "normalization_failure:appointment_time" in result.gate_reasons
    assert result.state.appointment_date == "2026-06-13"
    assert result.state.service_type == "chăm sóc da mặt"
    # Exactly one technician does facials -> suggested with confirmation,
    # but the ambiguous-time question is asked first.
    assert result.state.staff_name == "Nguyễn Mai Lan"
    assert result.state.appointment_time is None
    assert result.reply == "Anh/chị muốn 8 giờ sáng hay 8 giờ tối ạ?"
