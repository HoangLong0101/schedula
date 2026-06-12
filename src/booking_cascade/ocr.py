"""OCR front-end: read booking-related text out of an image.

Images (chat screenshots, photos of notes...) are read with EasyOCR --
fully local, torch-based, Vietnamese-capable. The recognized lines are then
filtered down to the ones that look booking-related (dates, times, phones,
emails, spa keywords), so UI noise in screenshots ("Đang hoạt động",
reaction buttons...) doesn't pollute the extraction. The filtered text is
what gets handed to the main extraction process.

The EasyOCR reader is loaded once (and cached) the first time it's needed.
For tests, any object exposing ``readtext(image) -> [(bbox, text, conf)]``
(matching EasyOCR's output shape) can be passed in via the ``reader``
parameter, so the heavy ``easyocr`` stack never needs to be imported in
unit tests.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Optional, Protocol

from booking_cascade.fast_path import resolve_device
from booking_cascade.normalize import EMAIL_RE, PHONE_RE

DEFAULT_LANGUAGES: tuple[str, ...] = ("vi", "en")
DEFAULT_MIN_CONFIDENCE = 0.3
# True/False, or "auto" -> use the GPU when a CUDA torch build is present.
DEFAULT_GPU = "auto"


class OCRReader(Protocol):
    """Anything shaped like ``easyocr.Reader`` -- real or fake."""

    def readtext(self, image: Any) -> list: ...


@dataclass(frozen=True)
class OCRConfig:
    languages: tuple[str, ...] = field(default_factory=lambda: DEFAULT_LANGUAGES)
    # True/False, or "auto" to use CUDA when available.
    gpu: Any = DEFAULT_GPU
    min_confidence: float = DEFAULT_MIN_CONFIDENCE

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "OCRConfig":
        return cls(
            languages=tuple(data.get("languages", DEFAULT_LANGUAGES)),
            gpu=data.get("gpu", DEFAULT_GPU),
            min_confidence=data.get("min_confidence", DEFAULT_MIN_CONFIDENCE),
        )

    def use_gpu(self) -> bool:
        if self.gpu == "auto":
            return resolve_device("auto") == "cuda"
        return bool(self.gpu)


_READER_CACHE: dict[tuple, OCRReader] = {}


def load_reader(config: Optional[OCRConfig] = None) -> OCRReader:
    """Load and cache an EasyOCR reader.

    The ``easyocr`` import is deferred to this function so the rest of the
    codebase (and the test suite, via dependency injection of a fake
    reader) never needs the heavy dependency installed.
    """
    config = config or OCRConfig()
    use_gpu = config.use_gpu()
    key = (config.languages, use_gpu)
    if key not in _READER_CACHE:
        import easyocr

        _READER_CACHE[key] = easyocr.Reader(list(config.languages), gpu=use_gpu)
    return _READER_CACHE[key]


@dataclass(frozen=True)
class OCRLine:
    text: str
    confidence: float


@dataclass(frozen=True)
class OCRResult:
    lines: list[OCRLine]
    full_text: str
    # Lines that look booking-related; empty if none matched.
    booking_lines: list[str]
    # What the extraction pipeline should consume: the booking lines joined,
    # or all recognized text when no line looked booking-related.
    booking_text: str


# Heuristics for "this OCR line is about a booking": spa/booking keywords,
# date/time spans, phone numbers, emails, contact words.
_BOOKING_PATTERNS: tuple[str, ...] = (
    r"đặt|lịch|hẹn|spa|massage|mát.?xa|gội đầu|da mặt|làm móng|nail|triệt lông|xông hơi",
    r"hủy|huỷ|dời|đổi|chuyển|hoãn",
    r"\d{1,2}\s*(?:giờ|h)(?:\s*\d{2})?\b|\d{1,2}:\d{2}|rưỡi\b|sáng\b|chiều\b|tối\b",
    r"\bngày\b|\bhôm nay\b|\bmai\b|\bmốt\b|thứ\s*[2-7]|thứ\s+(?:hai|ba|tư|năm|sáu|bảy)|chủ\s*nhật|\d{1,2}[/-]\d{1,2}",
    r"sđt|số điện thoại|liên hệ|tên (?:em|mình|tôi|là)",
    PHONE_RE.pattern,
    EMAIL_RE.pattern,
)
_BOOKING_RE = re.compile("|".join(f"(?:{p})" for p in _BOOKING_PATTERNS), re.IGNORECASE)


def is_booking_line(text: str) -> bool:
    """True if an OCR line looks related to a spa booking."""
    return bool(_BOOKING_RE.search(text))


def read_image(
    image: bytes,
    config: Optional[OCRConfig] = None,
    reader: Optional[OCRReader] = None,
) -> OCRResult:
    """OCR ``image`` and isolate the booking-related text.

    Returns every recognized line (above ``min_confidence``) plus the
    filtered ``booking_text`` to feed into the extraction pipeline.
    """
    config = config or OCRConfig()
    if reader is None:
        reader = load_reader(config)

    raw = reader.readtext(image)
    lines: list[OCRLine] = []
    for _bbox, text, confidence in raw:
        text = text.strip()
        if text and confidence >= config.min_confidence:
            lines.append(OCRLine(text=text, confidence=float(confidence)))

    full_text = "\n".join(line.text for line in lines)
    booking_lines = [line.text for line in lines if is_booking_line(line.text)]
    if booking_lines:
        booking_text = " ".join(booking_lines)
    else:
        # Nothing looked booking-related: hand over everything rather than
        # silently dropping the message.
        booking_text = " ".join(line.text for line in lines)

    return OCRResult(
        lines=lines,
        full_text=full_text,
        booking_lines=booking_lines,
        booking_text=booking_text,
    )
