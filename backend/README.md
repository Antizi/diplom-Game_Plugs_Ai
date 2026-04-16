Запуск через Docker Compose

1\. Склонируйте репозиторий и перейдите в папку проекта.

2\. Убедитесь, что порты 5432 и 8000 не заняты (при необходимости измените их в docker-compose.yml).

3\. Выполните команду:

&#x20;   docker-compose build --no-cache
&#x20;   docker-compose up -d

4\. После успешного старта проверьте, что оба контейнера работают:

&#x20;   docker ps

5\. Get-Content gamedb_backup.sql | docker exec -i postgres-gamedb psql -U postgres -d gamedb – восстановить данные.

6\. Откройте в браузере: http://localhost:8000/docs – должна открыться Swagger-документация.

