# syntax=docker/dockerfile:1

# --- build stage: install deps into an isolated prefix -----------------------
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
# Install into /install so we can copy only what's needed into the final image.
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- runtime stage: small, non-root ------------------------------------------
FROM python:3.12-slim AS runtime

# Create an unprivileged user; never run as root.
RUN groupadd --system app && useradd --system --gid app --home /app app
WORKDIR /app

COPY --from=build /install /usr/local
COPY app.py .

ENV PORT=8080 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
EXPOSE 8080
USER app

# 2 workers x 4 threads is plenty for a demo; tune via replicas/HPA in k8s.
# --timeout keeps a stuck request from wedging a worker forever.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", \
     "--timeout", "30", "--access-logfile", "-", "app:app"]
