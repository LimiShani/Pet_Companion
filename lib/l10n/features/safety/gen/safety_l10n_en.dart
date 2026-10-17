// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'safety_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SafetyL10nEn extends SafetyL10n {
  SafetyL10nEn([String locale = 'en']) : super(locale);

  @override
  String get emergencyLead => 'Call first. The rows below help you decide and prepare.';

  @override
  String get confirmOpen => 'Call to confirm they are open';

  @override
  String get urgentRow => 'Is it urgent?';

  @override
  String get urgentRowNote => 'Signs that mean going to the vet now';

  @override
  String foodRow(String name) {
    return 'Can $name eat this?';
  }

  @override
  String get foodRowNote => 'Foods and plants: safe, a little or dangerous';

  @override
  String get lostRow => 'Lost mode';

  @override
  String get lostRowNote => 'Tell people nearby and share a card';

  @override
  String get lostRowCardNote => 'Make a card to share';

  @override
  String lostRowActive(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sightings',
      one: '1 sighting',
      zero: 'no sightings yet',
    );
    return '$name is missing · $_temp0';
  }

  @override
  String lostRowActiveNote(String when) {
    return 'Last seen $when';
  }

  @override
  String get findClinicNote => 'Emergency clinics near you';
}
