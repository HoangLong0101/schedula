"""Tests for the extraction HTTP API (FastAPI TestClient, all models faked)."""

from fastapi.testclient import TestClient

from booking_cascade.api import create_app
from booking_cascade.fast_path import LABEL_DATE, LABEL_PERSON, LABEL_SERVICE, LABEL_TIME
from tests._helpers import (
    FakeOCRReader,
    ScriptedGLiNERModel,
    make_entity,
    make_ocr_line,
)

REFERENCE = "2026-06-12T09:00:00"  # Friday

BOOKING_MESSAGE = (
    "Đặt lịch massage toàn thân với chị Hương thứ ba tuần sau lúc "
    "3 giờ chiều, tên em là Ngọc, sđt 0901234567"
)


def _booking_entities():
    return [
        make_entity(BOOKING_MESSAGE, "Hương", LABEL_PERSON, 0.95),
        make_entity(BOOKING_MESSAGE, "Ngọc", LABEL_PERSON, 0.9),
        make_entity(BOOKING_MESSAGE, "thứ ba tuần sau", LABEL_DATE, 0.9),
        make_entity(BOOKING_MESSAGE, "3 giờ chiều", LABEL_TIME, 0.9),
        make_entity(BOOKING_MESSAGE, "massage toàn thân", LABEL_SERVICE, 0.85),
    ]


# What the fake OCR "reads" from an uploaded screenshot: noise + booking lines.
OCR_SCREENSHOT_LINES = [
    make_ocr_line("Đang hoạt động", 0.9),
    make_ocr_line("Đặt lịch massage thứ ba tuần sau lúc 3 giờ chiều", 0.95),
    make_ocr_line("sđt 0901234567", 0.9),
    make_ocr_line("Thích · Trả lời", 0.9),
]
OCR_BOOKING_TEXT = "Đặt lịch massage thứ ba tuần sau lúc 3 giờ chiều sđt 0901234567"


def _client(responses=None, ocr_reader=None) -> TestClient:
    entities_by_text = {
        BOOKING_MESSAGE: _booking_entities(),
        OCR_BOOKING_TEXT: [
            make_entity(OCR_BOOKING_TEXT, "thứ ba tuần sau", LABEL_DATE, 0.9),
            make_entity(OCR_BOOKING_TEXT, "3 giờ chiều", LABEL_TIME, 0.9),
        ],
    }
    app = create_app(
        config={},
        fast_path_model=ScriptedGLiNERModel(entities_by_text),
        ocr_reader=ocr_reader,
    )
    return TestClient(app)


def test_health():
    response = _client().get("/api/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["gliner_loaded"] is True


def test_spa_info():
    response = _client().get("/api/v1/spa-info")

    assert response.status_code == 200
    body = response.json()
    staff_names = [member["name"] for member in body["staff"]]
    assert "Trần Thu Hương" in staff_names
    assert "massage toàn thân" in body["service_types"]
    assert body["opening_hours"]["sunday"] == {"open": "09:00", "close": "18:00"}
    assert "monday" not in body["opening_hours"]


def test_chatbot_routes_are_removed():
    client = _client()

    assert client.post("/api/v1/chat", json={"message": BOOKING_MESSAGE}).status_code == 404
    assert client.get("/api/v1/sessions/anything").status_code == 404
    assert client.delete("/api/v1/sessions/anything").status_code == 404


def test_extract_stateless():
    response = _client().post(
        "/api/v1/extract",
        json={"text": BOOKING_MESSAGE, "record": False, "reference": REFERENCE},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["intent"] == "book"
    labels = [e["label"] for e in body["entities"]]
    assert "số điện thoại" in labels
    assert body["slots"]["appointment_date"]["value"] == "2026-06-16"
    assert body["slots"]["appointment_time"]["value"] == "15:00"
    assert body["slots"]["phone"]["value"] == "0901234567"
    assert body["extracted_fields"]["customer_name"] == "Ngọc"
    assert body["extracted_fields"]["staff_name"] == "Hương"
    assert body["extracted_fields"]["appointment_date"] == "2026-06-16"
    assert body["extracted_fields"]["appointment_time"] == "15:00"
    assert body["extracted_fields"]["service_type"] == "massage toàn thân"
    assert body["extracted_fields"]["phone"] == "0901234567"


def test_empty_extract_text_is_rejected():
    response = _client().post("/api/v1/extract", json={"text": ""})

    assert response.status_code == 422


def test_extract_image_runs_ocr_then_main_extraction():
    client = _client(ocr_reader=FakeOCRReader(OCR_SCREENSHOT_LINES))

    response = client.post(
        "/api/v1/extract-image",
        params={"record": "false", "reference": REFERENCE},
        files={"image": ("screenshot.png", b"fake-image-bytes", "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "image"
    assert body["text"] == OCR_BOOKING_TEXT
    assert body["intent"] == "book"
    assert body["slots"]["appointment_date"]["value"] == "2026-06-16"
    assert body["slots"]["appointment_time"]["value"] == "15:00"
    assert body["slots"]["phone"]["value"] == "0901234567"
    assert body["extracted_fields"]["appointment_date"] == "2026-06-16"
    assert body["extracted_fields"]["appointment_time"] == "15:00"
    assert body["extracted_fields"]["phone"] == "0901234567"
    # OCR metadata: noise lines kept in full_text but excluded from booking text
    assert "Đang hoạt động" in body["ocr"]["full_text"]
    assert body["ocr"]["booking_lines"] == [
        "Đặt lịch massage thứ ba tuần sau lúc 3 giờ chiều",
        "sđt 0901234567",
    ]


def test_scan_appointment_alias_runs_full_image_workflow():
    client = _client(ocr_reader=FakeOCRReader(OCR_SCREENSHOT_LINES))

    response = client.post(
        "/api/v1/scan-appointment",
        params={"record": "false", "reference": REFERENCE},
        files={"image": ("screenshot.png", b"fake-image-bytes", "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "image"
    assert body["text"] == OCR_BOOKING_TEXT
    assert body["intent"] == "book"
    assert body["extracted_fields"]["appointment_date"] == "2026-06-16"
    assert body["extracted_fields"]["appointment_time"] == "15:00"
    assert body["extracted_fields"]["phone"] == "0901234567"
    assert body["ocr"]["booking_lines"] == [
        "Đặt lịch massage thứ ba tuần sau lúc 3 giờ chiều",
        "sđt 0901234567",
    ]


def test_extract_image_returns_503_when_ocr_unavailable(monkeypatch):
    from booking_cascade import ocr as ocr_module

    def boom(config=None):
        raise ImportError("No module named 'easyocr'")

    monkeypatch.setattr(ocr_module, "load_reader", boom)
    client = _client(ocr_reader=None)

    response = client.post(
        "/api/v1/extract-image",
        files={"image": ("a.png", b"bytes", "image/png")},
    )

    assert response.status_code == 503
    assert "OCR" in response.json()["detail"]


def test_extract_image_rejects_empty_upload():
    client = _client(ocr_reader=FakeOCRReader([]))

    response = client.post(
        "/api/v1/extract-image",
        files={"image": ("empty.png", b"", "image/png")},
    )

    assert response.status_code == 422
