import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'healthplan_l10n_en.dart';
import 'healthplan_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of HealthPlanL10n
/// returned by `HealthPlanL10n.of(context)`.
///
/// Applications need to include `HealthPlanL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/healthplan_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: HealthPlanL10n.localizationsDelegates,
///   supportedLocales: HealthPlanL10n.supportedLocales,
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
/// be consistent with the languages listed in the HealthPlanL10n.supportedLocales
/// property.
abstract class HealthPlanL10n {
  HealthPlanL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static HealthPlanL10n of(BuildContext context) {
    return Localizations.of<HealthPlanL10n>(context, HealthPlanL10n)!;
  }

  static const LocalizationsDelegate<HealthPlanL10n> delegate = _HealthPlanL10nDelegate();

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

  /// The insight line on the Health Overview: walk minutes of the last 4 weeks more than 20% below the 4 before. Calm, never a diagnosis.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s walks were shorter than last month. Worth a word with your vet if it goes on.'**
  String insightShorterWalks(String pet);

  /// Insight: weight up more than 5% within 8 weeks.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s weight went up by about {percent}% in the last few weeks. Worth a word with your vet if it goes on.'**
  String insightWeightUp(String pet, int percent);

  /// Insight: weight down more than 5% within 8 weeks.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s weight went down by about {percent}% in the last few weeks. Worth a word with your vet if it goes on.'**
  String insightWeightDown(String pet, int percent);

  /// Insight: three or more "less than usual" appetite entries in 14 days.
  ///
  /// In en, this message translates to:
  /// **'In the last two weeks you noted {count} times that {pet} ate less than usual. Worth a word with your vet if it goes on.'**
  String insightAppetiteLess(String pet, int count);

  /// The insight's link to the pet's activity page.
  ///
  /// In en, this message translates to:
  /// **'See walks'**
  String get insightSeeWalks;

  /// The insight's link to the weight in Records.
  ///
  /// In en, this message translates to:
  /// **'See weight'**
  String get insightSeeWeight;

  /// The insight's link to the journal in Records.
  ///
  /// In en, this message translates to:
  /// **'See journal'**
  String get insightSeeJournal;
}

class _HealthPlanL10nDelegate extends LocalizationsDelegate<HealthPlanL10n> {
  const _HealthPlanL10nDelegate();

  @override
  Future<HealthPlanL10n> load(Locale locale) {
    return SynchronousFuture<HealthPlanL10n>(lookupHealthPlanL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_HealthPlanL10nDelegate old) => false;
}

HealthPlanL10n lookupHealthPlanL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return HealthPlanL10nEn();
    case 'he': return HealthPlanL10nHe();
  }

  throw FlutterError(
    'HealthPlanL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
