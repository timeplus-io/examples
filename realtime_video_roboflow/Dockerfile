FROM python:3.12.10 AS builder

# Install build dependencies for all packages
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
RUN pip install --upgrade pip
RUN pip install wheel
RUN pip install fastapi uvicorn opencv-python python-multipart inference supervision proton-driver

# Final slim image
FROM python:3.12.10-slim

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libgl1 \
    ffmpeg \
    libavcodec-extra \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /timeplus
ADD ./server.py /timeplus/
ADD ./static/ /timeplus/static/

EXPOSE 5001

ENTRYPOINT ["python", "server.py"]