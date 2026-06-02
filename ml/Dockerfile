FROM python:3.11-slim
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY predictor.py main.py ./
COPY scripts/train_model.py scripts/train_model.py
RUN python scripts/train_model.py

ENV MODELS_DIR=/app/models
ENV MODEL_ONNX_PATH=/app/models/classifier.onnx
ENV MODEL_META_PATH=/app/models/model_meta.json

EXPOSE 8001
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
