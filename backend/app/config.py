import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "your_password")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "gamedb")

SQLALCHEMY_DATABASE_URL = (
    f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

ML_SERVICE_URL = os.getenv("ML_SERVICE_URL", "").strip()
ML_PREDICT_ENABLED = os.getenv("ML_PREDICT_ENABLED", "false").lower() == "true"
BOOTSTRAP_ACTIONS_DEFAULT = int(os.getenv("BOOTSTRAP_ACTIONS", "10"))

MODELS_DIR = Path(os.getenv("MODELS_DIR", "/app/models"))
CORS_ORIGINS = [
    o.strip()
    for o in os.getenv("CORS_ORIGINS", "*").split(",")
    if o.strip()
]
