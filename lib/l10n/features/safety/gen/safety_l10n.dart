import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'safety_l10n_en.dart';
import 'safety_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SafetyL10n
/// returned by `SafetyL10n.of(context)`.
///
/// Applications need to include `SafetyL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/safety_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SafetyL10n.localizationsDelegates,
///   supportedLocales: SafetyL10n.supportedLocales,
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
/// be consistent with the languages listed in the SafetyL10n.supportedLocales
/// property.
abstract class SafetyL10n {
  SafetyL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SafetyL10n of(BuildContext context) {
    return Localizations.of<SafetyL10n>(context, SafetyL10n)!;
  }

  static const LocalizationsDelegate<SafetyL10n> delegate = _SafetyL10nDelegate();

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

  /// The line under the Emergency sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Call first. The rows below help you decide and prepare.'**
  String get emergencyLead;

  /// On the Emergency sheet's first contact (a clinic or a vet): opening hours change, so call before driving.
  ///
  /// In en, this message translates to:
  /// **'Call to confirm they are open'**
  String get confirmOpen;

  /// Emergency sheet row: opens the list of signs that mean going to a vet now.
  ///
  /// In en, this message translates to:
  /// **'Is it urgent?'**
  String get urgentRow;

  /// No description provided for @urgentRowNote.
  ///
  /// In en, this message translates to:
  /// **'Signs that mean going to the vet now'**
  String get urgentRowNote;

  /// Emergency sheet row: opens the searchable list of foods and plants.
  ///
  /// In en, this message translates to:
  /// **'Can {name} eat this?'**
  String foodRow(String name);

  /// No description provided for @foodRowNote.
  ///
  /// In en, this message translates to:
  /// **'Foods and plants: safe, a little or dangerous'**
  String get foodRowNote;

  /// Emergency sheet row: starts Lost mode (an alert to people nearby and a card to share).
  ///
  /// In en, this message translates to:
  /// **'Lost mode'**
  String get lostRow;

  /// No description provided for @lostRowNote.
  ///
  /// In en, this message translates to:
  /// **'Tell people nearby and share a card'**
  String get lostRowNote;

  /// Subtitle of the Lost mode row for an account without Lost mode: it opens the lost-pet card only.
  ///
  /// In en, this message translates to:
  /// **'Make a card to share'**
  String get lostRowCardNote;

  /// The Lost mode row while an alert is open: the pet and how many people commented on the post.
  ///
  /// In en, this message translates to:
  /// **'{name} is missing · {count, plural, =0{no sightings yet} =1{1 sighting} other{{count} sightings}}'**
  String lostRowActive(String name, int count);

  /// Under the open alert's row: when the pet was last seen, e.g. 'Today 14:30'.
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String lostRowActiveNote(String when);

  /// Under the Emergency sheet's Find a clinic nearby row.
  ///
  /// In en, this message translates to:
  /// **'Emergency clinics near you'**
  String get findClinicNote;
}

class _SafetyL10nDelegate extends LocalizationsDelegate<SafetyL10n> {
  const _SafetyL10nDelegate();

  @override
  Future<SafetyL10n> load(Locale locale) {
    return SynchronousFuture<SafetyL10n>(lookupSafetyL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_SafetyL10nDelegate old) => false;
}

SafetyL10n lookupSafetyL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return SafetyL10nEn();
    case 'he': return SafetyL10nHe();
  }

  throw FlutterError(
    'SafetyL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
