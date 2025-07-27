# Multi-stage build for production
FROM python:3.11-slim as builder

# Build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Add local bin to PATH
ENV PATH=/root/.local/bin:$PATH

# Create app user for security
RUN useradd --create-home --shell /bin/bash app
USER app
WORKDIR /home/app

# Copy application code
COPY --chown=app:app . .

# Create models directory
RUN mkdir -p models

# Environment variables
ENV PYTHONPATH=/home/app
ENV MODEL_PATH=/home/app/models
ENV API_PORT=8080
ENV WORKERS=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${API_PORT}/api/v1/health || exit 1

# Expose port
EXPOSE 8080

# Startup script
COPY --chown=app:app deployment/startup.sh /home/app/
RUN chmod +x startup.sh

# Start application
CMD ["./startup.sh"]