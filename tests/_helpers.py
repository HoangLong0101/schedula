"""Small test doubles and helpers shared across test modules."""

from __future__ import annotations

from typing import Any, Optional

import httpx


def make_entity(message: str, text: str, label: str, score: float = 0.9) -> dict[str, Any]:
    """Build a GLiNER-shaped entity dict, deriving start/end from ``message``."""
    start = message.index(text)
    return {"text": text, "label": label, "score": score, "start": start, "end": start + len(text)}


class FakeGLiNERModel:
    """Stand-in for ``GLiNER`` that returns a fixed list of entities."""

    def __init__(self, entities: list[dict[str, Any]]):
        self._entities = entities

    def predict_entities(
        self, text: str, labels: list[str], threshold: float = 0.5
    ) -> list[dict[str, Any]]:
        return [e for e in self._entities if e["label"] in labels and e["score"] >= threshold]


class ScriptedGLiNERModel:
    """Fake GLiNER model returning canned entities keyed by exact message text.

    Useful for multi-turn pipeline tests where each turn's message needs a
    different set of entities.
    """

    def __init__(self, entities_by_text: dict[str, list[dict[str, Any]]]):
        self._entities_by_text = entities_by_text

    def predict_entities(
        self, text: str, labels: list[str], threshold: float = 0.5
    ) -> list[dict[str, Any]]:
        entities = self._entities_by_text.get(text, [])
        return [e for e in entities if e["label"] in labels and e["score"] >= threshold]


class FakeOCRReader:
    """Stand-in for ``easyocr.Reader``: returns canned (bbox, text, conf)
    tuples regardless of the image passed in."""

    def __init__(self, results: list[tuple[Any, str, float]]):
        self._results = results
        self.calls: list[Any] = []

    def readtext(self, image: Any) -> list:
        self.calls.append(image)
        return self._results


def make_ocr_line(text: str, confidence: float = 0.9) -> tuple[Any, str, float]:
    """Build an EasyOCR-shaped result tuple (bbox is unused by the code)."""
    return ([[0, 0], [1, 0], [1, 1], [0, 1]], text, confidence)


class FakeOllamaResponse:
    """Stand-in for ``httpx.Response``."""

    def __init__(self, response_text: str, status_code: int = 200):
        self._response_text = response_text
        self.status_code = status_code

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise httpx.HTTPStatusError(
                "error", request=httpx.Request("POST", "http://x"), response=None
            )

    def json(self) -> dict[str, Any]:
        return {"response": self._response_text}


class FakeOllamaClient:
    """Stand-in for ``httpx.Client``.

    ``responses`` is a queue of response texts (the Ollama "response" field)
    returned on successive ``post`` calls, one per call. If ``raises`` is
    set, every call raises that exception instead (e.g. to simulate Ollama
    being unreachable).
    """

    def __init__(
        self,
        responses: Optional[list[str]] = None,
        raises: Optional[Exception] = None,
    ):
        self._responses = list(responses or [])
        self._raises = raises
        self.calls: list[dict[str, Any]] = []

    def post(self, url: str, json: dict[str, Any], timeout: float) -> FakeOllamaResponse:
        self.calls.append({"url": url, "json": json, "timeout": timeout})
        if self._raises is not None:
            raise self._raises
        response_text = self._responses.pop(0)
        return FakeOllamaResponse(response_text)
