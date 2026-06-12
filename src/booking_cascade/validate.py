"""Business-rule validation of the merged ``BookingState``.

Checks:
- ``staff_name`` (if set) exists on the spa roster.
- ``phone`` / ``email`` (if set) have valid formats.
- ``appointment_date`` is not in the past.
- ``appointment_time`` falls within opening hours for that weekday.

Each violation appends a human-readable (Vietnamese) warning to
``state.warnings`` and clears the offending slot (plus its
confidence/provenance) so followup.py asks about it again.
"""

from __future__ import annotations

from datetime import date, datetime

from booking_cascade.grounding import SpaData
from booking_cascade.normalize import normalize_email, normalize_phone
from booking_cascade.schema import BookingState

_VN_WEEKDAY_NAMES: dict[str, str] = {
    "monday": "Thứ Hai",
    "tuesday": "Thứ Ba",
    "wednesday": "Thứ Tư",
    "thursday": "Thứ Năm",
    "friday": "Thứ Sáu",
    "saturday": "Thứ Bảy",
    "sunday": "Chủ Nhật",
}


def _clear_slot(state: BookingState, slot_name: str) -> None:
    setattr(state, slot_name, None)
    state.slot_confidence.pop(slot_name, None)
    state.slot_provenance.pop(slot_name, None)


def validate(state: BookingState, spa_data: SpaData, reference: datetime) -> BookingState:
    """Return a copy of ``state`` with business-rule violations resolved."""
    updated = state.model_copy(deep=True)

    if updated.staff_name is not None and updated.staff_name not in spa_data.staff_names():
        updated.warnings.append(
            f"'{updated.staff_name}' không có trong danh sách kỹ thuật viên của spa."
        )
        _clear_slot(updated, "staff_name")

    if updated.phone is not None and not normalize_phone(updated.phone).success:
        updated.warnings.append(f"Số điện thoại '{updated.phone}' không hợp lệ.")
        _clear_slot(updated, "phone")

    if updated.email is not None and not normalize_email(updated.email).success:
        updated.warnings.append(f"Email '{updated.email}' không hợp lệ.")
        _clear_slot(updated, "email")

    if updated.appointment_date is None:
        return updated

    try:
        appointment_date = date.fromisoformat(updated.appointment_date)
    except ValueError:
        return updated

    if appointment_date < reference.date():
        updated.warnings.append(f"Ngày {updated.appointment_date} đã qua rồi.")
        _clear_slot(updated, "appointment_date")
        _clear_slot(updated, "appointment_time")
        return updated

    if updated.appointment_time is None:
        return updated

    weekday = appointment_date.strftime("%A").lower()
    weekday_vn = _VN_WEEKDAY_NAMES.get(weekday, weekday)
    hours = spa_data.opening_hours.get(weekday)
    if hours is None:
        updated.warnings.append(f"Spa đóng cửa vào {weekday_vn}.")
        _clear_slot(updated, "appointment_time")
        return updated

    if not (hours.open <= updated.appointment_time < hours.close):
        updated.warnings.append(
            f"{updated.appointment_time} nằm ngoài giờ mở cửa "
            f"({hours.open}-{hours.close}) {weekday_vn}."
        )
        _clear_slot(updated, "appointment_time")

    return updated
