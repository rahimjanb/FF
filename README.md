# Fitness Formulasi

Система фитнес-клуба. Этап 1 (MVP).

| Часть | Технологии | Папка |
|---|---|---|
| Backend API | ASP.NET Core 10, EF Core 10, PostgreSQL 17, JWT | [backend/](backend/) |
| Веб-панель администратора | React 19, TypeScript, Vite | [admin/](admin/) |
| Мобильное приложение (клиент и кабинет тренера) | Flutter 3.47, Dart 3.13 | [mobile/](mobile/) |
| Инфраструктура | Docker Compose | [infrastructure/](infrastructure/) |
| Документация | | [docs/](docs/) |

## Быстрый старт

```bash
# 1. База данных
cp infrastructure/.env.example infrastructure/.env   # задайте POSTGRES_PASSWORD
docker compose -f infrastructure/docker-compose.yml up -d postgres

# 2. Backend (секреты — через user-secrets, см. docs/DEVELOPMENT.md)
cd backend/src/FitnessFormulasi.Api && ASPNETCORE_ENVIRONMENT=Development dotnet run   # http://localhost:5080/swagger

# 3. Веб-панель
cd admin && npm install && npm run dev                # http://localhost:5173

# 4. Мобильное приложение
cd mobile && flutter run
```

Подробности:
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — запуск, конфигурация, первый администратор.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — архитектура, модель данных, безопасность, бизнес-правила.
- [docs/TESTING.md](docs/TESTING.md) — тесты и ручная проверка.
- [docs/PROGRESS.md](docs/PROGRESS.md) — статус функций и результаты проверок.
- [docs/OPERATIONS.md](docs/OPERATIONS.md) — секреты, миграции, резервное копирование, требования к серверу.
- [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md) — соответствие договору и ТЗ, сценарий демонстрации, чек-лист приёмки.
- [docs/CLIENT_DECISIONS.md](docs/CLIENT_DECISIONS.md) — вопросы для письменного согласования с заказчиком.

## Что входит и не входит в этап 1

Входит: регистрация и вход по телефону, роли (клиент / тренер / администратор), абонементы и планы,
заявки на тренера, тренировки, ручной учёт посещений, внутренние уведомления, dashboard и отчёты,
русский и узбекский языки в мобильном приложении.

Не входит (этап 2): SMS-подтверждение через провайдера, Click/Payme, турникет, автопродление,
push-уведомления и рассылки, промокоды, 1С, фитнес-бар и склад. Точки расширения описаны в
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#точки-расширения-этап-2).
