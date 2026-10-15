import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'today_l10n_en.dart';
import 'today_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of TodayL10n
/// returned by `TodayL10n.of(context)`.
///
/// Applications need to include `TodayL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/today_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: TodayL10n.localizationsDelegates,
///   supportedLocales: TodayL10n.supportedLocales,
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
/// be consistent with the languages listed in the TodayL10n.supportedLocales
/// property.
abstract class TodayL10n {
  TodayL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static TodayL10n of(BuildContext context) {
    return Localizations.of<TodayL10n>(context, TodayL10n)!;
  }

  static const LocalizationsDelegate<TodayL10n> delegate = _TodayL10nDelegate();

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

  /// The title of Home's Today card.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get title;

  /// The line beside the Today title: the date, and how many of the day's items are done.
  ///
  /// In en, this message translates to:
  /// **'{day} · {done} of {total} done'**
  String headerDone(String day, int done, int total);

  /// A row's title with its pet's name, when the account has more than one pet: "Breakfast · Kelly".
  ///
  /// In en, this message translates to:
  /// **'{title} · {pet}'**
  String withPet(String title, String pet);

  /// Who logged a done row when it was the signed-in person: "7:40 · you".
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get you;

  /// Under a done row: when it was done and who did it (a household member's name, or "you").
  ///
  /// In en, this message translates to:
  /// **'{time} · {who}'**
  String doneBy(String time, String who);

  /// Under a row answered as not done (a meal not eaten, a dose not given).
  ///
  /// In en, this message translates to:
  /// **'{time} · {who} · not done'**
  String notDoneBy(String time, String who);

  /// Under a row answered as not done when who answered is not known.
  ///
  /// In en, this message translates to:
  /// **'{time} · not done'**
  String notDoneAt(String time);

  /// A basket product that runs out soon, as a Today row: "Dry food runs out in 4 days".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{name} runs out today} =1{{name} runs out tomorrow} other{{name} runs out in {count} days}}'**
  String runsOutIn(int count, String name);

  /// A basket product that already ran out, as a Today row.
  ///
  /// In en, this message translates to:
  /// **'{name} ran out'**
  String ranOut(String name);

  /// Under the Today row of the first 30 days' next step.
  ///
  /// In en, this message translates to:
  /// **'First 30 days · day {day}'**
  String firstDaysLine(String day);

  /// The row the done items fold into when there are many; tapping it shows them.
  ///
  /// In en, this message translates to:
  /// **'{count} done'**
  String foldDone(int count);

  /// Screen reader hint of the folded done row.
  ///
  /// In en, this message translates to:
  /// **'Show what is done'**
  String get showDone;

  /// Screen reader hint of the open done row.
  ///
  /// In en, this message translates to:
  /// **'Hide what is done'**
  String get hideDone;

  /// Screen reader label of a row's tick.
  ///
  /// In en, this message translates to:
  /// **'Mark {title} as done'**
  String markDone(String title);

  /// Screen reader label of a done row's tick, within the hour it can be taken back.
  ///
  /// In en, this message translates to:
  /// **'Undo {title}'**
  String undoDone(String title);

  /// Screen reader label of a done row's tick once it can no longer be taken back.
  ///
  /// In en, this message translates to:
  /// **'{title}, done'**
  String doneSemantics(String title);

  /// The Today card when the day has no items.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned today.'**
  String get empty;

  /// The one action of an empty Today card, for a pet with no meal times: opens the feeding page.
  ///
  /// In en, this message translates to:
  /// **'Set up feeding'**
  String get setUpFeeding;

  /// The Today card when its data could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load today\'s list. Tap to try again.'**
  String get loadFailed;
}

class _TodayL10nDelegate extends LocalizationsDelegate<TodayL10n> {
  const _TodayL10nDelegate();

  @override
  Future<TodayL10n> load(Locale locale) {
    return SynchronousFuture<TodayL10n>(lookupTodayL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_TodayL10nDelegate old) => false;
}

TodayL10n lookupTodayL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return TodayL10nEn();
    case 'he': return TodayL10nHe();
  }

  throw FlutterError(
    'TodayL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
