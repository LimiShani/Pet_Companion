/// The app's languages in one import: the strings classes, the language
/// choice, the week layout, and the helpers for dates, numbers and text
/// direction.
///
/// Strings live in ARB files, one English and one Hebrew file per feature,
/// each with its own generated class:
///
/// | Folder                        | Class           | In a widget             |
/// |-------------------------------|-----------------|-------------------------|
/// | `lib/l10n/`                   | `AppL10n`       | `context.l10n`          |
/// | `lib/features/health/l10n/`   | `HealthL10n`    | `context.healthL10n`    |
/// | `lib/features/community/l10n/`| `CommunityL10n` | `context.communityL10n` |
/// | `lib/features/store/l10n/`    | `StoreL10n`     | `context.storeL10n`     |
/// | `lib/features/pets/l10n/`     | `PetsL10n`      | `context.petsL10n`      |
/// | `lib/features/care/l10n/`     | `CareL10n`      | `context.careL10n`      |
/// | `lib/notifications/l10n/`     | `NotificationsL10n` | `context.notificationsL10n` |
///
/// To add a string: add the key to `<feature>_en.arb` and its Hebrew to
/// `<feature>_he.arb` (wording: `lib/l10n/GLOSSARY.md`), run
/// `dart run tool/gen_l10n.dart <feature>`, and use the getter. Code that
/// has no `BuildContext` reads the same strings from a provider, e.g.
/// `ref.watch(healthL10nProvider)`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/care/l10n/gen/care_l10n.dart';
import '../features/community/l10n/gen/community_l10n.dart';
import '../features/health/l10n/gen/health_l10n.dart';
import '../features/pets/l10n/gen/pets_l10n.dart';
import '../features/store/l10n/gen/store_l10n.dart';
import '../notifications/l10n/gen/notifications_l10n.dart';
import 'app_language.dart';
import 'gen/app_l10n.dart';

export '../features/care/l10n/gen/care_l10n.dart' show CareL10n, lookupCareL10n;
export '../features/community/l10n/gen/community_l10n.dart' show CommunityL10n, lookupCommunityL10n;
export '../features/health/l10n/gen/health_l10n.dart' show HealthL10n, lookupHealthL10n;
export '../features/pets/l10n/gen/pets_l10n.dart' show PetsL10n, lookupPetsL10n;
export '../features/store/l10n/gen/store_l10n.dart' show StoreL10n, lookupStoreL10n;
export '../notifications/l10n/gen/notifications_l10n.dart' show NotificationsL10n, lookupNotificationsL10n;
export 'app_format.dart';
export 'app_language.dart';
export 'bidi.dart';
export 'gen/app_l10n.dart' show AppL10n, lookupAppL10n;
export 'settings_store.dart';
export 'week_settings.dart';

/// Everything `MaterialApp.localizationsDelegates` needs: the seven strings
/// classes, and Flutter's own texts (date picker, "Cancel") and direction.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppL10n.delegate,
  HealthL10n.delegate,
  CommunityL10n.delegate,
  StoreL10n.delegate,
  PetsL10n.delegate,
  CareL10n.delegate,
  NotificationsL10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The strings of the screen's language.
///
/// These work in any widget tree. In the app the strings come from the
/// delegates above. A widget pumped on its own in a test, inside a plain
/// `MaterialApp` without them, gets the strings of that app's locale
/// (English unless the test says otherwise), so existing tests need no
/// setup.
extension L10nContext on BuildContext {
  /// Shared strings: sign-in, Home, navigation, shared widgets, and common
  /// words such as Save and Cancel.
  AppL10n get l10n => _strings(this, lookupAppL10n);
  HealthL10n get healthL10n => _strings(this, lookupHealthL10n);
  CommunityL10n get communityL10n => _strings(this, lookupCommunityL10n);
  StoreL10n get storeL10n => _strings(this, lookupStoreL10n);
  PetsL10n get petsL10n => _strings(this, lookupPetsL10n);

  /// Home's daily care: the feeding and activity pages and sheets.
  CareL10n get careL10n => _strings(this, lookupCareL10n);

  /// The phone's reminders: their texts, the Notifications settings and
  /// the sheet that asks for permission.
  NotificationsL10n get notificationsL10n => _strings(this, lookupNotificationsL10n);

  /// Whether this part of the screen runs right to left.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}

T _strings<T extends Object>(BuildContext context, T Function(Locale locale) lookup) {
  final registered = Localizations.of<T>(context, T);
  if (registered != null) return registered;
  final locale = Localizations.maybeLocaleOf(context);
  return lookup(locale != null && isHebrew(locale) ? hebrewLocale : englishLocale);
}

// The same strings for code that has no BuildContext (a repository, a PDF,
// a message composed for another app). They follow the language switch.
final appL10nProvider = Provider<AppL10n>((ref) => lookupAppL10n(ref.watch(appLocaleProvider)));
final healthL10nProvider = Provider<HealthL10n>((ref) => lookupHealthL10n(ref.watch(appLocaleProvider)));
final communityL10nProvider = Provider<CommunityL10n>((ref) => lookupCommunityL10n(ref.watch(appLocaleProvider)));
final storeL10nProvider = Provider<StoreL10n>((ref) => lookupStoreL10n(ref.watch(appLocaleProvider)));
final petsL10nProvider = Provider<PetsL10n>((ref) => lookupPetsL10n(ref.watch(appLocaleProvider)));

/// The texts of the phone's reminders, which are built outside any widget.
final notificationsL10nProvider = Provider<NotificationsL10n>(
  (ref) => lookupNotificationsL10n(ref.watch(appLocaleProvider)),
);
