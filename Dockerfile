FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml .
COPY cloudrift_runners/ cloudrift_runners/

RUN pip install --no-cache-dir .

RUN mkdir -p /app/data

EXPOSE 8080

CMD ["gunicorn", "cloudrift_runners.main:get_app()", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "1", \
     "--threads", "4", \
     "--access-logfile", "-"]
