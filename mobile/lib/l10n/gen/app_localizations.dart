import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'Fitness Formulasi'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'С возвращением'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Войдите по номеру телефона'**
  String get loginSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Создайте аккаунт клиента клуба'**
  String get registerSubtitle;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get phone;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get confirmPassword;

  /// No description provided for @firstName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In ru, this message translates to:
  /// **'Фамилия'**
  String get lastName;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @birthDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата рождения'**
  String get birthDate;

  /// No description provided for @gender.
  ///
  /// In ru, this message translates to:
  /// **'Пол'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In ru, this message translates to:
  /// **'Мужской'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In ru, this message translates to:
  /// **'Женский'**
  String get genderFemale;

  /// No description provided for @notSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get notSpecified;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get signUp;

  /// No description provided for @noAccount.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта? Зарегистрируйтесь'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт? Войти'**
  String get haveAccount;

  /// No description provided for @smsNotice.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение номера по SMS появится в следующем обновлении.'**
  String get smsNotice;

  /// No description provided for @validationRequired.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get validationRequired;

  /// No description provided for @validationPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер в формате +998 90 123 45 67'**
  String get validationPhone;

  /// No description provided for @validationPassword.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 8 символов, буквы и цифры'**
  String get validationPassword;

  /// No description provided for @validationPasswordMatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get validationPasswordMatch;

  /// No description provided for @validationEmail.
  ///
  /// In ru, this message translates to:
  /// **'Неверный email'**
  String get validationEmail;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так. Попробуйте ещё раз.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером'**
  String get errorNetwork;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный номер или пароль'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAccountLocked.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Попробуйте через 15 минут.'**
  String get errorAccountLocked;

  /// No description provided for @errorAccountBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт заблокирован. Обратитесь в клуб.'**
  String get errorAccountBlocked;

  /// No description provided for @errorPhoneTaken.
  ///
  /// In ru, this message translates to:
  /// **'Этот номер уже зарегистрирован'**
  String get errorPhoneTaken;

  /// No description provided for @errorDuplicateRequest.
  ///
  /// In ru, this message translates to:
  /// **'Заявка этому тренеру уже отправлена'**
  String get errorDuplicateRequest;

  /// No description provided for @errorTrainerNotAccepting.
  ///
  /// In ru, this message translates to:
  /// **'Тренер сейчас не принимает новых клиентов'**
  String get errorTrainerNotAccepting;

  /// No description provided for @errorAlreadyAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Этот тренер уже закреплён за вами'**
  String get errorAlreadyAssigned;

  /// No description provided for @errorRequestNotPending.
  ///
  /// In ru, this message translates to:
  /// **'Заявка уже обработана'**
  String get errorRequestNotPending;

  /// No description provided for @errorSessionOverlap.
  ///
  /// In ru, this message translates to:
  /// **'На это время уже есть тренировка'**
  String get errorSessionOverlap;

  /// No description provided for @errorStartInPast.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время в будущем'**
  String get errorStartInPast;

  /// No description provided for @errorAdminUseWeb.
  ///
  /// In ru, this message translates to:
  /// **'Администраторы работают в веб-панели'**
  String get errorAdminUseWeb;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get saved;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @send.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get send;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get logoutConfirm;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @tabHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get tabHome;

  /// No description provided for @tabMembership.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент'**
  String get tabMembership;

  /// No description provided for @tabTrainers.
  ///
  /// In ru, this message translates to:
  /// **'Тренеры'**
  String get tabTrainers;

  /// No description provided for @tabWorkouts.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки'**
  String get tabWorkouts;

  /// No description provided for @tabProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get tabProfile;

  /// No description provided for @tabRequests.
  ///
  /// In ru, this message translates to:
  /// **'Заявки'**
  String get tabRequests;

  /// No description provided for @tabClients.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get tabClients;

  /// No description provided for @tabSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get tabSchedule;

  /// No description provided for @greetingMorning.
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingDay.
  ///
  /// In ru, this message translates to:
  /// **'Добрый день, {name}'**
  String greetingDay(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер, {name}'**
  String greetingEvening(String name);

  /// No description provided for @membership.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент'**
  String get membership;

  /// No description provided for @noMembership.
  ///
  /// In ru, this message translates to:
  /// **'Нет действующего абонемента'**
  String get noMembership;

  /// No description provided for @noMembershipHint.
  ///
  /// In ru, this message translates to:
  /// **'Оформите абонемент на ресепшене клуба'**
  String get noMembershipHint;

  /// No description provided for @validUntil.
  ///
  /// In ru, this message translates to:
  /// **'Действует до {date}'**
  String validUntil(String date);

  /// No description provided for @startsOn.
  ///
  /// In ru, this message translates to:
  /// **'Начнётся {date}'**
  String startsOn(String date);

  /// No description provided for @daysLeft.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Сегодня последний день} one{Остался {count} день} few{Осталось {count} дня} many{Осталось {count} дней} other{Осталось {count} дня}}'**
  String daysLeft(int count);

  /// No description provided for @daysShort.
  ///
  /// In ru, this message translates to:
  /// **'дн.'**
  String get daysShort;

  /// No description provided for @visitsUsed.
  ///
  /// In ru, this message translates to:
  /// **'Посещения: {used} из {limit}'**
  String visitsUsed(int used, int limit);

  /// No description provided for @unlimited.
  ///
  /// In ru, this message translates to:
  /// **'Безлимит'**
  String get unlimited;

  /// No description provided for @limitedVisits.
  ///
  /// In ru, this message translates to:
  /// **'По посещениям'**
  String get limitedVisits;

  /// No description provided for @statusActive.
  ///
  /// In ru, this message translates to:
  /// **'Активен'**
  String get statusActive;

  /// No description provided for @statusUpcoming.
  ///
  /// In ru, this message translates to:
  /// **'Скоро начнётся'**
  String get statusUpcoming;

  /// No description provided for @statusExpired.
  ///
  /// In ru, this message translates to:
  /// **'Истёк'**
  String get statusExpired;

  /// No description provided for @statusExhausted.
  ///
  /// In ru, this message translates to:
  /// **'Посещения исчерпаны'**
  String get statusExhausted;

  /// No description provided for @statusFrozen.
  ///
  /// In ru, this message translates to:
  /// **'Заморожен'**
  String get statusFrozen;

  /// No description provided for @statusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get statusCancelled;

  /// No description provided for @nextMembership.
  ///
  /// In ru, this message translates to:
  /// **'Следующий абонемент'**
  String get nextMembership;

  /// No description provided for @membershipHistory.
  ///
  /// In ru, this message translates to:
  /// **'История абонементов'**
  String get membershipHistory;

  /// No description provided for @period.
  ///
  /// In ru, this message translates to:
  /// **'Срок действия'**
  String get period;

  /// No description provided for @type.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get type;

  /// No description provided for @nextWorkout.
  ///
  /// In ru, this message translates to:
  /// **'Ближайшая тренировка'**
  String get nextWorkout;

  /// No description provided for @noUpcomingWorkouts.
  ///
  /// In ru, this message translates to:
  /// **'Запланированных тренировок нет'**
  String get noUpcomingWorkouts;

  /// No description provided for @noUpcomingWorkoutsHint.
  ///
  /// In ru, this message translates to:
  /// **'Тренер назначит тренировку, и она появится здесь'**
  String get noUpcomingWorkoutsHint;

  /// No description provided for @yourTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Ваш тренер'**
  String get yourTrainer;

  /// No description provided for @noTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Тренер не выбран'**
  String get noTrainer;

  /// No description provided for @chooseTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать тренера'**
  String get chooseTrainer;

  /// No description provided for @visits.
  ///
  /// In ru, this message translates to:
  /// **'Посещения'**
  String get visits;

  /// No description provided for @visitsThisMonth.
  ///
  /// In ru, this message translates to:
  /// **'В этом месяце'**
  String get visitsThisMonth;

  /// No description provided for @visitsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Всего'**
  String get visitsTotal;

  /// No description provided for @lastVisit.
  ///
  /// In ru, this message translates to:
  /// **'Последнее'**
  String get lastVisit;

  /// No description provided for @pendingRequestTo.
  ///
  /// In ru, this message translates to:
  /// **'Заявка тренеру {name} на рассмотрении'**
  String pendingRequestTo(String name);

  /// No description provided for @trainersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тренеры клуба'**
  String get trainersTitle;

  /// No description provided for @noTrainers.
  ///
  /// In ru, this message translates to:
  /// **'Тренеров пока нет'**
  String get noTrainers;

  /// No description provided for @experienceYears.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Опыт {count} год} few{Опыт {count} года} many{Опыт {count} лет} other{Опыт {count} года}}'**
  String experienceYears(int count);

  /// No description provided for @acceptingClients.
  ///
  /// In ru, this message translates to:
  /// **'Набирает клиентов'**
  String get acceptingClients;

  /// No description provided for @notAcceptingClients.
  ///
  /// In ru, this message translates to:
  /// **'Набор закрыт'**
  String get notAcceptingClients;

  /// No description provided for @about.
  ///
  /// In ru, this message translates to:
  /// **'О тренере'**
  String get about;

  /// No description provided for @sendRequest.
  ///
  /// In ru, this message translates to:
  /// **'Отправить заявку'**
  String get sendRequest;

  /// No description provided for @requestMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Цель тренировок, удобное время (необязательно)'**
  String get requestMessageHint;

  /// No description provided for @requestSent.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отправлена'**
  String get requestSent;

  /// No description provided for @cancelRequest.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заявку'**
  String get cancelRequest;

  /// No description provided for @myRequests.
  ///
  /// In ru, this message translates to:
  /// **'Мои заявки'**
  String get myRequests;

  /// No description provided for @requestPending.
  ///
  /// In ru, this message translates to:
  /// **'На рассмотрении'**
  String get requestPending;

  /// No description provided for @requestAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принята'**
  String get requestAccepted;

  /// No description provided for @requestRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонена'**
  String get requestRejected;

  /// No description provided for @requestCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменена'**
  String get requestCancelled;

  /// No description provided for @trainerComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий: {text}'**
  String trainerComment(String text);

  /// No description provided for @currentTrainerBadge.
  ///
  /// In ru, this message translates to:
  /// **'Ваш тренер'**
  String get currentTrainerBadge;

  /// No description provided for @workoutsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки'**
  String get workoutsTitle;

  /// No description provided for @upcoming.
  ///
  /// In ru, this message translates to:
  /// **'Предстоящие'**
  String get upcoming;

  /// No description provided for @history.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get history;

  /// No description provided for @minutes.
  ///
  /// In ru, this message translates to:
  /// **'{count} мин'**
  String minutes(int count);

  /// No description provided for @withTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Тренер: {name}'**
  String withTrainer(String name);

  /// No description provided for @withClient.
  ///
  /// In ru, this message translates to:
  /// **'Клиент: {name}'**
  String withClient(String name);

  /// No description provided for @sessionScheduled.
  ///
  /// In ru, this message translates to:
  /// **'Запланирована'**
  String get sessionScheduled;

  /// No description provided for @sessionCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Проведена'**
  String get sessionCompleted;

  /// No description provided for @sessionCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменена'**
  String get sessionCancelled;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @personalData.
  ///
  /// In ru, this message translates to:
  /// **'Личные данные'**
  String get personalData;

  /// No description provided for @phoneNotConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Номер не подтверждён'**
  String get phoneNotConfirmed;

  /// No description provided for @phoneChangeHint.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона меняется через администратора клуба'**
  String get phoneChangeHint;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлений нет'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать все'**
  String get markAllRead;

  /// No description provided for @notifTrainerRequestReceived.
  ///
  /// In ru, this message translates to:
  /// **'Новая заявка от клиента'**
  String get notifTrainerRequestReceived;

  /// No description provided for @notifTrainerRequestAccepted.
  ///
  /// In ru, this message translates to:
  /// **'{name} принял(а) вашу заявку'**
  String notifTrainerRequestAccepted(String name);

  /// No description provided for @notifTrainerRequestRejected.
  ///
  /// In ru, this message translates to:
  /// **'{name} отклонил(а) вашу заявку'**
  String notifTrainerRequestRejected(String name);

  /// No description provided for @notifTrainingSessionScheduled.
  ///
  /// In ru, this message translates to:
  /// **'Назначена новая тренировка'**
  String get notifTrainingSessionScheduled;

  /// No description provided for @notifTrainingSessionCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Тренировка отменена'**
  String get notifTrainingSessionCancelled;

  /// No description provided for @notifMembershipAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Оформлен абонемент «{name}»'**
  String notifMembershipAssigned(String name);

  /// No description provided for @trainerCabinet.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет тренера'**
  String get trainerCabinet;

  /// No description provided for @incomingRequests.
  ///
  /// In ru, this message translates to:
  /// **'Входящие заявки'**
  String get incomingRequests;

  /// No description provided for @noRequests.
  ///
  /// In ru, this message translates to:
  /// **'Заявок нет'**
  String get noRequests;

  /// No description provided for @accept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get reject;

  /// No description provided for @commentOptional.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий клиенту (необязательно)'**
  String get commentOptional;

  /// No description provided for @myClients.
  ///
  /// In ru, this message translates to:
  /// **'Мои клиенты'**
  String get myClients;

  /// No description provided for @noClients.
  ///
  /// In ru, this message translates to:
  /// **'Закреплённых клиентов пока нет'**
  String get noClients;

  /// No description provided for @schedule.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get schedule;

  /// No description provided for @noSessions.
  ///
  /// In ru, this message translates to:
  /// **'На ближайшие 30 дней тренировок нет'**
  String get noSessions;

  /// No description provided for @newSession.
  ///
  /// In ru, this message translates to:
  /// **'Новая тренировка'**
  String get newSession;

  /// No description provided for @client.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get client;

  /// No description provided for @date.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get date;

  /// No description provided for @time.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get time;

  /// No description provided for @duration.
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get duration;

  /// No description provided for @notes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get notes;

  /// No description provided for @create.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

  /// No description provided for @markCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Отметить проведённой'**
  String get markCompleted;

  /// No description provided for @cancelSession.
  ///
  /// In ru, this message translates to:
  /// **'Отменить тренировку'**
  String get cancelSession;

  /// No description provided for @specialization.
  ///
  /// In ru, this message translates to:
  /// **'Специализация'**
  String get specialization;

  /// No description provided for @bio.
  ///
  /// In ru, this message translates to:
  /// **'О себе'**
  String get bio;

  /// No description provided for @acceptNewClients.
  ///
  /// In ru, this message translates to:
  /// **'Принимаю новых клиентов'**
  String get acceptNewClients;

  /// No description provided for @lastVisitOn.
  ///
  /// In ru, this message translates to:
  /// **'Последнее посещение: {date}'**
  String lastVisitOn(String date);

  /// No description provided for @noVisitsYet.
  ///
  /// In ru, this message translates to:
  /// **'Посещений ещё не было'**
  String get noVisitsYet;

  /// No description provided for @clientsCount.
  ///
  /// In ru, this message translates to:
  /// **'Клиентов: {count}'**
  String clientsCount(int count);

  /// No description provided for @todayLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get todayLabel;

  /// No description provided for @tomorrowLabel.
  ///
  /// In ru, this message translates to:
  /// **'Завтра'**
  String get tomorrowLabel;

  /// No description provided for @changePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get changePassword;

  /// No description provided for @changePasswordForcedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Придумайте свой пароль'**
  String get changePasswordForcedTitle;

  /// No description provided for @changePasswordForcedText.
  ///
  /// In ru, this message translates to:
  /// **'Вам выдали временный пароль в клубе. Чтобы продолжить, задайте новый пароль, который знаете только вы.'**
  String get changePasswordForcedText;

  /// No description provided for @currentPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get newPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get passwordChanged;

  /// No description provided for @errorInvalidPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль указан неверно'**
  String get errorInvalidPassword;

  /// No description provided for @errorPasswordUnchanged.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль должен отличаться от текущего'**
  String get errorPasswordUnchanged;

  /// No description provided for @errorPasswordChangeRequired.
  ///
  /// In ru, this message translates to:
  /// **'Сначала смените временный пароль'**
  String get errorPasswordChangeRequired;

  /// No description provided for @sessionEnded.
  ///
  /// In ru, this message translates to:
  /// **'Прошла'**
  String get sessionEnded;

  /// No description provided for @workoutsNoTrainerHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите тренера — он сможет назначать вам тренировки'**
  String get workoutsNoTrainerHint;

  /// No description provided for @membershipInactiveWarning.
  ///
  /// In ru, this message translates to:
  /// **'Нет действующего абонемента. Оформите или продлите его на ресепшене клуба.'**
  String get membershipInactiveWarning;

  /// No description provided for @pastWeek.
  ///
  /// In ru, this message translates to:
  /// **'Прошедшие за 7 дней'**
  String get pastWeek;

  /// No description provided for @clientNoActiveMembership.
  ///
  /// In ru, this message translates to:
  /// **'У клиента нет действующего абонемента'**
  String get clientNoActiveMembership;

  /// No description provided for @markResultHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы отметить результат'**
  String get markResultHint;

  /// No description provided for @cancelSessionConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Отменить тренировку?'**
  String get cancelSessionConfirm;

  /// No description provided for @cancelSessionConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Клиент увидит, что тренировка отменена. Вернуть её будет нельзя.'**
  String get cancelSessionConfirmBody;

  /// No description provided for @keepSession.
  ///
  /// In ru, this message translates to:
  /// **'Не отменять'**
  String get keepSession;

  /// No description provided for @sessionMarkedCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Тренировка отмечена проведённой'**
  String get sessionMarkedCompleted;

  /// No description provided for @sessionMarkedCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Тренировка отменена'**
  String get sessionMarkedCancelled;

  /// No description provided for @errorSessionNotScheduled.
  ///
  /// In ru, this message translates to:
  /// **'Тренировка уже отмечена или отменена'**
  String get errorSessionNotScheduled;

  /// No description provided for @errorSessionNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Отметить проведённой можно только после начала тренировки'**
  String get errorSessionNotStarted;

  /// No description provided for @errorNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Запись не найдена или недоступна'**
  String get errorNotFound;

  /// No description provided for @loadMore.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get loadMore;

  /// No description provided for @myMembership.
  ///
  /// In ru, this message translates to:
  /// **'Мой абонемент'**
  String get myMembership;

  /// No description provided for @qrEntry.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get qrEntry;

  /// No description provided for @soon.
  ///
  /// In ru, this message translates to:
  /// **'скоро'**
  String get soon;

  /// No description provided for @statusInactive.
  ///
  /// In ru, this message translates to:
  /// **'Неактивен'**
  String get statusInactive;

  /// No description provided for @noWorkoutsYet.
  ///
  /// In ru, this message translates to:
  /// **'Тренировок пока нет'**
  String get noWorkoutsYet;

  /// No description provided for @workoutsByTrainerHint.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки назначает ваш тренер'**
  String get workoutsByTrainerHint;

  /// No description provided for @chooseTrainerForWorkoutsHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите тренера, чтобы получать тренировки'**
  String get chooseTrainerForWorkoutsHint;

  /// No description provided for @findYourTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Найдите своего тренера'**
  String get findYourTrainer;

  /// No description provided for @withTrainerShort.
  ///
  /// In ru, this message translates to:
  /// **'С тренером {name}'**
  String withTrainerShort(String name);

  /// No description provided for @membershipPlansSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите подходящий тариф'**
  String get membershipPlansSubtitle;

  /// No description provided for @membershipManageSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Управление и история'**
  String get membershipManageSubtitle;

  /// No description provided for @plansInfo.
  ///
  /// In ru, this message translates to:
  /// **'О тарифах'**
  String get plansInfo;

  /// No description provided for @plansInfoText.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы и цены устанавливает клуб. Сейчас абонемент оформляется на ресепшене, онлайн-оплата появится позже.'**
  String get plansInfoText;

  /// No description provided for @monthsShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} мес'**
  String monthsShort(int count);

  /// No description provided for @daysShortCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} дн.'**
  String daysShortCount(int count);

  /// No description provided for @monthsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} месяц} few{{count} месяца} many{{count} месяцев} other{{count} месяца}}'**
  String monthsCount(int count);

  /// No description provided for @daysCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день} few{{count} дня} many{{count} дней} other{{count} дня}}'**
  String daysCount(int count);

  /// No description provided for @visitsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} посещение} few{{count} посещения} many{{count} посещений} other{{count} посещения}}'**
  String visitsCount(int count);

  /// No description provided for @perPeriod.
  ///
  /// In ru, this message translates to:
  /// **'/ {period}'**
  String perPeriod(String period);

  /// No description provided for @currencySum.
  ///
  /// In ru, this message translates to:
  /// **'сум'**
  String get currencySum;

  /// No description provided for @unlimitedVisits.
  ///
  /// In ru, this message translates to:
  /// **'Безлимитные посещения'**
  String get unlimitedVisits;

  /// No description provided for @validForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Действует {period}'**
  String validForPeriod(String period);

  /// No description provided for @paymentMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get paymentMethod;

  /// No description provided for @paymentMethodValue.
  ///
  /// In ru, this message translates to:
  /// **'Банковская карта'**
  String get paymentMethodValue;

  /// No description provided for @totalFor.
  ///
  /// In ru, this message translates to:
  /// **'Итого за {period}'**
  String totalFor(String period);

  /// No description provided for @checkoutPlan.
  ///
  /// In ru, this message translates to:
  /// **'Оформить «{plan}»'**
  String checkoutPlan(String plan);

  /// No description provided for @alsoAtReception.
  ///
  /// In ru, this message translates to:
  /// **'Также можно оформить на ресепшене клуба'**
  String get alsoAtReception;

  /// No description provided for @onlinePaymentSoon.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн-оплата скоро будет доступна. Пока абонемент можно оформить на ресепшене клуба.'**
  String get onlinePaymentSoon;

  /// No description provided for @noPlansTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы пока не опубликованы'**
  String get noPlansTitle;

  /// No description provided for @noPlansHint.
  ///
  /// In ru, this message translates to:
  /// **'Уточните стоимость на ресепшене клуба'**
  String get noPlansHint;

  /// No description provided for @statusExpiring.
  ///
  /// In ru, this message translates to:
  /// **'Скоро истекает'**
  String get statusExpiring;

  /// No description provided for @ofTotal.
  ///
  /// In ru, this message translates to:
  /// **'из {total}'**
  String ofTotal(int total);

  /// No description provided for @validTillLabel.
  ///
  /// In ru, this message translates to:
  /// **'Действует до'**
  String get validTillLabel;

  /// No description provided for @ownerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get ownerLabel;

  /// No description provided for @numberLabel.
  ///
  /// In ru, this message translates to:
  /// **'Номер'**
  String get numberLabel;

  /// No description provided for @showQrPass.
  ///
  /// In ru, this message translates to:
  /// **'Показать QR-пропуск'**
  String get showQrPass;

  /// No description provided for @actionFreeze.
  ///
  /// In ru, this message translates to:
  /// **'Заморозить'**
  String get actionFreeze;

  /// No description provided for @actionRenew.
  ///
  /// In ru, this message translates to:
  /// **'Продлить'**
  String get actionRenew;

  /// No description provided for @actionGuest.
  ///
  /// In ru, this message translates to:
  /// **'Гость'**
  String get actionGuest;

  /// No description provided for @actionChangePlan.
  ///
  /// In ru, this message translates to:
  /// **'Сменить'**
  String get actionChangePlan;

  /// No description provided for @includedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Включено в абонемент'**
  String get includedTitle;

  /// No description provided for @startLabel.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get startLabel;

  /// No description provided for @usedOfLimit.
  ///
  /// In ru, this message translates to:
  /// **'{used} из {limit}'**
  String usedOfLimit(int used, int limit);

  /// No description provided for @historyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся прошлые абонементы'**
  String get historyEmpty;

  /// No description provided for @more.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// No description provided for @menuContract.
  ///
  /// In ru, this message translates to:
  /// **'Договор'**
  String get menuContract;

  /// No description provided for @menuRules.
  ///
  /// In ru, this message translates to:
  /// **'Правила клуба'**
  String get menuRules;

  /// No description provided for @menuSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get menuSupport;

  /// No description provided for @perMonth.
  ///
  /// In ru, this message translates to:
  /// **'/ мес'**
  String get perMonth;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// No description provided for @phoneStatusConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждён'**
  String get phoneStatusConfirmed;

  /// No description provided for @phoneStatusNotConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Не подтверждён'**
  String get phoneStatusNotConfirmed;

  /// No description provided for @phoneChangeHintShort.
  ///
  /// In ru, this message translates to:
  /// **'Номер меняется через администратора клуба'**
  String get phoneChangeHintShort;

  /// No description provided for @statVisits.
  ///
  /// In ru, this message translates to:
  /// **'Посещений'**
  String get statVisits;

  /// No description provided for @memberSince.
  ///
  /// In ru, this message translates to:
  /// **'В клубе с'**
  String get memberSince;

  /// No description provided for @filledOf.
  ///
  /// In ru, this message translates to:
  /// **'{filled} из {total} заполнено'**
  String filledOf(int filled, int total);

  /// No description provided for @addEmail.
  ///
  /// In ru, this message translates to:
  /// **'Добавить email'**
  String get addEmail;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @faceIdLogin.
  ///
  /// In ru, this message translates to:
  /// **'Вход по Face ID'**
  String get faceIdLogin;

  /// No description provided for @logoutAccount.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get logoutAccount;

  /// No description provided for @appVersion.
  ///
  /// In ru, this message translates to:
  /// **'Fitness Formula · версия {version}'**
  String appVersion(String version);

  /// No description provided for @editTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование'**
  String get editTitle;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// No description provided for @changePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сменить фото'**
  String get changePhoto;

  /// No description provided for @photoSoon.
  ///
  /// In ru, this message translates to:
  /// **'Смена фото скоро будет доступна'**
  String get photoSoon;

  /// No description provided for @languageName.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageName;

  /// No description provided for @workoutsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Расписание и история занятий'**
  String get workoutsSubtitle;

  /// No description provided for @openCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get openCalendar;

  /// No description provided for @calendarSoon.
  ///
  /// In ru, this message translates to:
  /// **'Полный календарь скоро будет доступен'**
  String get calendarSoon;

  /// No description provided for @noActiveMembership.
  ///
  /// In ru, this message translates to:
  /// **'Нет действующего абонемента'**
  String get noActiveMembership;

  /// No description provided for @renewAtReception.
  ///
  /// In ru, this message translates to:
  /// **'Продлите на ресепшене'**
  String get renewAtReception;

  /// No description provided for @getMembership.
  ///
  /// In ru, this message translates to:
  /// **'Оформить'**
  String get getMembership;

  /// No description provided for @chatWithTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Написать тренеру'**
  String get chatWithTrainer;

  /// No description provided for @chatSoon.
  ///
  /// In ru, this message translates to:
  /// **'Чат с тренером скоро будет доступен'**
  String get chatSoon;

  /// No description provided for @reschedule.
  ///
  /// In ru, this message translates to:
  /// **'Перенести'**
  String get reschedule;

  /// No description provided for @cancelShort.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get cancelShort;

  /// No description provided for @personalWorkout.
  ///
  /// In ru, this message translates to:
  /// **'Персональная тренировка'**
  String get personalWorkout;

  /// No description provided for @inHours.
  ///
  /// In ru, this message translates to:
  /// **'через {count} ч'**
  String inHours(int count);

  /// No description provided for @inMinutes.
  ///
  /// In ru, this message translates to:
  /// **'через {count} мин'**
  String inMinutes(int count);

  /// No description provided for @happeningNow.
  ///
  /// In ru, this message translates to:
  /// **'Идёт сейчас'**
  String get happeningNow;

  /// No description provided for @bookWorkout.
  ///
  /// In ru, this message translates to:
  /// **'Записаться на тренировку'**
  String get bookWorkout;

  /// No description provided for @noWorkoutsOnDay.
  ///
  /// In ru, this message translates to:
  /// **'В этот день тренировок нет'**
  String get noWorkoutsOnDay;

  /// No description provided for @trainersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} тренер} few{{count} тренера} many{{count} тренеров} other{{count} тренера}} · выберите своего'**
  String trainersCount(int count);

  /// No description provided for @searchTrainersHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени или направлению'**
  String get searchTrainersHint;

  /// No description provided for @clearSearch.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clearSearch;

  /// No description provided for @filters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get filters;

  /// No description provided for @sortTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get sortTitle;

  /// No description provided for @sortByName.
  ///
  /// In ru, this message translates to:
  /// **'По имени'**
  String get sortByName;

  /// No description provided for @sortByExperience.
  ///
  /// In ru, this message translates to:
  /// **'По опыту'**
  String get sortByExperience;

  /// No description provided for @onlyAccepting.
  ///
  /// In ru, this message translates to:
  /// **'Только набирающие клиентов'**
  String get onlyAccepting;

  /// No description provided for @allTrainers.
  ///
  /// In ru, this message translates to:
  /// **'Все тренеры'**
  String get allTrainers;

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Никого не нашли'**
  String get nothingFound;

  /// No description provided for @resetFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get resetFilters;

  /// No description provided for @chooseYourTrainerHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите своего тренера — он составит программу и будет вести ваши тренировки'**
  String get chooseYourTrainerHint;

  /// No description provided for @writeToTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get writeToTrainer;

  /// No description provided for @bookWithTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Записаться'**
  String get bookWithTrainer;

  /// No description provided for @experienceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Опыт'**
  String get experienceLabel;

  /// No description provided for @yearsShort.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} год} few{{count} года} many{{count} лет} other{{count} года}}'**
  String yearsShort(int count);

  /// No description provided for @chooseAsTrainer.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать тренером'**
  String get chooseAsTrainer;

  /// No description provided for @requestExplain.
  ///
  /// In ru, this message translates to:
  /// **'Тренер получит заявку и подтвердит её'**
  String get requestExplain;

  /// No description provided for @clubApp.
  ///
  /// In ru, this message translates to:
  /// **'Клубное приложение'**
  String get clubApp;

  /// No description provided for @phoneNumberHint.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get phoneNumberHint;

  /// No description provided for @showPassword.
  ///
  /// In ru, this message translates to:
  /// **'Показать пароль'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть пароль'**
  String get hidePassword;

  /// No description provided for @forgotPassword.
  ///
  /// In ru, this message translates to:
  /// **'Забыли пароль?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление пароля'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordText.
  ///
  /// In ru, this message translates to:
  /// **'Подойдите на ресепшн клуба: администратор выдаст временный пароль. При входе с ним приложение попросит придумать новый.'**
  String get forgotPasswordText;

  /// No description provided for @orDivider.
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get orDivider;

  /// No description provided for @signInWithFaceId.
  ///
  /// In ru, this message translates to:
  /// **'Войти с Face ID'**
  String get signInWithFaceId;

  /// No description provided for @faceIdSoon.
  ///
  /// In ru, this message translates to:
  /// **'Вход по Face ID скоро будет доступен'**
  String get faceIdSoon;

  /// No description provided for @noAccountQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта?'**
  String get noAccountQuestion;

  /// No description provided for @registerLink.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрируйтесь'**
  String get registerLink;

  /// No description provided for @qrPassTitle.
  ///
  /// In ru, this message translates to:
  /// **'QR-пропуск'**
  String get qrPassTitle;

  /// No description provided for @qrPassHint.
  ///
  /// In ru, this message translates to:
  /// **'Поднесите код к сканеру на ресепшене'**
  String get qrPassHint;

  /// No description provided for @qrRefreshIn.
  ///
  /// In ru, this message translates to:
  /// **'Код обновится через {seconds} с'**
  String qrRefreshIn(int seconds);

  /// No description provided for @qrScreenshotNote.
  ///
  /// In ru, this message translates to:
  /// **'Код меняется каждые 30 секунд — скриншот не подойдёт'**
  String get qrScreenshotNote;

  /// No description provided for @qrOffline.
  ///
  /// In ru, this message translates to:
  /// **'QR-пропуск работает только онлайн. Проверьте подключение к интернету.'**
  String get qrOffline;

  /// No description provided for @qrEntryRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Вход отмечен'**
  String get qrEntryRecorded;

  /// No description provided for @qrEntryRecordedHint.
  ///
  /// In ru, this message translates to:
  /// **'Хорошей тренировки!'**
  String get qrEntryRecordedHint;

  /// No description provided for @qrNotUsable.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент сейчас не действует — на ресепшене во входе откажут'**
  String get qrNotUsable;

  /// No description provided for @freezeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка абонемента'**
  String get freezeTitle;

  /// No description provided for @freezeHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Заморозить абонемент можно здесь или на ресепшене клуба. Срок абонемента продлится на число дней заморозки. Пока абонемент заморожен, вход по нему закрыт.'**
  String get freezeHowTo;

  /// No description provided for @frozenPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Заморожен с {from} по {to}'**
  String frozenPeriod(String from, String to);

  /// No description provided for @freezePlanned.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка запланирована: {from} — {to}'**
  String freezePlanned(String from, String to);

  /// No description provided for @extendedUntil.
  ///
  /// In ru, this message translates to:
  /// **'Срок продлён до {date}'**
  String extendedUntil(String date);

  /// No description provided for @renewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продление абонемента'**
  String get renewTitle;

  /// No description provided for @changePlanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена абонемента'**
  String get changePlanTitle;

  /// No description provided for @renewHint.
  ///
  /// In ru, this message translates to:
  /// **'Новый абонемент начнётся после окончания текущего. Оплатите его на ресепшене — администратор оформит заявку.'**
  String get renewHint;

  /// No description provided for @changeHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите новый план и оплатите его на ресепшене. Администратор оформит абонемент и скажет, с какого дня он действует.'**
  String get changeHint;

  /// No description provided for @requestSentPay.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отправлена. Оплатите абонемент на ресепшене клуба.'**
  String get requestSentPay;

  /// No description provided for @requestKindNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый абонемент'**
  String get requestKindNew;

  /// No description provided for @requestKindRenew.
  ///
  /// In ru, this message translates to:
  /// **'Продление'**
  String get requestKindRenew;

  /// No description provided for @requestKindChange.
  ///
  /// In ru, this message translates to:
  /// **'Смена плана'**
  String get requestKindChange;

  /// No description provided for @pendingPayAtDesk.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает оплаты на ресепшене'**
  String get pendingPayAtDesk;

  /// No description provided for @requestAlreadyPending.
  ///
  /// In ru, this message translates to:
  /// **'У вас уже есть заявка на абонемент'**
  String get requestAlreadyPending;

  /// No description provided for @noOtherPlans.
  ///
  /// In ru, this message translates to:
  /// **'Других планов сейчас нет'**
  String get noOtherPlans;

  /// No description provided for @currentPlanBadge.
  ///
  /// In ru, this message translates to:
  /// **'Текущий'**
  String get currentPlanBadge;

  /// No description provided for @paymentAtDesk.
  ///
  /// In ru, this message translates to:
  /// **'Оплата на ресепшене'**
  String get paymentAtDesk;

  /// No description provided for @requestPayAtDeskHint.
  ///
  /// In ru, this message translates to:
  /// **'Администратор оформит абонемент после оплаты на ресепшене'**
  String get requestPayAtDeskHint;

  /// No description provided for @notifMembershipFrozen.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент заморожен с {from} по {to}'**
  String notifMembershipFrozen(String from, String to);

  /// No description provided for @notifMembershipUnfrozen.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка завершена, абонемент действует до {date}'**
  String notifMembershipUnfrozen(String date);

  /// No description provided for @notifMembershipRequestRejected.
  ///
  /// In ru, this message translates to:
  /// **'Заявка на абонемент «{name}» отклонена'**
  String notifMembershipRequestRejected(String name);

  /// No description provided for @bannerDetails.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get bannerDetails;

  /// No description provided for @bannerVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get bannerVideo;

  /// No description provided for @bannerVideoError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить видео'**
  String get bannerVideoError;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @freezeAction.
  ///
  /// In ru, this message translates to:
  /// **'Заморозить'**
  String get freezeAction;

  /// No description provided for @freezeFrom.
  ///
  /// In ru, this message translates to:
  /// **'Начало заморозки'**
  String get freezeFrom;

  /// No description provided for @freezeDuration.
  ///
  /// In ru, this message translates to:
  /// **'Длительность'**
  String get freezeDuration;

  /// No description provided for @freezeDays.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} день} few{{count} дня} many{{count} дней} other{{count} дня}}'**
  String freezeDays(int count);

  /// No description provided for @freezeLeft.
  ///
  /// In ru, this message translates to:
  /// **'Осталось заморозок: {left} из {total}'**
  String freezeLeft(int left, int total);

  /// No description provided for @freezeRules.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка доступна 3 раза в год, до {days} дней за раз. Срок абонемента продлится на эти дни, а вход по нему на время заморозки закроется.'**
  String freezeRules(int days);

  /// No description provided for @freezeNotAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка доступна только для абонементов от 6 месяцев'**
  String get freezeNotAvailable;

  /// No description provided for @freezeNotAvailableHint.
  ///
  /// In ru, this message translates to:
  /// **'Оформите абонемент на полгода или год — его можно будет замораживать до 3 раз в год.'**
  String get freezeNotAvailableHint;

  /// No description provided for @freezeLimitReached.
  ///
  /// In ru, this message translates to:
  /// **'Вы использовали все заморозки этого абонемента'**
  String get freezeLimitReached;

  /// No description provided for @freezeResult.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент продлится до {date}'**
  String freezeResult(String date);

  /// No description provided for @freezeDone.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент заморожен'**
  String get freezeDone;

  /// No description provided for @freezePlannedDone.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка запланирована'**
  String get freezePlannedDone;

  /// No description provided for @unfreezeAction.
  ///
  /// In ru, this message translates to:
  /// **'Разморозить сегодня'**
  String get unfreezeAction;

  /// No description provided for @cancelFreezeAction.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заморозку'**
  String get cancelFreezeAction;

  /// No description provided for @unfreezeDone.
  ///
  /// In ru, this message translates to:
  /// **'Абонемент разморожен'**
  String get unfreezeDone;

  /// No description provided for @freezeCancelledDone.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка отменена'**
  String get freezeCancelledDone;

  /// No description provided for @unfreezeHint.
  ///
  /// In ru, this message translates to:
  /// **'Неиспользованные дни заморозки вычтутся из срока абонемента.'**
  String get unfreezeHint;

  /// No description provided for @errorFreezeTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Одна заморозка — не дольше 30 дней'**
  String get errorFreezeTooLong;

  /// No description provided for @errorFreezeExists.
  ///
  /// In ru, this message translates to:
  /// **'У абонемента уже есть текущая или запланированная заморозка'**
  String get errorFreezeExists;

  /// No description provided for @errorFreezeInPast.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка не может начинаться в прошлом'**
  String get errorFreezeInPast;

  /// No description provided for @errorFreezeOutside.
  ///
  /// In ru, this message translates to:
  /// **'Заморозка должна начинаться в период действия абонемента'**
  String get errorFreezeOutside;

  /// No description provided for @withoutTrainerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Без тренера'**
  String get withoutTrainerTitle;

  /// No description provided for @withoutTrainerOption.
  ///
  /// In ru, this message translates to:
  /// **'Заниматься без тренера'**
  String get withoutTrainerOption;

  /// No description provided for @withoutTrainerOptionHint.
  ///
  /// In ru, this message translates to:
  /// **'Приходите в зал по QR-пропуску и тренируйтесь самостоятельно. Тренера можно выбрать в любой момент.'**
  String get withoutTrainerOptionHint;

  /// No description provided for @withoutTrainerSelected.
  ///
  /// In ru, this message translates to:
  /// **'Вы занимаетесь без тренера'**
  String get withoutTrainerSelected;

  /// No description provided for @withoutTrainerSelectedHint.
  ///
  /// In ru, this message translates to:
  /// **'Захотите заниматься с тренером — выберите его в списке ниже.'**
  String get withoutTrainerSelectedHint;

  /// No description provided for @withoutTrainerConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Начать без тренера'**
  String get withoutTrainerConfirm;

  /// No description provided for @withoutTrainerCancelsRequest.
  ///
  /// In ru, this message translates to:
  /// **'Заявка тренеру {name} будет отменена.'**
  String withoutTrainerCancelsRequest(String name);

  /// No description provided for @withoutTrainerDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово! Тренируйтесь в своём ритме'**
  String get withoutTrainerDone;

  /// No description provided for @withoutTrainerHome.
  ///
  /// In ru, this message translates to:
  /// **'Самостоятельные тренировки'**
  String get withoutTrainerHome;

  /// No description provided for @soloWorkoutsHint.
  ///
  /// In ru, this message translates to:
  /// **'Вы занимаетесь без тренера — приходите в зал по QR-пропуску. Тренировки с тренером появятся здесь, когда вы его выберете.'**
  String get soloWorkoutsHint;

  /// No description provided for @soloNextWorkoutHint.
  ///
  /// In ru, this message translates to:
  /// **'Приходите в зал в удобное время по QR-пропуску'**
  String get soloNextWorkoutHint;

  /// No description provided for @startWorkout.
  ///
  /// In ru, this message translates to:
  /// **'Начать тренировку'**
  String get startWorkout;

  /// No description provided for @errorTrainerAssigned.
  ///
  /// In ru, this message translates to:
  /// **'У вас уже есть тренер'**
  String get errorTrainerAssigned;

  /// No description provided for @requestSentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заявка отправлена!'**
  String get requestSentTitle;

  /// No description provided for @requestSentBody.
  ///
  /// In ru, this message translates to:
  /// **'{name} получит заявку и ответит в приложении. Чтобы быстрее договориться о первой тренировке, напишите тренеру:'**
  String requestSentBody(String name);

  /// No description provided for @requestSentBodyNoContacts.
  ///
  /// In ru, this message translates to:
  /// **'{name} получит заявку и ответит в приложении — мы пришлём уведомление.'**
  String requestSentBodyNoContacts(String name);

  /// No description provided for @trainerContactsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с тренером'**
  String get trainerContactsTitle;

  /// No description provided for @openLinkFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть ссылку'**
  String get openLinkFailed;

  /// No description provided for @faceAccessTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход по лицу'**
  String get faceAccessTitle;

  /// No description provided for @faceAccessSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Проходите через турникет без телефона и QR-кода'**
  String get faceAccessSubtitle;

  /// No description provided for @faceStatusNone.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото — и проходите в клуб по лицу'**
  String get faceStatusNone;

  /// No description provided for @faceStatusNoneHint.
  ///
  /// In ru, this message translates to:
  /// **'Фото попадёт на терминал у входа. Его видите только вы и администраторы клуба.'**
  String get faceStatusNoneHint;

  /// No description provided for @faceStatusWaitingNoAccess.
  ///
  /// In ru, this message translates to:
  /// **'Фото сохранено. Вход по лицу заработает, когда абонемент будет активен.'**
  String get faceStatusWaitingNoAccess;

  /// No description provided for @faceStatusWaitingNoTerminal.
  ///
  /// In ru, this message translates to:
  /// **'Фото сохранено. Терминал в клубе ещё не подключён — пока проходите по QR-пропуску.'**
  String get faceStatusWaitingNoTerminal;

  /// No description provided for @faceStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'Отправляем на турникет…'**
  String get faceStatusPending;

  /// No description provided for @faceStatusPendingHint.
  ///
  /// In ru, this message translates to:
  /// **'Обычно это занимает несколько секунд. Пока можно пройти по QR-пропуску.'**
  String get faceStatusPendingHint;

  /// No description provided for @faceStatusReady.
  ///
  /// In ru, this message translates to:
  /// **'Проходите в клуб по лицу'**
  String get faceStatusReady;

  /// No description provided for @faceAccessPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Турникет пропустит вас с {from} по {to}'**
  String faceAccessPeriod(String from, String to);

  /// No description provided for @faceStatusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Терминал не распознал лицо на фото — сделайте новое'**
  String get faceStatusRejected;

  /// No description provided for @faceTipsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как сделать фото'**
  String get faceTipsTitle;

  /// No description provided for @faceTipFront.
  ///
  /// In ru, this message translates to:
  /// **'Лицо анфас и целиком в кадре'**
  String get faceTipFront;

  /// No description provided for @faceTipNoAccessories.
  ///
  /// In ru, this message translates to:
  /// **'Без очков, маски и головного убора'**
  String get faceTipNoAccessories;

  /// No description provided for @faceTipLight.
  ///
  /// In ru, this message translates to:
  /// **'Ровный свет, без засветки сзади'**
  String get faceTipLight;

  /// No description provided for @faceConsent.
  ///
  /// In ru, this message translates to:
  /// **'Согласен на обработку фото лица для прохода через турникет клуба'**
  String get faceConsent;

  /// No description provided for @faceConsentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Отметьте согласие на обработку фото'**
  String get faceConsentRequired;

  /// No description provided for @faceTakeSelfie.
  ///
  /// In ru, this message translates to:
  /// **'Сделать селфи'**
  String get faceTakeSelfie;

  /// No description provided for @facePickGallery.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из галереи'**
  String get facePickGallery;

  /// No description provided for @faceSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get faceSend;

  /// No description provided for @faceRetake.
  ///
  /// In ru, this message translates to:
  /// **'Переснять'**
  String get faceRetake;

  /// No description provided for @faceReplace.
  ///
  /// In ru, this message translates to:
  /// **'Заменить фото'**
  String get faceReplace;

  /// No description provided for @faceDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get faceDelete;

  /// No description provided for @faceDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото?'**
  String get faceDeleteTitle;

  /// No description provided for @faceDeleteBody.
  ///
  /// In ru, this message translates to:
  /// **'Вас уберут с турникета, и проходить в клуб нужно будет по QR-пропуску. Фото можно добавить снова в любой момент.'**
  String get faceDeleteBody;

  /// No description provided for @faceDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Фото удалено'**
  String get faceDeleted;

  /// No description provided for @faceUploaded.
  ///
  /// In ru, this message translates to:
  /// **'Фото отправлено'**
  String get faceUploaded;

  /// No description provided for @facePreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте фото'**
  String get facePreviewTitle;

  /// No description provided for @faceErrorTooSmall.
  ///
  /// In ru, this message translates to:
  /// **'Фото слишком маленькое: нужно не меньше 240 точек по каждой стороне'**
  String get faceErrorTooSmall;

  /// No description provided for @faceErrorUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть фото. Выберите другое.'**
  String get faceErrorUnreadable;

  /// No description provided for @faceErrorCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера недоступна. Выберите фото из галереи.'**
  String get faceErrorCamera;

  /// No description provided for @faceErrorPermission.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к камере или фото. Разрешите его в настройках телефона.'**
  String get faceErrorPermission;

  /// No description provided for @errorFaceFormat.
  ///
  /// In ru, this message translates to:
  /// **'Нужна фотография в формате JPEG'**
  String get errorFaceFormat;

  /// No description provided for @errorFaceTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Фото слишком большое: до 200 КБ'**
  String get errorFaceTooLarge;

  /// No description provided for @errorFaceBadSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер фото — от 240 до 4096 точек по каждой стороне'**
  String get errorFaceBadSize;

  /// No description provided for @faceShortNone.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото'**
  String get faceShortNone;

  /// No description provided for @faceShortWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Фото сохранено'**
  String get faceShortWaiting;

  /// No description provided for @faceShortPending.
  ///
  /// In ru, this message translates to:
  /// **'Отправляется на турникет'**
  String get faceShortPending;

  /// No description provided for @faceShortReady.
  ///
  /// In ru, this message translates to:
  /// **'Работает'**
  String get faceShortReady;

  /// No description provided for @faceShortRejected.
  ///
  /// In ru, this message translates to:
  /// **'Нужно новое фото'**
  String get faceShortRejected;

  /// No description provided for @faceHomePromptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в клуб по лицу'**
  String get faceHomePromptTitle;

  /// No description provided for @faceHomePromptBody.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото — турникет узнает вас без телефона'**
  String get faceHomePromptBody;

  /// No description provided for @faceOfferTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото для входа по лицу'**
  String get faceOfferTitle;

  /// No description provided for @faceOfferBody.
  ///
  /// In ru, this message translates to:
  /// **'Когда абонемент начнёт действовать, турникет пропустит вас по лицу — без телефона и QR-кода.'**
  String get faceOfferBody;

  /// No description provided for @faceOfferAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото для входа по лицу'**
  String get faceOfferAdd;

  /// No description provided for @later.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get later;

  /// No description provided for @deleteAccount.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountPointData.
  ///
  /// In ru, this message translates to:
  /// **'Имя, телефон, email, дата рождения и фото лица будут удалены, вход по лицу перестанет работать.'**
  String get deleteAccountPointData;

  /// No description provided for @deleteAccountPointMembership.
  ///
  /// In ru, this message translates to:
  /// **'Оставшиеся дни и посещения по абонементу сгорят, заявки и будущие тренировки отменятся.'**
  String get deleteAccountPointMembership;

  /// No description provided for @deleteAccountPointRecords.
  ///
  /// In ru, this message translates to:
  /// **'Записи об оплатах и посещениях клуб хранит без вашего имени — этого требует учёт.'**
  String get deleteAccountPointRecords;

  /// No description provided for @deleteAccountPointFinal.
  ///
  /// In ru, this message translates to:
  /// **'Отменить удаление нельзя. Номер можно будет зарегистрировать заново.'**
  String get deleteAccountPointFinal;

  /// No description provided for @deleteAccountPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль для подтверждения'**
  String get deleteAccountPasswordLabel;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить навсегда'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountWrongPassword.
  ///
  /// In ru, this message translates to:
  /// **'Неверный пароль'**
  String get deleteAccountWrongPassword;

  /// No description provided for @accountDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт удалён'**
  String get accountDeleted;

  /// No description provided for @privacyPolicy.
  ///
  /// In ru, this message translates to:
  /// **'Политика конфиденциальности'**
  String get privacyPolicy;

  /// Text before the privacy policy link under the register button; the link and the suffix follow without extra spaces.
  ///
  /// In ru, this message translates to:
  /// **'Регистрируясь, вы соглашаетесь с '**
  String get registerConsentPrefix;

  /// No description provided for @registerConsentLink.
  ///
  /// In ru, this message translates to:
  /// **'Политикой конфиденциальности'**
  String get registerConsentLink;

  /// Text right after the privacy policy link (Uzbek case ending); may be empty.
  ///
  /// In ru, this message translates to:
  /// **''**
  String get registerConsentSuffix;

  /// No description provided for @faceDataMore.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее о фото и данных'**
  String get faceDataMore;

  /// No description provided for @foodPhotoUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать фото. Попробуйте другое.'**
  String get foodPhotoUnreadable;

  /// No description provided for @foodPhotoTooSmall.
  ///
  /// In ru, this message translates to:
  /// **'Фото слишком маленькое: нужно не меньше 320 пикселей по короткой стороне.'**
  String get foodPhotoTooSmall;

  /// No description provided for @foodPhotoNoCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера недоступна на этом устройстве. Выберите фото из галереи.'**
  String get foodPhotoNoCamera;

  /// No description provided for @foodPhotoPermission.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к камере или фото. Разрешите его в настройках телефона.'**
  String get foodPhotoPermission;

  /// No description provided for @unitKcal.
  ///
  /// In ru, this message translates to:
  /// **'ккал'**
  String get unitKcal;

  /// No description provided for @unitG.
  ///
  /// In ru, this message translates to:
  /// **'г'**
  String get unitG;

  /// No description provided for @unitMg.
  ///
  /// In ru, this message translates to:
  /// **'мг'**
  String get unitMg;

  /// No description provided for @unitMl.
  ///
  /// In ru, this message translates to:
  /// **'мл'**
  String get unitMl;

  /// No description provided for @protein.
  ///
  /// In ru, this message translates to:
  /// **'Белки'**
  String get protein;

  /// No description provided for @fat.
  ///
  /// In ru, this message translates to:
  /// **'Жиры'**
  String get fat;

  /// No description provided for @carbs.
  ///
  /// In ru, this message translates to:
  /// **'Углеводы'**
  String get carbs;

  /// No description provided for @fiber.
  ///
  /// In ru, this message translates to:
  /// **'Клетчатка'**
  String get fiber;

  /// No description provided for @sugar.
  ///
  /// In ru, this message translates to:
  /// **'Сахар'**
  String get sugar;

  /// No description provided for @saturatedFat.
  ///
  /// In ru, this message translates to:
  /// **'Насыщ. жиры'**
  String get saturatedFat;

  /// No description provided for @sodium.
  ///
  /// In ru, this message translates to:
  /// **'Натрий'**
  String get sodium;

  /// No description provided for @proteinShort.
  ///
  /// In ru, this message translates to:
  /// **'Б'**
  String get proteinShort;

  /// No description provided for @fatShort.
  ///
  /// In ru, this message translates to:
  /// **'Ж'**
  String get fatShort;

  /// No description provided for @carbsShort.
  ///
  /// In ru, this message translates to:
  /// **'У'**
  String get carbsShort;

  /// No description provided for @kcalEatenSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Съедено {kcal} ккал'**
  String kcalEatenSemantics(String kcal);

  /// No description provided for @kcalOfTargetSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Съедено {kcal} из {target} ккал'**
  String kcalOfTargetSemantics(String kcal, String target);

  /// No description provided for @ofKcal.
  ///
  /// In ru, this message translates to:
  /// **'из {target} ккал'**
  String ofKcal(String target);

  /// No description provided for @gramsInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите вес от 1 до 5000'**
  String get gramsInvalid;

  /// No description provided for @amountGrams.
  ///
  /// In ru, this message translates to:
  /// **'Вес, г'**
  String get amountGrams;

  /// No description provided for @amountMl.
  ///
  /// In ru, this message translates to:
  /// **'Объём, мл'**
  String get amountMl;

  /// No description provided for @mealBreakfast.
  ///
  /// In ru, this message translates to:
  /// **'Завтрак'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In ru, this message translates to:
  /// **'Обед'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In ru, this message translates to:
  /// **'Ужин'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In ru, this message translates to:
  /// **'Перекус'**
  String get mealSnack;

  /// No description provided for @foodCatBreakfast.
  ///
  /// In ru, this message translates to:
  /// **'Завтрак'**
  String get foodCatBreakfast;

  /// No description provided for @foodCatLunch.
  ///
  /// In ru, this message translates to:
  /// **'Обед'**
  String get foodCatLunch;

  /// No description provided for @foodCatDinner.
  ///
  /// In ru, this message translates to:
  /// **'Ужин'**
  String get foodCatDinner;

  /// No description provided for @foodCatSnacks.
  ///
  /// In ru, this message translates to:
  /// **'Перекусы'**
  String get foodCatSnacks;

  /// No description provided for @foodCatFruits.
  ///
  /// In ru, this message translates to:
  /// **'Фрукты'**
  String get foodCatFruits;

  /// No description provided for @foodCatVegetables.
  ///
  /// In ru, this message translates to:
  /// **'Овощи'**
  String get foodCatVegetables;

  /// No description provided for @foodCatMeat.
  ///
  /// In ru, this message translates to:
  /// **'Мясо'**
  String get foodCatMeat;

  /// No description provided for @foodCatFish.
  ///
  /// In ru, this message translates to:
  /// **'Рыба'**
  String get foodCatFish;

  /// No description provided for @foodCatDairy.
  ///
  /// In ru, this message translates to:
  /// **'Молочное'**
  String get foodCatDairy;

  /// No description provided for @foodCatBakery.
  ///
  /// In ru, this message translates to:
  /// **'Выпечка'**
  String get foodCatBakery;

  /// No description provided for @foodCatDesserts.
  ///
  /// In ru, this message translates to:
  /// **'Десерты'**
  String get foodCatDesserts;

  /// No description provided for @foodCatFastFood.
  ///
  /// In ru, this message translates to:
  /// **'Фастфуд'**
  String get foodCatFastFood;

  /// No description provided for @foodCatDrinks.
  ///
  /// In ru, this message translates to:
  /// **'Напитки'**
  String get foodCatDrinks;

  /// No description provided for @foodCatPackaged.
  ///
  /// In ru, this message translates to:
  /// **'Упакованные продукты'**
  String get foodCatPackaged;

  /// No description provided for @foodCatTraditional.
  ///
  /// In ru, this message translates to:
  /// **'Национальная кухня'**
  String get foodCatTraditional;

  /// No description provided for @foodCatGrains.
  ///
  /// In ru, this message translates to:
  /// **'Крупы и гарниры'**
  String get foodCatGrains;

  /// No description provided for @foodCatLegumes.
  ///
  /// In ru, this message translates to:
  /// **'Бобовые'**
  String get foodCatLegumes;

  /// No description provided for @foodCatNuts.
  ///
  /// In ru, this message translates to:
  /// **'Орехи и семена'**
  String get foodCatNuts;

  /// No description provided for @foodCatFats.
  ///
  /// In ru, this message translates to:
  /// **'Масла и жиры'**
  String get foodCatFats;

  /// No description provided for @foodCatSauces.
  ///
  /// In ru, this message translates to:
  /// **'Соусы'**
  String get foodCatSauces;

  /// No description provided for @foodCatEggs.
  ///
  /// In ru, this message translates to:
  /// **'Яйца'**
  String get foodCatEggs;

  /// No description provided for @foodCatOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get foodCatOther;

  /// No description provided for @sourceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Этикетка'**
  String get sourceLabel;

  /// No description provided for @sourceRecipe.
  ///
  /// In ru, this message translates to:
  /// **'Рецепт'**
  String get sourceRecipe;

  /// No description provided for @sourceUser.
  ///
  /// In ru, this message translates to:
  /// **'Своё'**
  String get sourceUser;

  /// No description provided for @allergenGluten.
  ///
  /// In ru, this message translates to:
  /// **'Глютен'**
  String get allergenGluten;

  /// No description provided for @allergenMilk.
  ///
  /// In ru, this message translates to:
  /// **'Молоко'**
  String get allergenMilk;

  /// No description provided for @allergenEggs.
  ///
  /// In ru, this message translates to:
  /// **'Яйца'**
  String get allergenEggs;

  /// No description provided for @allergenNuts.
  ///
  /// In ru, this message translates to:
  /// **'Орехи'**
  String get allergenNuts;

  /// No description provided for @allergenPeanuts.
  ///
  /// In ru, this message translates to:
  /// **'Арахис'**
  String get allergenPeanuts;

  /// No description provided for @allergenSesame.
  ///
  /// In ru, this message translates to:
  /// **'Кунжут'**
  String get allergenSesame;

  /// No description provided for @allergenSoy.
  ///
  /// In ru, this message translates to:
  /// **'Соя'**
  String get allergenSoy;

  /// No description provided for @allergenFish.
  ///
  /// In ru, this message translates to:
  /// **'Рыба'**
  String get allergenFish;

  /// No description provided for @allergenShellfish.
  ///
  /// In ru, this message translates to:
  /// **'Ракообразные'**
  String get allergenShellfish;

  /// No description provided for @allergenMolluscs.
  ///
  /// In ru, this message translates to:
  /// **'Моллюски'**
  String get allergenMolluscs;

  /// No description provided for @allergenCelery.
  ///
  /// In ru, this message translates to:
  /// **'Сельдерей'**
  String get allergenCelery;

  /// No description provided for @allergenMustard.
  ///
  /// In ru, this message translates to:
  /// **'Горчица'**
  String get allergenMustard;

  /// No description provided for @allergenSulphites.
  ///
  /// In ru, this message translates to:
  /// **'Сульфиты'**
  String get allergenSulphites;

  /// No description provided for @allergenLupin.
  ///
  /// In ru, this message translates to:
  /// **'Люпин'**
  String get allergenLupin;

  /// No description provided for @goalLose.
  ///
  /// In ru, this message translates to:
  /// **'Снизить вес'**
  String get goalLose;

  /// No description provided for @goalMaintain.
  ///
  /// In ru, this message translates to:
  /// **'Поддерживать вес'**
  String get goalMaintain;

  /// No description provided for @goalGain.
  ///
  /// In ru, this message translates to:
  /// **'Набрать массу'**
  String get goalGain;

  /// No description provided for @activitySedentary.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In ru, this message translates to:
  /// **'Низкая'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In ru, this message translates to:
  /// **'Средняя'**
  String get activityModerate;

  /// No description provided for @activityActive.
  ///
  /// In ru, this message translates to:
  /// **'Высокая'**
  String get activityActive;

  /// No description provided for @activityVeryActive.
  ///
  /// In ru, this message translates to:
  /// **'Очень высокая'**
  String get activityVeryActive;

  /// No description provided for @activitySedentaryHint.
  ///
  /// In ru, this message translates to:
  /// **'Сидячая работа, почти без тренировок'**
  String get activitySedentaryHint;

  /// No description provided for @activityLightHint.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки 1–3 раза в неделю'**
  String get activityLightHint;

  /// No description provided for @activityModerateHint.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки 3–5 раз в неделю'**
  String get activityModerateHint;

  /// No description provided for @activityActiveHint.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки 6–7 раз в неделю'**
  String get activityActiveHint;

  /// No description provided for @activityVeryActiveHint.
  ///
  /// In ru, this message translates to:
  /// **'Тяжёлые тренировки каждый день или физическая работа'**
  String get activityVeryActiveHint;

  /// No description provided for @prepRaw.
  ///
  /// In ru, this message translates to:
  /// **'Сырое'**
  String get prepRaw;

  /// No description provided for @prepBoiled.
  ///
  /// In ru, this message translates to:
  /// **'Варёное'**
  String get prepBoiled;

  /// No description provided for @prepSteamed.
  ///
  /// In ru, this message translates to:
  /// **'На пару'**
  String get prepSteamed;

  /// No description provided for @prepFried.
  ///
  /// In ru, this message translates to:
  /// **'Жареное'**
  String get prepFried;

  /// No description provided for @prepDeepFried.
  ///
  /// In ru, this message translates to:
  /// **'Во фритюре'**
  String get prepDeepFried;

  /// No description provided for @prepBaked.
  ///
  /// In ru, this message translates to:
  /// **'Запечённое'**
  String get prepBaked;

  /// No description provided for @prepGrilled.
  ///
  /// In ru, this message translates to:
  /// **'На гриле / углях'**
  String get prepGrilled;

  /// No description provided for @prepStewed.
  ///
  /// In ru, this message translates to:
  /// **'Тушёное'**
  String get prepStewed;

  /// No description provided for @prepMixed.
  ///
  /// In ru, this message translates to:
  /// **'Смешанный способ'**
  String get prepMixed;

  /// No description provided for @prepUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Способ не определён'**
  String get prepUnknown;

  /// No description provided for @roleMain.
  ///
  /// In ru, this message translates to:
  /// **'Основа'**
  String get roleMain;

  /// No description provided for @roleFat.
  ///
  /// In ru, this message translates to:
  /// **'Масло / жир'**
  String get roleFat;

  /// No description provided for @roleSauce.
  ///
  /// In ru, this message translates to:
  /// **'Соус'**
  String get roleSauce;

  /// No description provided for @roleGarnish.
  ///
  /// In ru, this message translates to:
  /// **'Гарнир'**
  String get roleGarnish;

  /// No description provided for @roleDrink.
  ///
  /// In ru, this message translates to:
  /// **'Напиток'**
  String get roleDrink;

  /// No description provided for @warnLowConfidence.
  ///
  /// In ru, this message translates to:
  /// **'ИИ не уверен в блюде — проверьте название и состав.'**
  String get warnLowConfidence;

  /// No description provided for @warnWeightUncertain.
  ///
  /// In ru, this message translates to:
  /// **'Вес оценён по фото приблизительно — поправьте граммы, если знаете точнее.'**
  String get warnWeightUncertain;

  /// No description provided for @warnUnmatched.
  ///
  /// In ru, this message translates to:
  /// **'Некоторых ингредиентов нет в базе — выберите продукт, иначе калории будут занижены.'**
  String get warnUnmatched;

  /// No description provided for @warnCookingFatMissing.
  ///
  /// In ru, this message translates to:
  /// **'Блюдо жареное, но масла в составе нет. Добавьте его, если готовили на масле.'**
  String get warnCookingFatMissing;

  /// No description provided for @warnMultipleDishes.
  ///
  /// In ru, this message translates to:
  /// **'На фото несколько блюд — выберите нужное или добавьте все.'**
  String get warnMultipleDishes;

  /// No description provided for @imageBlurry.
  ///
  /// In ru, this message translates to:
  /// **'Фото размыто — переснимите при хорошем свете, держа телефон неподвижно.'**
  String get imageBlurry;

  /// No description provided for @imageDark.
  ///
  /// In ru, this message translates to:
  /// **'Фото слишком тёмное — переснимите при хорошем свете.'**
  String get imageDark;

  /// No description provided for @imagePartial.
  ///
  /// In ru, this message translates to:
  /// **'Блюдо видно не полностью — снимите всю тарелку сверху.'**
  String get imagePartial;

  /// No description provided for @weightConfLow.
  ///
  /// In ru, this message translates to:
  /// **'вес примерный'**
  String get weightConfLow;

  /// No description provided for @weightConfMedium.
  ///
  /// In ru, this message translates to:
  /// **'вес оценён'**
  String get weightConfMedium;

  /// No description provided for @weightConfHigh.
  ///
  /// In ru, this message translates to:
  /// **'вес уверенно'**
  String get weightConfHigh;

  /// No description provided for @dataProfile.
  ///
  /// In ru, this message translates to:
  /// **'профиль'**
  String get dataProfile;

  /// No description provided for @dataDiaryDay.
  ///
  /// In ru, this message translates to:
  /// **'дневник'**
  String get dataDiaryDay;

  /// No description provided for @dataPeriod.
  ///
  /// In ru, this message translates to:
  /// **'статистика'**
  String get dataPeriod;

  /// No description provided for @dataScans.
  ///
  /// In ru, this message translates to:
  /// **'сканирования'**
  String get dataScans;

  /// No description provided for @dataTrainings.
  ///
  /// In ru, this message translates to:
  /// **'тренировки'**
  String get dataTrainings;

  /// No description provided for @dataFoodSearch.
  ///
  /// In ru, this message translates to:
  /// **'база продуктов'**
  String get dataFoodSearch;

  /// No description provided for @errAiNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-анализ не подключён в клубе. Дневник, штрихкоды и поиск продуктов работают.'**
  String get errAiNotConfigured;

  /// No description provided for @errAiConsentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Нужно согласие на отправку фото ИИ-сервису.'**
  String get errAiConsentRequired;

  /// No description provided for @errAiUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-сервис сейчас недоступен. Попробуйте через несколько минут.'**
  String get errAiUnavailable;

  /// No description provided for @errAiRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много запросов подряд. Подождите минуту.'**
  String get errAiRateLimited;

  /// No description provided for @errAiQuotaExceeded.
  ///
  /// In ru, this message translates to:
  /// **'Дневной лимит ИИ-анализов исчерпан. Завтра снова можно будет сканировать, а пока добавьте блюдо вручную.'**
  String get errAiQuotaExceeded;

  /// No description provided for @errAiBudgetExceeded.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-анализ временно недоступен в клубе. Добавьте блюдо вручную.'**
  String get errAiBudgetExceeded;

  /// No description provided for @errAiInvalidResponse.
  ///
  /// In ru, this message translates to:
  /// **'ИИ ответил непонятно. Попробуйте ещё раз.'**
  String get errAiInvalidResponse;

  /// No description provided for @errAiRefused.
  ///
  /// In ru, this message translates to:
  /// **'ИИ не смог обработать это фото. Попробуйте другое.'**
  String get errAiRefused;

  /// No description provided for @errPhotoFormat.
  ///
  /// In ru, this message translates to:
  /// **'Неподдерживаемый формат фото.'**
  String get errPhotoFormat;

  /// No description provided for @errPhotoTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Фото слишком большое.'**
  String get errPhotoTooLarge;

  /// No description provided for @errPhotoBadSize.
  ///
  /// In ru, this message translates to:
  /// **'Неподходящий размер фото: нужно от 320 до 4096 пикселей по каждой стороне.'**
  String get errPhotoBadSize;

  /// No description provided for @errBarcodeNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Продукт с таким штрихкодом не найден.'**
  String get errBarcodeNotFound;

  /// No description provided for @errBarcodeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверный штрихкод: нужно от 8 до 14 цифр.'**
  String get errBarcodeInvalid;

  /// No description provided for @errFoodDbUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'База продуктов сейчас недоступна. Попробуйте позже или найдите продукт вручную.'**
  String get errFoodDbUnavailable;

  /// No description provided for @errItemWithoutNutrition.
  ///
  /// In ru, this message translates to:
  /// **'У продукта нет данных о пищевой ценности — выберите продукт из базы.'**
  String get errItemWithoutNutrition;

  /// No description provided for @errProfileIncomplete.
  ///
  /// In ru, this message translates to:
  /// **'Заполните профиль питания, чтобы рассчитать норму.'**
  String get errProfileIncomplete;

  /// No description provided for @errValidation.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте введённые данные.'**
  String get errValidation;

  /// No description provided for @aiProviderUnknown.
  ///
  /// In ru, this message translates to:
  /// **'внешний ИИ-сервис'**
  String get aiProviderUnknown;

  /// No description provided for @aiConsentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Анализ еды с помощью ИИ'**
  String get aiConsentTitle;

  /// No description provided for @aiConsentBody.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы распознать блюдо, прочитать этикетку или ответить на вопрос о питании, приложение отправляет фото и данные о питании в ИИ-сервис {provider}. Калории считает сервер клуба по базе продуктов.'**
  String aiConsentBody(String provider);

  /// No description provided for @aiConsentPointPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Отправляется только фото еды или этикетки — без геолокации и данных камеры.'**
  String get aiConsentPointPhoto;

  /// No description provided for @aiConsentPointNoName.
  ///
  /// In ru, this message translates to:
  /// **'Имя и телефон не передаются. Для советов — только возраст, рост, вес, цель и дневник питания.'**
  String get aiConsentPointNoName;

  /// No description provided for @aiConsentPointDelete.
  ///
  /// In ru, this message translates to:
  /// **'Фото и историю можно удалить в любой момент, согласие — отозвать в настройках питания.'**
  String get aiConsentPointDelete;

  /// No description provided for @aiConsentAgree.
  ///
  /// In ru, this message translates to:
  /// **'Согласен'**
  String get aiConsentAgree;

  /// No description provided for @aiConsentDecline.
  ///
  /// In ru, this message translates to:
  /// **'Не сейчас'**
  String get aiConsentDecline;

  /// No description provided for @nutritionProfileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль питания'**
  String get nutritionProfileTitle;

  /// No description provided for @nutritionProfileSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Цель и параметры для дневной нормы'**
  String get nutritionProfileSubtitle;

  /// No description provided for @nutritionProfileSaved.
  ///
  /// In ru, this message translates to:
  /// **'Профиль питания сохранён'**
  String get nutritionProfileSaved;

  /// No description provided for @nutritionGoal.
  ///
  /// In ru, this message translates to:
  /// **'Цель'**
  String get nutritionGoal;

  /// No description provided for @nutritionGoalPick.
  ///
  /// In ru, this message translates to:
  /// **'Выберите цель — от неё зависит норма калорий.'**
  String get nutritionGoalPick;

  /// No description provided for @aboutYou.
  ///
  /// In ru, this message translates to:
  /// **'О вас'**
  String get aboutYou;

  /// No description provided for @heightCm.
  ///
  /// In ru, this message translates to:
  /// **'Рост, см'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In ru, this message translates to:
  /// **'Вес, кг'**
  String get weightKg;

  /// No description provided for @activityLevel.
  ///
  /// In ru, this message translates to:
  /// **'Активность'**
  String get activityLevel;

  /// No description provided for @customTarget.
  ///
  /// In ru, this message translates to:
  /// **'Своя норма калорий'**
  String get customTarget;

  /// No description provided for @customTargetHint.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно — иначе рассчитаем'**
  String get customTargetHint;

  /// No description provided for @restrictions.
  ///
  /// In ru, this message translates to:
  /// **'Ограничения в питании'**
  String get restrictions;

  /// No description provided for @restrictionsHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: без свинины, вегетарианство, мало соли'**
  String get restrictionsHint;

  /// No description provided for @allergies.
  ///
  /// In ru, this message translates to:
  /// **'Аллергии'**
  String get allergies;

  /// No description provided for @aiAnalysis.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-анализ'**
  String get aiAnalysis;

  /// No description provided for @aiConsentGiven.
  ///
  /// In ru, this message translates to:
  /// **'Согласие на отправку фото ИИ-сервису дано {date}.'**
  String aiConsentGiven(String date);

  /// No description provided for @aiConsentNotGiven.
  ///
  /// In ru, this message translates to:
  /// **'Согласие на отправку фото ИИ-сервису не дано. Без него работают дневник, поиск и штрихкоды.'**
  String get aiConsentNotGiven;

  /// No description provided for @aiConsentRevoke.
  ///
  /// In ru, this message translates to:
  /// **'Отозвать согласие'**
  String get aiConsentRevoke;

  /// No description provided for @aiConsentGive.
  ///
  /// In ru, this message translates to:
  /// **'Дать согласие'**
  String get aiConsentGive;

  /// No description provided for @aiConsentRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Согласие отозвано'**
  String get aiConsentRevoked;

  /// No description provided for @valueRange.
  ///
  /// In ru, this message translates to:
  /// **'Значение от {min} до {max}'**
  String valueRange(String min, String max);

  /// No description provided for @dailyTarget.
  ///
  /// In ru, this message translates to:
  /// **'Дневная норма'**
  String get dailyTarget;

  /// No description provided for @targetCustomNote.
  ///
  /// In ru, this message translates to:
  /// **'Ваша норма калорий; белки, жиры и углеводы рассчитаны от неё.'**
  String get targetCustomNote;

  /// No description provided for @targetMethodNote.
  ///
  /// In ru, this message translates to:
  /// **'Расчёт по формуле Миффлина — Сан Жеора: базовый обмен {bmr} ккал, с учётом активности {tdee} ккал, скорректировано под цель.'**
  String targetMethodNote(String bmr, String tdee);

  /// No description provided for @errScanInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущее фото ещё анализируется. Подождите немного.'**
  String get errScanInProgress;

  /// No description provided for @scanPreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото блюда'**
  String get scanPreviewTitle;

  /// No description provided for @scanPreviewSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте фото и запустите анализ'**
  String get scanPreviewSubtitle;

  /// No description provided for @labelPreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото этикетки'**
  String get labelPreviewTitle;

  /// No description provided for @labelPreviewSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте таблицу пищевой ценности целиком'**
  String get labelPreviewSubtitle;

  /// No description provided for @analyzeFood.
  ///
  /// In ru, this message translates to:
  /// **'Анализировать'**
  String get analyzeFood;

  /// No description provided for @readLabel.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать этикетку'**
  String get readLabel;

  /// No description provided for @labelUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать пищевую ценность на этикетке. Переснимите таблицу крупнее и при хорошем свете.'**
  String get labelUnreadable;

  /// No description provided for @scanHintLabel.
  ///
  /// In ru, this message translates to:
  /// **'Что на фото? (необязательно)'**
  String get scanHintLabel;

  /// No description provided for @scanHintExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: лагман, домашний плов'**
  String get scanHintExample;

  /// No description provided for @retakePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Переснять'**
  String get retakePhoto;

  /// No description provided for @fromGallery.
  ///
  /// In ru, this message translates to:
  /// **'Из галереи'**
  String get fromGallery;

  /// No description provided for @analyzing1.
  ///
  /// In ru, this message translates to:
  /// **'Ищем блюдо на фото…'**
  String get analyzing1;

  /// No description provided for @analyzing2.
  ///
  /// In ru, this message translates to:
  /// **'Определяем ингредиенты…'**
  String get analyzing2;

  /// No description provided for @analyzing3.
  ///
  /// In ru, this message translates to:
  /// **'Оцениваем вес порции…'**
  String get analyzing3;

  /// No description provided for @analyzing4.
  ///
  /// In ru, this message translates to:
  /// **'Считаем калории по базе продуктов…'**
  String get analyzing4;

  /// No description provided for @analyzingLabel1.
  ///
  /// In ru, this message translates to:
  /// **'Читаем этикетку…'**
  String get analyzingLabel1;

  /// No description provided for @analyzingLabel2.
  ///
  /// In ru, this message translates to:
  /// **'Ищем таблицу пищевой ценности…'**
  String get analyzingLabel2;

  /// No description provided for @analyzingLabel3.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем состав и аллергены…'**
  String get analyzingLabel3;

  /// No description provided for @scanResultTitle.
  ///
  /// In ru, this message translates to:
  /// **'Результат'**
  String get scanResultTitle;

  /// No description provided for @scanReused.
  ///
  /// In ru, this message translates to:
  /// **'Это фото уже анализировалось — показан прежний результат.'**
  String get scanReused;

  /// No description provided for @addToDiary.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в дневник'**
  String get addToDiary;

  /// No description provided for @addAllDishes.
  ///
  /// In ru, this message translates to:
  /// **'Добавить все ({count})'**
  String addAllDishes(int count);

  /// No description provided for @addedToDiary.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено в дневник: {meal}'**
  String addedToDiary(String meal);

  /// No description provided for @addedAllToDiary.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Добавлено {count} блюдо} few{Добавлено {count} блюда} many{Добавлено {count} блюд} other{Добавлено {count} блюда}}'**
  String addedAllToDiary(int count);

  /// No description provided for @lastIngredient.
  ///
  /// In ru, this message translates to:
  /// **'В блюде должен остаться хотя бы один ингредиент.'**
  String get lastIngredient;

  /// No description provided for @noFatsToScale.
  ///
  /// In ru, this message translates to:
  /// **'В составе нет масла или соуса.'**
  String get noFatsToScale;

  /// No description provided for @addIngredient.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ингредиент'**
  String get addIngredient;

  /// No description provided for @addIngredientShort.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get addIngredientShort;

  /// No description provided for @pickProductFor.
  ///
  /// In ru, this message translates to:
  /// **'Продукт для «{name}»'**
  String pickProductFor(String name);

  /// No description provided for @dishRenamed.
  ///
  /// In ru, this message translates to:
  /// **'Название сохранено'**
  String get dishRenamed;

  /// No description provided for @renameDish.
  ///
  /// In ru, this message translates to:
  /// **'Название блюда'**
  String get renameDish;

  /// No description provided for @dishName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get dishName;

  /// No description provided for @deleteScanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить сканирование?'**
  String get deleteScanTitle;

  /// No description provided for @deleteScanBody.
  ///
  /// In ru, this message translates to:
  /// **'Фото и результат анализа будут удалены. Записи в дневнике останутся, но без фото.'**
  String get deleteScanBody;

  /// No description provided for @deleteAction.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deleteAction;

  /// No description provided for @clarifyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что на фото?'**
  String get clarifyTitle;

  /// No description provided for @photoUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Фото больше недоступно. Сделайте новое.'**
  String get photoUnavailable;

  /// No description provided for @notFoodTitle.
  ///
  /// In ru, this message translates to:
  /// **'Еда не найдена'**
  String get notFoodTitle;

  /// No description provided for @notFoodBody.
  ///
  /// In ru, this message translates to:
  /// **'На фото не видно еды или напитка. Сфотографируйте блюдо сверху, чтобы оно было целиком в кадре.'**
  String get notFoodBody;

  /// No description provided for @scanFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Анализ не выполнен'**
  String get scanFailedTitle;

  /// No description provided for @scanFailedBody.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-сервис не ответил. Попробуйте ещё раз — это фото сохранено.'**
  String get scanFailedBody;

  /// No description provided for @clarifyNeededTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нужно уточнение'**
  String get clarifyNeededTitle;

  /// No description provided for @clarifyNeededBody.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось уверенно определить блюдо. Напишите, что на фото, или переснимите.'**
  String get clarifyNeededBody;

  /// No description provided for @clarifyName.
  ///
  /// In ru, this message translates to:
  /// **'Уточнить название'**
  String get clarifyName;

  /// No description provided for @kcalRangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'возможно {range} ккал'**
  String kcalRangeLabel(String range);

  /// No description provided for @incompleteData.
  ///
  /// In ru, this message translates to:
  /// **'Неполные данные'**
  String get incompleteData;

  /// No description provided for @possibleAllergens.
  ///
  /// In ru, this message translates to:
  /// **'Возможные аллергены'**
  String get possibleAllergens;

  /// No description provided for @ingredients.
  ///
  /// In ru, this message translates to:
  /// **'Ингредиенты'**
  String get ingredients;

  /// No description provided for @fatLess.
  ///
  /// In ru, this message translates to:
  /// **'Меньше'**
  String get fatLess;

  /// No description provided for @fatMore.
  ///
  /// In ru, this message translates to:
  /// **'Больше'**
  String get fatMore;

  /// No description provided for @fatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Масло и соусы'**
  String get fatTitle;

  /// No description provided for @fatHint.
  ///
  /// In ru, this message translates to:
  /// **'Количество масла и соуса на фото видно хуже всего — поправьте, если знаете, как готовили.'**
  String get fatHint;

  /// No description provided for @mealTypeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приём пищи'**
  String get mealTypeTitle;

  /// No description provided for @calcNote.
  ///
  /// In ru, this message translates to:
  /// **'Калории посчитаны по базе продуктов (USDA, Open Food Facts) по весу каждого ингредиента. Это оценка по фото — точнее будет, если поправить граммы.'**
  String get calcNote;

  /// No description provided for @notInDatabasePick.
  ///
  /// In ru, this message translates to:
  /// **'нет в базе — выбрать продукт'**
  String get notInDatabasePick;

  /// No description provided for @decrease.
  ///
  /// In ru, this message translates to:
  /// **'Меньше'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In ru, this message translates to:
  /// **'Больше'**
  String get increase;

  /// No description provided for @confidenceHigh.
  ///
  /// In ru, this message translates to:
  /// **'Уверенно'**
  String get confidenceHigh;

  /// No description provided for @confidenceMedium.
  ///
  /// In ru, this message translates to:
  /// **'Вероятно'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In ru, this message translates to:
  /// **'Неуверенно'**
  String get confidenceLow;

  /// No description provided for @serving.
  ///
  /// In ru, this message translates to:
  /// **'Порция · {grams} г'**
  String serving(int grams);

  /// No description provided for @package.
  ///
  /// In ru, this message translates to:
  /// **'Упаковка · {grams} г'**
  String package(int grams);

  /// No description provided for @portion.
  ///
  /// In ru, this message translates to:
  /// **'Порция · {grams} г'**
  String portion(int grams);

  /// No description provided for @halfPortion.
  ///
  /// In ru, this message translates to:
  /// **'Полпорции'**
  String get halfPortion;

  /// No description provided for @searchFoodHint.
  ///
  /// In ru, this message translates to:
  /// **'Продукт или блюдо'**
  String get searchFoodHint;

  /// No description provided for @searchFoodStart.
  ///
  /// In ru, this message translates to:
  /// **'Начните вводить название: «плов», «гречка», «кефир»…'**
  String get searchFoodStart;

  /// No description provided for @searchFoodNothing.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашлось. Попробуйте другое название или создайте свой продукт.'**
  String get searchFoodNothing;

  /// No description provided for @traditionalDish.
  ///
  /// In ru, this message translates to:
  /// **'Национальное блюдо'**
  String get traditionalDish;

  /// No description provided for @createOwnProduct.
  ///
  /// In ru, this message translates to:
  /// **'Создать свой продукт'**
  String get createOwnProduct;

  /// No description provided for @createProductSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Пищевая ценность — с упаковки или из рецепта'**
  String get createProductSubtitle;

  /// No description provided for @productCreated.
  ///
  /// In ru, this message translates to:
  /// **'Продукт сохранён'**
  String get productCreated;

  /// No description provided for @productName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get productName;

  /// No description provided for @productBrand.
  ///
  /// In ru, this message translates to:
  /// **'Производитель (необязательно)'**
  String get productBrand;

  /// No description provided for @per100MlSwitch.
  ///
  /// In ru, this message translates to:
  /// **'Это напиток — значения на 100 мл'**
  String get per100MlSwitch;

  /// No description provided for @per100g.
  ///
  /// In ru, this message translates to:
  /// **'На 100 г'**
  String get per100g;

  /// No description provided for @per100Ml.
  ///
  /// In ru, this message translates to:
  /// **'На 100 мл'**
  String get per100Ml;

  /// No description provided for @portionSizes.
  ///
  /// In ru, this message translates to:
  /// **'Размер порции и упаковки'**
  String get portionSizes;

  /// No description provided for @servingSize.
  ///
  /// In ru, this message translates to:
  /// **'Порция'**
  String get servingSize;

  /// No description provided for @packageSize.
  ///
  /// In ru, this message translates to:
  /// **'Упаковка'**
  String get packageSize;

  /// No description provided for @barcodeOptional.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод (необязательно)'**
  String get barcodeOptional;

  /// No description provided for @allergensStated.
  ///
  /// In ru, this message translates to:
  /// **'Аллергены по составу'**
  String get allergensStated;

  /// No description provided for @composition.
  ///
  /// In ru, this message translates to:
  /// **'Состав'**
  String get composition;

  /// No description provided for @howMuchEaten.
  ///
  /// In ru, this message translates to:
  /// **'Сколько съели'**
  String get howMuchEaten;

  /// No description provided for @barcodeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get barcodeTitle;

  /// No description provided for @barcodeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Наведите камеру на штрихкод упаковки'**
  String get barcodeSubtitle;

  /// No description provided for @barcodeCameraUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Камера недоступна. Введите цифры под штрихкодом вручную.'**
  String get barcodeCameraUnavailable;

  /// No description provided for @barcodeManual.
  ///
  /// In ru, this message translates to:
  /// **'Ввести вручную'**
  String get barcodeManual;

  /// No description provided for @barcodeDigits.
  ///
  /// In ru, this message translates to:
  /// **'Цифры под штрихкодом'**
  String get barcodeDigits;

  /// No description provided for @barcodeFind.
  ///
  /// In ru, this message translates to:
  /// **'Найти продукт'**
  String get barcodeFind;

  /// No description provided for @barcodeSourceNote.
  ///
  /// In ru, this message translates to:
  /// **'Продукты ищутся в открытой базе Open Food Facts. Если продукта там нет, сфотографируйте этикетку.'**
  String get barcodeSourceNote;

  /// No description provided for @barcodeNotFoundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продукт не найден'**
  String get barcodeNotFoundTitle;

  /// No description provided for @barcodeNotFoundBody.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкода {code} нет в базе продуктов. Сфотографируйте этикетку с пищевой ценностью или найдите продукт вручную.'**
  String barcodeNotFoundBody(String code);

  /// No description provided for @photoLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографировать этикетку'**
  String get photoLabel;

  /// No description provided for @findManually.
  ///
  /// In ru, this message translates to:
  /// **'Найти вручную'**
  String get findManually;

  /// No description provided for @nutritionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Питание'**
  String get nutritionTitle;

  /// No description provided for @nutritionSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-сканер еды и дневник питания'**
  String get nutritionSubtitle;

  /// No description provided for @scanFood.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать еду'**
  String get scanFood;

  /// No description provided for @scanFoodHint.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте блюдо — ИИ определит состав'**
  String get scanFoodHint;

  /// No description provided for @labelShort.
  ///
  /// In ru, this message translates to:
  /// **'Этикетка'**
  String get labelShort;

  /// No description provided for @scansLeft.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-анализов сегодня: осталось {left} из {total}'**
  String scansLeft(int left, int total);

  /// No description provided for @aiOffInfo.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-анализ фото не подключён в клубе. Добавляйте еду по штрихкоду или вручную — дневник и аналитика работают.'**
  String get aiOffInfo;

  /// No description provided for @addManually.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вручную'**
  String get addManually;

  /// No description provided for @foodDiary.
  ///
  /// In ru, this message translates to:
  /// **'Дневник питания'**
  String get foodDiary;

  /// No description provided for @foodDiaryHint.
  ///
  /// In ru, this message translates to:
  /// **'Завтрак, обед, ужин и перекусы'**
  String get foodDiaryHint;

  /// No description provided for @nutritionAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get nutritionAnalytics;

  /// No description provided for @nutritionAnalyticsHint.
  ///
  /// In ru, this message translates to:
  /// **'Калории и БЖУ за день, неделю, месяц'**
  String get nutritionAnalyticsHint;

  /// No description provided for @consultantTitle.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-консультант'**
  String get consultantTitle;

  /// No description provided for @consultantHint.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы о питании по вашим данным'**
  String get consultantHint;

  /// No description provided for @recentScans.
  ///
  /// In ru, this message translates to:
  /// **'Последние сканирования'**
  String get recentScans;

  /// No description provided for @noScansYet.
  ///
  /// In ru, this message translates to:
  /// **'Сканирований пока нет. Сфотографируйте свою еду — результат появится здесь.'**
  String get noScansYet;

  /// No description provided for @eatenKcal.
  ///
  /// In ru, this message translates to:
  /// **'Съедено {kcal} ккал'**
  String eatenKcal(String kcal);

  /// No description provided for @remainingKcal.
  ///
  /// In ru, this message translates to:
  /// **'Осталось {kcal} ккал'**
  String remainingKcal(String kcal);

  /// No description provided for @overKcal.
  ///
  /// In ru, this message translates to:
  /// **'Больше нормы на {kcal} ккал'**
  String overKcal(String kcal);

  /// No description provided for @noTargetYet.
  ///
  /// In ru, this message translates to:
  /// **'Норма не рассчитана'**
  String get noTargetYet;

  /// No description provided for @setupTarget.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитать дневную норму'**
  String get setupTarget;

  /// No description provided for @statusNeedsClarification.
  ///
  /// In ru, this message translates to:
  /// **'нужно уточнение'**
  String get statusNeedsClarification;

  /// No description provided for @statusNotFood.
  ///
  /// In ru, this message translates to:
  /// **'еда не найдена'**
  String get statusNotFood;

  /// No description provided for @statusFailed.
  ///
  /// In ru, this message translates to:
  /// **'ошибка анализа'**
  String get statusFailed;

  /// No description provided for @unknownDish.
  ///
  /// In ru, this message translates to:
  /// **'Блюдо'**
  String get unknownDish;

  /// No description provided for @inDiary.
  ///
  /// In ru, this message translates to:
  /// **'В дневнике'**
  String get inDiary;

  /// No description provided for @nutritionHomeHint.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте еду — ИИ посчитает калории'**
  String get nutritionHomeHint;

  /// No description provided for @yesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterday;

  /// No description provided for @previousDay.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий день'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In ru, this message translates to:
  /// **'Следующий день'**
  String get nextDay;

  /// No description provided for @addToMeal.
  ///
  /// In ru, this message translates to:
  /// **'Добавить: {meal}'**
  String addToMeal(String meal);

  /// No description provided for @mealEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока ничего — нажмите, чтобы добавить'**
  String get mealEmpty;

  /// No description provided for @addFromSearch.
  ///
  /// In ru, this message translates to:
  /// **'Найти продукт или блюдо'**
  String get addFromSearch;

  /// No description provided for @addFromRecent.
  ///
  /// In ru, this message translates to:
  /// **'Из недавних'**
  String get addFromRecent;

  /// No description provided for @addFromScans.
  ///
  /// In ru, this message translates to:
  /// **'Из истории сканирований'**
  String get addFromScans;

  /// No description provided for @noRecent.
  ///
  /// In ru, this message translates to:
  /// **'Недавних записей пока нет'**
  String get noRecent;

  /// No description provided for @lastItemDeleteEntry.
  ///
  /// In ru, this message translates to:
  /// **'Это последний продукт — удалите запись целиком.'**
  String get lastItemDeleteEntry;

  /// No description provided for @entrySaved.
  ///
  /// In ru, this message translates to:
  /// **'Запись сохранена'**
  String get entrySaved;

  /// No description provided for @entryRepeated.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено ещё раз на сегодня'**
  String get entryRepeated;

  /// No description provided for @deleteEntryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить запись?'**
  String get deleteEntryTitle;

  /// No description provided for @deleteEntryBody.
  ///
  /// In ru, this message translates to:
  /// **'Запись пропадёт из дневника и статистики.'**
  String get deleteEntryBody;

  /// No description provided for @repeatToday.
  ///
  /// In ru, this message translates to:
  /// **'Повторить сегодня'**
  String get repeatToday;

  /// No description provided for @recalcOnSave.
  ///
  /// In ru, this message translates to:
  /// **'Точные значения пересчитаются при сохранении'**
  String get recalcOnSave;

  /// No description provided for @noNutritionData.
  ///
  /// In ru, this message translates to:
  /// **'нет данных о пищевой ценности'**
  String get noNutritionData;

  /// No description provided for @portionSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер порции'**
  String get portionSize;

  /// No description provided for @eatenAt.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get eatenAt;

  /// No description provided for @periodDay.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get periodMonth;

  /// No description provided for @previousPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий период'**
  String get previousPeriod;

  /// No description provided for @nextPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Следующий период'**
  String get nextPeriod;

  /// No description provided for @aiReport.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-отчёт'**
  String get aiReport;

  /// No description provided for @aiReportDay.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт за день'**
  String get aiReportDay;

  /// No description provided for @aiReportWeek.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт за неделю'**
  String get aiReportWeek;

  /// No description provided for @aiReportDayButton.
  ///
  /// In ru, this message translates to:
  /// **'Получить отчёт за день'**
  String get aiReportDayButton;

  /// No description provided for @aiReportWeekButton.
  ///
  /// In ru, this message translates to:
  /// **'Получить отчёт за неделю'**
  String get aiReportWeekButton;

  /// No description provided for @notMedicalAdvice.
  ///
  /// In ru, this message translates to:
  /// **'Это не медицинская рекомендация. При заболеваниях обратитесь к врачу.'**
  String get notMedicalAdvice;

  /// No description provided for @workoutsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} тренировка} few{{count} тренировки} many{{count} тренировок} other{{count} тренировки}}'**
  String workoutsCount(int count);

  /// No description provided for @clubVisit.
  ///
  /// In ru, this message translates to:
  /// **'Посещение клуба'**
  String get clubVisit;

  /// No description provided for @byMeal.
  ///
  /// In ru, this message translates to:
  /// **'По приёмам пищи'**
  String get byMeal;

  /// No description provided for @macroSplit.
  ///
  /// In ru, this message translates to:
  /// **'Доля БЖУ в калориях'**
  String get macroSplit;

  /// No description provided for @averageKcal.
  ///
  /// In ru, this message translates to:
  /// **'ккал в среднем'**
  String get averageKcal;

  /// No description provided for @daysLogged.
  ///
  /// In ru, this message translates to:
  /// **'дней с записями'**
  String get daysLogged;

  /// No description provided for @daysWithinTarget.
  ///
  /// In ru, this message translates to:
  /// **'дней в норме ±10%'**
  String get daysWithinTarget;

  /// No description provided for @caloriesPerDay.
  ///
  /// In ru, this message translates to:
  /// **'Калории по дням'**
  String get caloriesPerDay;

  /// No description provided for @macrosPerDay.
  ///
  /// In ru, this message translates to:
  /// **'Белки, жиры, углеводы по дням'**
  String get macrosPerDay;

  /// No description provided for @averagePerDay.
  ///
  /// In ru, this message translates to:
  /// **'В среднем за день'**
  String get averagePerDay;

  /// No description provided for @chartSemantics.
  ///
  /// In ru, this message translates to:
  /// **'График калорий: дней с записями {days}, в среднем {kcal} ккал'**
  String chartSemantics(int days, String kcal);

  /// No description provided for @legendWithin.
  ///
  /// In ru, this message translates to:
  /// **'в норме'**
  String get legendWithin;

  /// No description provided for @legendOver.
  ///
  /// In ru, this message translates to:
  /// **'больше нормы'**
  String get legendOver;

  /// No description provided for @legendUnder.
  ///
  /// In ru, this message translates to:
  /// **'меньше нормы'**
  String get legendUnder;

  /// No description provided for @legendWorkout.
  ///
  /// In ru, this message translates to:
  /// **'тренировка'**
  String get legendWorkout;

  /// No description provided for @noDataYet.
  ///
  /// In ru, this message translates to:
  /// **'Данных пока нет'**
  String get noDataYet;

  /// No description provided for @periodActivity.
  ///
  /// In ru, this message translates to:
  /// **'За период: тренировок — {workouts}, посещений клуба — {visits}'**
  String periodActivity(int workouts, int visits);

  /// No description provided for @consultantSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Отвечает по вашему дневнику и профилю'**
  String get consultantSubtitle;

  /// No description provided for @consultantIntro.
  ///
  /// In ru, this message translates to:
  /// **'Спросите о своём питании: консультант видит ваш дневник, сканирования, цель и тренировки и отвечает по реальным данным.'**
  String get consultantIntro;

  /// No description provided for @consultantHintInput.
  ///
  /// In ru, this message translates to:
  /// **'Вопрос о питании'**
  String get consultantHintInput;

  /// No description provided for @consultantTyping.
  ///
  /// In ru, this message translates to:
  /// **'Консультант печатает'**
  String get consultantTyping;

  /// No description provided for @basedOn.
  ///
  /// In ru, this message translates to:
  /// **'на основе: {sources}'**
  String basedOn(String sources);

  /// No description provided for @askEatenToday.
  ///
  /// In ru, this message translates to:
  /// **'Сколько калорий я сегодня съел?'**
  String get askEatenToday;

  /// No description provided for @askDinner.
  ///
  /// In ru, this message translates to:
  /// **'Что мне лучше съесть на ужин?'**
  String get askDinner;

  /// No description provided for @askPlov.
  ///
  /// In ru, this message translates to:
  /// **'Можно ли мне сейчас съесть плов?'**
  String get askPlov;

  /// No description provided for @askProteinLeft.
  ///
  /// In ru, this message translates to:
  /// **'Сколько белка мне осталось набрать?'**
  String get askProteinLeft;

  /// No description provided for @askWhyOver.
  ///
  /// In ru, this message translates to:
  /// **'Почему я превышаю норму?'**
  String get askWhyOver;

  /// No description provided for @askCompare.
  ///
  /// In ru, this message translates to:
  /// **'Сравни сегодня со вчера'**
  String get askCompare;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
