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
}
