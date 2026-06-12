FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

# Runtime libraries needed by OpenCV/EasyOCR, plus build tools for Python wheels
# that may not have a prebuilt binary for the target platform.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml README.md ./
COPY src ./src
COPY config.yaml ./
COPY data ./data

# PyTorch pip wheels bundle the CUDA runtime, so a plain Python base image is
# enough for GPU inference -- the host only needs the NVIDIA driver and the
# container must be started with GPU access (--gpus all).
# For a smaller CPU-only image, build with:
#   docker build --build-arg TORCH_INDEX=https://download.pytorch.org/whl/cpu .
ARG TORCH_INDEX=https://download.pytorch.org/whl/cu130
RUN python -m pip install --upgrade pip \
    && python -m pip install torch torchvision --index-url ${TORCH_INDEX} \
    && python -m pip install -e ".[api,ocr]"

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/v1/health', timeout=3).read()"

CMD ["uvicorn", "booking_cascade.api:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
