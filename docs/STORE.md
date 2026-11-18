# Публикация в App Store и Google Play

Документ для того, кто будет отправлять приложение в магазины: владельца клуба или разработчика. Здесь описано, что подготовить, что заполнить в App Store Connect и Google Play Console, а также готовые тексты на русском и узбекском.

Данные приложения:

| | |
|---|---|
| Название | Fitness Formulasi |
| iOS bundle ID / Android applicationId | `uz.fitnessformulasi` (одинаковый на обеих платформах) |
| Версия первой публикации | 1.0.0, сборка 1 (`version: 1.0.0+1` в `mobile/pubspec.yaml`) |
| Устройства | iOS: только iPhone, портретная ориентация. Android: телефоны |
| Цена | бесплатно, без встроенных покупок |
| Команда Apple в проекте | R47FSG2N52 (Rahimjan Bekbergenov) |
| Политика конфиденциальности | `https://<адрес API>/legal/privacy` |
| Страница удаления аккаунта | `https://<адрес API>/legal/delete-account` |

Почему не нужны встроенные покупки. В приложении клиент только отправляет заявку на абонемент, а оплачивает его на ресепшене клуба. Абонемент — это услуга в реальном мире, поэтому правило App Store 3.1.3(e) не требует In-App Purchase. Цифровые товары за деньги в приложение добавлять нельзя.

## 1. Что клуб должен решить и предоставить

| Что | Где используется | Комментарий |
|---|---|---|
| Юридическое лицо (название), адрес | политика конфиденциальности, страница удаления, копирайт в App Store | оператор персональных данных |
| Телефон, e-mail поддержки, Telegram | страницы `/legal/*`, контакт в Google Play, App Review | e-mail обязателен для Google Play |
| Домен API с HTTPS, например `api.<домен клуба>` | сборка приложения, ссылки на политику и удаление | без HTTPS release-сборка Android не подключится к серверу |
| Сайт или страница поддержки | Support URL в App Store | если сайта нет, можно указать страницу политики: в ней есть раздел «Контакты» |
| Демо-аккаунт клиента с действующим абонементом | проверка Apple и Google | создаётся в веб-панели, см. раздел 3.3 |
| Аккаунт Apple Developer: личный или организации | имя продавца в App Store | см. раздел 2 |
| Аккаунт Google Play: личный или организации | для личного аккаунта нужно закрытое тестирование | см. раздел 2 |
| 12 тестировщиков на 14 дней | только для личного аккаунта Google Play | см. раздел 2 |
| Срок обработки запросов на удаление аккаунта | страница `/legal/delete-account` | в тексте указано «до 30 дней». Клуб должен подтвердить этот срок |
| Где физически стоит сервер | политика конфиденциальности | закон Узбекистана требует хранить персональные данные граждан на территории республики. Политика это утверждает, поэтому сервер должен быть в Узбекистане |
| Страны распространения | App Store, Google Play | рекомендуем только Узбекистан |
| Возраст аудитории | Google Play, раздел «Целевая аудитория» | рекомендуем 18+. Если в клубе есть подростки, добавьте группу 16–17 |

## 2. Аккаунты разработчика

**Apple Developer Program** стоит 99 USD в год.
- Сейчас в проекте указана команда R47FSG2N52 (Rahimjan Bekbergenov). В App Store продавцом будет показано имя владельца этого аккаунта.
- Чтобы продавцом был клуб, нужен аккаунт организации, а для него — номер D-U-N-S юрлица.

**Google Play Console** стоит 25 USD один раз и требует проверки личности.
- Для личного аккаунта, созданного после 13 ноября 2023 года, перед первым выпуском в продакшн обязательно закрытое тестирование. В тесте должны участвовать минимум 12 тестировщиков 14 дней подряд, причём это правило действует для каждого нового приложения.
- Аккаунт организации с D-U-N-S от этого требования освобождён.
- Внутреннее тестирование (Internal testing) в эти 14 дней не засчитывается.

## 3. Подготовка сервера

### 3.1. HTTPS и маршруты

- API должен быть доступен по HTTPS. Требования к боевому серверу перечислены в [OPERATIONS.md](OPERATIONS.md), раздел 5.
- Обратный прокси (nginx и т. п.) должен передавать в API не только `/api/`, но и `/legal/`. Без этого страницы политики и удаления не откроются.

### 3.2. Данные клуба для юридических страниц

API подставляет данные клуба в страницы `/legal/privacy` и `/legal/delete-account` из конфигурации:

| Переменная окружения | Что указать |
|---|---|
| `Legal__OperatorName` | название юрлица клуба |
| `Legal__Address` | адрес клуба |
| `Legal__Phone` | телефон для вопросов о данных и удалении аккаунта |
| `Legal__Email` | e-mail |
| `Legal__Telegram` | Telegram клуба, например `@club` |
| `Legal__UpdatedOn` | дата редакции политики, например `09.11.2026` |

Незаполненное значение показывается как «—». Перед отправкой в магазины откройте обе страницы в браузере телефона и проверьте, что все поля заполнены.

### 3.3. Демо-аккаунт для проверяющих

1. В веб-панели создайте клиента с выдуманным именем, например «Демо Клиент». Номер телефона должен быть таким, по которому никто реальный не зарегистрируется.
2. Задайте ему постоянный пароль. Для этого один раз войдите в приложение под этим клиентом и смените временный пароль.
3. Оформите ему абонемент на 3–6 месяцев, чтобы на время проверки был действующий абонемент и QR-пропуск.
4. По желанию назначьте тренера и тренировку, чтобы были заполнены разделы «Тренеры» и «Тренировки».
5. Не удаляйте этот аккаунт: проверяющие могут войти под ним при любом следующем обновлении. Если проверяющий удалит аккаунт, проверяя удаление, создайте новый и обновите данные в консолях.

Пока приложение на проверке, сервер должен работать.

## 4. Сборка

```bash
cd mobile
scripts/build_release.sh https://api.<домен клуба>
```

Скрипт собирает обе версии с адресом боевого API:
- Android: `build/app/outputs/bundle/release/app-release.aab`;
- iOS: `build/ios/ipa/*.ipa`.

Номер сборки нужно увеличивать для каждой загрузки в магазин:
- `version: 1.0.0+1` → `1.0.0+2` для повторной загрузки той же версии;
- `1.1.0+3` для следующего выпуска.

Вместо правки `pubspec.yaml` номер можно передать при сборке: `BUILD_NUMBER=2 scripts/build_release.sh https://api.<домен>`.
Магазины не принимают сборку с номером, который уже загружали.

Скрипт:
- принимает только HTTPS-адрес;
- проверяет, что `/health`, `/legal/privacy` и `/legal/delete-account` отвечают;
- без ключа загрузки Android не собирает;
- третьим словом можно собрать только одну платформу: `… https://api.<домен> android` или `… ios`.

В сборке для магазинов скрыты функции, которые ещё не сделаны (онлайн-оплата, чат, календарь, гостевой визит,
вход по Face ID и т. п.): Apple отклоняет приложения с неработающими кнопками. В отладочной сборке они видны как
раньше. Флаг — `SHOW_UPCOMING` в `mobile/lib/core/config.dart`.

**Android: ключ загрузки (upload key).**
- Ключ уже создан: `mobile/android/upload-keystore.jks` и `mobile/android/key.properties` (пароль внутри). Новый
  ключ на другом компьютере создаёт `scripts/create_upload_key.sh`. Отпечаток SHA-256 текущего ключа:
  `9A:0C:19:2F:74:AC:38:D4:2E:F8:02:EA:BB:4E:C7:0C:BF:37:C2:EC:62:82:69:FA:1D:38:44:74:8E:DF:90:8B`.
- Файл keystore и `mobile/android/key.properties` с паролями в git не попадают.
- Сделайте их резервную копию минимум в двух местах, например в менеджере паролей и на зашифрованном носителе.
- В Google Play включено подписание через Play App Signing: ключ подписи приложения хранит Google, а ваш ключ нужен только для загрузки.
- Если ключ загрузки потерян, его можно сбросить через поддержку Play Console, но это занимает время.

**iOS.**
1. В Xcode → Settings → Accounts войдите в Apple ID, у которого есть доступ к команде.
2. Готовый `.ipa` загрузите через приложение Transporter (Mac App Store) или через Xcode → Window → Organizer → Distribute App.
3. В Info.plist указано, что приложение использует только стандартное шифрование (HTTPS). Поэтому вопрос об экспортном контроле при загрузке задаваться не должен.

## 5. App Store Connect — по шагам

1. **Apps → «+» → New App.**
   - Platform: iOS.
   - Name: Fitness Formulasi.
   - Primary Language: Russian.
   - Bundle ID: `uz.fitnessformulasi`.
   - SKU: `fitnessformulasi-ios`.
   - User Access: Full Access.
2. **App Information.**
   - Category: Health & Fitness, вторая категория не нужна.
   - Content Rights: «не содержит контент третьих лиц» (баннеры загружает сам клуб).
   - Локализации: русская (основная) и узбекская. Проверьте, есть ли узбекский в списке языков App Store Connect. Если нет, оставьте только русский.
3. **Age Rating.** Отвечайте по факту:
   - насилия, азартных игр, контента для взрослых, рекламы и открытого доступа в интернет нет;
   - общения между пользователями нет: комментарий к заявке тренеру — не чат.

   Ожидаемый рейтинг — 4+. Проверьте, какой рейтинг покажет App Store Connect после анкеты.
4. **Pricing and Availability.**
   - Цена: Free.
   - Страны: Узбекистан (решает клуб).
5. **App Privacy.**
   - Privacy Policy URL: `https://<адрес API>/legal/privacy`.
   - Ответы — в разделе 8.
6. **Страница версии 1.0:**
   - скриншоты 6.9" (раздел 11);
   - промотекст, описание, ключевые слова, Support URL (раздел 7);
   - Version 1.0;
   - Copyright: `2026 <юрлицо клуба>`;
   - сборка — выберите загруженную;
   - App Review Information: включите Sign-in required, укажите телефон и пароль демо-аккаунта, контакты, заметки из раздела 10;
   - Version Release: Manually release, чтобы выпустить вручную после одобрения.
7. **Add for Review → Submit.**

Sign in with Apple не требуется. Правило 4.8 касается только приложений, где можно войти через сторонний сервис (Google, Facebook и т. п.), а здесь вход по собственному телефону и паролю.

## 6. Google Play Console — по шагам

1. **Create app.**
   - Name: Fitness Formulasi.
   - Default language: Russian (ru-RU).
   - App.
   - Free.
   - Подтвердите декларации.
2. **App content (Policy → App content):**
   - **Privacy policy:** `https://<адрес API>/legal/privacy`.
   - **App access:** «All or some functionality is restricted». Укажите телефон и пароль демо-аккаунта и инструкцию из раздела 10.
   - **Ads:** No.
   - **Content rating** (анкета IARC):
     - категория «All Other App Types»;
     - насилия, сексуального контента, азартных игр, наркотиков нет;
     - на вопрос, могут ли пользователи обмениваться сообщениями, отвечайте осторожно, «Да»: клиент пишет комментарий тренеру в заявке;
     - местоположение не передаётся;
     - цифровых покупок нет.
   - **Target audience:** 18+ или по решению клуба (раздел 1). Не выбирайте группы младше 13 лет, иначе на приложение распространятся правила для детей.
   - **News app:** No.
   - **Data safety:** ответы в разделе 9, включая ссылку на удаление аккаунта.
   - **Government app:** No.
   - **Financial features:** нет.
   - **Health apps:** приложение не собирает медицинские данные. Если форма требует выбрать категорию, подходит «Activity and fitness»: расписание тренировок и посещения зала. Если такой категории нет, отметьте, что функций здоровья нет.
   - **Advertising ID:** No.
3. **Store presence → Main store listing:**
   - тексты на русском;
   - перевод на узбекский — через Add translation, если узбекский есть в списке языков консоли. Если нет, ограничьтесь русским, по желанию добавьте английский;
   - графика (раздел 11).
4. **Store settings:**
   - Category: Health & Fitness;
   - контакт: e-mail клуба (обязателен), телефон и сайт по желанию.
5. **Testing:**
   - сначала Internal testing — проверьте установку на нескольких телефонах;
   - для личного аккаунта — Closed testing: 12+ тестировщиков на 14 дней, потом Apply for production.
6. **Production → Create release:**
   - загрузите `app-release.aab`;
   - страны: Узбекистан;
   - Review and roll out.

## 7. Тексты для магазинов

Длина указана в символах и проверена скриптом.

### App Store — русский

| Поле | Текст | Длина / лимит |
|---|---|---|
| Name | Fitness Formulasi | 17 / 30 |
| Subtitle | Абонемент, тренер, вход в клуб | 30 / 30 |
| Promotional Text | Добавьте фото лица и проходите в клуб через турникет без телефона. Абонемент, заморозка, QR-пропуск и тренировки с тренером — в одном приложении. | 145 / 170 |
| Keywords | `фитнес,спортзал,зал,абонемент,тренер,тренировки,пропуск,турникет,qr,расписание,спорт,gym,fitness` | 96 / 100 |
| Support URL | сайт клуба или `https://<адрес API>/legal/privacy` | |
| Privacy Policy URL | `https://<адрес API>/legal/privacy` | |

Description (1078 / 4000), этот же текст подходит для полного описания в Google Play:

```text
Fitness Formulasi — приложение для клиентов и тренеров фитнес-клуба Fitness Formulasi.

АБОНЕМЕНТ ВСЕГДА ПОД РУКОЙ
• Сколько дней и посещений осталось по абонементу
• Заявка на новый абонемент или продление — оплата на ресепшене клуба
• Заморозка абонемента прямо в приложении (по правилам клуба)
• История абонементов и посещений

ВХОД В КЛУБ
• QR-пропуск: код обновляется каждые 30 секунд, поэтому скриншот не сработает
• Вход по лицу: добавьте фото, и турникет пропустит вас без телефона, пока действует абонемент. Фото добавляется только с вашего согласия, используется только для прохода в клуб и удаляется в любой момент

ТРЕНЕР И ТРЕНИРОВКИ
• Тренеры клуба: фото, специализация и опыт
• Заявка выбранному тренеру с целью и удобным временем
• Расписание тренировок и уведомления о новых и отменённых занятиях

НОВОСТИ КЛУБА
• Акции и новости клуба на главном экране

ДЛЯ ТРЕНЕРОВ
• Заявки клиентов, список клиентов и расписание тренировок

Приложение на русском и узбекском языках. Аккаунт создаётся по номеру телефона и паролю. Удалить аккаунт можно в профиле приложения.
```

### App Store — узбекский (если язык доступен)

| Поле | Текст | Длина / лимит |
|---|---|---|
| Name | Fitness Formulasi | 17 / 30 |
| Subtitle | Abonement, murabbiy va kirish | 29 / 30 |
| Promotional Text | Yuz rasmingizni qo‘shing va klubga turniket orqali telefonsiz kiring. Abonement, muzlatish, QR-ruxsatnoma va murabbiy bilan mashg‘ulotlar — bitta ilovada. | 154 / 170 |
| Keywords | `fitnes,sport zal,zal,abonement,murabbiy,trener,mashg‘ulot,turniket,qr,jadval,sport,gym,fitness` | 94 / 100 |

Description (1184 / 4000), этот же текст подходит для Google Play:

```text
Fitness Formulasi — Fitness Formulasi fitnes-klubi mijozlari va murabbiylari uchun ilova.

ABONEMENT DOIM QO‘L OSTIDA
• Abonement bo‘yicha qancha kun va tashrif qolgani
• Yangi abonement yoki uzaytirish uchun ariza — to‘lov klub resepshnida
• Abonementni to‘g‘ridan-to‘g‘ri ilovada muzlatish (klub qoidalariga ko‘ra)
• Abonementlar va tashriflar tarixi

KLUBGA KIRISH
• QR-ruxsatnoma: kod har 30 soniyada yangilanadi, shuning uchun skrinshot ishlamaydi
• Yuz orqali kirish: rasmingizni qo‘shing — abonement amalda bo‘lgan vaqtda turniket sizni telefonsiz o‘tkazadi. Rasm faqat roziligingiz bilan qo‘shiladi, faqat klubga kirish uchun ishlatiladi va istalgan vaqtda o‘chiriladi

MURABBIY VA MASHG‘ULOTLAR
• Klub murabbiylari: rasm, mutaxassislik va tajriba
• Tanlangan murabbiyga maqsad va qulay vaqt ko‘rsatilgan ariza
• Mashg‘ulotlar jadvali, yangi va bekor qilingan mashg‘ulotlar haqida bildirishnomalar

KLUB YANGILIKLARI
• Asosiy ekranda klub aksiyalari va yangiliklari

MURABBIYLAR UCHUN
• Mijozlar arizalari, mijozlar ro‘yxati va mashg‘ulotlar jadvali

Ilova rus va o‘zbek tillarida. Hisob telefon raqami va parol orqali yaratiladi. Hisobni ilovadagi profildan o‘chirish mumkin.
```

### Google Play

| Поле | Русский | Узбекский |
|---|---|---|
| App name (≤ 30) | Fitness Formulasi (17) | Fitness Formulasi (17) |
| Short description (≤ 80) | Абонемент, тренер, QR-пропуск и вход по лицу в клуб Fitness Formulasi (69) | Abonement, murabbiy, QR-ruxsatnoma va klubga yuz orqali kirish (62) |
| Full description (≤ 4000) | текст Description выше (1078) | текст Description выше (1184) |
| Contact email | e-mail клуба | |
| Privacy policy | `https://<адрес API>/legal/privacy` | |
| Delete account URL (в Data safety) | `https://<адрес API>/legal/delete-account` | |

## 8. App Store — App Privacy

Общие ответы:
- данные собираются;
- все типы ниже связаны с личностью пользователя (Linked to the user);
- для отслеживания (Tracking) ничего не используется;
- цель — только App Functionality.

| Категория Apple | Тип | Что это в приложении |
|---|---|---|
| Contact Info | Name | имя и фамилия |
| Contact Info | Email Address | e-mail, если указан |
| Contact Info | Phone Number | номер телефона для входа |
| Identifiers | User ID | идентификатор аккаунта и номер на турникете |
| Purchases | Purchase History | абонементы и заявки на них |
| Health & Fitness | Fitness | посещения зала и тренировки с тренером (указываем, чтобы не занизить данные) |
| Health & Fitness | Health | раздел «Питание», по желанию: вес, рост, цель, дневник питания, ограничения в питании и аллергии |
| User Content | Photos or Videos | фото лица для турникета (только с согласия); фото еды и этикеток в разделе «Питание» |
| User Content | Other User Content | комментарий к заявке тренеру; вопросы ИИ-консультанту по питанию |
| Sensitive Info | Sensitive Info | фото лица: терминал строит по нему биометрический шаблон для распознавания |
| Other Data | Other Data Types | дата рождения и пол, если указаны |

Не собираются: Location, Financial Info (оплата на ресепшене), Contacts, Browsing/Search History, Usage Data (аналитики нет), Diagnostics (нет SDK сбоев), Device ID.

Правило 5.1.2(vi) запрещает использовать данные, полученные с камеры или из фотографий, для рекламы и анализа. Приложение использует фото лица только для прохода через турникет, и политика конфиденциальности это прямо указывает.

Раздел «Питание» отправляет фото еды и данные питания внешнему ИИ-сервису (OpenAI, ChatGPT, или Anthropic, Claude —
какой подключён в админ-панели), без имени и телефона.
Правило 5.1.2(i) требует назвать такого получателя и спросить разрешение до передачи. Приложение показывает
экран согласия с названием сервиса и ссылкой на политику перед первой ИИ-функцией. После смены провайдера согласие
спрашивается заново, страница политики называет подключённый сервис. Сервер без согласия отвечает
`ai_consent_required`, согласие можно отозвать ([NUTRITION.md](NUTRITION.md)). Сервис обрабатывает данные по
поручению клуба, это не отслеживание (Tracking).

## 9. Google Play — Data safety

Общие ответы:
- данные собираются: да;
- данные передаются третьим лицам (shared): нет. Терминал в клубе принадлежит клубу, хостинг хранит данные по поручению клуба, ИИ-сервис (OpenAI или Anthropic) анализирует фото еды и данные питания по поручению клуба (service provider), а это не считается передачей. В Open Food Facts уходит только штрихкод;
- данные шифруются при передаче: да (HTTPS);
- аккаунт можно создать: да, по телефону и паролю;
- ссылка на удаление аккаунта: `https://<адрес API>/legal/delete-account`;
- можно запросить удаление данных: да.

| Раздел Google | Тип | Обязательно? | Цели |
|---|---|---|---|
| Personal info | Name | обязательно | App functionality, Account management |
| Personal info | Email address | по желанию | App functionality, Account management |
| Personal info | Phone number | обязательно | App functionality, Account management |
| Personal info | User IDs | обязательно | App functionality, Account management |
| Personal info | Other info (дата рождения, пол) | по желанию | App functionality |
| Financial info | Purchase history (абонементы) | обязательно | App functionality |
| Health and fitness | Fitness info (посещения, тренировки) | обязательно | App functionality |
| Messages | Other in-app messages (комментарий тренеру) | по желанию | App functionality |
| Photos and videos | Photos (фото лица; фото еды и этикеток) | по желанию | App functionality |
| Health and fitness | Health info (вес, рост, цель, дневник питания, ограничения, аллергии) | по желанию | App functionality |
| Messages | Other in-app messages (вопросы ИИ-консультанту) | по желанию | App functionality |

Для всех типов: собирается, не передаётся, не обрабатывается «эфемерно» (хранится на сервере).

Отдельного типа «биометрия» в форме Google нет. Фото лица указывается как Photos, а его назначение описано в политике. Сбоев, диагностики, местоположения, установленных приложений и рекламного ID приложение не собирает.

## 10. Заметки для проверяющих

App Review Information (App Store) и App access (Google Play) — на английском, проверяющие читают на нём:

```text
Fitness Formulasi is the members' app of a single fitness club in Uzbekistan.
Members see their membership, request a new membership or a renewal, freeze a
membership, show a rotating QR pass at the club entrance, choose a personal
trainer and see their training schedule. Trainers of the club use the same app
to answer client requests and plan sessions.

Demo account (club member with an active membership):
  Phone:    +998 __ ___ __ __
  Password: ____________

Payments: memberships are paid in person at the club's front desk. The app only
sends a request; no digital goods or content are sold (guideline 3.1.3(e)).

Language: the app is in Russian and Uzbek (switch on the sign-in screen or in
Profile). Tabs: Главная = Home, Абонемент = Membership, Тренеры = Trainers,
Тренировки = Workouts, Профиль = Profile.

Face entry (optional): Membership tab -> "Вход по лицу" (Face entry). With
explicit consent the member uploads a selfie; the club's face recognition
terminal at the entrance uses it to open the turnstile while the membership is
valid. The photo is not used for anything else, is never shared and can be
deleted at any time ("Удалить фото"). Outside the club you will see the photo
saved and a status such as "sending to the turnstile" or "terminal not
connected yet" - this is expected, the terminal is only in the club's network.

Nutrition (optional): Home tab -> "Питание" (Nutrition). The member photographs
a meal with the in-app camera; after an explicit consent screen naming the AI
provider (OpenAI ChatGPT), the photo without metadata is analysed to recognise dishes, ingredients
and portion weight. Calories and macronutrients are then computed on our server
from a food database (USDA FoodData Central, Open Food Facts, package labels),
not by the AI; the member can correct weights and ingredients and adds the meal
to the food diary only by tapping "Добавить в дневник". Also: barcode scanning
(Open Food Facts), nutrition label reading, diary, charts and an AI nutrition
consultant answering from the member's own diary. Values are estimates, not
medical advice; consent can be withdrawn in the nutrition settings.

Account deletion: Profile tab -> "Удалить аккаунт" (Delete account) -> enter
the password -> confirm. Personal data is deleted immediately; anonymised
membership and visit records are kept for accounting. Web page:
https://<api-host>/legal/delete-account

No SMS code is needed to sign in.
```

Краткая версия по-русски, для себя:
- демо-аккаунт клиента с действующим абонементом;
- оплата на ресепшене, поэтому встроенных покупок нет;
- вход по лицу — по желанию и с согласием. Вне клуба проверяющий увидит статус ожидания, это нормально;
- удаление аккаунта: «Профиль» → «Удалить аккаунт»;
- раздел «Питание»: на сервере для проверки должен быть подключён ИИ (админ-панель → «Интеграции» → «ИИ-анализ еды»,
  или `Ai__Provider`, `Ai__ApiKey`). Без него
  анализ фото показан как «не подключён», и проверяющий может счесть функцию незаконченной (правило 2.1).

## 11. Скриншоты и графика

Готовые файлы лежат в `mobile/store/`. Их сняли на демо-данных в отдельной базе: клиент «Азиз Каримов», тренеры
«Жасур Алимов», «Мадина Юсупова», «Тимур Назаров». Реальных клиентов на скриншотах нет.

| Магазин | Файлы | Размер |
|---|---|---|
| App Store | `mobile/store/screenshots/app-store/01…06.png` — с подписью сверху | 1320 × 2868 (iPhone 6.9"), без прозрачности |
| App Store, по желанию | `mobile/store/screenshots/raw/01…06.png` — экраны без подписей | 1320 × 2868 |
| Google Play | `mobile/store/screenshots/google-play/01…06.png` | 1080 × 1920 (9:16) |
| Google Play | `mobile/store/google-play/icon-512.png` | 512 × 512 |
| Google Play | `mobile/store/google-play/feature-graphic.png` | 1024 × 500 |

| № | Экран | Подпись |
|---|---|---|
| 1 | Главная: баннер, вход по лицу, абонемент | Абонемент и новости клуба |
| 2 | Абонемент | Срок, посещения и заморозка |
| 3 | QR-пропуск | Вход по QR-пропуску |
| 4 | Вход по лицу (до загрузки фото) | Проходите в клуб по лицу |
| 5 | Тренеры клуба | Выберите своего тренера |
| 6 | Тренировки | Тренировки по расписанию |

Скриншоты одни для русской и узбекской страниц. Узбекские подписи: «Abonement va klub yangiliklari»,
«Muddat, tashriflar va muzlatish», «QR-ruxsatnoma orqali kirish», «Klubga yuzingiz orqali kiring»,
«O‘z murabbiyingizni tanlang», «Jadval bo‘yicha mashg‘ulotlar».

**Как переснять после изменений в приложении:**
1. Запустите API с демо-клиентом: у него должен быть абонемент, тренер и будущие тренировки.
2. Включите симулятор iPhone 17 Pro Max.
3. Выполните в `mobile/`:
   ```bash
   flutter drive --driver=test_driver/screenshots.dart --target=integration_test/store_screenshots_test.dart \
     -d "iPhone 17 Pro Max" --dart-define=API_URL=http://127.0.0.1:5080 --dart-define=SHOW_UPCOMING=false \
     --dart-define=SHOTS_PHONE=<телефон демо-клиента> --dart-define=SHOTS_PASSWORD=<пароль>
   node store/frame_screenshots.cjs   # подписи; нужен npm install в admin/ (Playwright)
   ```

## 12. Что проверить перед отправкой

- [x] В приложении есть ссылка на политику конфиденциальности: в профиле клиента и тренера, на экране регистрации и рядом с согласием на фото лица.
- [x] Нет заглушек «скоро будет»: в сборке для магазинов они скрыты (`SHOW_UPCOMING`, раздел 4). Если добавите новую незаконченную функцию, спрячьте её тем же флагом.
- [ ] Удаление аккаунта работает в release-сборке на боевом сервере. Проверено на тестовом аккаунте, не на демо-аккаунте.
- [ ] Страницы `/legal/privacy` и `/legal/delete-account` открываются по HTTPS, все поля заполнены.
- [ ] Демо-аккаунт входит, у него действующий абонемент, QR-пропуск показывается.
- [ ] Сборка обращается к боевому API: проверить на телефоне без подключения к Mac.
- [ ] В боевой базе нет dev-аккаунтов: проверка в [OPERATIONS.md](OPERATIONS.md), раздел 5.
- [ ] Номер сборки больше, чем у прошлой загрузки.
- [ ] Раздел «Питание»: ИИ подключён в админ-панели и «Проверить подключение» проходит (или `Ai__Provider`, `Ai__ApiKey`),
  в Review Notes указан тот же провайдер (OpenAI или Anthropic), анализ фото
  демо-аккаунтом работает, экран согласия на ИИ появляется перед первым анализом ([NUTRITION.md](NUTRITION.md)).
- [ ] Разрешения. Сканер штрихкодов (`mobile_scanner`) и камера для еды (`camera`) добавляют на Android разрешение
  `CAMERA` (камера не обязательна для установки). Разрешение микрофона `RECORD_AUDIO`, которое добавляет плагин
  `camera`, убрано в манифесте приложения: звук не записывается. На iOS тексты `NSCameraUsageDescription` и `NSPhotoLibraryUsageDescription`
  упоминают фото лица, еду, этикетки и штрихкоды. На Android штрихкод распознаёт Google ML Kit на устройстве;
  ML Kit может отправлять в Google технические метрики. Сверьте ответы Data safety с
  https://developers.google.com/ml-kit/android-data-disclosure перед отправкой.

## 13. После публикации

- Каждое обновление требует новый номер сборки и снова проходит проверку. Обычно это от нескольких часов до пары дней.
- Если меняется состав собираемых данных, обновите политику, `Legal__UpdatedOn` и ответы в App Privacy и Data safety.
- Запросы на удаление аккаунта обрабатывайте в обещанный срок. Удаление делается в веб-панели, в карточке клиента.
- Держите демо-аккаунт рабочим: он нужен при каждой проверке обновления.

## Источники

- [Google Play: требования к target API](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google Play: требования к удалению аккаунта](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google Play: закрытое тестирование для новых личных аккаунтов](https://support.google.com/googleplay/android-developer/answer/14151465)
- [App Store Connect: размеры скриншотов](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [App Store Connect: локализации](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
