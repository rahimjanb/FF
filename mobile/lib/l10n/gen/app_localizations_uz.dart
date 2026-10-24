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
}
