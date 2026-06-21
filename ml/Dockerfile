FROM python:3.11-slim
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY predictor.py main.py ./
COPY training/ training/
COPY scripts/ scripts/

ENV MODELS_DIR=/app/models
ENV MODEL_ONNX_PATH=/app/models/classifier.onnx
ENV MODEL_META_PATH=/app/models/model_meta.json

EXPOSE 8001

# При первом старте с пустым volume — генерируем синтетическую модель.
# После POST /train она заменяется моделью на реальных данных из Postgres.
CMD ["sh", "-c", "test -f $MODEL_ONNX_PATH || python scripts/train_model.py && python -m uvicorn main:app --host 0.0.0.0 --port 8001"]
