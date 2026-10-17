// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'notifications_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class NotificationsL10nEn extends NotificationsL10n {
  NotificationsL10nEn([String locale = 'en']) : super(locale);

  @override
  String title(String pet) {
    return 'PetLoop · $pet';
  }

  @override
  String mealBody(String meal) {
    return '$meal · time to feed';
  }

  @override
  String get walkFallback => 'Time for a walk';

  @override
  String medicineBody(String medicine, String dose) {
    return '$medicine · $dose';
  }

  @override
  String medicineNoDose(String medicine) {
    return '$medicine · time for a dose';
  }

  @override
  String appointmentToday(String time, String title) {
    return 'Today $time: $title';
  }

  @override
  String appointmentTomorrow(String time, String title) {
    return 'Tomorrow $time: $title';
  }

  @override
  String appointmentOn(String date, String time, String title) {
    return '$date $time: $title';
  }

  @override
  String withPlace(String text, String place) {
    return '$text · $place';
  }

  @override
  String get snooze => 'In 15 min';

  @override
  String get done => 'Done';

  @override
  String get sectionTitle => 'Notifications';

  @override
  String get masterTitle => 'Reminders on this phone';

  @override
  String get masterNote => 'PetLoop rings at the time of each reminder';

  @override
  String get masterDoneNote => 'Meals, walks and medicines can be marked done right from the notification';

  @override
  String get meals => 'Meals';

  @override
  String get walks => 'Walks';

  @override
  String get medicines => 'Medicines';

  @override
  String get appointments => 'Appointments and vaccinations';

  @override
  String get appointmentsNote => 'The evening before (18:00) and 2 hours before';

  @override
  String get basket => 'Basket: running low';

  @override
  String get basketNote => '5 days before';

  @override
  String get quietHours => 'Quiet hours, 22:00–07:00';

  @override
  String get quietHoursNote => 'Medicines ring in quiet hours too';

  @override
  String get quietHoursMoved => 'Meals, walks and the basket wait until 07:00';

  @override
  String get exactTitle => 'Exact time';

  @override
  String get exactNote => 'For a medicine reminder to arrive on the minute, Android asks for “Alarms & reminders”.';

  @override
  String get exactAllowed => 'Allowed';

  @override
  String get exactMissing => 'Not allowed yet: a reminder can come late, by up to an hour.';

  @override
  String get exactAllow => 'Allow';

  @override
  String get blockedTitle => 'PetLoop may not show notifications';

  @override
  String get blockedNote => 'Notifications are off for PetLoop in the phone\'s settings, so no reminder can ring.';

  @override
  String get openPhoneSettings => 'Open phone settings';

  @override
  String get summaryQuietOff => 'Reminders on · quiet hours off';

  @override
  String get summaryQuietOn => 'Reminders on · quiet hours on';

  @override
  String get summaryOff => 'Reminders off';

  @override
  String get summaryBlocked => 'Off on this phone';

  @override
  String get askTitle => 'Reminders, right on time';

  @override
  String get askIntro => 'PetLoop can ring when it is time for:';

  @override
  String get askMeals => 'Meals and walks';

  @override
  String get askMedicines => 'Medicine doses';

  @override
  String get askAppointments => 'Vet appointments and vaccinations, the evening before and 2 hours before';

  @override
  String get askFoot => 'In Settings you choose what rings, and you can add quiet hours.';

  @override
  String get askAllow => 'Turn on reminders';

  @override
  String get askLater => 'Not now';

  @override
  String get askExactTitle => 'One more thing: on the minute';

  @override
  String get askExactAllow => 'Open Alarms & reminders';

  @override
  String get communityChannel => 'Community';

  @override
  String get weekly => 'Weekly summary';

  @override
  String get weeklyNote => 'One note a week for each pet: walks, doses and what is due next';

  @override
  String get weeklyDay => 'Day';

  @override
  String get weeklyTime => 'Time';

  @override
  String weeklyTitle(String pet) {
    return '$pet\'s week';
  }

  @override
  String weeklyLastWeek(String numbers) {
    return 'Last week: $numbers';
  }

  @override
  String weeklyWalks(int done, int planned) {
    return '$done of $planned walks';
  }

  @override
  String weeklyWalksLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count walks',
      one: '1 walk',
    );
    return '$_temp0';
  }

  @override
  String weeklyDoses(int given, int planned) {
    return '$given of $planned doses given';
  }

  @override
  String weeklyDueToday(String title) {
    return '$title is due today';
  }

  @override
  String weeklyDueTomorrow(String title) {
    return '$title is due tomorrow';
  }

  @override
  String weeklyDueInDays(String title, int count) {
    return '$title due in $count days';
  }

  @override
  String weeklyDueInWeeks(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$title due in $count weeks',
      one: '$title due in 1 week',
    );
    return '$_temp0';
  }

  @override
  String weeklyDueOn(String title, String date) {
    return '$title due on $date';
  }
}
