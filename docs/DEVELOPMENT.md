# Запуск для разработки

## Требования

Flutter 3.47 (stable), .NET SDK 10, Node.js 24 LTS, Docker Desktop, Xcode, Android Studio.

## 1. PostgreSQL

```bash
cp infrastructure/.env.example infrastructure/.env      # не коммитится
# в .env задайте POSTGRES_PASSWORD
docker compose -f infrastructure/docker-compose.yml up -d postgres
```

Порт привязан к `127.0.0.1:5432`, данные лежат в volume `fitness-formulasi_postgres-data`.
Остановка без потери данных: `docker compose -f infrastructure/docker-compose.yml stop`.

## 2. Backend

Секреты для локального запуска хранятся в `dotnet user-secrets`, вне репозитория:

```bash
cd backend/src/FitnessFormulasi.Api
dotnet user-secrets set "ConnectionStrings:Default" "Host=localhost;Port=5432;Database=fitness_formulasi;Username=ff_app;Password=<из .env>"
dotnet user-secrets set "Jwt:SigningKey" "$(openssl rand -base64 48)"
# Первый администратор. Создаётся один раз, только если администраторов ещё нет:
dotnet user-secrets set "Bootstrap:AdminPhone" "+998XXXXXXXXX"
dotnet user-secrets set "Bootstrap:AdminPassword" "<надёжный пароль>"

ASPNETCORE_ENVIRONMENT=Development dotnet run --launch-profile http
```

- API доступен на `http://localhost:5080` (на всех интерфейсах, чтобы его видели эмулятор и телефон).
- Swagger: `http://localhost:5080/swagger`.
- Health check: `http://localhost:5080/health`.
- В Development миграции применяются автоматически. Вручную: `dotnet ef database update`.
- Новая миграция: `dotnet ef migrations add <Name> -o Data/Migrations`.

### Переменные окружения (Production)

| Переменная | Назначение |
|---|---|
| `ConnectionStrings__Default` | Строка подключения к PostgreSQL |
| `Jwt__SigningKey` | Ключ подписи JWT, не короче 32 символов |
| `Club__TimeZoneId` | Часовой пояс клуба, по умолчанию `Asia/Tashkent` |
| `Cors__AllowedOrigins__0` | Адрес веб-панели, если она на другом домене |
| `Database__MigrateOnStartup` | `true`, чтобы применять миграции при старте |
| `Bootstrap__AdminPhone`, `Bootstrap__AdminPassword` | Первый администратор (однократно) |

API в контейнере: `docker compose -f infrastructure/docker-compose.yml --profile api up -d --build`
(порт `127.0.0.1:8080`, переменные берутся из `infrastructure/.env`).

## 3. Веб-панель

```bash
cd admin
npm install
npm run dev          # http://localhost:5173, /api проксируется на localhost:5080
npm run build        # production-сборка в admin/dist
```

Если API на другом адресе: `API_URL=http://host:port npm run dev` (для dev-прокси) или
`VITE_API_URL=https://api.example.uz npm run build`.

## 4. Мобильное приложение

```bash
cd mobile
flutter pub get
flutter run                      # API по умолчанию: iOS — 127.0.0.1:5080, Android-эмулятор — 10.0.2.2:5080
flutter run --dart-define=API_URL=http://192.168.1.10:5080   # физическое устройство в той же сети
```

Переключить язык (RU / UZ) можно на экране входа и в профиле.

## Учётные записи

- **Клиенты** регистрируются в приложении или создаются администратором в веб-панели.
- **Тренеров** создаёт администратор (раздел «Тренеры»); тренер входит в мобильное приложение со своими телефоном и паролем.
- **Временный пароль.** Если пароль задал администратор (создание клиента или тренера, сброс), при первом
  входе пользователь обязан задать свой пароль, до этого API доступен только для смены пароля. То же
  касается первого администратора, созданного из `Bootstrap:*`.
- **Сброс пароля** на этапе 1 выполняет администратор (карточка клиента или тренера → «Сменить пароль»).
  Все сессии пользователя при этом завершаются.
- **Смена своего пароля**: в мобильном приложении — «Профиль» → «Сменить пароль», в веб-панели —
  «Сменить пароль» внизу меню.

## Короткие dev-логины (только Development)

Для ручной проверки API в окружении `Development` создаёт аккаунты и принимает короткий логин вместо телефона:

| Логин | Пароль | Роль | Телефон |
|---|---|---|---|
| `1` | `1` | Администратор (веб-панель) | +998000000001 |
| `2` | `2` | Тренер (мобильное приложение) | +998000000002 |
| `3` | `3` | Клиент (мобильное приложение) | +998000000003 |

Мобильное приложение принимает короткий логин только в debug-сборке. Вне `Development` (Testing, Production) сервис `DevLogins` не регистрируется, и логин `1` отклоняется с `validation_failed` (тест `Short_dev_logins_are_rejected_outside_development`). Код: `backend/src/FitnessFormulasi.Api/Auth/DevLogins.cs`.
