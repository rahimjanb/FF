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
