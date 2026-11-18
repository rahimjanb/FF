// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Fitness Formulasi';

  @override
  String get loginTitle => 'С возвращением';

  @override
  String get loginSubtitle => 'Войдите по номеру телефона';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get registerSubtitle => 'Создайте аккаунт клиента клуба';

  @override
  String get phone => 'Номер телефона';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Повторите пароль';

  @override
  String get firstName => 'Имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get email => 'Email';

  @override
  String get birthDate => 'Дата рождения';

  @override
  String get gender => 'Пол';

  @override
  String get genderMale => 'Мужской';

  @override
  String get genderFemale => 'Женский';

  @override
  String get notSpecified => 'Не указано';

  @override
  String get signIn => 'Войти';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get noAccount => 'Нет аккаунта? Зарегистрируйтесь';

  @override
  String get haveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get smsNotice =>
      'Подтверждение номера по SMS появится в следующем обновлении.';

  @override
  String get validationRequired => 'Обязательное поле';

  @override
  String get validationPhone => 'Введите номер в формате +998 90 123 45 67';

  @override
  String get validationPassword => 'Минимум 8 символов, буквы и цифры';

  @override
  String get validationPasswordMatch => 'Пароли не совпадают';

  @override
  String get validationEmail => 'Неверный email';

  @override
  String get errorGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get errorNetwork => 'Нет соединения с сервером';

  @override
  String get errorInvalidCredentials => 'Неверный номер или пароль';

  @override
  String get errorAccountLocked =>
      'Слишком много попыток. Попробуйте через 15 минут.';

  @override
  String get errorAccountBlocked => 'Аккаунт заблокирован. Обратитесь в клуб.';

  @override
  String get errorPhoneTaken => 'Этот номер уже зарегистрирован';

  @override
  String get errorDuplicateRequest => 'Заявка этому тренеру уже отправлена';

  @override
  String get errorTrainerNotAccepting =>
      'Тренер сейчас не принимает новых клиентов';

  @override
  String get errorAlreadyAssigned => 'Этот тренер уже закреплён за вами';

  @override
  String get errorRequestNotPending => 'Заявка уже обработана';

  @override
  String get errorSessionOverlap => 'На это время уже есть тренировка';

  @override
  String get errorStartInPast => 'Выберите время в будущем';

  @override
  String get errorAdminUseWeb => 'Администраторы работают в веб-панели';

  @override
  String get retry => 'Повторить';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get send => 'Отправить';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutConfirm => 'Выйти из аккаунта?';

  @override
  String get language => 'Язык';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabMembership => 'Абонемент';

  @override
  String get tabTrainers => 'Тренеры';

  @override
  String get tabWorkouts => 'Тренировки';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get tabRequests => 'Заявки';

  @override
  String get tabClients => 'Клиенты';

  @override
  String get tabSchedule => 'Расписание';

  @override
  String greetingMorning(String name) {
    return 'Доброе утро, $name';
  }

  @override
  String greetingDay(String name) {
    return 'Добрый день, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Добрый вечер, $name';
  }

  @override
  String get membership => 'Абонемент';

  @override
  String get noMembership => 'Нет действующего абонемента';

  @override
  String get noMembershipHint => 'Оформите абонемент на ресепшене клуба';

  @override
  String validUntil(String date) {
    return 'Действует до $date';
  }

  @override
  String startsOn(String date) {
    return 'Начнётся $date';
  }

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count дня',
      many: 'Осталось $count дней',
      few: 'Осталось $count дня',
      one: 'Остался $count день',
      zero: 'Сегодня последний день',
    );
    return '$_temp0';
  }

  @override
  String get daysShort => 'дн.';

  @override
  String visitsUsed(int used, int limit) {
    return 'Посещения: $used из $limit';
  }

  @override
  String get unlimited => 'Безлимит';

  @override
  String get limitedVisits => 'По посещениям';

  @override
  String get statusActive => 'Активен';

  @override
  String get statusUpcoming => 'Скоро начнётся';

  @override
  String get statusExpired => 'Истёк';

  @override
  String get statusExhausted => 'Посещения исчерпаны';

  @override
  String get statusFrozen => 'Заморожен';

  @override
  String get statusCancelled => 'Отменён';

  @override
  String get nextMembership => 'Следующий абонемент';

  @override
  String get membershipHistory => 'История абонементов';

  @override
  String get period => 'Срок действия';

  @override
  String get type => 'Тип';

  @override
  String get nextWorkout => 'Ближайшая тренировка';

  @override
  String get noUpcomingWorkouts => 'Запланированных тренировок нет';

  @override
  String get noUpcomingWorkoutsHint =>
      'Тренер назначит тренировку, и она появится здесь';

  @override
  String get yourTrainer => 'Ваш тренер';

  @override
  String get noTrainer => 'Тренер не выбран';

  @override
  String get chooseTrainer => 'Выбрать тренера';

  @override
  String get visits => 'Посещения';

  @override
  String get visitsThisMonth => 'В этом месяце';

  @override
  String get visitsTotal => 'Всего';

  @override
  String get lastVisit => 'Последнее';

  @override
  String pendingRequestTo(String name) {
    return 'Заявка тренеру $name на рассмотрении';
  }

  @override
  String get trainersTitle => 'Тренеры клуба';

  @override
  String get noTrainers => 'Тренеров пока нет';

  @override
  String experienceYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Опыт $count года',
      many: 'Опыт $count лет',
      few: 'Опыт $count года',
      one: 'Опыт $count год',
    );
    return '$_temp0';
  }

  @override
  String get acceptingClients => 'Набирает клиентов';

  @override
  String get notAcceptingClients => 'Набор закрыт';

  @override
  String get about => 'О тренере';

  @override
  String get sendRequest => 'Отправить заявку';

  @override
  String get requestMessageHint =>
      'Цель тренировок, удобное время (необязательно)';

  @override
  String get requestSent => 'Заявка отправлена';

  @override
  String get cancelRequest => 'Отменить заявку';

  @override
  String get myRequests => 'Мои заявки';

  @override
  String get requestPending => 'На рассмотрении';

  @override
  String get requestAccepted => 'Принята';

  @override
  String get requestRejected => 'Отклонена';

  @override
  String get requestCancelled => 'Отменена';

  @override
  String trainerComment(String text) {
    return 'Комментарий: $text';
  }

  @override
  String get currentTrainerBadge => 'Ваш тренер';

  @override
  String get workoutsTitle => 'Тренировки';

  @override
  String get upcoming => 'Предстоящие';

  @override
  String get history => 'История';

  @override
  String minutes(int count) {
    return '$count мин';
  }

  @override
  String withTrainer(String name) {
    return 'Тренер: $name';
  }

  @override
  String withClient(String name) {
    return 'Клиент: $name';
  }

  @override
  String get sessionScheduled => 'Запланирована';

  @override
  String get sessionCompleted => 'Проведена';

  @override
  String get sessionCancelled => 'Отменена';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get personalData => 'Личные данные';

  @override
  String get phoneNotConfirmed => 'Номер не подтверждён';

  @override
  String get phoneChangeHint =>
      'Номер телефона меняется через администратора клуба';

  @override
  String get notifications => 'Уведомления';

  @override
  String get noNotifications => 'Уведомлений нет';

  @override
  String get markAllRead => 'Прочитать все';

  @override
  String get notifTrainerRequestReceived => 'Новая заявка от клиента';

  @override
  String notifTrainerRequestAccepted(String name) {
    return '$name принял(а) вашу заявку';
  }

  @override
  String notifTrainerRequestRejected(String name) {
    return '$name отклонил(а) вашу заявку';
  }

  @override
  String get notifTrainingSessionScheduled => 'Назначена новая тренировка';

  @override
  String get notifTrainingSessionCancelled => 'Тренировка отменена';

  @override
  String notifMembershipAssigned(String name) {
    return 'Оформлен абонемент «$name»';
  }

  @override
  String get trainerCabinet => 'Кабинет тренера';

  @override
  String get incomingRequests => 'Входящие заявки';

  @override
  String get noRequests => 'Заявок нет';

  @override
  String get accept => 'Принять';

  @override
  String get reject => 'Отклонить';

  @override
  String get commentOptional => 'Комментарий клиенту (необязательно)';

  @override
  String get myClients => 'Мои клиенты';

  @override
  String get noClients => 'Закреплённых клиентов пока нет';

  @override
  String get schedule => 'Расписание';

  @override
  String get noSessions => 'На ближайшие 30 дней тренировок нет';

  @override
  String get newSession => 'Новая тренировка';

  @override
  String get client => 'Клиент';

  @override
  String get date => 'Дата';

  @override
  String get time => 'Время';

  @override
  String get duration => 'Длительность';

  @override
  String get notes => 'Заметки';

  @override
  String get create => 'Создать';

  @override
  String get markCompleted => 'Отметить проведённой';

  @override
  String get cancelSession => 'Отменить тренировку';

  @override
  String get specialization => 'Специализация';

  @override
  String get bio => 'О себе';

  @override
  String get acceptNewClients => 'Принимаю новых клиентов';

  @override
  String lastVisitOn(String date) {
    return 'Последнее посещение: $date';
  }

  @override
  String get noVisitsYet => 'Посещений ещё не было';

  @override
  String clientsCount(int count) {
    return 'Клиентов: $count';
  }

  @override
  String get todayLabel => 'Сегодня';

  @override
  String get tomorrowLabel => 'Завтра';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get changePasswordForcedTitle => 'Придумайте свой пароль';

  @override
  String get changePasswordForcedText =>
      'Вам выдали временный пароль в клубе. Чтобы продолжить, задайте новый пароль, который знаете только вы.';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get errorInvalidPassword => 'Текущий пароль указан неверно';

  @override
  String get errorPasswordUnchanged =>
      'Новый пароль должен отличаться от текущего';

  @override
  String get errorPasswordChangeRequired => 'Сначала смените временный пароль';

  @override
  String get sessionEnded => 'Прошла';

  @override
  String get workoutsNoTrainerHint =>
      'Выберите тренера — он сможет назначать вам тренировки';

  @override
  String get membershipInactiveWarning =>
      'Нет действующего абонемента. Оформите или продлите его на ресепшене клуба.';

  @override
  String get pastWeek => 'Прошедшие за 7 дней';

  @override
  String get clientNoActiveMembership =>
      'У клиента нет действующего абонемента';

  @override
  String get markResultHint => 'Нажмите, чтобы отметить результат';

  @override
  String get cancelSessionConfirm => 'Отменить тренировку?';

  @override
  String get cancelSessionConfirmBody =>
      'Клиент увидит, что тренировка отменена. Вернуть её будет нельзя.';

  @override
  String get keepSession => 'Не отменять';

  @override
  String get sessionMarkedCompleted => 'Тренировка отмечена проведённой';

  @override
  String get sessionMarkedCancelled => 'Тренировка отменена';

  @override
  String get errorSessionNotScheduled => 'Тренировка уже отмечена или отменена';

  @override
  String get errorSessionNotStarted =>
      'Отметить проведённой можно только после начала тренировки';

  @override
  String get errorNotFound => 'Запись не найдена или недоступна';

  @override
  String get loadMore => 'Показать ещё';

  @override
  String get myMembership => 'Мой абонемент';

  @override
  String get qrEntry => 'Вход';

  @override
  String get soon => 'скоро';

  @override
  String get statusInactive => 'Неактивен';

  @override
  String get noWorkoutsYet => 'Тренировок пока нет';

  @override
  String get workoutsByTrainerHint => 'Тренировки назначает ваш тренер';

  @override
  String get chooseTrainerForWorkoutsHint =>
      'Выберите тренера, чтобы получать тренировки';

  @override
  String get findYourTrainer => 'Найдите своего тренера';

  @override
  String withTrainerShort(String name) {
    return 'С тренером $name';
  }

  @override
  String get membershipPlansSubtitle => 'Выберите подходящий тариф';

  @override
  String get membershipManageSubtitle => 'Управление и история';

  @override
  String get plansInfo => 'О тарифах';

  @override
  String get plansInfoText =>
      'Тарифы и цены устанавливает клуб. Сейчас абонемент оформляется на ресепшене, онлайн-оплата появится позже.';

  @override
  String monthsShort(int count) {
    return '$count мес';
  }

  @override
  String daysShortCount(int count) {
    return '$count дн.';
  }

  @override
  String monthsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String visitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count посещения',
      many: '$count посещений',
      few: '$count посещения',
      one: '$count посещение',
    );
    return '$_temp0';
  }

  @override
  String perPeriod(String period) {
    return '/ $period';
  }

  @override
  String get currencySum => 'сум';

  @override
  String get unlimitedVisits => 'Безлимитные посещения';

  @override
  String validForPeriod(String period) {
    return 'Действует $period';
  }

  @override
  String get paymentMethod => 'Способ оплаты';

  @override
  String get paymentMethodValue => 'Банковская карта';

  @override
  String totalFor(String period) {
    return 'Итого за $period';
  }

  @override
  String checkoutPlan(String plan) {
    return 'Оформить «$plan»';
  }

  @override
  String get alsoAtReception => 'Также можно оформить на ресепшене клуба';

  @override
  String get onlinePaymentSoon =>
      'Онлайн-оплата скоро будет доступна. Пока абонемент можно оформить на ресепшене клуба.';

  @override
  String get noPlansTitle => 'Тарифы пока не опубликованы';

  @override
  String get noPlansHint => 'Уточните стоимость на ресепшене клуба';

  @override
  String get statusExpiring => 'Скоро истекает';

  @override
  String ofTotal(int total) {
    return 'из $total';
  }

  @override
  String get validTillLabel => 'Действует до';

  @override
  String get ownerLabel => 'Владелец';

  @override
  String get numberLabel => 'Номер';

  @override
  String get showQrPass => 'Показать QR-пропуск';

  @override
  String get actionFreeze => 'Заморозить';

  @override
  String get actionRenew => 'Продлить';

  @override
  String get actionGuest => 'Гость';

  @override
  String get actionChangePlan => 'Сменить';

  @override
  String get includedTitle => 'Включено в абонемент';

  @override
  String get startLabel => 'Начало';

  @override
  String usedOfLimit(int used, int limit) {
    return '$used из $limit';
  }

  @override
  String get historyEmpty => 'Здесь появятся прошлые абонементы';

  @override
  String get more => 'Ещё';

  @override
  String get menuContract => 'Договор';

  @override
  String get menuRules => 'Правила клуба';

  @override
  String get menuSupport => 'Поддержка';

  @override
  String get perMonth => '/ мес';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get phoneStatusConfirmed => 'Подтверждён';

  @override
  String get phoneStatusNotConfirmed => 'Не подтверждён';

  @override
  String get phoneChangeHintShort =>
      'Номер меняется через администратора клуба';

  @override
  String get statVisits => 'Посещений';

  @override
  String get memberSince => 'В клубе с';

  @override
  String filledOf(int filled, int total) {
    return '$filled из $total заполнено';
  }

  @override
  String get addEmail => 'Добавить email';

  @override
  String get settings => 'Настройки';

  @override
  String get faceIdLogin => 'Вход по Face ID';

  @override
  String get logoutAccount => 'Выйти из аккаунта';

  @override
  String appVersion(String version) {
    return 'Fitness Formula · версия $version';
  }

  @override
  String get editTitle => 'Редактирование';

  @override
  String get done => 'Готово';

  @override
  String get changePhoto => 'Сменить фото';

  @override
  String get photoSoon => 'Смена фото скоро будет доступна';

  @override
  String get languageName => 'Русский';

  @override
  String get workoutsSubtitle => 'Расписание и история занятий';

  @override
  String get openCalendar => 'Календарь';

  @override
  String get calendarSoon => 'Полный календарь скоро будет доступен';

  @override
  String get noActiveMembership => 'Нет действующего абонемента';

  @override
  String get renewAtReception => 'Продлите на ресепшене';

  @override
  String get getMembership => 'Оформить';

  @override
  String get chatWithTrainer => 'Написать тренеру';

  @override
  String get chatSoon => 'Чат с тренером скоро будет доступен';

  @override
  String get reschedule => 'Перенести';

  @override
  String get cancelShort => 'Отменить';

  @override
  String get personalWorkout => 'Персональная тренировка';

  @override
  String inHours(int count) {
    return 'через $count ч';
  }

  @override
  String inMinutes(int count) {
    return 'через $count мин';
  }

  @override
  String get happeningNow => 'Идёт сейчас';

  @override
  String get bookWorkout => 'Записаться на тренировку';

  @override
  String get noWorkoutsOnDay => 'В этот день тренировок нет';

  @override
  String trainersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тренера',
      many: '$count тренеров',
      few: '$count тренера',
      one: '$count тренер',
    );
    return '$_temp0 · выберите своего';
  }

  @override
  String get searchTrainersHint => 'Поиск по имени или направлению';

  @override
  String get clearSearch => 'Очистить';

  @override
  String get filters => 'Фильтры';

  @override
  String get sortTitle => 'Сортировка';

  @override
  String get sortByName => 'По имени';

  @override
  String get sortByExperience => 'По опыту';

  @override
  String get onlyAccepting => 'Только набирающие клиентов';

  @override
  String get allTrainers => 'Все тренеры';

  @override
  String get nothingFound => 'Никого не нашли';

  @override
  String get resetFilters => 'Сбросить фильтры';

  @override
  String get chooseYourTrainerHint =>
      'Выберите своего тренера — он составит программу и будет вести ваши тренировки';

  @override
  String get writeToTrainer => 'Написать';

  @override
  String get bookWithTrainer => 'Записаться';

  @override
  String get experienceLabel => 'Опыт';

  @override
  String yearsShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String get chooseAsTrainer => 'Выбрать тренером';

  @override
  String get requestExplain => 'Тренер получит заявку и подтвердит её';

  @override
  String get clubApp => 'Клубное приложение';

  @override
  String get phoneNumberHint => 'Номер телефона';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get forgotPasswordTitle => 'Восстановление пароля';

  @override
  String get forgotPasswordText =>
      'Подойдите на ресепшн клуба: администратор выдаст временный пароль. При входе с ним приложение попросит придумать новый.';

  @override
  String get orDivider => 'или';

  @override
  String get signInWithFaceId => 'Войти с Face ID';

  @override
  String get faceIdSoon => 'Вход по Face ID скоро будет доступен';

  @override
  String get noAccountQuestion => 'Нет аккаунта?';

  @override
  String get registerLink => 'Зарегистрируйтесь';

  @override
  String get qrPassTitle => 'QR-пропуск';

  @override
  String get qrPassHint => 'Поднесите код к сканеру на ресепшене';

  @override
  String qrRefreshIn(int seconds) {
    return 'Код обновится через $seconds с';
  }

  @override
  String get qrScreenshotNote =>
      'Код меняется каждые 30 секунд — скриншот не подойдёт';

  @override
  String get qrOffline =>
      'QR-пропуск работает только онлайн. Проверьте подключение к интернету.';

  @override
  String get qrEntryRecorded => 'Вход отмечен';

  @override
  String get qrEntryRecordedHint => 'Хорошей тренировки!';

  @override
  String get qrNotUsable =>
      'Абонемент сейчас не действует — на ресепшене во входе откажут';

  @override
  String get freezeTitle => 'Заморозка абонемента';

  @override
  String get freezeHowTo =>
      'Заморозить абонемент можно здесь или на ресепшене клуба. Срок абонемента продлится на число дней заморозки. Пока абонемент заморожен, вход по нему закрыт.';

  @override
  String frozenPeriod(String from, String to) {
    return 'Заморожен с $from по $to';
  }

  @override
  String freezePlanned(String from, String to) {
    return 'Заморозка запланирована: $from — $to';
  }

  @override
  String extendedUntil(String date) {
    return 'Срок продлён до $date';
  }

  @override
  String get renewTitle => 'Продление абонемента';

  @override
  String get changePlanTitle => 'Смена абонемента';

  @override
  String get renewHint =>
      'Новый абонемент начнётся после окончания текущего. Оплатите его на ресепшене — администратор оформит заявку.';

  @override
  String get changeHint =>
      'Выберите новый план и оплатите его на ресепшене. Администратор оформит абонемент и скажет, с какого дня он действует.';

  @override
  String get requestSentPay =>
      'Заявка отправлена. Оплатите абонемент на ресепшене клуба.';

  @override
  String get requestKindNew => 'Новый абонемент';

  @override
  String get requestKindRenew => 'Продление';

  @override
  String get requestKindChange => 'Смена плана';

  @override
  String get pendingPayAtDesk => 'Ожидает оплаты на ресепшене';

  @override
  String get requestAlreadyPending => 'У вас уже есть заявка на абонемент';

  @override
  String get noOtherPlans => 'Других планов сейчас нет';

  @override
  String get currentPlanBadge => 'Текущий';

  @override
  String get paymentAtDesk => 'Оплата на ресепшене';

  @override
  String get requestPayAtDeskHint =>
      'Администратор оформит абонемент после оплаты на ресепшене';

  @override
  String notifMembershipFrozen(String from, String to) {
    return 'Абонемент заморожен с $from по $to';
  }

  @override
  String notifMembershipUnfrozen(String date) {
    return 'Заморозка завершена, абонемент действует до $date';
  }

  @override
  String notifMembershipRequestRejected(String name) {
    return 'Заявка на абонемент «$name» отклонена';
  }

  @override
  String get bannerDetails => 'Подробнее';

  @override
  String get bannerVideo => 'Видео';

  @override
  String get bannerVideoError => 'Не удалось загрузить видео';

  @override
  String get back => 'Назад';

  @override
  String get freezeAction => 'Заморозить';

  @override
  String get freezeFrom => 'Начало заморозки';

  @override
  String get freezeDuration => 'Длительность';

  @override
  String freezeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String freezeLeft(int left, int total) {
    return 'Осталось заморозок: $left из $total';
  }

  @override
  String freezeRules(int days) {
    return 'Заморозка доступна 3 раза в год, до $days дней за раз. Срок абонемента продлится на эти дни, а вход по нему на время заморозки закроется.';
  }

  @override
  String get freezeNotAvailable =>
      'Заморозка доступна только для абонементов от 6 месяцев';

  @override
  String get freezeNotAvailableHint =>
      'Оформите абонемент на полгода или год — его можно будет замораживать до 3 раз в год.';

  @override
  String get freezeLimitReached =>
      'Вы использовали все заморозки этого абонемента';

  @override
  String freezeResult(String date) {
    return 'Абонемент продлится до $date';
  }

  @override
  String get freezeDone => 'Абонемент заморожен';

  @override
  String get freezePlannedDone => 'Заморозка запланирована';

  @override
  String get unfreezeAction => 'Разморозить сегодня';

  @override
  String get cancelFreezeAction => 'Отменить заморозку';

  @override
  String get unfreezeDone => 'Абонемент разморожен';

  @override
  String get freezeCancelledDone => 'Заморозка отменена';

  @override
  String get unfreezeHint =>
      'Неиспользованные дни заморозки вычтутся из срока абонемента.';

  @override
  String get errorFreezeTooLong => 'Одна заморозка — не дольше 30 дней';

  @override
  String get errorFreezeExists =>
      'У абонемента уже есть текущая или запланированная заморозка';

  @override
  String get errorFreezeInPast => 'Заморозка не может начинаться в прошлом';

  @override
  String get errorFreezeOutside =>
      'Заморозка должна начинаться в период действия абонемента';

  @override
  String get withoutTrainerTitle => 'Без тренера';

  @override
  String get withoutTrainerOption => 'Заниматься без тренера';

  @override
  String get withoutTrainerOptionHint =>
      'Приходите в зал по QR-пропуску и тренируйтесь самостоятельно. Тренера можно выбрать в любой момент.';

  @override
  String get withoutTrainerSelected => 'Вы занимаетесь без тренера';

  @override
  String get withoutTrainerSelectedHint =>
      'Захотите заниматься с тренером — выберите его в списке ниже.';

  @override
  String get withoutTrainerConfirm => 'Начать без тренера';

  @override
  String withoutTrainerCancelsRequest(String name) {
    return 'Заявка тренеру $name будет отменена.';
  }

  @override
  String get withoutTrainerDone => 'Готово! Тренируйтесь в своём ритме';

  @override
  String get withoutTrainerHome => 'Самостоятельные тренировки';

  @override
  String get soloWorkoutsHint =>
      'Вы занимаетесь без тренера — приходите в зал по QR-пропуску. Тренировки с тренером появятся здесь, когда вы его выберете.';

  @override
  String get soloNextWorkoutHint =>
      'Приходите в зал в удобное время по QR-пропуску';

  @override
  String get startWorkout => 'Начать тренировку';

  @override
  String get errorTrainerAssigned => 'У вас уже есть тренер';

  @override
  String get requestSentTitle => 'Заявка отправлена!';

  @override
  String requestSentBody(String name) {
    return '$name получит заявку и ответит в приложении. Чтобы быстрее договориться о первой тренировке, напишите тренеру:';
  }

  @override
  String requestSentBodyNoContacts(String name) {
    return '$name получит заявку и ответит в приложении — мы пришлём уведомление.';
  }

  @override
  String get trainerContactsTitle => 'Связаться с тренером';

  @override
  String get openLinkFailed => 'Не удалось открыть ссылку';

  @override
  String get faceAccessTitle => 'Вход по лицу';

  @override
  String get faceAccessSubtitle =>
      'Проходите через турникет без телефона и QR-кода';

  @override
  String get faceStatusNone => 'Добавьте фото — и проходите в клуб по лицу';

  @override
  String get faceStatusNoneHint =>
      'Фото попадёт на терминал у входа. Его видите только вы и администраторы клуба.';

  @override
  String get faceStatusWaitingNoAccess =>
      'Фото сохранено. Вход по лицу заработает, когда абонемент будет активен.';

  @override
  String get faceStatusWaitingNoTerminal =>
      'Фото сохранено. Терминал в клубе ещё не подключён — пока проходите по QR-пропуску.';

  @override
  String get faceStatusPending => 'Отправляем на турникет…';

  @override
  String get faceStatusPendingHint =>
      'Обычно это занимает несколько секунд. Пока можно пройти по QR-пропуску.';

  @override
  String get faceStatusReady => 'Проходите в клуб по лицу';

  @override
  String faceAccessPeriod(String from, String to) {
    return 'Турникет пропустит вас с $from по $to';
  }

  @override
  String get faceStatusRejected =>
      'Терминал не распознал лицо на фото — сделайте новое';

  @override
  String get faceTipsTitle => 'Как сделать фото';

  @override
  String get faceTipFront => 'Лицо анфас и целиком в кадре';

  @override
  String get faceTipNoAccessories => 'Без очков, маски и головного убора';

  @override
  String get faceTipLight => 'Ровный свет, без засветки сзади';

  @override
  String get faceConsent =>
      'Согласен на обработку фото лица для прохода через турникет клуба';

  @override
  String get faceConsentRequired => 'Отметьте согласие на обработку фото';

  @override
  String get faceTakeSelfie => 'Сделать селфи';

  @override
  String get facePickGallery => 'Выбрать из галереи';

  @override
  String get faceSend => 'Отправить';

  @override
  String get faceRetake => 'Переснять';

  @override
  String get faceReplace => 'Заменить фото';

  @override
  String get faceDelete => 'Удалить фото';

  @override
  String get faceDeleteTitle => 'Удалить фото?';

  @override
  String get faceDeleteBody =>
      'Вас уберут с турникета, и проходить в клуб нужно будет по QR-пропуску. Фото можно добавить снова в любой момент.';

  @override
  String get faceDeleted => 'Фото удалено';

  @override
  String get faceUploaded => 'Фото отправлено';

  @override
  String get facePreviewTitle => 'Проверьте фото';

  @override
  String get faceErrorTooSmall =>
      'Фото слишком маленькое: нужно не меньше 240 точек по каждой стороне';

  @override
  String get faceErrorUnreadable => 'Не удалось открыть фото. Выберите другое.';

  @override
  String get faceErrorCamera => 'Камера недоступна. Выберите фото из галереи.';

  @override
  String get faceErrorPermission =>
      'Нет доступа к камере или фото. Разрешите его в настройках телефона.';

  @override
  String get errorFaceFormat => 'Нужна фотография в формате JPEG';

  @override
  String get errorFaceTooLarge => 'Фото слишком большое: до 200 КБ';

  @override
  String get errorFaceBadSize =>
      'Размер фото — от 240 до 4096 точек по каждой стороне';

  @override
  String get faceShortNone => 'Добавьте фото';

  @override
  String get faceShortWaiting => 'Фото сохранено';

  @override
  String get faceShortPending => 'Отправляется на турникет';

  @override
  String get faceShortReady => 'Работает';

  @override
  String get faceShortRejected => 'Нужно новое фото';

  @override
  String get faceHomePromptTitle => 'Вход в клуб по лицу';

  @override
  String get faceHomePromptBody =>
      'Добавьте фото — турникет узнает вас без телефона';

  @override
  String get faceOfferTitle => 'Добавьте фото для входа по лицу';

  @override
  String get faceOfferBody =>
      'Когда абонемент начнёт действовать, турникет пропустит вас по лицу — без телефона и QR-кода.';

  @override
  String get faceOfferAdd => 'Добавить фото для входа по лицу';

  @override
  String get later => 'Позже';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountTitle => 'Удалить аккаунт?';

  @override
  String get deleteAccountPointData =>
      'Имя, телефон, email, дата рождения и фото лица будут удалены, вход по лицу перестанет работать.';

  @override
  String get deleteAccountPointMembership =>
      'Оставшиеся дни и посещения по абонементу сгорят, заявки и будущие тренировки отменятся.';

  @override
  String get deleteAccountPointRecords =>
      'Записи об оплатах и посещениях клуб хранит без вашего имени — этого требует учёт.';

  @override
  String get deleteAccountPointFinal =>
      'Отменить удаление нельзя. Номер можно будет зарегистрировать заново.';

  @override
  String get deleteAccountPasswordLabel => 'Пароль для подтверждения';

  @override
  String get deleteAccountConfirm => 'Удалить навсегда';

  @override
  String get deleteAccountWrongPassword => 'Неверный пароль';

  @override
  String get accountDeleted => 'Аккаунт удалён';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get registerConsentPrefix => 'Регистрируясь, вы соглашаетесь с ';

  @override
  String get registerConsentLink => 'Политикой конфиденциальности';

  @override
  String get registerConsentSuffix => '';

  @override
  String get faceDataMore => 'Подробнее о фото и данных';

  @override
  String get foodPhotoUnreadable =>
      'Не удалось прочитать фото. Попробуйте другое.';

  @override
  String get foodPhotoTooSmall =>
      'Фото слишком маленькое: нужно не меньше 320 пикселей по короткой стороне.';

  @override
  String get foodPhotoNoCamera =>
      'Камера недоступна на этом устройстве. Выберите фото из галереи.';

  @override
  String get foodPhotoPermission =>
      'Нет доступа к камере или фото. Разрешите его в настройках телефона.';

  @override
  String get unitKcal => 'ккал';

  @override
  String get unitG => 'г';

  @override
  String get unitMg => 'мг';

  @override
  String get unitMl => 'мл';

  @override
  String get protein => 'Белки';

  @override
  String get fat => 'Жиры';

  @override
  String get carbs => 'Углеводы';

  @override
  String get fiber => 'Клетчатка';

  @override
  String get sugar => 'Сахар';

  @override
  String get saturatedFat => 'Насыщ. жиры';

  @override
  String get sodium => 'Натрий';

  @override
  String get proteinShort => 'Б';

  @override
  String get fatShort => 'Ж';

  @override
  String get carbsShort => 'У';

  @override
  String kcalEatenSemantics(String kcal) {
    return 'Съедено $kcal ккал';
  }

  @override
  String kcalOfTargetSemantics(String kcal, String target) {
    return 'Съедено $kcal из $target ккал';
  }

  @override
  String ofKcal(String target) {
    return 'из $target ккал';
  }

  @override
  String get gramsInvalid => 'Введите вес от 1 до 5000';

  @override
  String get amountGrams => 'Вес, г';

  @override
  String get amountMl => 'Объём, мл';

  @override
  String get mealBreakfast => 'Завтрак';

  @override
  String get mealLunch => 'Обед';

  @override
  String get mealDinner => 'Ужин';

  @override
  String get mealSnack => 'Перекус';

  @override
  String get foodCatBreakfast => 'Завтрак';

  @override
  String get foodCatLunch => 'Обед';

  @override
  String get foodCatDinner => 'Ужин';

  @override
  String get foodCatSnacks => 'Перекусы';

  @override
  String get foodCatFruits => 'Фрукты';

  @override
  String get foodCatVegetables => 'Овощи';

  @override
  String get foodCatMeat => 'Мясо';

  @override
  String get foodCatFish => 'Рыба';

  @override
  String get foodCatDairy => 'Молочное';

  @override
  String get foodCatBakery => 'Выпечка';

  @override
  String get foodCatDesserts => 'Десерты';

  @override
  String get foodCatFastFood => 'Фастфуд';

  @override
  String get foodCatDrinks => 'Напитки';

  @override
  String get foodCatPackaged => 'Упакованные продукты';

  @override
  String get foodCatTraditional => 'Национальная кухня';

  @override
  String get foodCatGrains => 'Крупы и гарниры';

  @override
  String get foodCatLegumes => 'Бобовые';

  @override
  String get foodCatNuts => 'Орехи и семена';

  @override
  String get foodCatFats => 'Масла и жиры';

  @override
  String get foodCatSauces => 'Соусы';

  @override
  String get foodCatEggs => 'Яйца';

  @override
  String get foodCatOther => 'Другое';

  @override
  String get sourceLabel => 'Этикетка';

  @override
  String get sourceRecipe => 'Рецепт';

  @override
  String get sourceUser => 'Своё';

  @override
  String get allergenGluten => 'Глютен';

  @override
  String get allergenMilk => 'Молоко';

  @override
  String get allergenEggs => 'Яйца';

  @override
  String get allergenNuts => 'Орехи';

  @override
  String get allergenPeanuts => 'Арахис';

  @override
  String get allergenSesame => 'Кунжут';

  @override
  String get allergenSoy => 'Соя';

  @override
  String get allergenFish => 'Рыба';

  @override
  String get allergenShellfish => 'Ракообразные';

  @override
  String get allergenMolluscs => 'Моллюски';

  @override
  String get allergenCelery => 'Сельдерей';

  @override
  String get allergenMustard => 'Горчица';

  @override
  String get allergenSulphites => 'Сульфиты';

  @override
  String get allergenLupin => 'Люпин';

  @override
  String get goalLose => 'Снизить вес';

  @override
  String get goalMaintain => 'Поддерживать вес';

  @override
  String get goalGain => 'Набрать массу';

  @override
  String get activitySedentary => 'Минимальная';

  @override
  String get activityLight => 'Низкая';

  @override
  String get activityModerate => 'Средняя';

  @override
  String get activityActive => 'Высокая';

  @override
  String get activityVeryActive => 'Очень высокая';

  @override
  String get activitySedentaryHint => 'Сидячая работа, почти без тренировок';

  @override
  String get activityLightHint => 'Тренировки 1–3 раза в неделю';

  @override
  String get activityModerateHint => 'Тренировки 3–5 раз в неделю';

  @override
  String get activityActiveHint => 'Тренировки 6–7 раз в неделю';

  @override
  String get activityVeryActiveHint =>
      'Тяжёлые тренировки каждый день или физическая работа';

  @override
  String get prepRaw => 'Сырое';

  @override
  String get prepBoiled => 'Варёное';

  @override
  String get prepSteamed => 'На пару';

  @override
  String get prepFried => 'Жареное';

  @override
  String get prepDeepFried => 'Во фритюре';

  @override
  String get prepBaked => 'Запечённое';

  @override
  String get prepGrilled => 'На гриле / углях';

  @override
  String get prepStewed => 'Тушёное';

  @override
  String get prepMixed => 'Смешанный способ';

  @override
  String get prepUnknown => 'Способ не определён';

  @override
  String get roleMain => 'Основа';

  @override
  String get roleFat => 'Масло / жир';

  @override
  String get roleSauce => 'Соус';

  @override
  String get roleGarnish => 'Гарнир';

  @override
  String get roleDrink => 'Напиток';

  @override
  String get warnLowConfidence =>
      'ИИ не уверен в блюде — проверьте название и состав.';

  @override
  String get warnWeightUncertain =>
      'Вес оценён по фото приблизительно — поправьте граммы, если знаете точнее.';

  @override
  String get warnUnmatched =>
      'Некоторых ингредиентов нет в базе — выберите продукт, иначе калории будут занижены.';

  @override
  String get warnCookingFatMissing =>
      'Блюдо жареное, но масла в составе нет. Добавьте его, если готовили на масле.';

  @override
  String get warnMultipleDishes =>
      'На фото несколько блюд — выберите нужное или добавьте все.';

  @override
  String get imageBlurry =>
      'Фото размыто — переснимите при хорошем свете, держа телефон неподвижно.';

  @override
  String get imageDark =>
      'Фото слишком тёмное — переснимите при хорошем свете.';

  @override
  String get imagePartial =>
      'Блюдо видно не полностью — снимите всю тарелку сверху.';

  @override
  String get weightConfLow => 'вес примерный';

  @override
  String get weightConfMedium => 'вес оценён';

  @override
  String get weightConfHigh => 'вес уверенно';

  @override
  String get dataProfile => 'профиль';

  @override
  String get dataDiaryDay => 'дневник';

  @override
  String get dataPeriod => 'статистика';

  @override
  String get dataScans => 'сканирования';

  @override
  String get dataTrainings => 'тренировки';

  @override
  String get dataFoodSearch => 'база продуктов';

  @override
  String get errAiNotConfigured =>
      'ИИ-анализ не подключён в клубе. Дневник, штрихкоды и поиск продуктов работают.';

  @override
  String get errAiConsentRequired =>
      'Нужно согласие на отправку фото ИИ-сервису.';

  @override
  String get errAiUnavailable =>
      'ИИ-сервис сейчас недоступен. Попробуйте через несколько минут.';

  @override
  String get errAiRateLimited =>
      'Слишком много запросов подряд. Подождите минуту.';

  @override
  String get errAiQuotaExceeded =>
      'Дневной лимит ИИ-анализов исчерпан. Завтра снова можно будет сканировать, а пока добавьте блюдо вручную.';

  @override
  String get errAiBudgetExceeded =>
      'ИИ-анализ временно недоступен в клубе. Добавьте блюдо вручную.';

  @override
  String get errAiInvalidResponse =>
      'ИИ ответил непонятно. Попробуйте ещё раз.';

  @override
  String get errAiRefused =>
      'ИИ не смог обработать это фото. Попробуйте другое.';

  @override
  String get errPhotoFormat => 'Неподдерживаемый формат фото.';

  @override
  String get errPhotoTooLarge => 'Фото слишком большое.';

  @override
  String get errPhotoBadSize =>
      'Неподходящий размер фото: нужно от 320 до 4096 пикселей по каждой стороне.';

  @override
  String get errBarcodeNotFound => 'Продукт с таким штрихкодом не найден.';

  @override
  String get errBarcodeInvalid => 'Неверный штрихкод: нужно от 8 до 14 цифр.';

  @override
  String get errFoodDbUnavailable =>
      'База продуктов сейчас недоступна. Попробуйте позже или найдите продукт вручную.';

  @override
  String get errItemWithoutNutrition =>
      'У продукта нет данных о пищевой ценности — выберите продукт из базы.';

  @override
  String get errProfileIncomplete =>
      'Заполните профиль питания, чтобы рассчитать норму.';

  @override
  String get errValidation => 'Проверьте введённые данные.';

  @override
  String get aiProviderUnknown => 'внешний ИИ-сервис';

  @override
  String get aiConsentTitle => 'Анализ еды с помощью ИИ';

  @override
  String aiConsentBody(String provider) {
    return 'Чтобы распознать блюдо, прочитать этикетку или ответить на вопрос о питании, приложение отправляет фото и данные о питании в ИИ-сервис $provider. Калории считает сервер клуба по базе продуктов.';
  }

  @override
  String get aiConsentPointPhoto =>
      'Отправляется только фото еды или этикетки — без геолокации и данных камеры.';

  @override
  String get aiConsentPointNoName =>
      'Имя и телефон не передаются. Для советов — только возраст, рост, вес, цель и дневник питания.';

  @override
  String get aiConsentPointDelete =>
      'Фото и историю можно удалить в любой момент, согласие — отозвать в настройках питания.';

  @override
  String get aiConsentAgree => 'Согласен';

  @override
  String get aiConsentDecline => 'Не сейчас';

  @override
  String get nutritionProfileTitle => 'Профиль питания';

  @override
  String get nutritionProfileSubtitle => 'Цель и параметры для дневной нормы';

  @override
  String get nutritionProfileSaved => 'Профиль питания сохранён';

  @override
  String get nutritionGoal => 'Цель';

  @override
  String get nutritionGoalPick =>
      'Выберите цель — от неё зависит норма калорий.';

  @override
  String get aboutYou => 'О вас';

  @override
  String get heightCm => 'Рост, см';

  @override
  String get weightKg => 'Вес, кг';

  @override
  String get activityLevel => 'Активность';

  @override
  String get customTarget => 'Своя норма калорий';

  @override
  String get customTargetHint => 'Необязательно — иначе рассчитаем';

  @override
  String get restrictions => 'Ограничения в питании';

  @override
  String get restrictionsHint =>
      'Например: без свинины, вегетарианство, мало соли';

  @override
  String get allergies => 'Аллергии';

  @override
  String get aiAnalysis => 'ИИ-анализ';

  @override
  String aiConsentGiven(String date) {
    return 'Согласие на отправку фото ИИ-сервису дано $date.';
  }

  @override
  String get aiConsentNotGiven =>
      'Согласие на отправку фото ИИ-сервису не дано. Без него работают дневник, поиск и штрихкоды.';

  @override
  String get aiConsentRevoke => 'Отозвать согласие';

  @override
  String get aiConsentGive => 'Дать согласие';

  @override
  String get aiConsentRevoked => 'Согласие отозвано';

  @override
  String valueRange(String min, String max) {
    return 'Значение от $min до $max';
  }

  @override
  String get dailyTarget => 'Дневная норма';

  @override
  String get targetCustomNote =>
      'Ваша норма калорий; белки, жиры и углеводы рассчитаны от неё.';

  @override
  String targetMethodNote(String bmr, String tdee) {
    return 'Расчёт по формуле Миффлина — Сан Жеора: базовый обмен $bmr ккал, с учётом активности $tdee ккал, скорректировано под цель.';
  }

  @override
  String get errScanInProgress =>
      'Предыдущее фото ещё анализируется. Подождите немного.';

  @override
  String get scanPreviewTitle => 'Фото блюда';

  @override
  String get scanPreviewSubtitle => 'Проверьте фото и запустите анализ';

  @override
  String get labelPreviewTitle => 'Фото этикетки';

  @override
  String get labelPreviewSubtitle =>
      'Сфотографируйте таблицу пищевой ценности целиком';

  @override
  String get analyzeFood => 'Анализировать';

  @override
  String get readLabel => 'Прочитать этикетку';

  @override
  String get labelUnreadable =>
      'Не удалось прочитать пищевую ценность на этикетке. Переснимите таблицу крупнее и при хорошем свете.';

  @override
  String get scanHintLabel => 'Что на фото? (необязательно)';

  @override
  String get scanHintExample => 'Например: лагман, домашний плов';

  @override
  String get retakePhoto => 'Переснять';

  @override
  String get fromGallery => 'Из галереи';

  @override
  String get analyzing1 => 'Ищем блюдо на фото…';

  @override
  String get analyzing2 => 'Определяем ингредиенты…';

  @override
  String get analyzing3 => 'Оцениваем вес порции…';

  @override
  String get analyzing4 => 'Считаем калории по базе продуктов…';

  @override
  String get analyzingLabel1 => 'Читаем этикетку…';

  @override
  String get analyzingLabel2 => 'Ищем таблицу пищевой ценности…';

  @override
  String get analyzingLabel3 => 'Проверяем состав и аллергены…';

  @override
  String get scanResultTitle => 'Результат';

  @override
  String get scanReused =>
      'Это фото уже анализировалось — показан прежний результат.';

  @override
  String get addToDiary => 'Добавить в дневник';

  @override
  String addAllDishes(int count) {
    return 'Добавить все ($count)';
  }

  @override
  String addedToDiary(String meal) {
    return 'Добавлено в дневник: $meal';
  }

  @override
  String addedAllToDiary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count блюда',
      many: 'Добавлено $count блюд',
      few: 'Добавлено $count блюда',
      one: 'Добавлено $count блюдо',
    );
    return '$_temp0';
  }

  @override
  String get lastIngredient =>
      'В блюде должен остаться хотя бы один ингредиент.';

  @override
  String get noFatsToScale => 'В составе нет масла или соуса.';

  @override
  String get addIngredient => 'Добавить ингредиент';

  @override
  String get addIngredientShort => 'Добавить';

  @override
  String pickProductFor(String name) {
    return 'Продукт для «$name»';
  }

  @override
  String get dishRenamed => 'Название сохранено';

  @override
  String get renameDish => 'Название блюда';

  @override
  String get dishName => 'Название';

  @override
  String get deleteScanTitle => 'Удалить сканирование?';

  @override
  String get deleteScanBody =>
      'Фото и результат анализа будут удалены. Записи в дневнике останутся, но без фото.';

  @override
  String get deleteAction => 'Удалить';

  @override
  String get clarifyTitle => 'Что на фото?';

  @override
  String get photoUnavailable => 'Фото больше недоступно. Сделайте новое.';

  @override
  String get notFoodTitle => 'Еда не найдена';

  @override
  String get notFoodBody =>
      'На фото не видно еды или напитка. Сфотографируйте блюдо сверху, чтобы оно было целиком в кадре.';

  @override
  String get scanFailedTitle => 'Анализ не выполнен';

  @override
  String get scanFailedBody =>
      'ИИ-сервис не ответил. Попробуйте ещё раз — это фото сохранено.';

  @override
  String get clarifyNeededTitle => 'Нужно уточнение';

  @override
  String get clarifyNeededBody =>
      'Не удалось уверенно определить блюдо. Напишите, что на фото, или переснимите.';

  @override
  String get clarifyName => 'Уточнить название';

  @override
  String kcalRangeLabel(String range) {
    return 'возможно $range ккал';
  }

  @override
  String get incompleteData => 'Неполные данные';

  @override
  String get possibleAllergens => 'Возможные аллергены';

  @override
  String get ingredients => 'Ингредиенты';

  @override
  String get fatLess => 'Меньше';

  @override
  String get fatMore => 'Больше';

  @override
  String get fatTitle => 'Масло и соусы';

  @override
  String get fatHint =>
      'Количество масла и соуса на фото видно хуже всего — поправьте, если знаете, как готовили.';

  @override
  String get mealTypeTitle => 'Приём пищи';

  @override
  String get calcNote =>
      'Калории посчитаны по базе продуктов (USDA, Open Food Facts) по весу каждого ингредиента. Это оценка по фото — точнее будет, если поправить граммы.';

  @override
  String get notInDatabasePick => 'нет в базе — выбрать продукт';

  @override
  String get decrease => 'Меньше';

  @override
  String get increase => 'Больше';

  @override
  String get confidenceHigh => 'Уверенно';

  @override
  String get confidenceMedium => 'Вероятно';

  @override
  String get confidenceLow => 'Неуверенно';

  @override
  String serving(int grams) {
    return 'Порция · $grams г';
  }

  @override
  String package(int grams) {
    return 'Упаковка · $grams г';
  }

  @override
  String portion(int grams) {
    return 'Порция · $grams г';
  }

  @override
  String get halfPortion => 'Полпорции';

  @override
  String get searchFoodHint => 'Продукт или блюдо';

  @override
  String get searchFoodStart =>
      'Начните вводить название: «плов», «гречка», «кефир»…';

  @override
  String get searchFoodNothing =>
      'Ничего не нашлось. Попробуйте другое название или создайте свой продукт.';

  @override
  String get traditionalDish => 'Национальное блюдо';

  @override
  String get createOwnProduct => 'Создать свой продукт';

  @override
  String get createProductSubtitle =>
      'Пищевая ценность — с упаковки или из рецепта';

  @override
  String get productCreated => 'Продукт сохранён';

  @override
  String get productName => 'Название';

  @override
  String get productBrand => 'Производитель (необязательно)';

  @override
  String get per100MlSwitch => 'Это напиток — значения на 100 мл';

  @override
  String get per100g => 'На 100 г';

  @override
  String get per100Ml => 'На 100 мл';

  @override
  String get portionSizes => 'Размер порции и упаковки';

  @override
  String get servingSize => 'Порция';

  @override
  String get packageSize => 'Упаковка';

  @override
  String get barcodeOptional => 'Штрихкод (необязательно)';

  @override
  String get allergensStated => 'Аллергены по составу';

  @override
  String get composition => 'Состав';

  @override
  String get howMuchEaten => 'Сколько съели';

  @override
  String get barcodeTitle => 'Штрихкод';

  @override
  String get barcodeSubtitle => 'Наведите камеру на штрихкод упаковки';

  @override
  String get barcodeCameraUnavailable =>
      'Камера недоступна. Введите цифры под штрихкодом вручную.';

  @override
  String get barcodeManual => 'Ввести вручную';

  @override
  String get barcodeDigits => 'Цифры под штрихкодом';

  @override
  String get barcodeFind => 'Найти продукт';

  @override
  String get barcodeSourceNote =>
      'Продукты ищутся в открытой базе Open Food Facts. Если продукта там нет, сфотографируйте этикетку.';

  @override
  String get barcodeNotFoundTitle => 'Продукт не найден';

  @override
  String barcodeNotFoundBody(String code) {
    return 'Штрихкода $code нет в базе продуктов. Сфотографируйте этикетку с пищевой ценностью или найдите продукт вручную.';
  }

  @override
  String get photoLabel => 'Сфотографировать этикетку';

  @override
  String get findManually => 'Найти вручную';

  @override
  String get nutritionTitle => 'Питание';

  @override
  String get nutritionSubtitle => 'ИИ-сканер еды и дневник питания';

  @override
  String get scanFood => 'Сканировать еду';

  @override
  String get scanFoodHint => 'Сфотографируйте блюдо — ИИ определит состав';

  @override
  String get labelShort => 'Этикетка';

  @override
  String scansLeft(int left, int total) {
    return 'ИИ-анализов сегодня: осталось $left из $total';
  }

  @override
  String get aiOffInfo =>
      'ИИ-анализ фото не подключён в клубе. Добавляйте еду по штрихкоду или вручную — дневник и аналитика работают.';

  @override
  String get addManually => 'Добавить вручную';

  @override
  String get foodDiary => 'Дневник питания';

  @override
  String get foodDiaryHint => 'Завтрак, обед, ужин и перекусы';

  @override
  String get nutritionAnalytics => 'Аналитика';

  @override
  String get nutritionAnalyticsHint => 'Калории и БЖУ за день, неделю, месяц';

  @override
  String get consultantTitle => 'ИИ-консультант';

  @override
  String get consultantHint => 'Вопросы о питании по вашим данным';

  @override
  String get recentScans => 'Последние сканирования';

  @override
  String get noScansYet =>
      'Сканирований пока нет. Сфотографируйте свою еду — результат появится здесь.';

  @override
  String eatenKcal(String kcal) {
    return 'Съедено $kcal ккал';
  }

  @override
  String remainingKcal(String kcal) {
    return 'Осталось $kcal ккал';
  }

  @override
  String overKcal(String kcal) {
    return 'Больше нормы на $kcal ккал';
  }

  @override
  String get noTargetYet => 'Норма не рассчитана';

  @override
  String get setupTarget => 'Рассчитать дневную норму';

  @override
  String get statusNeedsClarification => 'нужно уточнение';

  @override
  String get statusNotFood => 'еда не найдена';

  @override
  String get statusFailed => 'ошибка анализа';

  @override
  String get unknownDish => 'Блюдо';

  @override
  String get inDiary => 'В дневнике';

  @override
  String get nutritionHomeHint => 'Сфотографируйте еду — ИИ посчитает калории';

  @override
  String get yesterday => 'Вчера';

  @override
  String get previousDay => 'Предыдущий день';

  @override
  String get nextDay => 'Следующий день';

  @override
  String addToMeal(String meal) {
    return 'Добавить: $meal';
  }

  @override
  String get mealEmpty => 'Пока ничего — нажмите, чтобы добавить';

  @override
  String get addFromSearch => 'Найти продукт или блюдо';

  @override
  String get addFromRecent => 'Из недавних';

  @override
  String get addFromScans => 'Из истории сканирований';

  @override
  String get noRecent => 'Недавних записей пока нет';

  @override
  String get lastItemDeleteEntry =>
      'Это последний продукт — удалите запись целиком.';

  @override
  String get entrySaved => 'Запись сохранена';

  @override
  String get entryRepeated => 'Добавлено ещё раз на сегодня';

  @override
  String get deleteEntryTitle => 'Удалить запись?';

  @override
  String get deleteEntryBody => 'Запись пропадёт из дневника и статистики.';

  @override
  String get repeatToday => 'Повторить сегодня';

  @override
  String get recalcOnSave => 'Точные значения пересчитаются при сохранении';

  @override
  String get noNutritionData => 'нет данных о пищевой ценности';

  @override
  String get portionSize => 'Размер порции';

  @override
  String get eatenAt => 'Время';

  @override
  String get periodDay => 'День';

  @override
  String get periodWeek => 'Неделя';

  @override
  String get periodMonth => 'Месяц';

  @override
  String get previousPeriod => 'Предыдущий период';

  @override
  String get nextPeriod => 'Следующий период';

  @override
  String get aiReport => 'ИИ-отчёт';

  @override
  String get aiReportDay => 'Отчёт за день';

  @override
  String get aiReportWeek => 'Отчёт за неделю';

  @override
  String get aiReportDayButton => 'Получить отчёт за день';

  @override
  String get aiReportWeekButton => 'Получить отчёт за неделю';

  @override
  String get notMedicalAdvice =>
      'Это не медицинская рекомендация. При заболеваниях обратитесь к врачу.';

  @override
  String workoutsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тренировки',
      many: '$count тренировок',
      few: '$count тренировки',
      one: '$count тренировка',
    );
    return '$_temp0';
  }

  @override
  String get clubVisit => 'Посещение клуба';

  @override
  String get byMeal => 'По приёмам пищи';

  @override
  String get macroSplit => 'Доля БЖУ в калориях';

  @override
  String get averageKcal => 'ккал в среднем';

  @override
  String get daysLogged => 'дней с записями';

  @override
  String get daysWithinTarget => 'дней в норме ±10%';

  @override
  String get caloriesPerDay => 'Калории по дням';

  @override
  String get macrosPerDay => 'Белки, жиры, углеводы по дням';

  @override
  String get averagePerDay => 'В среднем за день';

  @override
  String chartSemantics(int days, String kcal) {
    return 'График калорий: дней с записями $days, в среднем $kcal ккал';
  }

  @override
  String get legendWithin => 'в норме';

  @override
  String get legendOver => 'больше нормы';

  @override
  String get legendUnder => 'меньше нормы';

  @override
  String get legendWorkout => 'тренировка';

  @override
  String get noDataYet => 'Данных пока нет';

  @override
  String periodActivity(int workouts, int visits) {
    return 'За период: тренировок — $workouts, посещений клуба — $visits';
  }

  @override
  String get consultantSubtitle => 'Отвечает по вашему дневнику и профилю';

  @override
  String get consultantIntro =>
      'Спросите о своём питании: консультант видит ваш дневник, сканирования, цель и тренировки и отвечает по реальным данным.';

  @override
  String get consultantHintInput => 'Вопрос о питании';

  @override
  String get consultantTyping => 'Консультант печатает';

  @override
  String basedOn(String sources) {
    return 'на основе: $sources';
  }

  @override
  String get askEatenToday => 'Сколько калорий я сегодня съел?';

  @override
  String get askDinner => 'Что мне лучше съесть на ужин?';

  @override
  String get askPlov => 'Можно ли мне сейчас съесть плов?';

  @override
  String get askProteinLeft => 'Сколько белка мне осталось набрать?';

  @override
  String get askWhyOver => 'Почему я превышаю норму?';

  @override
  String get askCompare => 'Сравни сегодня со вчера';

  @override
  String get cameraDishTitle => 'Фото блюда';

  @override
  String get cameraLabelTitle => 'Фото этикетки';

  @override
  String get cameraDishHint => 'Вся тарелка в кадре — сверху или под углом';

  @override
  String get cameraLabelHint => 'Таблица пищевой ценности целиком, без бликов';

  @override
  String get cameraShutter => 'Сделать снимок';

  @override
  String get cameraFlashOff => 'Вспышка выключена';

  @override
  String get cameraFlashAuto => 'Вспышка: авто';

  @override
  String get cameraFlashOn => 'Вспышка включена';

  @override
  String cameraZoom(String zoom) {
    return 'Увеличение $zoom';
  }

  @override
  String get cameraProcessing => 'Готовим фото…';

  @override
  String get cameraNoAccessTitle => 'Нет доступа к камере';

  @override
  String get cameraNoAccessBody =>
      'Разрешите приложению доступ к камере в Настройках, чтобы фотографировать еду. Или выберите фото из галереи.';

  @override
  String get cameraOpenSettings => 'Открыть настройки';

  @override
  String get cameraUnavailableTitle => 'Камера недоступна';

  @override
  String get cameraUnavailableBody =>
      'На этом устройстве нет камеры. Выберите фото из галереи.';

  @override
  String get cameraFailedTitle => 'Камера не запустилась';

  @override
  String get cameraFailedBody =>
      'Попробуйте ещё раз или выберите фото из галереи.';

  @override
  String get cameraTapToFocus => 'Нажмите на экран, чтобы сфокусироваться';
}
