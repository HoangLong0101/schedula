"""Pure regex/keyword intent classification for Vietnamese spa messages.

No ML involved: a message is classified by checking ordered groups of
regex patterns. The first group that matches wins, in priority order
``cancel > reschedule > query > book`` (book is the default when nothing
else matches).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional

from booking_cascade.schema import Intent

# "hủy" and "huỷ" are two common Unicode spellings of the same word.
CANCEL_PATTERNS: tuple[str, ...] = (
    r"\b(?:hủy|huỷ)\b",
    r"\bbỏ (?:lịch|hẹn|buổi hẹn)\b",
    r"\bkhông (?:cần|đến|tới)\b.*\b(?:lịch|hẹn)\b.*\bnữa\b",
    r"\bkhỏi đặt\b",
    r"\bcancel\w*\b",
)

RESCHEDULE_PATTERNS: tuple[str, ...] = (
    r"\bdời\b",
    r"\bđổi\b.*\b(?:lịch|hẹn)\b",
    r"\bchuyển\b.*\b(?:lịch|hẹn)\b",
    r"\blùi (?:lịch|hẹn)\b",
    r"\bhoãn\b",
    r"\bsang (?:ngày|giờ|hôm|buổi) khác\b",
    r"\breschedul\w*\b",
)

QUERY_PATTERNS: tuple[str, ...] = (
    r"\blịch (?:hẹn )?của (?:tôi|mình|em|chị|anh)\b",
    r"\bkhi nào\b",
    r"\bmấy giờ\b",
    r"\bkiểm tra (?:lịch|hẹn)\b",
    r"\bxem (?:lại )?lịch\b",
    r"\bcòn (?:trống|chỗ|slot)\b",
    r"\bcó lịch\b.*\bkhông\b",
)

BOOK_PATTERNS: tuple[str, ...] = (
    r"\bđặt (?:lịch|hẹn|chỗ|slot)\b",
    r"\bmuốn đặt\b",
    r"\bđăng ký\b",
    r"\blấy hẹn\b",
    r"\bmuốn làm\b",
    r"\bcho (?:mình|tôi|em) (?:một|1)? ?(?:suất|lịch|slot)\b",
    r"\bbook\w*\b",
)

_PRIORITY: tuple[tuple[Intent, tuple[str, ...]], ...] = (
    ("cancel", CANCEL_PATTERNS),
    ("reschedule", RESCHEDULE_PATTERNS),
    ("query", QUERY_PATTERNS),
    ("book", BOOK_PATTERNS),
)


@dataclass(frozen=True)
class IntentResult:
    """Classified intent plus the phrase that triggered it (for logs/UX)."""

    intent: Intent
    matched_phrase: Optional[str] = None


def detect_intent(message: str) -> IntentResult:
    """Classify ``message`` into book/reschedule/cancel/query.

    Returns ``IntentResult(intent="book", matched_phrase=None)`` when no
    pattern matches, since "book" is the default intent.
    """
    text = message.lower()
    for intent, patterns in _PRIORITY:
        for pattern in patterns:
            match = re.search(pattern, text)
            if match:
                return IntentResult(intent=intent, matched_phrase=match.group(0))
    return IntentResult(intent="book", matched_phrase=None)
