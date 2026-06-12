"""Slow path: ask a local Ollama-served LLM to interpret the message.

The LLM sees today's date/weekday, the spa timezone, the current
``BookingState`` as JSON, recent conversation history, and the new message
(in Vietnamese), and is asked to return ONLY a JSON object shaped like
``SlotUpdate``.

Graceful degradation: if Ollama is unreachable, times out, or returns
unparseable output (even after one retry), this module returns a
"degraded" ``SlotUpdate`` asking the user to rephrase -- it never raises.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Optional, Protocol

import httpx
from pydantic import ValidationError

from booking_cascade.schema import (
    SLOT_NAMES,
    BookingState,
    ExtractionResult,
    Intent,
    SlotUpdate,
)

DEFAULT_OLLAMA_HOST = "http://localhost:11434"
DEFAULT_MODEL = "qwen2.5:7b-instruct"
DEFAULT_TEMPERATURE = 0.0
DEFAULT_TIMEOUT_SECONDS = 30.0
DEFAULT_MAX_HISTORY_TURNS = 6
DEFAULT_SPA_TIMEZONE = "Asia/Ho_Chi_Minh"

CLARIFY_MESSAGE = (
    "Xin lỗi, em chưa hiểu rõ ý anh/chị -- anh/chị có thể nói lại được không ạ?"
)

_VN_WEEKDAY_NAMES: dict[int, str] = {
    0: "Thứ Hai",
    1: "Thứ Ba",
    2: "Thứ Tư",
    3: "Thứ Năm",
    4: "Thứ Sáu",
    5: "Thứ Bảy",
    6: "Chủ Nhật",
}

OUTPUT_SCHEMA_DESCRIPTION = """{
  "intent": "book" | "reschedule" | "cancel" | "query" | null,
  "slots": {
    "<slot_name>": {"value": <string or number>, "confidence": <float 0-1>, "source_span": "<exact text from the message>"}
  },
  "cleared_slots": ["<slot_name>", ...],
  "ambiguity_flags": ["<short_flag_name>", ...],
  "needs_confirmation": {"<slot_name>": "<câu hỏi xác nhận, bằng tiếng Việt>"}
}

Valid slot_name values: appointment_date, appointment_time, customer_name, phone,
email, service_type, staff_name, duration_minutes, notes, reschedule_from_date,
reschedule_from_time.

- Dates may be natural Vietnamese ("thứ ba tuần sau", "ngày mai") or ISO
  ("2026-06-16"); they are normalized afterwards.
- Times may be "3 giờ chiều", "15h30" or "15:00".
- "phone" is the customer's phone number, "email" the customer's email,
  "customer_name" the customer's name, "staff_name" the requested technician.
- Only include slots that are new or changed because of the new message.
- "cleared_slots" lists slots the user explicitly asked to unset.
- Output ONLY the JSON object. No markdown, no commentary, no code fences."""


class HTTPClient(Protocol):
    """Anything shaped like ``httpx.Client`` -- real or fake."""

    def post(self, url: str, json: dict[str, Any], timeout: float) -> Any: ...


@dataclass(frozen=True)
class SlowPathConfig:
    ollama_host: str = DEFAULT_OLLAMA_HOST
    model: str = DEFAULT_MODEL
    temperature: float = DEFAULT_TEMPERATURE
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
    max_history_turns: int = DEFAULT_MAX_HISTORY_TURNS
    spa_timezone: str = DEFAULT_SPA_TIMEZONE

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SlowPathConfig":
        return cls(
            ollama_host=data.get("ollama_host", DEFAULT_OLLAMA_HOST),
            model=data.get("model", DEFAULT_MODEL),
            temperature=data.get("temperature", DEFAULT_TEMPERATURE),
            timeout_seconds=data.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS),
            max_history_turns=data.get("max_history_turns", DEFAULT_MAX_HISTORY_TURNS),
            spa_timezone=data.get("spa_timezone", DEFAULT_SPA_TIMEZONE),
        )


def _state_summary(state: BookingState) -> dict[str, Any]:
    summary: dict[str, Any] = {"intent": state.intent}
    for slot_name in SLOT_NAMES:
        summary[slot_name] = getattr(state, slot_name)
    return summary


def build_prompt(
    message: str,
    state: BookingState,
    history: list[dict[str, str]],
    intent: Intent,
    reference: datetime,
    config: SlowPathConfig,
) -> str:
    """Build the extraction prompt for the slow-path LLM."""
    today = reference.strftime("%Y-%m-%d")
    weekday = _VN_WEEKDAY_NAMES[reference.weekday()]
    state_json = json.dumps(_state_summary(state), ensure_ascii=False)

    recent_history = history[-config.max_history_turns :]
    if recent_history:
        history_text = "\n".join(f"{turn['role']}: {turn['text']}" for turn in recent_history)
    else:
        history_text = "(chưa có lượt hội thoại nào)"

    return f"""You are the extraction engine for a Vietnamese spa's appointment-booking \
assistant. Customer messages are in Vietnamese.

Hôm nay là {weekday}, {today}. Múi giờ của spa: {config.spa_timezone}.
A simple keyword classifier guessed the message intent as: {intent} (it may be wrong).

Current booking state (JSON):
{state_json}

Conversation history (most recent {config.max_history_turns} turns):
{history_text}

New customer message (Vietnamese):
"{message}"

Extract a structured update describing how the new message changes the booking state.
Output ONLY a single JSON object matching exactly this schema, with no extra text,
no markdown formatting, and no commentary:

{OUTPUT_SCHEMA_DESCRIPTION}"""


def build_retry_prompt(original_prompt: str, bad_response: str) -> str:
    return (
        f"{original_prompt}\n\n"
        "Your previous response could not be parsed as valid JSON matching the "
        f"schema above. Your previous response was:\n{bad_response}\n\n"
        "Respond again with ONLY the corrected JSON object -- nothing else."
    )


_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)


def _extract_json(text: str) -> Optional[str]:
    match = _JSON_OBJECT_RE.search(text)
    if match is None:
        return None
    return match.group(0)


def _parse_response(raw_response: str, message: str, intent: Intent) -> Optional[SlotUpdate]:
    json_str = _extract_json(raw_response)
    if json_str is None:
        return None
    try:
        data = json.loads(json_str)
    except json.JSONDecodeError:
        return None
    try:
        slot_update = SlotUpdate.model_validate(data)
    except ValidationError:
        return None

    slot_update.raw_text = message
    if slot_update.intent is None:
        slot_update.intent = intent
    return slot_update


def _call_ollama(
    prompt: str, config: SlowPathConfig, client: Optional[HTTPClient]
) -> Optional[str]:
    payload = {
        "model": config.model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": config.temperature},
    }
    try:
        if client is not None:
            response = client.post(
                f"{config.ollama_host}/api/generate", json=payload, timeout=config.timeout_seconds
            )
        else:
            with httpx.Client(timeout=config.timeout_seconds) as default_client:
                response = default_client.post(f"{config.ollama_host}/api/generate", json=payload)
        response.raise_for_status()
        data = response.json()
    except (httpx.HTTPError, json.JSONDecodeError):
        return None
    return data.get("response")


def _degraded_result(message: str, intent: Intent) -> ExtractionResult:
    slot_update = SlotUpdate(
        intent=intent,
        ambiguity_flags=["llm_unavailable_or_unparseable"],
        needs_confirmation={"_clarify": CLARIFY_MESSAGE},
        raw_text=message,
    )
    return ExtractionResult(slot_update=slot_update, raw_entities=[], path="slow")


def extract(
    message: str,
    state: BookingState,
    history: list[dict[str, str]],
    intent: Intent,
    reference: datetime,
    config: Optional[SlowPathConfig] = None,
    client: Optional[HTTPClient] = None,
) -> ExtractionResult:
    """Ask the local LLM to interpret ``message`` given the current state.

    Returns a "slow" ``ExtractionResult``. Never raises: connection errors,
    timeouts, and unparseable output (even after one retry) all fall back to
    a degraded result that asks the user to rephrase.
    """
    config = config or SlowPathConfig()
    prompt = build_prompt(message, state, history, intent, reference, config)

    raw_response = _call_ollama(prompt, config, client)
    if raw_response is not None:
        slot_update = _parse_response(raw_response, message, intent)
        if slot_update is not None:
            return ExtractionResult(slot_update=slot_update, raw_entities=[], path="slow")

        retry_prompt = build_retry_prompt(prompt, raw_response)
        retry_response = _call_ollama(retry_prompt, config, client)
        if retry_response is not None:
            slot_update = _parse_response(retry_response, message, intent)
            if slot_update is not None:
                return ExtractionResult(slot_update=slot_update, raw_entities=[], path="slow")

    return _degraded_result(message, intent)
