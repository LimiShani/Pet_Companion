import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../services/findvet/regions/regions.dart';
import '../../services/outdoors/data/park_area.dart';
import '../../services/outdoors/data/park_models.dart';

/// The words of the parks feature for its enums and computed names.
extension OutdoorsWords on OutdoorsL10n {
  String detail(ParkDetail detail) => switch (detail) {
    ParkDetail.fenced => detailFenced,
    ParkDetail.water => detailWater,
    ParkDetail.shade => detailShade,
    ParkDetail.lighting => detailLighting,
    ParkDetail.smallDogs => detailSmallDogs,
    ParkDetail.benches => detailBenches,
  };

  String answer(ParkAnswer answer) => switch (answer) {
    ParkAnswer.yes => answerYes,
    ParkAnswer.no => answerNo,
    ParkAnswer.unknown => answerUnknown,
  };

  String radius(ParkRadius radius) =>
      radius == ParkRadius.cityOnly ? radiusCityOnly : radiusKm(radius.km);

  /// The park's title on a card or a page: its own name, else "Dog park ·"
  /// and the nearest street, else "Dog park".
  String parkTitle(DogPark park, String language) {
    final name = park.name(language);
    if (name != null) return name;
    final street = park.street(language);
    return street == null ? parkDefaultName : parkOnStreet(street);
  }

  /// The title with the city: "Dog park · Ahuza, Ra'anana" (a park picker,
  /// a meetup's place).
  String parkFullName(DogPark park, String language) {
    final city = localityName(park.localityCode, language);
    final title = parkTitle(park, language);
    return city == null ? title : parkInCity(title, city);
  }

  /// "0.8 km", "350 m".
  String distance(double metres, String language) {
    if (metres < 1000) return distanceM((metres / 10).round() * 10);
    final km = metres / 1000;
    final format = NumberFormat(km < 10 ? '0.0' : '0', language);
    return distanceKm(format.format(km));
  }
}

/// The name of the locality with [code] in [language], or `null`.
String? localityName(String? code, String language) {
  if (code == null) return null;
  for (final region in vetRegions) {
    final locality = region.localityByCode(code);
    if (locality != null) return locality.nameIn(language);
  }
  return null;
}

/// The app's language code ('he' or 'en') where [context] is.
String languageOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'he' ? 'he' : 'en';
