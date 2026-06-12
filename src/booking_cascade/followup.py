"""Generate the next clarifying question (or final confirmation), in Vietnamese."""

from __future__ import annotations

from typing import Optional

from booking_cascade.schema import REQUIRED_SLOTS, BookingState, SlotUpdate

# Order in which pending confirmations are surfaced: date, time, then
# customer info, then staff.
PRIORITY_SLOTS: tuple[str, ...] = (
    "appointment_date",
    "appointment_time",
    "customer_name",
    "phone",
    "email",
    "staff_name",
)


def _missing_slot_question(state: BookingState, slot_name: str) -> str:
    if slot_name == "appointment_date":
        if state.intent == "reschedule" and state.reschedule_from_date is None:
            return (
                "Anh/chị muốn dời lịch hẹn nào, và đổi sang ngày nào ạ?"
            )
        return "Anh/chị muốn đặt lịch vào ngày nào ạ?"
    if slot_name == "appointment_time":
        if state.appointment_date:
            return f"Anh/chị muốn đến lúc mấy giờ ngày {state.appointment_date} ạ?"
        return "Anh/chị muốn đến lúc mấy giờ ạ?"
    if slot_name == "customer_name":
        return "Anh/chị cho em xin tên người đặt lịch ạ?"
    if slot_name == "phone":
        return "Anh/chị cho em xin số điện thoại để xác nhận lịch hẹn ạ?"
    return "Anh/chị có thể cho em thêm thông tin về lịch hẹn không ạ?"


def _confirmation_summary(state: BookingState) -> str:
    if state.intent == "cancel":
        return (
            f"Em sẽ hủy lịch hẹn ngày {state.appointment_date} lúc "
            f"{state.appointment_time} của anh/chị. Đúng không ạ?"
        )

    details = [f"ngày {state.appointment_date} lúc {state.appointment_time}"]
    if state.service_type:
        details.append(f"dịch vụ {state.service_type}")
    if state.staff_name:
        details.append(f"với kỹ thuật viên {state.staff_name}")
    details.append(f"cho khách {state.customer_name}")
    details.append(f"SĐT {state.phone}")
    if state.email:
        details.append(f"email {state.email}")
    detail_text = ", ".join(details)

    if state.intent == "reschedule" and state.reschedule_from_date and state.reschedule_from_time:
        return (
            f"Em sẽ dời lịch hẹn của anh/chị từ {state.reschedule_from_date} "
            f"{state.reschedule_from_time} sang {detail_text}. Đúng không ạ?"
        )

    return f"Em xin xác nhận lịch hẹn {detail_text}. Đúng không ạ?"


def generate_followup(state: BookingState, slot_update: Optional[SlotUpdate] = None) -> str:
    """Produce the reply text for this turn.

    Grounding confirmations (e.g. "Ý anh/chị là kỹ thuật viên X?") take
    priority over missing-slot questions. If the state is bookable, a
    confirmation summary is returned instead of a question. Any pending
    warnings are prepended.
    """
    if slot_update is not None and slot_update.needs_confirmation:
        for slot_name in PRIORITY_SLOTS:
            if slot_name in slot_update.needs_confirmation:
                question = slot_update.needs_confirmation[slot_name]
                break
        else:
            question = next(iter(slot_update.needs_confirmation.values()))
        return _with_warnings(state, question)

    if state.is_bookable():
        return _with_warnings(state, _confirmation_summary(state))

    for slot_name in REQUIRED_SLOTS:
        if getattr(state, slot_name) is None:
            return _with_warnings(state, _missing_slot_question(state, slot_name))

    return _with_warnings(state, "Anh/chị có thể cho em thêm thông tin về lịch hẹn không ạ?")


def _with_warnings(state: BookingState, message: str) -> str:
    if not state.warnings:
        return message
    return " ".join(state.warnings) + " " + message
