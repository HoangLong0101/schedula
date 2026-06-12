"""HTTP API for appointment extraction -- the backend for Flutter clients.

Endpoints:

- ``POST /api/v1/extract`` stateless entity extraction from one text.
- ``POST /api/v1/scan-appointment`` image upload -> OCR -> booking text -> extraction.
- ``POST /api/v1/extract-image`` backward-compatible image extraction alias.
- ``GET /api/v1/spa-info`` staff roster, services, opening hours.
- ``GET /api/v1/health`` liveness + whether the GLiNER model loaded.

Run:

    uvicorn booking_cascade.api:create_app --factory --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from booking_cascade import fast_path, ocr
from booking_cascade.extractor import (
    extract_entities,
    load_model_with_fallback,
    record_extraction,
)
from booking_cascade.grounding import SpaData, load_spa_data
from booking_cascade.pipeline import load_config

API_PREFIX = "/api/v1"
_PROJECT_ROOT = Path(__file__).resolve().parents[2]


class ExtractRequest(BaseModel):
    text: str = Field(min_length=1)
    # Append the extraction to logging.entities_log_path (default on).
    record: bool = True
    reference: Optional[datetime] = None


class StaffInfo(BaseModel):
    name: str
    services: list[str]


class SpaInfoResponse(BaseModel):
    staff: list[StaffInfo]
    service_types: list[str]
    opening_hours: dict[str, dict[str, str]]
    default_service_duration_minutes: int


class HealthResponse(BaseModel):
    status: str
    gliner_loaded: bool
    gliner_model: str
    # Resolved inference device ("cuda" / "cpu") -- handy for checking that
    # the container actually got the GPU.
    device: str


class EntityItem(BaseModel):
    text: str
    label: str
    score: float
    start: int
    end: int


class SlotItem(BaseModel):
    value: Any
    confidence: float
    source_span: str


class OCRLineItem(BaseModel):
    text: str
    confidence: float


class OCRPayload(BaseModel):
    full_text: str
    booking_lines: list[str]
    lines: list[OCRLineItem]


class ExtractionResponse(BaseModel):
    source: str
    timestamp: str
    text: str
    intent: str
    entities: list[EntityItem]
    slots: dict[str, SlotItem]
    # Flat values for Flutter forms/state: {"appointment_date": "2026-06-16", ...}
    extracted_fields: dict[str, Any]
    warnings: list[str]
    ocr: Optional[OCRPayload] = None


def create_app(
    config: Optional[dict[str, Any]] = None,
    spa_data: Optional[SpaData] = None,
    fast_path_model: Optional[fast_path.EntityModel] = None,
    ocr_reader: Optional[ocr.OCRReader] = None,
) -> FastAPI:
    """Build the extraction-only FastAPI app.

    All collaborators are injectable for tests. By default the config is read
    from ``config.yaml``, the GLiNER model is loaded eagerly with a regex-only
    fallback, and the EasyOCR reader is loaded lazily on the first image request.
    """
    config = config if config is not None else load_config()
    fast_path_config = fast_path.FastPathConfig.from_dict(config.get("fast_path", {}))
    ocr_config = ocr.OCRConfig.from_dict(config.get("ocr", {}))

    if fast_path_model is None:
        fast_path_model, gliner_loaded = load_model_with_fallback(
            fast_path_config.gliner_model, device=fast_path_config.device
        )
    else:
        gliner_loaded = True

    if spa_data is not None:
        shared_spa_data = spa_data
    else:
        spa_data_path = Path(config.get("spa_data_path", "data/spa.yaml"))
        if not spa_data_path.is_absolute():
            spa_data_path = _PROJECT_ROOT / spa_data_path
        shared_spa_data = load_spa_data(spa_data_path)

    ocr_state: dict[str, Any] = {"reader": ocr_reader, "error": None}

    def _get_ocr_reader() -> ocr.OCRReader:
        if ocr_state["reader"] is None and ocr_state["error"] is None:
            try:
                ocr_state["reader"] = ocr.load_reader(ocr_config)
            except Exception as exc:
                ocr_state["error"] = f"{type(exc).__name__}: {exc}"
        if ocr_state["reader"] is None:
            raise HTTPException(
                status_code=503,
                detail=(
                    "OCR không khả dụng (cài bằng: pip install -e \".[ocr]\"). "
                    f"Lỗi: {ocr_state['error']}"
                ),
            )
        return ocr_state["reader"]

    raw_log_path = config.get("logging", {}).get("entities_log_path", "logs/entities.json")
    entities_log_path = Path(raw_log_path)
    if not entities_log_path.is_absolute():
        entities_log_path = _PROJECT_ROOT / entities_log_path

    app = FastAPI(
        title="Spa Appointment Extraction API",
        description="Vietnamese spa-booking OCR and entity extraction API.",
        version="0.1.0",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # development; restrict for production
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.post(f"{API_PREFIX}/extract", response_model=ExtractionResponse)
    def extract(request: ExtractRequest) -> dict[str, Any]:
        record = extract_entities(
            request.text, fast_path_model, fast_path_config, request.reference
        )
        if request.record:
            record_extraction(entities_log_path, record)
        return record

    async def _scan_image_payload(
        image: UploadFile = File(...),
        record: bool = True,
        reference: Optional[datetime] = None,
    ) -> dict[str, Any]:
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=422, detail="Empty image upload")

        ocr_result = ocr.read_image(image_bytes, ocr_config, reader=_get_ocr_reader())
        extraction = extract_entities(
            ocr_result.booking_text,
            fast_path_model,
            fast_path_config,
            reference,
            source="image",
        )
        extraction["ocr"] = {
            "full_text": ocr_result.full_text,
            "booking_lines": ocr_result.booking_lines,
            "lines": [
                {"text": line.text, "confidence": round(line.confidence, 4)}
                for line in ocr_result.lines
            ],
        }
        if record:
            record_extraction(entities_log_path, extraction)
        return extraction

    @app.post(f"{API_PREFIX}/scan-appointment", response_model=ExtractionResponse)
    async def scan_appointment(
        image: UploadFile = File(...),
        record: bool = True,
        reference: Optional[datetime] = None,
    ) -> dict[str, Any]:
        return await _scan_image_payload(image=image, record=record, reference=reference)

    @app.post(f"{API_PREFIX}/extract-image", response_model=ExtractionResponse)
    async def extract_image(
        image: UploadFile = File(...),
        record: bool = True,
        reference: Optional[datetime] = None,
    ) -> dict[str, Any]:
        return await _scan_image_payload(image=image, record=record, reference=reference)

    @app.get(f"{API_PREFIX}/spa-info", response_model=SpaInfoResponse)
    def spa_info() -> SpaInfoResponse:
        return SpaInfoResponse(
            staff=[
                StaffInfo(name=member.name, services=list(member.services))
                for member in shared_spa_data.staff
            ],
            service_types=list(shared_spa_data.service_types),
            opening_hours={
                day: {"open": hours.open, "close": hours.close}
                for day, hours in shared_spa_data.opening_hours.items()
            },
            default_service_duration_minutes=shared_spa_data.default_service_duration_minutes,
        )

    @app.get(f"{API_PREFIX}/health", response_model=HealthResponse)
    def health() -> HealthResponse:
        return HealthResponse(
            status="ok",
            gliner_loaded=gliner_loaded,
            gliner_model=fast_path_config.gliner_model,
            device=fast_path.resolve_device(fast_path_config.device),
        )

    return app


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(create_app(), host="0.0.0.0", port=8000)
