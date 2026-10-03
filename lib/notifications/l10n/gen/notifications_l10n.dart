import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'notifications_l10n_en.dart';
import 'notifications_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of NotificationsL10n
/// returned by `NotificationsL10n.of(context)`.
///
/// Applications need to include `NotificationsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/notifications_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: NotificationsL10n.localizationsDelegates,
///   supportedLocales: NotificationsL10n.supportedLocales,
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
/// be consistent with the languages listed in the NotificationsL10n.supportedLocales
/// property.
abstract class NotificationsL10n {
  NotificationsL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static NotificationsL10n of(BuildContext context) {
    return Localizations.of<NotificationsL10n>(context, NotificationsL10n)!;
  }

  static const LocalizationsDelegate<NotificationsL10n> delegate = _NotificationsL10nDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// Title of a reminder on the phone: the app and the pet's name.
  ///
  /// In en, this message translates to:
  /// **'PetLoop · {pet}'**
  String title(String pet);

  /// Text of a meal reminder. {meal} is the routine's name, e.g. Dinner.
  ///
  /// In en, this message translates to:
  /// **'{meal} · time to feed'**
  String mealBody(String meal);

  /// Text of a walk reminder whose routine has no name (a named one shows just its name, e.g. Evening walk).
  ///
  /// In en, this message translates to:
  /// **'Time for a walk'**
  String get walkFallback;

  /// Text of a medicine reminder: the medicine and the dose, as the owner typed them (Joint tablets · 1 tablet).
  ///
  /// In en, this message translates to:
  /// **'{medicine} · {dose}'**
  String medicineBody(String medicine, String dose);

  /// Text of a medicine reminder when no dose was entered.
  ///
  /// In en, this message translates to:
  /// **'{medicine} · time for a dose'**
  String medicineNoDose(String medicine);

  /// Text of an appointment reminder for later today. {title} is the record's title.
  ///
  /// In en, this message translates to:
  /// **'Today {time}: {title}'**
  String appointmentToday(String time, String title);

  /// Text of the appointment reminder of the evening before.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}: {title}'**
  String appointmentTomorrow(String time, String title);

  /// Text of an appointment reminder for another day. {date} is like 12.06.25.
  ///
  /// In en, this message translates to:
  /// **'{date} {time}: {title}'**
  String appointmentOn(String date, String time, String title);

  /// An appointment reminder's text followed by the vet or clinic.
  ///
  /// In en, this message translates to:
  /// **'{text} · {place}'**
  String withPlace(String text, String place);

  /// Button on a reminder: show it again in 15 minutes.
  ///
  /// In en, this message translates to:
  /// **'In 15 min'**
  String get snooze;

  /// Section of the Settings page.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionTitle;

  /// No description provided for @masterTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders on this phone'**
  String get masterTitle;

  /// No description provided for @masterNote.
  ///
  /// In en, this message translates to:
  /// **'PetLoop rings at the time of each reminder'**
  String get masterNote;

  /// Switch in Settings, and the name of the phone's notification category.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @walks.
  ///
  /// In en, this message translates to:
  /// **'Walks'**
  String get walks;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments and vaccinations'**
  String get appointments;

  /// No description provided for @appointmentsNote.
  ///
  /// In en, this message translates to:
  /// **'The evening before (18:00) and 2 hours before'**
  String get appointmentsNote;

  /// Reminder that food or another basket item is about to run out.
  ///
  /// In en, this message translates to:
  /// **'Basket: running low'**
  String get basket;

  /// No description provided for @basketNote.
  ///
  /// In en, this message translates to:
  /// **'5 days before'**
  String get basketNote;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours, 22:00–07:00'**
  String get quietHours;

  /// No description provided for @quietHoursNote.
  ///
  /// In en, this message translates to:
  /// **'Medicines ring in quiet hours too'**
  String get quietHoursNote;

  /// No description provided for @quietHoursMoved.
  ///
  /// In en, this message translates to:
  /// **'Meals, walks and the basket wait until 07:00'**
  String get quietHoursMoved;

  /// No description provided for @exactTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact time'**
  String get exactTitle;

  /// No description provided for @exactNote.
  ///
  /// In en, this message translates to:
  /// **'For a medicine reminder to arrive on the minute, Android asks for “Alarms & reminders”.'**
  String get exactNote;

  /// No description provided for @exactAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get exactAllowed;

  /// No description provided for @exactMissing.
  ///
  /// In en, this message translates to:
  /// **'Not allowed yet: a reminder can come late, by up to an hour.'**
  String get exactMissing;

  /// Button that opens Android's Alarms & reminders screen for PetLoop.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get exactAllow;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'PetLoop may not show notifications'**
  String get blockedTitle;

  /// No description provided for @blockedNote.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for PetLoop in the phone\'s settings, so no reminder can ring.'**
  String get blockedNote;

  /// No description provided for @openPhoneSettings.
  ///
  /// In en, this message translates to:
  /// **'Open phone settings'**
  String get openPhoneSettings;

  /// Title of the sheet shown before the phone asks for permission to send notifications.
  ///
  /// In en, this message translates to:
  /// **'Reminders, right on time'**
  String get askTitle;

  /// No description provided for @askIntro.
  ///
  /// In en, this message translates to:
  /// **'PetLoop can ring when it is time for:'**
  String get askIntro;

  /// No description provided for @askMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals and walks'**
  String get askMeals;

  /// No description provided for @askMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicine doses'**
  String get askMedicines;

  /// No description provided for @askAppointments.
  ///
  /// In en, this message translates to:
  /// **'Vet appointments and vaccinations, the evening before and 2 hours before'**
  String get askAppointments;

  /// No description provided for @askFoot.
  ///
  /// In en, this message translates to:
  /// **'In Settings you choose what rings, and you can add quiet hours.'**
  String get askFoot;

  /// No description provided for @askAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders'**
  String get askAllow;

  /// No description provided for @askLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get askLater;

  /// No description provided for @askExactTitle.
  ///
  /// In en, this message translates to:
  /// **'One more thing: on the minute'**
  String get askExactTitle;

  /// Button that opens Android's Alarms & reminders screen.
  ///
  /// In en, this message translates to:
  /// **'Open Alarms & reminders'**
  String get askExactAllow;
}

class _NotificationsL10nDelegate extends LocalizationsDelegate<NotificationsL10n> {
  const _NotificationsL10nDelegate();

  @override
  Future<NotificationsL10n> load(Locale locale) {
    return SynchronousFuture<NotificationsL10n>(lookupNotificationsL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_NotificationsL10nDelegate old) => false;
}

NotificationsL10n lookupNotificationsL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return NotificationsL10nEn();
    case 'he': return NotificationsL10nHe();
  }

  throw FlutterError(
    'NotificationsL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
