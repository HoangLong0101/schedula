"""Simple OCR + entity-extraction CLI (Vietnamese spa appointments).

Takes free-text input, extracts entities with the fast path (GLiNER NER +
phone/email regexes), normalizes them (dates, times, phone, email, service
types), prints the result, and records every extraction into a JSON file
(``logging.entities_log_path`` in ``config.yaml``, default
``logs/entities.json``).

Run from the project root:

    python examples/demo_conversation.py
    python examples/demo_conversation.py path/to/screenshot.png

Example input:

    Đặt lịch massage toàn thân thứ ba tuần sau lúc 3 giờ chiều, tên em là
    Ngọc, sđt 0901234567

You can also enter the path to an image (.png/.jpg...): it runs the same
OCR workflow as ``POST /api/v1/scan-appointment``:

    OCR -> booking-related line filtering -> intent/entities -> JSON fields

Type "quit"/"exit" to leave.
"""

from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

# Allow running this script directly (``python examples/demo_conversation.py``)
# without installing the package: put <project root>/src on sys.path.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from booking_cascade import fast_path  # noqa: E402
from booking_cascade.extractor import (  # noqa: E402
    extract_entities,
    load_model_with_fallback,
    record_extraction,
)
from booking_cascade import ocr  # noqa: E402
from booking_cascade.pipeline import load_config  # noqa: E402

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tiff"}


def _is_image_path(text: str) -> bool:
    path = Path(text.strip('"'))
    return path.suffix.lower() in IMAGE_EXTENSIONS and path.is_file()


def _extract_from_image(
    image_path: Path,
    model: fast_path.EntityModel,
    fast_path_config: fast_path.FastPathConfig,
    ocr_config: ocr.OCRConfig,
    reference: datetime,
) -> dict:
    """Run OCR, filter appointment-related text, then extract entities."""
    print(f"Đang đọc ảnh {image_path.name} (lần đầu EasyOCR cần tải mô hình)...")
    result = ocr.read_image(image_path.read_bytes(), ocr_config)

    record = extract_entities(
        result.booking_text,
        model,
        fast_path_config,
        reference,
        source="image",
    )
    record["ocr"] = {
        "full_text": result.full_text,
        "booking_lines": result.booking_lines,
        "lines": [
            {"text": line.text, "confidence": round(line.confidence, 4)}
            for line in result.lines
        ],
    }
    return record


def _extract_input(
    user_input: str,
    model: fast_path.EntityModel,
    fast_path_config: fast_path.FastPathConfig,
    ocr_config: ocr.OCRConfig,
) -> dict | None:
    """Extract a record from either raw text or an image path."""
    reference = datetime.now()
    path = Path(user_input.strip('"'))
    if not _is_image_path(user_input):
        return extract_entities(user_input, model, fast_path_config, reference, source="text")

    try:
        return _extract_from_image(path, model, fast_path_config, ocr_config, reference)
    except Exception as exc:
        print(
            f"(!) Không OCR được ảnh ({type(exc).__name__}). "
            'Cài OCR bằng: pip install -e ".[ocr]"'
        )
        return None


def _print_entities(record: dict) -> None:
    """Print just the entities extracted from this input."""
    if not record["entities"]:
        print("(không phát hiện thực thể nào)")
        return
    for entity in record["entities"]:
        print(f"- [{entity['label']}] {entity['text']} ({entity['score']:.2f})")


def _resolve_log_path(config: dict) -> Path:
    raw = config.get("logging", {}).get("entities_log_path", "logs/entities.json")
    path = Path(raw)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path


def main() -> None:
    config = load_config()
    fast_path_config = fast_path.FastPathConfig.from_dict(config.get("fast_path", {}))
    print(
        f"Đang tải mô hình GLiNER '{fast_path_config.gliner_model}' "
        "(lần đầu có thể mất vài phút)..."
    )
    model, gliner_loaded = load_model_with_fallback(
        fast_path_config.gliner_model, device=fast_path_config.device
    )
    if gliner_loaded:
        print(f"Thiết bị suy luận: {fast_path.resolve_device(fast_path_config.device)}")
    ocr_config = ocr.OCRConfig.from_dict(config.get("ocr", {}))
    log_path = _resolve_log_path(config)

    print("Trình trích xuất thực thể. Nhập văn bản hoặc đường dẫn ảnh, gõ 'quit' để thoát.")
    print(f"Mỗi lần trích xuất được ghi vào: {log_path}")

    if len(sys.argv) > 1:
        for user_input in sys.argv[1:]:
            record = _extract_input(user_input, model, fast_path_config, ocr_config)
            if record is None:
                continue
            _print_entities(record)
            record_extraction(log_path, record)
        return

    while True:
        try:
            text = input("Văn bản: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if not text:
            continue
        if text.lower() in ("quit", "exit"):
            break

        record = _extract_input(text, model, fast_path_config, ocr_config)
        if record is None:
            continue

        _print_entities(record)
        record_extraction(log_path, record)


if __name__ == "__main__":
    main()
