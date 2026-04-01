from fastapi import APIRouter, Request
from pydantic import BaseModel
from typing import Optional, Any

router = APIRouter(tags=["test"])


# Модель для входящих данных (если Godot что-то отправляет)
class TestPayload(BaseModel):
    message: Optional[str] = None
    data: Optional[Any] = None


@router.post("/test", summary="Тестовый эндпоинт для Godot")
async def test_endpoint(payload: TestPayload = None):
    """
    Принимает POST-запрос от Godot-клиента и возвращает подтверждение.
    Можно отправить JSON с полями `message` и `data` (оба необязательны).
    """
    # Если payload не передан (пустое тело), создаём заглушку
    if payload is None:
        payload = TestPayload()

    return {
        "status": "ok",
        "received": payload.dict(exclude_unset=True),
        "message": "Сервер работает!",
        "hint": "Это тестовый эндпоинт для проверки связи."
    }