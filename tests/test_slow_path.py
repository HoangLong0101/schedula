import json

import httpx

from booking_cascade.schema import BookingState
from booking_cascade.slow_path import SlowPathConfig, extract
from tests._helpers import FakeOllamaClient


def _ok_response(slot_update_dict):
    return json.dumps(slot_update_dict, ensure_ascii=False)


def test_successful_extraction_on_first_try(reference_datetime):
    response = _ok_response(
        {
            "intent": "reschedule",
            "slots": {
                "reschedule_from_date": {"value": "2026-06-18", "confidence": 0.9, "source_span": "thứ năm"},
                "appointment_date": {"value": "2026-06-19", "confidence": 0.9, "source_span": "thứ sáu"},
            },
        }
    )
    client = FakeOllamaClient(responses=[response])

    result = extract(
        "Dời lịch hẹn thứ năm của mình sang thứ sáu",
        BookingState(),
        history=[],
        intent="reschedule",
        reference=reference_datetime,
        config=SlowPathConfig(),
        client=client,
    )

    assert result.path == "slow"
    assert result.slot_update.slots["reschedule_from_date"].value == "2026-06-18"
    assert result.slot_update.slots["appointment_date"].value == "2026-06-19"
    assert len(client.calls) == 1


def test_response_wrapped_in_markdown_code_fence_is_parsed(reference_datetime):
    payload = {
        "intent": "book",
        "slots": {"appointment_time": {"value": "16:00", "confidence": 0.9, "source_span": "4 giờ chiều"}},
    }
    response = "```json\n" + json.dumps(payload, ensure_ascii=False) + "\n```"
    client = FakeOllamaClient(responses=[response])

    result = extract(
        "à không, đổi lại 4 giờ chiều",
        BookingState(appointment_date="2026-06-13", customer_name="Ngọc"),
        history=[],
        intent="book",
        reference=reference_datetime,
        config=SlowPathConfig(),
        client=client,
    )

    assert result.slot_update.slots["appointment_time"].value == "16:00"


def test_unparseable_response_retries_once_then_succeeds(reference_datetime):
    good = _ok_response(
        {
            "intent": "book",
            "slots": {"appointment_date": {"value": "2026-06-16", "confidence": 0.9, "source_span": "thứ ba"}},
        }
    )
    client = FakeOllamaClient(responses=["không phải json", good])

    result = extract(
        "thứ ba tuần sau",
        BookingState(),
        history=[],
        intent="book",
        reference=reference_datetime,
        config=SlowPathConfig(),
        client=client,
    )

    assert len(client.calls) == 2
    assert result.slot_update.slots["appointment_date"].value == "2026-06-16"


def test_two_unparseable_responses_returns_degraded_result(reference_datetime):
    client = FakeOllamaClient(responses=["nope", "vẫn nope"])

    result = extract(
        "ờm sao ta",
        BookingState(),
        history=[],
        intent="book",
        reference=reference_datetime,
        config=SlowPathConfig(),
        client=client,
    )

    assert result.path == "slow"
    assert "llm_unavailable_or_unparseable" in result.slot_update.ambiguity_flags
    assert "_clarify" in result.slot_update.needs_confirmation


def test_ollama_unreachable_returns_degraded_result_without_crashing(reference_datetime):
    client = FakeOllamaClient(raises=httpx.ConnectError("connection refused"))

    result = extract(
        "Đặt lịch massage với chị Hương thứ sáu",
        BookingState(),
        history=[],
        intent="book",
        reference=reference_datetime,
        config=SlowPathConfig(),
        client=client,
    )

    assert result.path == "slow"
    assert "llm_unavailable_or_unparseable" in result.slot_update.ambiguity_flags


def test_prompt_uses_temperature_zero_and_configured_model(reference_datetime):
    response = _ok_response({"intent": "book", "slots": {}})
    client = FakeOllamaClient(responses=[response])
    config = SlowPathConfig(
        model="qwen2.5:7b-instruct", temperature=0.0, ollama_host="http://localhost:11434"
    )

    extract("xin chào", BookingState(), [], "book", reference_datetime, config, client)

    call = client.calls[0]
    assert call["json"]["model"] == "qwen2.5:7b-instruct"
    assert call["json"]["options"]["temperature"] == 0.0
    assert call["url"] == "http://localhost:11434/api/generate"


def test_prompt_contains_vietnamese_weekday_and_state(reference_datetime):
    response = _ok_response({"intent": "book", "slots": {}})
    client = FakeOllamaClient(responses=[response])

    extract(
        "xin chào",
        BookingState(customer_name="Ngọc"),
        [],
        "book",
        reference_datetime,
        SlowPathConfig(),
        client,
    )

    prompt = client.calls[0]["json"]["prompt"]
    assert "Thứ Sáu" in prompt  # 2026-06-12 is a Friday
    assert "2026-06-12" in prompt
    assert '"customer_name": "Ngọc"' in prompt


def test_default_intent_used_when_llm_omits_it(reference_datetime):
    response = _ok_response(
        {"slots": {"appointment_time": {"value": "10:00", "confidence": 0.9, "source_span": "10 giờ sáng"}}}
    )
    client = FakeOllamaClient(responses=[response])

    result = extract(
        "10 giờ sáng nha", BookingState(), [], "book", reference_datetime, SlowPathConfig(), client
    )

    assert result.slot_update.intent == "book"
