from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()  # загружаем переменные из .env

# Параметры подключения к БД (можно прописать прямо здесь или брать из .env)
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "gamedb")

# Формируем URL для подключения
SQLALCHEMY_DATABASE_URL = "postgresql://postgres:123@localhost:5432/gamedb"
# Создаем движок
engine = create_engine(SQLALCHEMY_DATABASE_URL)

# Сессия для работы с БД
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Базовый класс для моделей
Base = declarative_base()