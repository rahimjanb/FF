# Эксплуатация: конфигурация, секреты, миграции, резервное копирование

Документ для того, кто разворачивает систему на сервере клуба. Боевой сервер в рамках этапа 1 не
настраивался; ниже — требования и проверенные локально процедуры.

## 1. Окружения

| Окружение | Где используется | Особенности |
|---|---|---|
| `Development` | компьютер разработчика | Swagger, SMS-код в лог, короткие dev-логины `1`/`2`/`3`, секреты из user-secrets |
| `Testing` | `dotnet test` | одноразовый PostgreSQL в контейнере; dev-механизмов нет |
| `Production` | сервер клуба | dev-механизмов нет; Swagger закрыт; HSTS; секреты только из переменных окружения |

`Production` — значение по умолчанию для compose-профиля `api` (`API_ENVIRONMENT=Production`).
**Никогда не запускайте боевой API с `ASPNETCORE_ENVIRONMENT=Development`.**

## 2. Секреты

| Секрет | Откуда берётся | Проверка |
|---|---|---|
| Пароль PostgreSQL | `POSTGRES_PASSWORD` в `infrastructure/.env` (не в git), далее в `ConnectionStrings__Default` | compose не стартует без него |
| Ключ подписи JWT | `Jwt__SigningKey` (`JWT_SIGNING_KEY` в `.env`), не короче 32 символов: `openssl rand -base64 48` | API **не запускается** без ключа (проверено) |
| Первый администратор | `Bootstrap__AdminPhone`, `Bootstrap__AdminPassword` | пароль временный: при первом входе обязательна смена (проверено) |
| Ключ шифрования секретов интеграций | `Integrations__EncryptionKey` (`INTEGRATIONS_ENCRYPTION_KEY` в `.env`), 32 байта в base64: `openssl rand -base64 32` | необязателен: без него API работает, но секреты Click/Payme сохранить нельзя (ответ `encryption_not_configured`); неверный формат — API не запускается |

- В репозитории секретов нет: `appsettings.json` содержит пустые значения, `.env` в `.gitignore`.
- В логах API нет паролей и токенов (проверено поиском значений в логе Production-запуска).
- После первого входа администратора уберите `BOOTSTRAP_ADMIN_PASSWORD` из `.env`: повторно он не используется.
- Ключ JWT меняется заменой `Jwt__SigningKey` и перезапуском; все пользователи войдут заново.
- Секреты Click/Payme хранятся в PostgreSQL только зашифрованными (AES-256-GCM, таблица `IntegrationSecrets`); API их не возвращает, в журнал аудита и логи пишутся только имена полей. Ключ шифрования держите неизменным и в резервной копии отдельно от базы: при его смене или потере сохранённые секреты нужно ввести заново.
- Настройки интеграций видит и меняет только администратор с правом `CanManageIntegrations`. Его получает первый администратор (Bootstrap и миграция `AddIntegrationSettings`); выдать право другому пока можно только запросом в БД.

## 3. Миграции базы данных

Миграции EF Core лежат в `backend/src/FitnessFormulasi.Api/Data/Migrations`:
`20261023180145_InitialCreate`, `20261023213010_AddMustChangePassword`.

- Автоприменение при старте: `Database__MigrateOnStartup=true` (включено в compose-профиле `api`).
- Ручное применение (из исходников, с доступом к базе):
  `cd backend/src/FitnessFormulasi.Api && ConnectionStrings__Default="…" dotnet ef database update`
- SQL-скрипт для ревью до применения:
  `dotnet ef migrations script --idempotent -o migrate.sql`
- Расхождений модели и миграций нет: `dotnet ef migrations has-pending-model-changes` →
  «No changes have been made to the model since the last migration».
- **Перед применением новых миграций на боевой базе — резервная копия (раздел 4).**

## 4. Резервное копирование и восстановление

Процедура проверена 24.10.2026 на временной базе (`infrastructure/scripts/production-smoke.sh`, шаг 3):
дамп снят, восстановлен в новую базу, число записей совпало.

### Создание копии

```bash
# Формат custom (-Fc): сжатый, позволяет восстанавливать выборочно.
docker compose -f infrastructure/docker-compose.yml exec -T postgres \
  pg_dump -U ff_app -d fitness_formulasi -Fc > backup/ff_$(date +%Y%m%d_%H%M).dump
```

Рекомендуемый порядок для клуба (согласовать с заказчиком):
- ежедневная копия по расписанию (cron) и хранение не менее 14 последних;
- копия перед каждым обновлением системы;
- хранение копий **вне** сервера базы (другой диск или облачное хранилище);
- ежемесячная проверка восстановления в отдельную базу.

### Восстановление

Восстанавливайте **в новую базу**, проверяйте и только потом переключайте API. Не восстанавливайте
поверх рабочей базы и не удаляйте Docker volume `postgres-data`.

```bash
docker compose -f infrastructure/docker-compose.yml exec -T postgres createdb -U ff_app ff_restore
docker compose -f infrastructure/docker-compose.yml exec -T postgres \
  pg_restore -U ff_app -d ff_restore --no-owner < backup/ff_YYYYMMDD_HHMM.dump
# Проверка: число записей в основных таблицах
docker compose -f infrastructure/docker-compose.yml exec -T postgres \
  psql -U ff_app -d ff_restore -c 'select count(*) from "Users"' -c 'select count(*) from "Memberships"'
```

Переключение: указать `Database=ff_restore` в `ConnectionStrings__Default` и перезапустить API.

## 5. Требования к боевому развёртыванию (не выполнялось в этапе 1)

| Требование | Почему | Статус |
|---|---|---|
| HTTPS через обратный прокси (nginx, Caddy и т.п.) с сертификатом | API слушает HTTP; HSTS отправляется только по HTTPS | на стороне сервера заказчика |
| Настроить передачу IP клиента от прокси (`ForwardedHeaders`) | Ограничение 20 входов в минуту считается по IP. За прокси все клиенты будут иметь IP прокси и делить один лимит | **требует доработки до запуска**: в коде API обработка `X-Forwarded-For` не включена |
| Мобильное приложение собирать с адресом API: `flutter build apk --dart-define=API_URL=https://api…` (и так же для iOS) | без параметра release-сборка обращается к `127.0.0.1`/`10.0.2.2` и не работает | обязательный шаг сборки |
| Веб-панель: `VITE_API_URL=https://api… npm run build`, `Cors__AllowedOrigins__0` = адрес панели | иначе браузер заблокирует запросы | обязательный шаг сборки |
| Боевую базу создавать с нуля, а не копией dev-базы | в dev-базе есть тестовые записи «E2E» и dev-аккаунты `+99800000000x` | проверка: `select count(*) from "Users" where "Phone" like '+99800000000%'` → 0 |
| Порт PostgreSQL не публиковать наружу | в compose привязан к `127.0.0.1` | выполнено в compose |
| Публикация в App Store / Google Play | нужны аккаунты разработчика заказчика | не входит в п. 2.1 договора, согласовать отдельно |

## 6. Проверка Production-режима без боевого сервера

```bash
cd backend && dotnet publish src/FitnessFormulasi.Api -c Release -o /tmp/ff-check/publish
zsh infrastructure/scripts/production-smoke.sh /tmp/ff-check
```

Скрипт поднимает временный PostgreSQL без постоянного тома (порт `127.0.0.1:55432`), запускает release-сборку
API в `Production` со случайными одноразовыми секретами (порт `5091`), проверяет запуск без ключа,
миграции, отсутствие dev-аккаунтов и dev-логинов, закрытый Swagger, обязательную смену пароля
администратора, отсутствие секретов в логе, затем резервное копирование и восстановление и удаляет
временный контейнер. Существующие базы и контейнеры не затрагиваются.
