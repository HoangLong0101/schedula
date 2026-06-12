"""Shared pytest fixtures.

The fixed reference datetime (Friday 2026-06-12, 09:00) is used everywhere
instead of ``datetime.now()`` so date/time resolution is reproducible.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

import pytest

from tests._helpers import FakeOllamaClient

PROJECT_ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture
def reference_datetime() -> datetime:
    """Friday 2026-06-12, 09:00 -- the fixed 'now' for all tests."""
    return datetime(2026, 6, 12, 9, 0, 0)


@pytest.fixture
def spa_data_path() -> Path:
    return PROJECT_ROOT / "data" / "spa.yaml"


@pytest.fixture
def ollama_client_factory():
    """Returns ``FakeOllamaClient`` -- construct with canned response texts:

    ``ollama_client_factory(responses=['{"intent": "book", "slots": {}}'])``
    """
    return FakeOllamaClient
