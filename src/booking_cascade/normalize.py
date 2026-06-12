"""Normalization helpers for Vietnamese spa bookings.

Handles relative Vietnamese dates ("ngày mai", "thứ ba tuần sau"), Vietnamese
times ("3 giờ chiều", "15h30"), phone numbers (+84/0 forms), emails, and spa
service-type aliases.

Nothing in this module calls ``datetime.now()``. Every function that needs
"now" takes an explicit ``reference`` datetime so behaviour is reproducible
in tests.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Optional

import dateparser

from booking_cascade.schema import SlotUpdate


@dataclass(frozen=True)
class DateNormResult:
    """Result of normalizing a date span to ISO ``YYYY-MM-DD``."""

    iso_date: Optional[str]
    success: bool
    warning: Optional[str] = None


@dataclass(frozen=True)
class TimeNormResult:
    """Result of normalizing a time span to 24h ``HH:MM``."""

    time_24h: Optional[str]
    success: bool
    warning: Optional[str] = None


@dataclass(frozen=True)
class PhoneNormResult:
    """Result of normalizing a Vietnamese phone number to ``0xxxxxxxxx``."""

    phone: Optional[str]
    success: bool
    warning: Optional[str] = None


@dataclass(frozen=True)
class EmailNormResult:
    """Result of normalizing an email address (lower-cased, format-checked)."""

    email: Optional[str]
    success: bool
    warning: Optional[str] = None


# --- Vietnamese dates -------------------------------------------------------

# Relative day words -> day offset from the reference date.
_RELATIVE_DAYS: dict[str, int] = {
    "hôm nay": 0,
    "bữa nay": 0,
    "ngày mai": 1,
    "mai": 1,
    "sáng mai": 1,
    "chiều mai": 1,
    "tối mai": 1,
    "ngày mốt": 2,
    "mốt": 2,
    "ngày kia": 2,
}

# Vietnamese weekday names -> Python weekday index (Monday=0).
_VN_WEEKDAYS: dict[str, int] = {
    "thứ hai": 0,
    "thứ 2": 0,
    "thứ ba": 1,
    "thứ 3": 1,
    "thứ tư": 2,
    "thứ 4": 2,
    "thứ năm": 3,
    "thứ 5": 3,
    "thứ sáu": 4,
    "thứ 6": 4,
    "thứ bảy": 5,
    "thứ 7": 5,
    "chủ nhật": 6,
    "cn": 6,
}

_WEEKDAY_RE = re.compile(
    r"^(thứ\s*(?:hai|ba|tư|năm|sáu|bảy|[2-7])|chủ\s*nhật|cn)"
    r"(?:\s+(tuần\s+(?:sau|tới)))?$",
    re.IGNORECASE,
)

# "15/6", "15-6-2026", "ngày 15/06"
_DMY_RE = re.compile(r"^(?:ngày\s+)?(\d{1,2})[/\-.](\d{1,2})(?:[/\-.](\d{2,4}))?$")
# "ngày 15", "ngày 15 tháng 6", "ngày 15 tháng 6 năm 2026"
_NGAY_THANG_RE = re.compile(
    r"^ngày\s+(\d{1,2})(?:\s+tháng\s+(\d{1,2}))?(?:\s+năm\s+(\d{4}))?$"
)


def _resolve_weekday(weekday_index: int, next_week: bool, reference: datetime) -> date:
    if next_week:
        # "thứ X tuần sau" = that weekday in the next calendar week.
        days_ahead = 7 - reference.weekday() + weekday_index
    else:
        # Bare weekday = next upcoming occurrence (skipping today).
        days_ahead = (weekday_index - reference.weekday()) % 7 or 7
    return reference.date() + timedelta(days=days_ahead)


def normalize_date(text: str, reference: datetime) -> DateNormResult:
    """Resolve a (possibly relative, Vietnamese) date span against ``reference``.

    Dates that resolve to before ``reference``'s date are treated as a
    normalization failure (with a warning) rather than silently accepted,
    so the confidence gate can escalate "hôm qua"-style spans.
    """
    cleaned = " ".join(text.strip().lower().split())

    if cleaned in _RELATIVE_DAYS:
        resolved = reference.date() + timedelta(days=_RELATIVE_DAYS[cleaned])
        return DateNormResult(resolved.isoformat(), True)

    weekday_match = _WEEKDAY_RE.match(cleaned)
    if weekday_match:
        token = re.sub(r"\s+", " ", weekday_match.group(1))
        weekday_index = _VN_WEEKDAYS.get(token)
        if weekday_index is not None:
            resolved = _resolve_weekday(
                weekday_index, weekday_match.group(2) is not None, reference
            )
            return DateNormResult(resolved.isoformat(), True)

    dmy_match = _DMY_RE.match(cleaned)
    if dmy_match:
        return _resolve_explicit(
            text, dmy_match.group(1), dmy_match.group(2), dmy_match.group(3), reference
        )

    ngay_match = _NGAY_THANG_RE.match(cleaned)
    if ngay_match:
        return _resolve_explicit(
            text, ngay_match.group(1), ngay_match.group(2), ngay_match.group(3), reference
        )

    try:
        return _check_past(date.fromisoformat(cleaned), text, reference)
    except ValueError:
        pass

    parsed = dateparser.parse(
        cleaned,
        languages=["vi", "en"],
        settings={
            "PREFER_DATES_FROM": "future",
            "RELATIVE_BASE": reference,
            "DATE_ORDER": "DMY",
        },
    )
    if parsed is None:
        return DateNormResult(None, False, f"không hiểu được ngày '{text}'")
    return _check_past(parsed.date(), text, reference)


def _resolve_explicit(
    original: str,
    day_str: str,
    month_str: Optional[str],
    year_str: Optional[str],
    reference: datetime,
) -> DateNormResult:
    day = int(day_str)
    month = int(month_str) if month_str else reference.month
    year = int(year_str) if year_str else reference.year
    if year < 100:
        year += 2000

    try:
        resolved = date(year, month, day)
    except ValueError:
        return DateNormResult(None, False, f"không hiểu được ngày '{original}'")

    # No explicit year/month given and the date already passed: the user
    # means the next occurrence.
    if resolved < reference.date():
        if year_str is None and month_str is not None:
            try:
                resolved = date(year + 1, month, day)
            except ValueError:
                return DateNormResult(None, False, f"không hiểu được ngày '{original}'")
        elif year_str is None and month_str is None:
            next_month, next_year = (month % 12) + 1, year + (1 if month == 12 else 0)
            try:
                resolved = date(next_year, next_month, day)
            except ValueError:
                return DateNormResult(None, False, f"không hiểu được ngày '{original}'")

    return _check_past(resolved, original, reference)


def _check_past(resolved: date, original: str, reference: datetime) -> DateNormResult:
    if resolved < reference.date():
        return DateNormResult(
            None,
            False,
            f"ngày '{original}' rơi vào {resolved.isoformat()}, đã qua rồi",
        )
    return DateNormResult(resolved.isoformat(), True)


# --- Vietnamese times -------------------------------------------------------

# "15:00", "15h30", "3 giờ chiều", "3 rưỡi chiều", "9 giờ sáng", "8h"...
_TIME_RE = re.compile(
    r"^\s*(\d{1,2})\s*(:|giờ|h|g)?\s*(\d{1,2}|rưỡi)?\s*(?:phút)?"
    r"\s*(sáng|trưa|chiều|tối)?\s*$",
    re.IGNORECASE,
)


def normalize_time(text: str) -> TimeNormResult:
    """Resolve a Vietnamese time span to 24h ``HH:MM``.

    Hours <= 12 with no buổi marker (sáng/trưa/chiều/tối) and no explicit
    minutes (e.g. "8" or "8 giờ") are NOT resolved -- they are too ambiguous
    and should cause the confidence gate to escalate.
    """
    match = _TIME_RE.match(text.strip().lower())
    if not match:
        return TimeNormResult(None, False, f"không hiểu được giờ '{text}'")

    hour_str, _marker, minute_str, period = match.groups()
    hour = int(hour_str)
    if minute_str == "rưỡi":
        minute = 30
    elif minute_str:
        minute = int(minute_str)
    else:
        minute = 0

    if not (0 <= minute <= 59):
        return TimeNormResult(None, False, f"giờ '{text}' không hợp lệ")

    if period is None:
        if minute_str is not None:
            if not (0 <= hour <= 23):
                return TimeNormResult(None, False, f"giờ '{text}' không hợp lệ")
            return TimeNormResult(f"{hour:02d}:{minute:02d}", True)
        if 13 <= hour <= 23:
            return TimeNormResult(f"{hour:02d}:{minute:02d}", True)
        return TimeNormResult(
            None, False, f"'{text}' chưa rõ buổi (sáng/chiều/tối) nên chưa xác định được giờ"
        )

    if not (1 <= hour <= 12):
        return TimeNormResult(None, False, f"giờ '{text}' không hợp lệ")

    if period == "sáng":
        hour = 0 if hour == 12 else hour
    elif period == "trưa":
        hour = hour + 12 if hour in (1, 2) else hour
    elif period == "chiều":
        hour = hour + 12 if hour < 12 else 12
    else:  # tối
        hour = hour + 12 if hour < 12 else 0

    return TimeNormResult(f"{hour:02d}:{minute:02d}", True)


# --- Phone numbers / emails -------------------------------------------------

# Vietnamese mobile numbers: 0xxxxxxxxx or +84xxxxxxxxx (9 digits after prefix).
PHONE_RE = re.compile(r"(?<!\d)(?:\+?84|0)(?:[ .\-]?\d){9}(?!\d)")
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")

_PHONE_CANONICAL_RE = re.compile(r"^0\d{9}$")


def normalize_phone(text: str) -> PhoneNormResult:
    """Normalize a Vietnamese phone number to the canonical ``0xxxxxxxxx``."""
    digits = re.sub(r"[ .\-]", "", text.strip())
    if digits.startswith("+84"):
        digits = "0" + digits[3:]
    elif digits.startswith("84") and len(digits) == 11:
        digits = "0" + digits[2:]
    if _PHONE_CANONICAL_RE.match(digits):
        return PhoneNormResult(digits, True)
    return PhoneNormResult(None, False, f"số điện thoại '{text}' không hợp lệ")


def normalize_email(text: str) -> EmailNormResult:
    """Lower-case and format-check an email address."""
    cleaned = text.strip().lower()
    if EMAIL_RE.fullmatch(cleaned):
        return EmailNormResult(cleaned, True)
    return EmailNormResult(None, False, f"email '{text}' không hợp lệ")


# --- Spa service types ------------------------------------------------------

# Canonical service type -> accepted aliases (compared lower-cased, with
# hyphens normalized to spaces).
_SERVICE_TYPE_ALIASES: dict[str, tuple[str, ...]] = {
    "massage toàn thân": (
        "massage toàn thân",
        "mát xa toàn thân",
        "mát-xa toàn thân",
        "massage body",
        "body massage",
        "massage",
        "mát xa",
    ),
    "massage đá nóng": ("massage đá nóng", "mát xa đá nóng", "đá nóng", "hot stone"),
    "chăm sóc da mặt": (
        "chăm sóc da mặt",
        "chăm sóc da",
        "làm mặt",
        "facial",
        "da mặt",
    ),
    "tẩy tế bào chết": ("tẩy tế bào chết", "tẩy da chết", "body scrub", "tẩy tbc"),
    "gội đầu dưỡng sinh": ("gội đầu dưỡng sinh", "gội đầu", "gội dưỡng sinh"),
    "làm móng": ("làm móng", "làm nail", "nail", "sơn móng", "sơn gel"),
    "triệt lông": ("triệt lông", "waxing", "wax lông", "wax"),
    "xông hơi": ("xông hơi", "xông hơi đá muối", "sauna"),
}


def _flatten(text: str) -> str:
    return re.sub(r"[\s\-]+", " ", text.strip().lower())


def canonicalize_service_type(text: str) -> Optional[str]:
    """Map a free-text service span onto a canonical spa service type.

    Returns ``None`` if ``text`` doesn't match any known service.
    """
    normalized = _flatten(text)
    for canonical, aliases in _SERVICE_TYPE_ALIASES.items():
        candidates = {_flatten(canonical), *(_flatten(alias) for alias in aliases)}
        if normalized in candidates:
            return canonical
    return None


# --- Slot-update normalization ----------------------------------------------

# Date/time slots, normalized from raw spans to ISO date / 24h time.
_DATE_SLOT_NAMES: tuple[str, ...] = ("appointment_date", "reschedule_from_date")
_TIME_SLOT_NAMES: tuple[str, ...] = ("appointment_time", "reschedule_from_time")


def normalize_slot_update(
    slot_update: SlotUpdate, reference: datetime
) -> tuple[SlotUpdate, list[str]]:
    """Convert raw date/time/phone/email/service spans in ``slot_update`` to
    their normalized forms.

    Slots that fail to normalize are dropped from the update and produce a
    warning string (returned alongside the updated ``SlotUpdate``) so the
    caller can surface it and the slot stays unset for follow-up.
    """
    slots = dict(slot_update.slots)
    warnings: list[str] = []

    for slot_name in _DATE_SLOT_NAMES:
        if slot_name not in slots:
            continue
        raw = str(slots[slot_name].value)
        result = normalize_date(raw, reference)
        if result.success:
            slots[slot_name] = slots[slot_name].model_copy(update={"value": result.iso_date})
        else:
            warnings.append(result.warning or f"không hiểu được ngày '{raw}'")
            del slots[slot_name]

    for slot_name in _TIME_SLOT_NAMES:
        if slot_name not in slots:
            continue
        raw = str(slots[slot_name].value)
        result = normalize_time(raw)
        if result.success:
            slots[slot_name] = slots[slot_name].model_copy(update={"value": result.time_24h})
        else:
            warnings.append(result.warning or f"không hiểu được giờ '{raw}'")
            del slots[slot_name]

    if "phone" in slots:
        raw_phone = str(slots["phone"].value)
        phone_result = normalize_phone(raw_phone)
        if phone_result.success:
            slots["phone"] = slots["phone"].model_copy(update={"value": phone_result.phone})
        else:
            warnings.append(phone_result.warning or f"số điện thoại '{raw_phone}' không hợp lệ")
            del slots["phone"]

    if "email" in slots:
        raw_email = str(slots["email"].value)
        email_result = normalize_email(raw_email)
        if email_result.success:
            slots["email"] = slots["email"].model_copy(update={"value": email_result.email})
        else:
            warnings.append(email_result.warning or f"email '{raw_email}' không hợp lệ")
            del slots["email"]

    if "service_type" in slots:
        raw_service = str(slots["service_type"].value)
        canonical = canonicalize_service_type(raw_service)
        if canonical is not None:
            slots["service_type"] = slots["service_type"].model_copy(update={"value": canonical})

    new_slot_update = slot_update.model_copy(update={"slots": slots})
    return new_slot_update, warnings
