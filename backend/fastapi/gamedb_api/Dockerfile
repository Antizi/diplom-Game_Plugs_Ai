FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./gamedb_backend ./gamedb_backend
# COPY .env .env   # опционально, можно передавать через environment
EXPOSE 8000
CMD ["uvicorn", "gamedb_backend.main:app", "--host", "0.0.0.0", "--port", "8000"]