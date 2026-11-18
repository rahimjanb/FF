// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'Fitness Formulasi';

  @override
  String get loginTitle => 'Xush kelibsiz';

  @override
  String get loginSubtitle => 'Telefon raqamingiz orqali kiring';

  @override
  String get registerTitle => 'Ro‘yxatdan o‘tish';

  @override
  String get registerSubtitle => 'Klub mijozi hisobini yarating';

  @override
  String get phone => 'Telefon raqami';

  @override
  String get password => 'Parol';

  @override
  String get confirmPassword => 'Parolni takrorlang';

  @override
  String get firstName => 'Ism';

  @override
  String get lastName => 'Familiya';

  @override
  String get email => 'Email';

  @override
  String get birthDate => 'Tug‘ilgan sana';

  @override
  String get gender => 'Jinsi';

  @override
  String get genderMale => 'Erkak';

  @override
  String get genderFemale => 'Ayol';

  @override
  String get notSpecified => 'Ko‘rsatilmagan';

  @override
  String get signIn => 'Kirish';

  @override
  String get signUp => 'Ro‘yxatdan o‘tish';

  @override
  String get noAccount => 'Hisobingiz yo‘qmi? Ro‘yxatdan o‘ting';

  @override
  String get haveAccount => 'Hisobingiz bormi? Kirish';

  @override
  String get smsNotice =>
      'SMS orqali raqamni tasdiqlash keyingi yangilanishda paydo bo‘ladi.';

  @override
  String get validationRequired => 'Majburiy maydon';

  @override
  String get validationPhone => 'Raqamni +998 90 123 45 67 formatida kiriting';

  @override
  String get validationPassword => 'Kamida 8 ta belgi, harflar va raqamlar';

  @override
  String get validationPasswordMatch => 'Parollar mos kelmadi';

  @override
  String get validationEmail => 'Email noto‘g‘ri';

  @override
  String get errorGeneric => 'Nimadir xato ketdi. Qaytadan urinib ko‘ring.';

  @override
  String get errorNetwork => 'Server bilan aloqa yo‘q';

  @override
  String get errorInvalidCredentials => 'Raqam yoki parol noto‘g‘ri';

  @override
  String get errorAccountLocked =>
      'Juda ko‘p urinish. 15 daqiqadan so‘ng urinib ko‘ring.';

  @override
  String get errorAccountBlocked => 'Hisob bloklangan. Klubga murojaat qiling.';

  @override
  String get errorPhoneTaken => 'Bu raqam allaqachon ro‘yxatdan o‘tgan';

  @override
  String get errorDuplicateRequest =>
      'Bu murabbiyga ariza allaqachon yuborilgan';

  @override
  String get errorTrainerNotAccepting =>
      'Murabbiy hozir yangi mijozlarni qabul qilmayapti';

  @override
  String get errorAlreadyAssigned =>
      'Bu murabbiy allaqachon sizga biriktirilgan';

  @override
  String get errorRequestNotPending => 'Ariza allaqachon ko‘rib chiqilgan';

  @override
  String get errorSessionOverlap => 'Bu vaqtda mashg‘ulot allaqachon bor';

  @override
  String get errorStartInPast => 'Kelajakdagi vaqtni tanlang';

  @override
  String get errorAdminUseWeb => 'Administratorlar veb-panelda ishlaydi';

  @override
  String get retry => 'Qaytadan';

  @override
  String get save => 'Saqlash';

  @override
  String get saved => 'Saqlandi';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get close => 'Yopish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get send => 'Yuborish';

  @override
  String get logout => 'Chiqish';

  @override
  String get logoutConfirm => 'Hisobdan chiqasizmi?';

  @override
  String get language => 'Til';

  @override
  String get tabHome => 'Asosiy';

  @override
  String get tabMembership => 'Abonement';

  @override
  String get tabTrainers => 'Murabbiylar';

  @override
  String get tabWorkouts => 'Mashg‘ulotlar';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabRequests => 'Arizalar';

  @override
  String get tabClients => 'Mijozlar';

  @override
  String get tabSchedule => 'Jadval';

  @override
  String greetingMorning(String name) {
    return 'Xayrli tong, $name';
  }

  @override
  String greetingDay(String name) {
    return 'Xayrli kun, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Xayrli kech, $name';
  }

  @override
  String get membership => 'Abonement';

  @override
  String get noMembership => 'Amaldagi abonement yo‘q';

  @override
  String get noMembershipHint =>
      'Abonementni klub qabulxonasida rasmiylashtiring';

  @override
  String validUntil(String date) {
    return '$date gacha amal qiladi';
  }

  @override
  String startsOn(String date) {
    return '$date dan boshlanadi';
  }

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kun qoldi',
      zero: 'Bugun oxirgi kun',
    );
    return '$_temp0';
  }

  @override
  String get daysShort => 'kun';

  @override
  String visitsUsed(int used, int limit) {
    return 'Tashriflar: $used / $limit';
  }

  @override
  String get unlimited => 'Cheksiz';

  @override
  String get limitedVisits => 'Tashriflar bo‘yicha';

  @override
  String get statusActive => 'Faol';

  @override
  String get statusUpcoming => 'Tez orada boshlanadi';

  @override
  String get statusExpired => 'Muddati tugagan';

  @override
  String get statusExhausted => 'Tashriflar tugagan';

  @override
  String get statusFrozen => 'Muzlatilgan';

  @override
  String get statusCancelled => 'Bekor qilingan';

  @override
  String get nextMembership => 'Keyingi abonement';

  @override
  String get membershipHistory => 'Abonementlar tarixi';

  @override
  String get period => 'Amal qilish muddati';

  @override
  String get type => 'Turi';

  @override
  String get nextWorkout => 'Eng yaqin mashg‘ulot';

  @override
  String get noUpcomingWorkouts => 'Rejalashtirilgan mashg‘ulotlar yo‘q';

  @override
  String get noUpcomingWorkoutsHint =>
      'Murabbiy mashg‘ulot belgilaydi va u shu yerda paydo bo‘ladi';

  @override
  String get yourTrainer => 'Sizning murabbiyingiz';

  @override
  String get noTrainer => 'Murabbiy tanlanmagan';

  @override
  String get chooseTrainer => 'Murabbiy tanlash';

  @override
  String get visits => 'Tashriflar';

  @override
  String get visitsThisMonth => 'Shu oyda';

  @override
  String get visitsTotal => 'Jami';

  @override
  String get lastVisit => 'Oxirgisi';

  @override
  String pendingRequestTo(String name) {
    return '$name murabbiyiga ariza ko‘rib chiqilmoqda';
  }

  @override
  String get trainersTitle => 'Klub murabbiylari';

  @override
  String get noTrainers => 'Hozircha murabbiylar yo‘q';

  @override
  String experienceYears(int count) {
    return 'Tajriba $count yil';
  }

  @override
  String get acceptingClients => 'Mijozlarni qabul qilmoqda';

  @override
  String get notAcceptingClients => 'Qabul yopiq';

  @override
  String get about => 'Murabbiy haqida';

  @override
  String get sendRequest => 'Ariza yuborish';

  @override
  String get requestMessageHint => 'Mashg‘ulot maqsadi, qulay vaqt (ixtiyoriy)';

  @override
  String get requestSent => 'Ariza yuborildi';

  @override
  String get cancelRequest => 'Arizani bekor qilish';

  @override
  String get myRequests => 'Mening arizalarim';

  @override
  String get requestPending => 'Ko‘rib chiqilmoqda';

  @override
  String get requestAccepted => 'Qabul qilindi';

  @override
  String get requestRejected => 'Rad etildi';

  @override
  String get requestCancelled => 'Bekor qilindi';

  @override
  String trainerComment(String text) {
    return 'Izoh: $text';
  }

  @override
  String get currentTrainerBadge => 'Sizning murabbiyingiz';

  @override
  String get workoutsTitle => 'Mashg‘ulotlar';

  @override
  String get upcoming => 'Kelgusi';

  @override
  String get history => 'Tarix';

  @override
  String minutes(int count) {
    return '$count daqiqa';
  }

  @override
  String withTrainer(String name) {
    return 'Murabbiy: $name';
  }

  @override
  String withClient(String name) {
    return 'Mijoz: $name';
  }

  @override
  String get sessionScheduled => 'Rejalashtirilgan';

  @override
  String get sessionCompleted => 'O‘tkazildi';

  @override
  String get sessionCancelled => 'Bekor qilindi';

  @override
  String get profileTitle => 'Profil';

  @override
  String get personalData => 'Shaxsiy ma’lumotlar';

  @override
  String get phoneNotConfirmed => 'Raqam tasdiqlanmagan';

  @override
  String get phoneChangeHint =>
      'Telefon raqami klub administratori orqali o‘zgartiriladi';

  @override
  String get notifications => 'Bildirishnomalar';

  @override
  String get noNotifications => 'Bildirishnomalar yo‘q';

  @override
  String get markAllRead => 'Hammasini o‘qish';

  @override
  String get notifTrainerRequestReceived => 'Mijozdan yangi ariza';

  @override
  String notifTrainerRequestAccepted(String name) {
    return '$name arizangizni qabul qildi';
  }

  @override
  String notifTrainerRequestRejected(String name) {
    return '$name arizangizni rad etdi';
  }

  @override
  String get notifTrainingSessionScheduled => 'Yangi mashg‘ulot belgilandi';

  @override
  String get notifTrainingSessionCancelled => 'Mashg‘ulot bekor qilindi';

  @override
  String notifMembershipAssigned(String name) {
    return '«$name» abonementi rasmiylashtirildi';
  }

  @override
  String get trainerCabinet => 'Murabbiy kabineti';

  @override
  String get incomingRequests => 'Kiruvchi arizalar';

  @override
  String get noRequests => 'Arizalar yo‘q';

  @override
  String get accept => 'Qabul qilish';

  @override
  String get reject => 'Rad etish';

  @override
  String get commentOptional => 'Mijozga izoh (ixtiyoriy)';

  @override
  String get myClients => 'Mening mijozlarim';

  @override
  String get noClients => 'Biriktirilgan mijozlar hozircha yo‘q';

  @override
  String get schedule => 'Jadval';

  @override
  String get noSessions => 'Keyingi 30 kunda mashg‘ulotlar yo‘q';

  @override
  String get newSession => 'Yangi mashg‘ulot';

  @override
  String get client => 'Mijoz';

  @override
  String get date => 'Sana';

  @override
  String get time => 'Vaqt';

  @override
  String get duration => 'Davomiyligi';

  @override
  String get notes => 'Izohlar';

  @override
  String get create => 'Yaratish';

  @override
  String get markCompleted => 'O‘tkazildi deb belgilash';

  @override
  String get cancelSession => 'Mashg‘ulotni bekor qilish';

  @override
  String get specialization => 'Mutaxassislik';

  @override
  String get bio => 'O‘zim haqimda';

  @override
  String get acceptNewClients => 'Yangi mijozlarni qabul qilaman';

  @override
  String lastVisitOn(String date) {
    return 'Oxirgi tashrif: $date';
  }

  @override
  String get noVisitsYet => 'Hali tashriflar bo‘lmagan';

  @override
  String clientsCount(int count) {
    return 'Mijozlar: $count';
  }

  @override
  String get todayLabel => 'Bugun';

  @override
  String get tomorrowLabel => 'Ertaga';

  @override
  String get changePassword => 'Parolni o‘zgartirish';

  @override
  String get changePasswordForcedTitle => 'O‘z parolingizni o‘ylab toping';

  @override
  String get changePasswordForcedText =>
      'Sizga klubda vaqtinchalik parol berilgan. Davom etish uchun faqat o‘zingiz biladigan yangi parol o‘rnating.';

  @override
  String get currentPassword => 'Joriy parol';

  @override
  String get newPassword => 'Yangi parol';

  @override
  String get passwordChanged => 'Parol o‘zgartirildi';

  @override
  String get errorInvalidPassword => 'Joriy parol noto‘g‘ri';

  @override
  String get errorPasswordUnchanged =>
      'Yangi parol joriy paroldan farq qilishi kerak';

  @override
  String get errorPasswordChangeRequired =>
      'Avval vaqtinchalik parolni o‘zgartiring';

  @override
  String get sessionEnded => 'O‘tdi';

  @override
  String get workoutsNoTrainerHint =>
      'Murabbiy tanlang — u sizga mashg‘ulotlar belgilay oladi';

  @override
  String get membershipInactiveWarning =>
      'Amaldagi abonement yo‘q. Uni klub qabulxonasida rasmiylashtiring yoki uzaytiring.';

  @override
  String get pastWeek => 'So‘nggi 7 kundagilar';

  @override
  String get clientNoActiveMembership => 'Mijozda amaldagi abonement yo‘q';

  @override
  String get markResultHint => 'Natijani belgilash uchun bosing';

  @override
  String get cancelSessionConfirm => 'Mashg‘ulot bekor qilinsinmi?';

  @override
  String get cancelSessionConfirmBody =>
      'Mijoz mashg‘ulot bekor qilinganini ko‘radi. Uni qaytarib bo‘lmaydi.';

  @override
  String get keepSession => 'Bekor qilmaslik';

  @override
  String get sessionMarkedCompleted => 'Mashg‘ulot o‘tkazildi deb belgilandi';

  @override
  String get sessionMarkedCancelled => 'Mashg‘ulot bekor qilindi';

  @override
  String get errorSessionNotScheduled =>
      'Mashg‘ulot allaqachon belgilangan yoki bekor qilingan';

  @override
  String get errorSessionNotStarted =>
      'O‘tkazildi deb faqat mashg‘ulot boshlangandan keyin belgilash mumkin';

  @override
  String get errorNotFound => 'Yozuv topilmadi yoki mavjud emas';

  @override
  String get loadMore => 'Yana ko‘rsatish';

  @override
  String get myMembership => 'Abonementim';

  @override
  String get qrEntry => 'Kirish';

  @override
  String get soon => 'tez orada';

  @override
  String get statusInactive => 'Faol emas';

  @override
  String get noWorkoutsYet => 'Hozircha mashg‘ulotlar yo‘q';

  @override
  String get workoutsByTrainerHint => 'Mashg‘ulotlarni treneringiz belgilaydi';

  @override
  String get chooseTrainerForWorkoutsHint =>
      'Mashg‘ulot olish uchun trener tanlang';

  @override
  String get findYourTrainer => 'O‘z treneringizni toping';

  @override
  String withTrainerShort(String name) {
    return 'Trener: $name';
  }

  @override
  String get membershipPlansSubtitle => 'Mos tarifni tanlang';

  @override
  String get membershipManageSubtitle => 'Boshqaruv va tarix';

  @override
  String get plansInfo => 'Tariflar haqida';

  @override
  String get plansInfoText =>
      'Tariflar va narxlarni klub belgilaydi. Hozircha abonement qabulxonada rasmiylashtiriladi, onlayn to‘lov keyinroq qo‘shiladi.';

  @override
  String monthsShort(int count) {
    return '$count oy';
  }

  @override
  String daysShortCount(int count) {
    return '$count kun';
  }

  @override
  String monthsCount(int count) {
    return '$count oy';
  }

  @override
  String daysCount(int count) {
    return '$count kun';
  }

  @override
  String visitsCount(int count) {
    return '$count ta tashrif';
  }

  @override
  String perPeriod(String period) {
    return '/ $period';
  }

  @override
  String get currencySum => 'so‘m';

  @override
  String get unlimitedVisits => 'Cheksiz tashriflar';

  @override
  String validForPeriod(String period) {
    return '$period amal qiladi';
  }

  @override
  String get paymentMethod => 'To‘lov usuli';

  @override
  String get paymentMethodValue => 'Bank kartasi';

  @override
  String totalFor(String period) {
    return 'Jami, $period';
  }

  @override
  String checkoutPlan(String plan) {
    return '«$plan» ni rasmiylashtirish';
  }

  @override
  String get alsoAtReception =>
      'Klub qabulxonasida ham rasmiylashtirish mumkin';

  @override
  String get onlinePaymentSoon =>
      'Onlayn to‘lov tez orada ishga tushadi. Hozircha abonementni klub qabulxonasida rasmiylashtirish mumkin.';

  @override
  String get noPlansTitle => 'Tariflar hali e’lon qilinmagan';

  @override
  String get noPlansHint => 'Narxni klub qabulxonasidan so‘rang';

  @override
  String get statusExpiring => 'Tez orada tugaydi';

  @override
  String ofTotal(int total) {
    return '$total dan';
  }

  @override
  String get validTillLabel => 'Amal qiladi';

  @override
  String get ownerLabel => 'Egasi';

  @override
  String get numberLabel => 'Raqami';

  @override
  String get showQrPass => 'QR-ruxsatnoma';

  @override
  String get actionFreeze => 'Muzlatish';

  @override
  String get actionRenew => 'Uzaytirish';

  @override
  String get actionGuest => 'Mehmon';

  @override
  String get actionChangePlan => 'Almashtirish';

  @override
  String get includedTitle => 'Abonement tarkibi';

  @override
  String get startLabel => 'Boshlanishi';

  @override
  String usedOfLimit(int used, int limit) {
    return '$used / $limit';
  }

  @override
  String get historyEmpty => 'Bu yerda oldingi abonementlar paydo bo‘ladi';

  @override
  String get more => 'Yana';

  @override
  String get menuContract => 'Shartnoma';

  @override
  String get menuRules => 'Klub qoidalari';

  @override
  String get menuSupport => 'Yordam';

  @override
  String get perMonth => '/ oy';

  @override
  String get editProfile => 'Profilni tahrirlash';

  @override
  String get phoneStatusConfirmed => 'Tasdiqlangan';

  @override
  String get phoneStatusNotConfirmed => 'Tasdiqlanmagan';

  @override
  String get phoneChangeHintShort =>
      'Raqam klub administratori orqali o‘zgartiriladi';

  @override
  String get statVisits => 'Tashriflar';

  @override
  String get memberSince => 'Klubda';

  @override
  String filledOf(int filled, int total) {
    return '$filled / $total to‘ldirilgan';
  }

  @override
  String get addEmail => 'Email qo‘shish';

  @override
  String get settings => 'Sozlamalar';

  @override
  String get faceIdLogin => 'Face ID orqali kirish';

  @override
  String get logoutAccount => 'Akkauntdan chiqish';

  @override
  String appVersion(String version) {
    return 'Fitness Formula · versiya $version';
  }

  @override
  String get editTitle => 'Tahrirlash';

  @override
  String get done => 'Tayyor';

  @override
  String get changePhoto => 'Rasmni almashtirish';

  @override
  String get photoSoon => 'Rasmni almashtirish tez orada qo‘shiladi';

  @override
  String get languageName => 'O‘zbekcha';

  @override
  String get workoutsSubtitle => 'Mashg‘ulotlar jadvali va tarixi';

  @override
  String get openCalendar => 'Kalendar';

  @override
  String get calendarSoon => 'To‘liq kalendar tez orada qo‘shiladi';

  @override
  String get noActiveMembership => 'Amaldagi abonement yo‘q';

  @override
  String get renewAtReception => 'Qabulxonada uzaytiring';

  @override
  String get getMembership => 'Rasmiylashtirish';

  @override
  String get chatWithTrainer => 'Murabbiyga yozish';

  @override
  String get chatSoon => 'Murabbiy bilan chat tez orada qo‘shiladi';

  @override
  String get reschedule => 'Ko‘chirish';

  @override
  String get cancelShort => 'Bekor qilish';

  @override
  String get personalWorkout => 'Shaxsiy mashg‘ulot';

  @override
  String inHours(int count) {
    return '$count soatdan keyin';
  }

  @override
  String inMinutes(int count) {
    return '$count daqiqadan keyin';
  }

  @override
  String get happeningNow => 'Hozir davom etmoqda';

  @override
  String get bookWorkout => 'Mashg‘ulotga yozilish';

  @override
  String get noWorkoutsOnDay => 'Bu kunda mashg‘ulot yo‘q';

  @override
  String trainersCount(int count) {
    return '$count ta murabbiy · o‘zingiznikini tanlang';
  }

  @override
  String get searchTrainersHint => 'Ism yoki yo‘nalish bo‘yicha qidirish';

  @override
  String get clearSearch => 'Tozalash';

  @override
  String get filters => 'Filtrlar';

  @override
  String get sortTitle => 'Saralash';

  @override
  String get sortByName => 'Ism bo‘yicha';

  @override
  String get sortByExperience => 'Tajriba bo‘yicha';

  @override
  String get onlyAccepting => 'Faqat mijoz qabul qilayotganlar';

  @override
  String get allTrainers => 'Barcha murabbiylar';

  @override
  String get nothingFound => 'Hech kim topilmadi';

  @override
  String get resetFilters => 'Filtrlarni tozalash';

  @override
  String get chooseYourTrainerHint =>
      'O‘z murabbiyingizni tanlang — u dastur tuzadi va mashg‘ulotlaringizni olib boradi';

  @override
  String get writeToTrainer => 'Yozish';

  @override
  String get bookWithTrainer => 'Yozilish';

  @override
  String get experienceLabel => 'Tajriba';

  @override
  String yearsShort(int count) {
    return '$count yil';
  }

  @override
  String get chooseAsTrainer => 'Murabbiy sifatida tanlash';

  @override
  String get requestExplain => 'Murabbiy arizani oladi va tasdiqlaydi';

  @override
  String get clubApp => 'Klub ilovasi';

  @override
  String get phoneNumberHint => 'Telefon raqami';

  @override
  String get showPassword => 'Parolni ko‘rsatish';

  @override
  String get hidePassword => 'Parolni yashirish';

  @override
  String get forgotPassword => 'Parolni unutdingizmi?';

  @override
  String get forgotPasswordTitle => 'Parolni tiklash';

  @override
  String get forgotPasswordText =>
      'Klub resepshniga murojaat qiling: administrator vaqtinchalik parol beradi. U bilan kirganingizda ilova yangi parol o‘ylab topishni so‘raydi.';

  @override
  String get orDivider => 'yoki';

  @override
  String get signInWithFaceId => 'Face ID bilan kirish';

  @override
  String get faceIdSoon => 'Face ID orqali kirish tez orada ishga tushadi';

  @override
  String get noAccountQuestion => 'Hisobingiz yo‘qmi?';

  @override
  String get registerLink => 'Ro‘yxatdan o‘ting';

  @override
  String get qrPassTitle => 'QR-ruxsatnoma';

  @override
  String get qrPassHint => 'Kodni resepshndagi skanerga tuting';

  @override
  String qrRefreshIn(int seconds) {
    return 'Kod $seconds soniyadan keyin yangilanadi';
  }

  @override
  String get qrScreenshotNote =>
      'Kod har 30 soniyada o‘zgaradi — skrinshot ishlamaydi';

  @override
  String get qrOffline =>
      'QR-ruxsatnoma faqat internet orqali ishlaydi. Internetga ulanishni tekshiring.';

  @override
  String get qrEntryRecorded => 'Kirish qayd etildi';

  @override
  String get qrEntryRecordedHint => 'Yaxshi mashg‘ulot!';

  @override
  String get qrNotUsable =>
      'Abonement hozir amal qilmaydi — resepshnda kirishga ruxsat berilmaydi';

  @override
  String get freezeTitle => 'Abonementni muzlatish';

  @override
  String get freezeHowTo =>
      'Abonementni shu yerda yoki klub resepshnida muzlatish mumkin. Abonement muddati muzlatilgan kunlar soniga uzayadi. Abonement muzlatilgan paytda u bilan kirish yopiq.';

  @override
  String frozenPeriod(String from, String to) {
    return '$from dan $to gacha muzlatilgan';
  }

  @override
  String freezePlanned(String from, String to) {
    return 'Muzlatish rejalashtirilgan: $from — $to';
  }

  @override
  String extendedUntil(String date) {
    return 'Muddat $date gacha uzaytirildi';
  }

  @override
  String get renewTitle => 'Abonementni uzaytirish';

  @override
  String get changePlanTitle => 'Abonementni almashtirish';

  @override
  String get renewHint =>
      'Yangi abonement joriysi tugagandan keyin boshlanadi. Resepshnda to‘lang — administrator arizani rasmiylashtiradi.';

  @override
  String get changeHint =>
      'Yangi tarifni tanlang va resepshnda to‘lang. Administrator abonementni rasmiylashtiradi va qaysi kundan amal qilishini aytadi.';

  @override
  String get requestSentPay =>
      'Ariza yuborildi. Abonement uchun klub resepshnida to‘lang.';

  @override
  String get requestKindNew => 'Yangi abonement';

  @override
  String get requestKindRenew => 'Uzaytirish';

  @override
  String get requestKindChange => 'Tarifni almashtirish';

  @override
  String get pendingPayAtDesk => 'Resepshnda to‘lov kutilmoqda';

  @override
  String get requestAlreadyPending => 'Sizda allaqachon abonement arizasi bor';

  @override
  String get noOtherPlans => 'Hozircha boshqa tariflar yo‘q';

  @override
  String get currentPlanBadge => 'Joriy';

  @override
  String get paymentAtDesk => 'Resepshnda to‘lov';

  @override
  String get requestPayAtDeskHint =>
      'Administrator resepshnda to‘lovdan keyin abonementni rasmiylashtiradi';

  @override
  String notifMembershipFrozen(String from, String to) {
    return 'Abonement $from dan $to gacha muzlatildi';
  }

  @override
  String notifMembershipUnfrozen(String date) {
    return 'Muzlatish tugadi, abonement $date gacha amal qiladi';
  }

  @override
  String notifMembershipRequestRejected(String name) {
    return '«$name» abonementi uchun ariza rad etildi';
  }

  @override
  String get bannerDetails => 'Batafsil';

  @override
  String get bannerVideo => 'Video';

  @override
  String get bannerVideoError => 'Videoni yuklab bo‘lmadi';

  @override
  String get back => 'Orqaga';

  @override
  String get freezeAction => 'Muzlatish';

  @override
  String get freezeFrom => 'Muzlatish boshlanishi';

  @override
  String get freezeDuration => 'Davomiyligi';

  @override
  String freezeDays(int count) {
    return '$count kun';
  }

  @override
  String freezeLeft(int left, int total) {
    return 'Qolgan muzlatishlar: $left / $total';
  }

  @override
  String freezeRules(int days) {
    return 'Muzlatish yiliga 3 marta, har safar $days kungacha. Abonement muddati shu kunlarga uzayadi, muzlatish vaqtida u bilan kirish yopiladi.';
  }

  @override
  String get freezeNotAvailable =>
      'Muzlatish faqat 6 oy va undan uzoq abonementlar uchun';

  @override
  String get freezeNotAvailableHint =>
      'Yarim yillik yoki yillik abonement oling — uni yiliga 3 martagacha muzlatish mumkin bo‘ladi.';

  @override
  String get freezeLimitReached =>
      'Ushbu abonementning barcha muzlatishlaridan foydalandingiz';

  @override
  String freezeResult(String date) {
    return 'Abonement $date gacha amal qiladi';
  }

  @override
  String get freezeDone => 'Abonement muzlatildi';

  @override
  String get freezePlannedDone => 'Muzlatish rejalashtirildi';

  @override
  String get unfreezeAction => 'Bugun muzlatishdan chiqarish';

  @override
  String get cancelFreezeAction => 'Muzlatishni bekor qilish';

  @override
  String get unfreezeDone => 'Abonement muzlatishdan chiqarildi';

  @override
  String get freezeCancelledDone => 'Muzlatish bekor qilindi';

  @override
  String get unfreezeHint =>
      'Foydalanilmagan muzlatish kunlari abonement muddatidan ayiriladi.';

  @override
  String get errorFreezeTooLong => 'Bitta muzlatish 30 kundan oshmasligi kerak';

  @override
  String get errorFreezeExists =>
      'Abonementda allaqachon joriy yoki rejalashtirilgan muzlatish bor';

  @override
  String get errorFreezeInPast =>
      'Muzlatish o‘tgan kundan boshlanishi mumkin emas';

  @override
  String get errorFreezeOutside =>
      'Muzlatish abonement amal qilish davrida boshlanishi kerak';

  @override
  String get withoutTrainerTitle => 'Murabbiysiz';

  @override
  String get withoutTrainerOption => 'Murabbiysiz shug‘ullanish';

  @override
  String get withoutTrainerOptionHint =>
      'Zalga QR-ruxsatnoma bilan keling va mustaqil shug‘ullaning. Murabbiyni istalgan vaqtda tanlash mumkin.';

  @override
  String get withoutTrainerSelected => 'Siz murabbiysiz shug‘ullanyapsiz';

  @override
  String get withoutTrainerSelectedHint =>
      'Murabbiy bilan shug‘ullanmoqchi bo‘lsangiz, uni quyidagi ro‘yxatdan tanlang.';

  @override
  String get withoutTrainerConfirm => 'Murabbiysiz boshlash';

  @override
  String withoutTrainerCancelsRequest(String name) {
    return '$name murabbiyiga yuborilgan ariza bekor qilinadi.';
  }

  @override
  String get withoutTrainerDone => 'Tayyor! O‘z suratingizda shug‘ullaning';

  @override
  String get withoutTrainerHome => 'Mustaqil mashg‘ulotlar';

  @override
  String get soloWorkoutsHint =>
      'Siz murabbiysiz shug‘ullanyapsiz — zalga QR-ruxsatnoma bilan keling. Murabbiy tanlaganingizda mashg‘ulotlar shu yerda paydo bo‘ladi.';

  @override
  String get soloNextWorkoutHint =>
      'Zalga qulay vaqtda QR-ruxsatnoma bilan keling';

  @override
  String get startWorkout => 'Mashg‘ulotni boshlash';

  @override
  String get errorTrainerAssigned => 'Sizda allaqachon murabbiy bor';

  @override
  String get requestSentTitle => 'Ariza yuborildi!';

  @override
  String requestSentBody(String name) {
    return '$name arizani oladi va ilovada javob beradi. Birinchi mashg‘ulotni tezroq kelishib olish uchun murabbiyga yozing:';
  }

  @override
  String requestSentBodyNoContacts(String name) {
    return '$name arizani oladi va ilovada javob beradi — biz bildirishnoma yuboramiz.';
  }

  @override
  String get trainerContactsTitle => 'Murabbiy bilan bog‘lanish';

  @override
  String get openLinkFailed => 'Havolani ochib bo‘lmadi';

  @override
  String get faceAccessTitle => 'Yuz orqali kirish';

  @override
  String get faceAccessSubtitle => 'Turniketdan telefon va QR-kodsiz o‘ting';

  @override
  String get faceStatusNone => 'Rasm qo‘shing — klubga yuzingiz orqali kiring';

  @override
  String get faceStatusNoneHint =>
      'Rasm kirishdagi terminalga yuboriladi. Uni faqat siz va klub administratorlari ko‘radi.';

  @override
  String get faceStatusWaitingNoAccess =>
      'Rasm saqlandi. Yuz orqali kirish abonement faol bo‘lganda ishlaydi.';

  @override
  String get faceStatusWaitingNoTerminal =>
      'Rasm saqlandi. Klubdagi terminal hali ulanmagan — hozircha QR-ruxsatnoma bilan kiring.';

  @override
  String get faceStatusPending => 'Turniketga yuborilmoqda…';

  @override
  String get faceStatusPendingHint =>
      'Odatda bu bir necha soniya davom etadi. Hozircha QR-ruxsatnoma bilan kirish mumkin.';

  @override
  String get faceStatusReady => 'Klubga yuzingiz orqali kiring';

  @override
  String faceAccessPeriod(String from, String to) {
    return 'Turniket sizni $from dan $to gacha o‘tkazadi';
  }

  @override
  String get faceStatusRejected =>
      'Terminal rasmdagi yuzni aniqlay olmadi — yangisini oling';

  @override
  String get faceTipsTitle => 'Rasmni qanday olish kerak';

  @override
  String get faceTipFront => 'Yuz to‘g‘ridan va to‘liq kadrda';

  @override
  String get faceTipNoAccessories => 'Ko‘zoynak, niqob va bosh kiyimisiz';

  @override
  String get faceTipLight => 'Bir tekis yorug‘lik, orqadan yorug‘lik tushmasin';

  @override
  String get faceConsent =>
      'Klub turniketidan o‘tish uchun yuz rasmimga ishlov berilishiga roziman';

  @override
  String get faceConsentRequired =>
      'Rasmga ishlov berishga roziligingizni belgilang';

  @override
  String get faceTakeSelfie => 'Selfi olish';

  @override
  String get facePickGallery => 'Galereyadan tanlash';

  @override
  String get faceSend => 'Yuborish';

  @override
  String get faceRetake => 'Qayta olish';

  @override
  String get faceReplace => 'Rasmni almashtirish';

  @override
  String get faceDelete => 'Rasmni o‘chirish';

  @override
  String get faceDeleteTitle => 'Rasm o‘chirilsinmi?';

  @override
  String get faceDeleteBody =>
      'Siz turniketdan olib tashlanasiz va klubga QR-ruxsatnoma bilan kirishingiz kerak bo‘ladi. Rasmni istalgan vaqtda qayta qo‘shish mumkin.';

  @override
  String get faceDeleted => 'Rasm o‘chirildi';

  @override
  String get faceUploaded => 'Rasm yuborildi';

  @override
  String get facePreviewTitle => 'Rasmni tekshiring';

  @override
  String get faceErrorTooSmall =>
      'Rasm juda kichik: har bir tomoni kamida 240 nuqta bo‘lishi kerak';

  @override
  String get faceErrorUnreadable =>
      'Rasmni ochib bo‘lmadi. Boshqasini tanlang.';

  @override
  String get faceErrorCamera => 'Kamera mavjud emas. Galereyadan rasm tanlang.';

  @override
  String get faceErrorPermission =>
      'Kamera yoki rasmlarga ruxsat yo‘q. Telefon sozlamalarida ruxsat bering.';

  @override
  String get errorFaceFormat => 'JPEG formatidagi rasm kerak';

  @override
  String get errorFaceTooLarge => 'Rasm juda katta: 200 KB gacha';

  @override
  String get errorFaceBadSize =>
      'Rasm o‘lchami — har bir tomoni 240 dan 4096 nuqtagacha';

  @override
  String get faceShortNone => 'Rasm qo‘shing';

  @override
  String get faceShortWaiting => 'Rasm saqlandi';

  @override
  String get faceShortPending => 'Turniketga yuborilmoqda';

  @override
  String get faceShortReady => 'Ishlayapti';

  @override
  String get faceShortRejected => 'Yangi rasm kerak';

  @override
  String get faceHomePromptTitle => 'Klubga yuz orqali kirish';

  @override
  String get faceHomePromptBody =>
      'Rasm qo‘shing — turniket sizni telefonsiz taniydi';

  @override
  String get faceOfferTitle => 'Yuz orqali kirish uchun rasm qo‘shing';

  @override
  String get faceOfferBody =>
      'Abonement kuchga kirgach, turniket sizni yuzingiz orqali o‘tkazadi — telefon va QR-kodsiz.';

  @override
  String get faceOfferAdd => 'Yuz orqali kirish uchun rasm qo‘shish';

  @override
  String get later => 'Keyinroq';

  @override
  String get deleteAccount => 'Akkauntni o‘chirish';

  @override
  String get deleteAccountTitle => 'Akkaunt o‘chirilsinmi?';

  @override
  String get deleteAccountPointData =>
      'Ism, telefon, email, tug‘ilgan sana va yuz surati o‘chiriladi, yuz orqali kirish ishlamay qoladi.';

  @override
  String get deleteAccountPointMembership =>
      'Abonementdagi qolgan kunlar va tashriflar kuyib ketadi, arizalar va kelgusi mashg‘ulotlar bekor qilinadi.';

  @override
  String get deleteAccountPointRecords =>
      'To‘lovlar va tashriflar haqidagi yozuvlarni klub ismingizsiz saqlaydi — buni hisob-kitob talab qiladi.';

  @override
  String get deleteAccountPointFinal =>
      'O‘chirishni bekor qilib bo‘lmaydi. Raqamni qayta ro‘yxatdan o‘tkazish mumkin bo‘ladi.';

  @override
  String get deleteAccountPasswordLabel => 'Tasdiqlash uchun parol';

  @override
  String get deleteAccountConfirm => 'Butunlay o‘chirish';

  @override
  String get deleteAccountWrongPassword => 'Parol noto‘g‘ri';

  @override
  String get accountDeleted => 'Akkaunt o‘chirildi';

  @override
  String get privacyPolicy => 'Maxfiylik siyosati';

  @override
  String get registerConsentPrefix => 'Ro‘yxatdan o‘tish orqali siz ';

  @override
  String get registerConsentLink => 'Maxfiylik siyosati';

  @override
  String get registerConsentSuffix => 'ga rozilik bildirasiz';

  @override
  String get faceDataMore => 'Surat va ma’lumotlar haqida batafsil';

  @override
  String get foodPhotoUnreadable =>
      'Suratni o‘qib bo‘lmadi. Boshqasini tanlang.';

  @override
  String get foodPhotoTooSmall =>
      'Surat juda kichik: qisqa tomoni kamida 320 piksel bo‘lishi kerak.';

  @override
  String get foodPhotoNoCamera =>
      'Bu qurilmada kamera mavjud emas. Galereyadan surat tanlang.';

  @override
  String get foodPhotoPermission =>
      'Kamera yoki suratlarga ruxsat yo‘q. Telefon sozlamalarida ruxsat bering.';

  @override
  String get unitKcal => 'kkal';

  @override
  String get unitG => 'g';

  @override
  String get unitMg => 'mg';

  @override
  String get unitMl => 'ml';

  @override
  String get protein => 'Oqsillar';

  @override
  String get fat => 'Yog‘lar';

  @override
  String get carbs => 'Uglevodlar';

  @override
  String get fiber => 'Kletchatka';

  @override
  String get sugar => 'Shakar';

  @override
  String get saturatedFat => 'To‘yingan yog‘';

  @override
  String get sodium => 'Natriy';

  @override
  String get proteinShort => 'O';

  @override
  String get fatShort => 'Y';

  @override
  String get carbsShort => 'U';

  @override
  String kcalEatenSemantics(String kcal) {
    return '$kcal kkal iste’mol qilindi';
  }

  @override
  String kcalOfTargetSemantics(String kcal, String target) {
    return '$target kkaldan $kcal kkal iste’mol qilindi';
  }

  @override
  String ofKcal(String target) {
    return '$target kkaldan';
  }

  @override
  String get gramsInvalid => '1 dan 5000 gacha vazn kiriting';

  @override
  String get amountGrams => 'Vazn, g';

  @override
  String get amountMl => 'Hajm, ml';

  @override
  String get mealBreakfast => 'Nonushta';

  @override
  String get mealLunch => 'Tushlik';

  @override
  String get mealDinner => 'Kechki ovqat';

  @override
  String get mealSnack => 'Yengil tamaddi';

  @override
  String get foodCatBreakfast => 'Nonushta';

  @override
  String get foodCatLunch => 'Tushlik';

  @override
  String get foodCatDinner => 'Kechki ovqat';

  @override
  String get foodCatSnacks => 'Tamaddilar';

  @override
  String get foodCatFruits => 'Mevalar';

  @override
  String get foodCatVegetables => 'Sabzavotlar';

  @override
  String get foodCatMeat => 'Go‘sht';

  @override
  String get foodCatFish => 'Baliq';

  @override
  String get foodCatDairy => 'Sut mahsulotlari';

  @override
  String get foodCatBakery => 'Pishiriqlar';

  @override
  String get foodCatDesserts => 'Desertlar';

  @override
  String get foodCatFastFood => 'Fastfud';

  @override
  String get foodCatDrinks => 'Ichimliklar';

  @override
  String get foodCatPackaged => 'Qadoqlangan mahsulotlar';

  @override
  String get foodCatTraditional => 'Milliy taomlar';

  @override
  String get foodCatGrains => 'Don va garnirlar';

  @override
  String get foodCatLegumes => 'Dukkaklilar';

  @override
  String get foodCatNuts => 'Yong‘oq va urug‘lar';

  @override
  String get foodCatFats => 'Moylar va yog‘lar';

  @override
  String get foodCatSauces => 'Souslar';

  @override
  String get foodCatEggs => 'Tuxum';

  @override
  String get foodCatOther => 'Boshqa';

  @override
  String get sourceLabel => 'Yorliq';

  @override
  String get sourceRecipe => 'Retsept';

  @override
  String get sourceUser => 'O‘zim';

  @override
  String get allergenGluten => 'Glyuten';

  @override
  String get allergenMilk => 'Sut';

  @override
  String get allergenEggs => 'Tuxum';

  @override
  String get allergenNuts => 'Yong‘oq';

  @override
  String get allergenPeanuts => 'Yeryong‘oq';

  @override
  String get allergenSesame => 'Kunjut';

  @override
  String get allergenSoy => 'Soya';

  @override
  String get allergenFish => 'Baliq';

  @override
  String get allergenShellfish => 'Qisqichbaqasimonlar';

  @override
  String get allergenMolluscs => 'Mollyuskalar';

  @override
  String get allergenCelery => 'Selderey';

  @override
  String get allergenMustard => 'Xantal';

  @override
  String get allergenSulphites => 'Sulfitlar';

  @override
  String get allergenLupin => 'Lyupin';

  @override
  String get goalLose => 'Vazn kamaytirish';

  @override
  String get goalMaintain => 'Vaznni saqlash';

  @override
  String get goalGain => 'Massa yig‘ish';

  @override
  String get activitySedentary => 'Minimal';

  @override
  String get activityLight => 'Past';

  @override
  String get activityModerate => 'O‘rtacha';

  @override
  String get activityActive => 'Yuqori';

  @override
  String get activityVeryActive => 'Juda yuqori';

  @override
  String get activitySedentaryHint => 'O‘tirib ishlash, deyarli mashg‘ulotsiz';

  @override
  String get activityLightHint => 'Haftasiga 1–3 marta mashg‘ulot';

  @override
  String get activityModerateHint => 'Haftasiga 3–5 marta mashg‘ulot';

  @override
  String get activityActiveHint => 'Haftasiga 6–7 marta mashg‘ulot';

  @override
  String get activityVeryActiveHint =>
      'Har kuni og‘ir mashg‘ulot yoki jismoniy ish';

  @override
  String get prepRaw => 'Xom';

  @override
  String get prepBoiled => 'Qaynatilgan';

  @override
  String get prepSteamed => 'Bug‘da pishirilgan';

  @override
  String get prepFried => 'Qovurilgan';

  @override
  String get prepDeepFried => 'Ko‘p yog‘da qovurilgan';

  @override
  String get prepBaked => 'Pishirilgan (duxovkada)';

  @override
  String get prepGrilled => 'Grilda / cho‘g‘da';

  @override
  String get prepStewed => 'Dimlangan';

  @override
  String get prepMixed => 'Aralash usul';

  @override
  String get prepUnknown => 'Usul aniqlanmadi';

  @override
  String get roleMain => 'Asosiy';

  @override
  String get roleFat => 'Yog‘';

  @override
  String get roleSauce => 'Sous';

  @override
  String get roleGarnish => 'Garnir';

  @override
  String get roleDrink => 'Ichimlik';

  @override
  String get warnLowConfidence =>
      'SI taomni aniq bilmadi — nomi va tarkibini tekshiring.';

  @override
  String get warnWeightUncertain =>
      'Vazn surat bo‘yicha taxminan baholandi — aniqroq bilsangiz, grammni tuzating.';

  @override
  String get warnUnmatched =>
      'Ba’zi ingredientlar bazada yo‘q — mahsulotni tanlang, aks holda kaloriya kam ko‘rsatiladi.';

  @override
  String get warnCookingFatMissing =>
      'Taom qovurilgan, lekin tarkibda yog‘ yo‘q. Yog‘da pishirilgan bo‘lsa, qo‘shing.';

  @override
  String get warnMultipleDishes =>
      'Suratda bir nechta taom bor — keraklisini tanlang yoki hammasini qo‘shing.';

  @override
  String get imageBlurry =>
      'Surat xira — yaxshi yorug‘likda, telefonni qimirlatmay qayta oling.';

  @override
  String get imageDark =>
      'Surat juda qorong‘i — yaxshi yorug‘likda qayta oling.';

  @override
  String get imagePartial =>
      'Taom to‘liq ko‘rinmayapti — butun likopchani yuqoridan oling.';

  @override
  String get weightConfLow => 'vazn taxminiy';

  @override
  String get weightConfMedium => 'vazn baholandi';

  @override
  String get weightConfHigh => 'vazn aniq';

  @override
  String get dataProfile => 'profil';

  @override
  String get dataDiaryDay => 'kundalik';

  @override
  String get dataPeriod => 'statistika';

  @override
  String get dataScans => 'skanerlashlar';

  @override
  String get dataTrainings => 'mashg‘ulotlar';

  @override
  String get dataFoodSearch => 'mahsulotlar bazasi';

  @override
  String get errAiNotConfigured =>
      'Klubda SI tahlili ulanmagan. Kundalik, shtrix-kod va mahsulot qidiruvi ishlaydi.';

  @override
  String get errAiConsentRequired =>
      'Suratni SI xizmatiga yuborishga rozilik kerak.';

  @override
  String get errAiUnavailable =>
      'SI xizmati hozir mavjud emas. Bir necha daqiqadan so‘ng urinib ko‘ring.';

  @override
  String get errAiRateLimited =>
      'Ketma-ket juda ko‘p so‘rov. Bir daqiqa kuting.';

  @override
  String get errAiQuotaExceeded =>
      'Kunlik SI tahlillari limiti tugadi. Ertaga yana skanerlash mumkin, hozircha taomni qo‘lda qo‘shing.';

  @override
  String get errAiBudgetExceeded =>
      'SI tahlili klubda vaqtincha mavjud emas. Taomni qo‘lda qo‘shing.';

  @override
  String get errAiInvalidResponse =>
      'SI tushunarsiz javob berdi. Qayta urinib ko‘ring.';

  @override
  String get errAiRefused =>
      'SI bu suratni qayta ishlay olmadi. Boshqasini sinab ko‘ring.';

  @override
  String get errPhotoFormat => 'Surat formati qo‘llab-quvvatlanmaydi.';

  @override
  String get errPhotoTooLarge => 'Surat juda katta.';

  @override
  String get errPhotoBadSize =>
      'Surat o‘lchami mos emas: har bir tomoni 320 dan 4096 pikselgacha bo‘lishi kerak.';

  @override
  String get errBarcodeNotFound => 'Bunday shtrix-kodli mahsulot topilmadi.';

  @override
  String get errBarcodeInvalid =>
      'Noto‘g‘ri shtrix-kod: 8 dan 14 tagacha raqam kerak.';

  @override
  String get errFoodDbUnavailable =>
      'Mahsulotlar bazasi hozir mavjud emas. Keyinroq urinib ko‘ring yoki qo‘lda qidiring.';

  @override
  String get errItemWithoutNutrition =>
      'Mahsulotda ozuqaviy qiymat ma’lumoti yo‘q — bazadan mahsulot tanlang.';

  @override
  String get errProfileIncomplete =>
      'Me’yorni hisoblash uchun ovqatlanish profilini to‘ldiring.';

  @override
  String get errValidation => 'Kiritilgan ma’lumotlarni tekshiring.';

  @override
  String get aiProviderUnknown => 'tashqi SI xizmati';

  @override
  String get aiConsentTitle => 'Ovqatni SI yordamida tahlil qilish';

  @override
  String aiConsentBody(String provider) {
    return 'Taomni aniqlash, yorliqni o‘qish yoki ovqatlanish haqidagi savolga javob berish uchun ilova surat va ovqatlanish ma’lumotlarini $provider SI xizmatiga yuboradi. Kaloriyalarni klub serveri mahsulotlar bazasi bo‘yicha hisoblaydi.';
  }

  @override
  String get aiConsentPointPhoto =>
      'Faqat ovqat yoki yorliq surati yuboriladi — geolokatsiya va kamera ma’lumotlarisiz.';

  @override
  String get aiConsentPointNoName =>
      'Ism va telefon uzatilmaydi. Maslahatlar uchun — faqat yosh, bo‘y, vazn, maqsad va ovqatlanish kundaligi.';

  @override
  String get aiConsentPointDelete =>
      'Surat va tarixni istalgan vaqtda o‘chirish, rozilikni esa ovqatlanish sozlamalarida bekor qilish mumkin.';

  @override
  String get aiConsentAgree => 'Roziman';

  @override
  String get aiConsentDecline => 'Hozir emas';

  @override
  String get nutritionProfileTitle => 'Ovqatlanish profili';

  @override
  String get nutritionProfileSubtitle =>
      'Kunlik me’yor uchun maqsad va ko‘rsatkichlar';

  @override
  String get nutritionProfileSaved => 'Ovqatlanish profili saqlandi';

  @override
  String get nutritionGoal => 'Maqsad';

  @override
  String get nutritionGoalPick =>
      'Maqsadni tanlang — kaloriya me’yori unga bog‘liq.';

  @override
  String get aboutYou => 'Siz haqingizda';

  @override
  String get heightCm => 'Bo‘y, sm';

  @override
  String get weightKg => 'Vazn, kg';

  @override
  String get activityLevel => 'Faollik';

  @override
  String get customTarget => 'O‘z kaloriya me’yorim';

  @override
  String get customTargetHint => 'Ixtiyoriy — aks holda hisoblaymiz';

  @override
  String get restrictions => 'Ovqatlanishdagi cheklovlar';

  @override
  String get restrictionsHint =>
      'Masalan: cho‘chqa go‘shtisiz, vegetarian, kam tuz';

  @override
  String get allergies => 'Allergiyalar';

  @override
  String get aiAnalysis => 'SI tahlili';

  @override
  String aiConsentGiven(String date) {
    return 'Suratlarni SI xizmatiga yuborishga rozilik $date da berilgan.';
  }

  @override
  String get aiConsentNotGiven =>
      'Suratlarni SI xizmatiga yuborishga rozilik berilmagan. Usiz kundalik, qidiruv va shtrix-kodlar ishlaydi.';

  @override
  String get aiConsentRevoke => 'Rozilikni bekor qilish';

  @override
  String get aiConsentGive => 'Rozilik berish';

  @override
  String get aiConsentRevoked => 'Rozilik bekor qilindi';

  @override
  String valueRange(String min, String max) {
    return '$min dan $max gacha qiymat';
  }

  @override
  String get dailyTarget => 'Kunlik me’yor';

  @override
  String get targetCustomNote =>
      'Sizning kaloriya me’yoringiz; oqsil, yog‘ va uglevodlar undan hisoblangan.';

  @override
  String targetMethodNote(String bmr, String tdee) {
    return 'Miffin — San Jeor formulasi bo‘yicha: bazaviy almashinuv $bmr kkal, faollik bilan $tdee kkal, maqsadga moslashtirilgan.';
  }

  @override
  String get errScanInProgress =>
      'Oldingi surat hali tahlil qilinmoqda. Biroz kuting.';

  @override
  String get scanPreviewTitle => 'Taom surati';

  @override
  String get scanPreviewSubtitle => 'Suratni tekshiring va tahlilni boshlang';

  @override
  String get labelPreviewTitle => 'Yorliq surati';

  @override
  String get labelPreviewSubtitle =>
      'Ozuqaviy qiymat jadvalini to‘liq suratga oling';

  @override
  String get analyzeFood => 'Tahlil qilish';

  @override
  String get readLabel => 'Yorliqni o‘qish';

  @override
  String get labelUnreadable =>
      'Yorliqdagi ozuqaviy qiymatni o‘qib bo‘lmadi. Jadvalni yaqinroqdan va yaxshi yorug‘likda qayta oling.';

  @override
  String get scanHintLabel => 'Suratda nima bor? (ixtiyoriy)';

  @override
  String get scanHintExample => 'Masalan: lag‘mon, uy oshi';

  @override
  String get retakePhoto => 'Qayta olish';

  @override
  String get fromGallery => 'Galereyadan';

  @override
  String get analyzing1 => 'Suratda taomni qidirmoqdamiz…';

  @override
  String get analyzing2 => 'Ingredientlarni aniqlamoqdamiz…';

  @override
  String get analyzing3 => 'Porsiya vaznini baholamoqdamiz…';

  @override
  String get analyzing4 =>
      'Mahsulotlar bazasi bo‘yicha kaloriyani hisoblamoqdamiz…';

  @override
  String get analyzingLabel1 => 'Yorliqni o‘qimoqdamiz…';

  @override
  String get analyzingLabel2 => 'Ozuqaviy qiymat jadvalini qidirmoqdamiz…';

  @override
  String get analyzingLabel3 => 'Tarkib va allergenlarni tekshirmoqdamiz…';

  @override
  String get scanResultTitle => 'Natija';

  @override
  String get scanReused =>
      'Bu surat avval tahlil qilingan — oldingi natija ko‘rsatildi.';

  @override
  String get addToDiary => 'Kundalikka qo‘shish';

  @override
  String addAllDishes(int count) {
    return 'Hammasini qo‘shish ($count)';
  }

  @override
  String addedToDiary(String meal) {
    return 'Kundalikka qo‘shildi: $meal';
  }

  @override
  String addedAllToDiary(int count) {
    return '$count ta taom qo‘shildi';
  }

  @override
  String get lastIngredient => 'Taomda kamida bitta ingredient qolishi kerak.';

  @override
  String get noFatsToScale => 'Tarkibda yog‘ yoki sous yo‘q.';

  @override
  String get addIngredient => 'Ingredient qo‘shish';

  @override
  String get addIngredientShort => 'Qo‘shish';

  @override
  String pickProductFor(String name) {
    return '«$name» uchun mahsulot';
  }

  @override
  String get dishRenamed => 'Nomi saqlandi';

  @override
  String get renameDish => 'Taom nomi';

  @override
  String get dishName => 'Nomi';

  @override
  String get deleteScanTitle => 'Skanerlash o‘chirilsinmi?';

  @override
  String get deleteScanBody =>
      'Surat va tahlil natijasi o‘chiriladi. Kundalikdagi yozuvlar qoladi, lekin suratsiz.';

  @override
  String get deleteAction => 'O‘chirish';

  @override
  String get clarifyTitle => 'Suratda nima bor?';

  @override
  String get photoUnavailable => 'Surat endi mavjud emas. Yangisini oling.';

  @override
  String get notFoodTitle => 'Ovqat topilmadi';

  @override
  String get notFoodBody =>
      'Suratda ovqat yoki ichimlik ko‘rinmayapti. Taomni yuqoridan, to‘liq kadrga tushadigan qilib suratga oling.';

  @override
  String get scanFailedTitle => 'Tahlil bajarilmadi';

  @override
  String get scanFailedBody =>
      'SI xizmati javob bermadi. Qayta urinib ko‘ring — bu surat saqlangan.';

  @override
  String get clarifyNeededTitle => 'Aniqlik kiritish kerak';

  @override
  String get clarifyNeededBody =>
      'Taomni aniq aniqlab bo‘lmadi. Suratda nima borligini yozing yoki qayta oling.';

  @override
  String get clarifyName => 'Nomini aniqlashtirish';

  @override
  String kcalRangeLabel(String range) {
    return 'ehtimol $range kkal';
  }

  @override
  String get incompleteData => 'To‘liq bo‘lmagan ma’lumot';

  @override
  String get possibleAllergens => 'Ehtimoliy allergenlar';

  @override
  String get ingredients => 'Ingredientlar';

  @override
  String get fatLess => 'Kamroq';

  @override
  String get fatMore => 'Ko‘proq';

  @override
  String get fatTitle => 'Yog‘ va souslar';

  @override
  String get fatHint =>
      'Suratda yog‘ va sous miqdori eng yomon ko‘rinadi — qanday pishirilganini bilsangiz, tuzating.';

  @override
  String get mealTypeTitle => 'Ovqatlanish';

  @override
  String get calcNote =>
      'Kaloriyalar mahsulotlar bazasi (USDA, Open Food Facts) bo‘yicha har bir ingredient vazniga qarab hisoblangan. Bu surat bo‘yicha baho — grammni tuzatsangiz, aniqroq bo‘ladi.';

  @override
  String get notInDatabasePick => 'bazada yo‘q — mahsulot tanlash';

  @override
  String get decrease => 'Kamroq';

  @override
  String get increase => 'Ko‘proq';

  @override
  String get confidenceHigh => 'Ishonchli';

  @override
  String get confidenceMedium => 'Ehtimol';

  @override
  String get confidenceLow => 'Noaniq';

  @override
  String serving(int grams) {
    return 'Porsiya · $grams g';
  }

  @override
  String package(int grams) {
    return 'Qadoq · $grams g';
  }

  @override
  String portion(int grams) {
    return 'Porsiya · $grams g';
  }

  @override
  String get halfPortion => 'Yarim porsiya';

  @override
  String get searchFoodHint => 'Mahsulot yoki taom';

  @override
  String get searchFoodStart => 'Nomini kiriting: «osh», «grechka», «kefir»…';

  @override
  String get searchFoodNothing =>
      'Hech narsa topilmadi. Boshqa nom bilan urinib ko‘ring yoki o‘z mahsulotingizni yarating.';

  @override
  String get traditionalDish => 'Milliy taom';

  @override
  String get createOwnProduct => 'O‘z mahsulotimni yaratish';

  @override
  String get createProductSubtitle =>
      'Ozuqaviy qiymat — qadoqdan yoki retseptdan';

  @override
  String get productCreated => 'Mahsulot saqlandi';

  @override
  String get productName => 'Nomi';

  @override
  String get productBrand => 'Ishlab chiqaruvchi (ixtiyoriy)';

  @override
  String get per100MlSwitch => 'Bu ichimlik — qiymatlar 100 ml uchun';

  @override
  String get per100g => '100 g uchun';

  @override
  String get per100Ml => '100 ml uchun';

  @override
  String get portionSizes => 'Porsiya va qadoq hajmi';

  @override
  String get servingSize => 'Porsiya';

  @override
  String get packageSize => 'Qadoq';

  @override
  String get barcodeOptional => 'Shtrix-kod (ixtiyoriy)';

  @override
  String get allergensStated => 'Tarkib bo‘yicha allergenlar';

  @override
  String get composition => 'Tarkibi';

  @override
  String get howMuchEaten => 'Qancha yedingiz';

  @override
  String get barcodeTitle => 'Shtrix-kod';

  @override
  String get barcodeSubtitle => 'Kamerani qadoqdagi shtrix-kodga qarating';

  @override
  String get barcodeCameraUnavailable =>
      'Kamera mavjud emas. Shtrix-kod ostidagi raqamlarni qo‘lda kiriting.';

  @override
  String get barcodeManual => 'Qo‘lda kiritish';

  @override
  String get barcodeDigits => 'Shtrix-kod ostidagi raqamlar';

  @override
  String get barcodeFind => 'Mahsulotni topish';

  @override
  String get barcodeSourceNote =>
      'Mahsulotlar ochiq Open Food Facts bazasidan qidiriladi. U yerda bo‘lmasa, yorliqni suratga oling.';

  @override
  String get barcodeNotFoundTitle => 'Mahsulot topilmadi';

  @override
  String barcodeNotFoundBody(String code) {
    return '$code shtrix-kodi mahsulotlar bazasida yo‘q. Ozuqaviy qiymati yozilgan yorliqni suratga oling yoki mahsulotni qo‘lda toping.';
  }

  @override
  String get photoLabel => 'Yorliqni suratga olish';

  @override
  String get findManually => 'Qo‘lda topish';

  @override
  String get nutritionTitle => 'Ovqatlanish';

  @override
  String get nutritionSubtitle => 'SI ovqat skaneri va ovqatlanish kundaligi';

  @override
  String get scanFood => 'Ovqatni skanerlash';

  @override
  String get scanFoodHint => 'Taomni suratga oling — SI tarkibini aniqlaydi';

  @override
  String get labelShort => 'Yorliq';

  @override
  String scansLeft(int left, int total) {
    return 'Bugun SI tahlillari: $total tadan $left ta qoldi';
  }

  @override
  String get aiOffInfo =>
      'Klubda SI surat tahlili ulanmagan. Ovqatni shtrix-kod orqali yoki qo‘lda qo‘shing — kundalik va tahlil ishlaydi.';

  @override
  String get addManually => 'Qo‘lda qo‘shish';

  @override
  String get foodDiary => 'Ovqatlanish kundaligi';

  @override
  String get foodDiaryHint => 'Nonushta, tushlik, kechki ovqat va tamaddilar';

  @override
  String get nutritionAnalytics => 'Tahlil';

  @override
  String get nutritionAnalyticsHint =>
      'Kun, hafta, oy bo‘yicha kaloriya va OYU';

  @override
  String get consultantTitle => 'SI maslahatchi';

  @override
  String get consultantHint =>
      'Ma’lumotlaringiz bo‘yicha ovqatlanish savollari';

  @override
  String get recentScans => 'Oxirgi skanerlashlar';

  @override
  String get noScansYet =>
      'Hozircha skanerlashlar yo‘q. Ovqatingizni suratga oling — natija shu yerda paydo bo‘ladi.';

  @override
  String eatenKcal(String kcal) {
    return '$kcal kkal iste’mol qilindi';
  }

  @override
  String remainingKcal(String kcal) {
    return '$kcal kkal qoldi';
  }

  @override
  String overKcal(String kcal) {
    return 'Me’yordan $kcal kkal ortiq';
  }

  @override
  String get noTargetYet => 'Me’yor hisoblanmagan';

  @override
  String get setupTarget => 'Kunlik me’yorni hisoblash';

  @override
  String get statusNeedsClarification => 'aniqlik kerak';

  @override
  String get statusNotFood => 'ovqat topilmadi';

  @override
  String get statusFailed => 'tahlil xatosi';

  @override
  String get unknownDish => 'Taom';

  @override
  String get inDiary => 'Kundalikda';

  @override
  String get nutritionHomeHint =>
      'Ovqatni suratga oling — SI kaloriyani hisoblaydi';

  @override
  String get yesterday => 'Kecha';

  @override
  String get previousDay => 'Oldingi kun';

  @override
  String get nextDay => 'Keyingi kun';

  @override
  String addToMeal(String meal) {
    return 'Qo‘shish: $meal';
  }

  @override
  String get mealEmpty => 'Hozircha hech narsa — qo‘shish uchun bosing';

  @override
  String get addFromSearch => 'Mahsulot yoki taomni topish';

  @override
  String get addFromRecent => 'Yaqindagilardan';

  @override
  String get addFromScans => 'Skanerlash tarixidan';

  @override
  String get noRecent => 'Hozircha yaqindagi yozuvlar yo‘q';

  @override
  String get lastItemDeleteEntry =>
      'Bu oxirgi mahsulot — yozuvni butunlay o‘chiring.';

  @override
  String get entrySaved => 'Yozuv saqlandi';

  @override
  String get entryRepeated => 'Bugunga yana qo‘shildi';

  @override
  String get deleteEntryTitle => 'Yozuv o‘chirilsinmi?';

  @override
  String get deleteEntryBody => 'Yozuv kundalik va statistikadan o‘chadi.';

  @override
  String get repeatToday => 'Bugun takrorlash';

  @override
  String get recalcOnSave => 'Aniq qiymatlar saqlashda qayta hisoblanadi';

  @override
  String get noNutritionData => 'ozuqaviy qiymat ma’lumoti yo‘q';

  @override
  String get portionSize => 'Porsiya hajmi';

  @override
  String get eatenAt => 'Vaqt';

  @override
  String get periodDay => 'Kun';

  @override
  String get periodWeek => 'Hafta';

  @override
  String get periodMonth => 'Oy';

  @override
  String get previousPeriod => 'Oldingi davr';

  @override
  String get nextPeriod => 'Keyingi davr';

  @override
  String get aiReport => 'SI hisoboti';

  @override
  String get aiReportDay => 'Kunlik hisobot';

  @override
  String get aiReportWeek => 'Haftalik hisobot';

  @override
  String get aiReportDayButton => 'Kunlik hisobotni olish';

  @override
  String get aiReportWeekButton => 'Haftalik hisobotni olish';

  @override
  String get notMedicalAdvice =>
      'Bu tibbiy tavsiya emas. Kasallik bo‘lsa, shifokorga murojaat qiling.';

  @override
  String workoutsCount(int count) {
    return '$count ta mashg‘ulot';
  }

  @override
  String get clubVisit => 'Klubga tashrif';

  @override
  String get byMeal => 'Ovqatlanishlar bo‘yicha';

  @override
  String get macroSplit => 'Kaloriyada OYU ulushi';

  @override
  String get averageKcal => 'o‘rtacha kkal';

  @override
  String get daysLogged => 'yozuvli kunlar';

  @override
  String get daysWithinTarget => 'me’yorda ±10% kunlar';

  @override
  String get caloriesPerDay => 'Kunlar bo‘yicha kaloriya';

  @override
  String get macrosPerDay => 'Kunlar bo‘yicha oqsil, yog‘, uglevod';

  @override
  String get averagePerDay => 'Kuniga o‘rtacha';

  @override
  String chartSemantics(int days, String kcal) {
    return 'Kaloriya grafigi: yozuvli kunlar $days, o‘rtacha $kcal kkal';
  }

  @override
  String get legendWithin => 'me’yorda';

  @override
  String get legendOver => 'me’yordan ko‘p';

  @override
  String get legendUnder => 'me’yordan kam';

  @override
  String get legendWorkout => 'mashg‘ulot';

  @override
  String get noDataYet => 'Hozircha ma’lumot yo‘q';

  @override
  String periodActivity(int workouts, int visits) {
    return 'Davr mobaynida: mashg‘ulotlar — $workouts, klubga tashriflar — $visits';
  }

  @override
  String get consultantSubtitle =>
      'Kundaligingiz va profilingiz bo‘yicha javob beradi';

  @override
  String get consultantIntro =>
      'Ovqatlanishingiz haqida so‘rang: maslahatchi kundaligingiz, skanerlashlar, maqsad va mashg‘ulotlarni ko‘radi va haqiqiy ma’lumotlar bo‘yicha javob beradi.';

  @override
  String get consultantHintInput => 'Ovqatlanish haqida savol';

  @override
  String get consultantTyping => 'Maslahatchi yozmoqda';

  @override
  String basedOn(String sources) {
    return 'asosida: $sources';
  }

  @override
  String get askEatenToday => 'Bugun qancha kaloriya iste’mol qildim?';

  @override
  String get askDinner => 'Kechki ovqatga nima yeganim ma’qul?';

  @override
  String get askPlov => 'Hozir osh yesam bo‘ladimi?';

  @override
  String get askProteinLeft => 'Yana qancha oqsil olishim kerak?';

  @override
  String get askWhyOver => 'Nega me’yordan oshib ketyapman?';

  @override
  String get askCompare => 'Bugunni kecha bilan solishtir';
}
