# booking_cascade

A fully local API for extracting structured **spa appointment** data from
Vietnamese text or appointment screenshots -- no cloud APIs involved. It
extracts customer info (name, phone, email), booking date/time, requested
service, technician, and intent as JSON for Flutter app integration.

## Architecture

```text
image or text input
  -> ocr.py           OCR images and keep appointment-related lines
  -> intent.py        regex intent classifier (book/reschedule/cancel/query)
  -> fast_path.py      GLiNER NER (multilingual) + phone/email regexes
  -> normalize.py       Vietnamese relative dates / times ("3 giờ chiều"),
                        phone (+84 -> 0...), email, service aliases -> canonical
  -> JSON output        intent, entities, slots, extracted_fields, OCR metadata
```

Extracted slots: `customer_name`, `phone`, `email`, `appointment_date`,
`appointment_time`, `service_type`, `staff_name`, `duration_minutes`,
`notes`, and `reschedule_from_date`/`reschedule_from_time`.

## Setup

Requires Python 3.10+.

```bash
pip install -e ".[dev]"
```

The fast path uses a local multilingual [GLiNER](https://github.com/urchade/GLiNER)
model (`urchade/gliner_multi-v2.1`, handles Vietnamese; CPU-only `torch` is
fine; the model is downloaded and cached on first use). Phone numbers and
emails are extracted with deterministic regexes, not NER.

Image scanning uses EasyOCR when installed with the `ocr` extra.

## Configuration

All thresholds, model names, and connection details live in `config.yaml`
(never hardcoded):

- `fast_path`: GLiNER model name, entity confidence threshold, NER labels
  (Vietnamese).
- `ocr`: EasyOCR languages, GPU setting, and minimum confidence.
- `logging`: path for extraction records.
- `spa_data_path`: path to the spa roster (`data/spa.yaml`).

## Running the tests

```bash
pytest
pytest --cov=booking_cascade --cov-report=term-missing
```

Tests use fake GLiNER/OCR implementations, so the API tests do not require a
downloaded GLiNER model or EasyOCR model.

## HTTP API (backend for Flutter & other clients)

Install the API extras and start the server:

```bash
pip install -e ".[api,ocr]"
uvicorn booking_cascade.api:create_app --factory --host 0.0.0.0 --port 8000
```

Interactive OpenAPI docs: http://localhost:8000/docs. CORS is wide open for
development.

| Method | Path                        | Purpose                                          |
| ------ | --------------------------- | ------------------------------------------------ |
| POST   | `/api/v1/extract`           | Stateless entity extraction from one text        |
| POST   | `/api/v1/scan-appointment`  | Image upload: OCR -> booking text -> extraction  |
| POST   | `/api/v1/extract-image`     | Backward-compatible alias for image extraction   |
| GET    | `/api/v1/spa-info`          | Staff roster, services, opening hours            |
| GET    | `/api/v1/health`            | Liveness + whether the GLiNER model loaded       |

### Calling from Flutter

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class BookingApi {
  BookingApi(this.baseUrl);

  final String baseUrl; // e.g. 'http://10.0.2.2:8000' on the Android emulator

  Future<Map<String, dynamic>> extractText(String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/extract'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'text': text, 'record': false}),
    );
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
  }
}
```

Tips for Flutter development:

- Android emulator reaches your host machine at `http://10.0.2.2:8000`;
  iOS simulator and Flutter web use `http://localhost:8000`; a physical
  device needs your machine's LAN IP (and `--host 0.0.0.0`).
- Always decode with `utf8.decode(response.bodyBytes)` so the Vietnamese
  text renders correctly.
- Bind `extracted_fields` directly into your Flutter appointment form.

### Image scanning workflow

For message screenshots or appointment-note images, call:

```http
POST /api/v1/scan-appointment?record=false
Content-Type: multipart/form-data

image=@screenshot.png
```

The endpoint runs:

```text
OCR -> booking-related line filtering -> intent/entity extraction -> normalized JSON fields
```

Response fields useful for Flutter:

- `text`: OCR text that was actually extracted from.
- `intent`: `book`, `reschedule`, `cancel`, or `query`.
- `entities`: raw detected spans with labels and confidence.
- `slots`: normalized extracted slots with confidence and source spans.
- `extracted_fields`: flat form-friendly values, e.g.
  `{"appointment_date": "2026-06-16", "appointment_time": "15:00", "phone": "0901234567"}`.
- `ocr.full_text` and `ocr.booking_lines`: OCR debugging/display metadata.

## Demo: entity extraction

```bash
python examples/demo_conversation.py
```

A simple CLI: type Vietnamese text, get the extracted entities back, e.g.:

```
Văn bản: Đặt lịch massage toàn thân thứ ba tuần sau lúc 3 giờ chiều, tên em là Ngọc, sđt 0901234567
```

Each input is classified (intent), run through the fast path (GLiNER NER +
phone/email regexes), and normalized (ISO dates, 24h times, canonical phone/
email/service forms). The result -- raw entities, normalized slots, and any
warnings -- is printed as JSON and appended to the JSON file configured at
`logging.entities_log_path` (default `logs/entities.json`).

Type `quit`/`exit` to leave.

## Docker Deployment

Build and run the API container:

```bash
docker build -t booking-cascade-api .
docker run --rm -p 8000:8000 -v booking-model-cache:/root/.cache booking-cascade-api
```

Or use Compose:

```bash
docker compose up --build
```

Check the API:

```bash
curl http://localhost:8000/api/v1/health
```

Scan an appointment image:

```bash
curl -X POST "http://localhost:8000/api/v1/scan-appointment?record=false" \
  -F "image=@/path/to/screenshot.png"
```

The mounted `/root/.cache` volume keeps GLiNER/EasyOCR model downloads between
container runs. The Compose file also mounts `./logs` to persist extraction
records.
