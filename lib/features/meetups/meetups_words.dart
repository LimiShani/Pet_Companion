import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../../presentation/pet_words.dart' show petSummaryLine;
import '../../services/meetups/data/meetup_models.dart';
import '../outdoors/outdoors_words.dart';

/// The words of the partners feature for its enums and computed lines.
extension MeetupsWords on MeetupsL10n {
  String kind(MeetupKind kind) => switch (kind) {
    MeetupKind.walk => kindWalk,
    MeetupKind.play => kindPlay,
  };

  String dayPart(DayPart part) => switch (part) {
    DayPart.morning => dayPartMorning,
    DayPart.noon => dayPartNoon,
    DayPart.evening => dayPartEvening,
  };

  /// The dog's size in its summary line ("medium-sized").
  String size(PetSize size) => switch (size) {
    PetSize.small => sizeSmall,
    PetSize.medium => sizeMedium,
    PetSize.large => sizeLarge,
  };

  /// A size chip of the form.
  String sizeChip(PetSize size) => switch (size) {
    PetSize.small => sizeSmallChip,
    PetSize.medium => sizeMediumChip,
    PetSize.large => sizeLargeChip,
  };

  /// "For small and medium dogs"; `null` for every size.
  String? suits(Set<PetSize> sizes) {
    final words = [
      for (final size in PetSize.values)
        if (sizes.contains(size))
          switch (size) {
            PetSize.small => suitsSmall,
            PetSize.medium => suitsMedium,
            PetSize.large => suitsLarge,
          },
    ];
    if (words.isEmpty || words.length == PetSize.values.length) return null;
    return suitsLine(
      words.length == 1 ? words.single : suitsTwo(words.first, words.last),
    );
  }

  String failure(Object? error) => switch (error) {
    MeetupException(:final failure) => switch (failure) {
      MeetupFailure.rateLimited => errRateLimited,
      MeetupFailure.tooManyOpen => errTooManyOpen,
      MeetupFailure.notOpen => errNotOpen,
      MeetupFailure.blocked => errBlocked,
      MeetupFailure.invalid => errInvalid,
      MeetupFailure.unavailable => errUnavailable,
      MeetupFailure.other => errOther,
    },
    _ => errOther,
  };

  String? problem(MeetupDraftProblem problem) => switch (problem) {
    MeetupDraftProblem.place => null,
    MeetupDraftProblem.note => null,
    MeetupDraftProblem.hours => hoursProblem,
    MeetupDraftProblem.past => pastProblem,
    MeetupDraftProblem.tooFar => tooFarProblem,
    MeetupDraftProblem.days => daysProblem,
  };
}

/// The lines a card and a page show, in the screen's language.
class MeetupText {
  MeetupText(this.context, [WeekSettings? week])
    : week = week ?? WeekSettings.defaults,
      l10n = context.meetupsL10n,
      outdoors = context.outdoorsL10n,
      format = AppFormat.of(context),
      language = languageOf(context);

  final BuildContext context;

  /// The member's week: its order and what "Weekdays" means.
  final WeekSettings week;
  final MeetupsL10n l10n;
  final OutdoorsL10n outdoors;
  final AppFormat format;
  final String language;

  bool get _hebrew => language == 'he';

  /// The pet's line: "Dog · Mixed · about 3 years · medium-sized".
  String petLine(MeetupPet pet, DateTime now) => [
    petSummaryLine(context.petsL10n, pet.asPet, now: now),
    if (pet.size case final size?) l10n.size(size),
  ].join(' · ');

  /// The place: the park with its city, else the place and the city.
  String place(Meetup ad) {
    final park = ad.park;
    if (park != null) return outdoors.parkFullName(park, language);
    final city = localityName(ad.localityCode, language);
    final text = ad.placeText ?? '';
    if (city == null) return text;
    if (text.isEmpty) return city;
    return outdoors.parkInCity(text, city);
  }

  /// A short place for a message: the park's own name, else the place.
  String shortPlace(Meetup ad) {
    final park = ad.park;
    if (park != null) return outdoors.parkTitle(park, language);
    return ad.placeText ?? localityName(ad.localityCode, language) ?? '';
  }

  /// "Today 18:00–19:00", "Sat 10:00–12:00", "Sun–Thu · Morning";
  /// "Leaving 17:30" for a going-now ad.
  String when(MeetupTime time, DateTime now) => switch (time) {
    NowTime(:final start) => l10n.leavingAt(ltr(format.time(start))),
    OneOffTime(:final start, :final end) =>
      '${_day(start, now)} ${ltr('${format.time(start)}–${format.time(end)}')}',
    RecurringTime(:final weekdays, :final part) =>
      '${days(weekdays)} · ${l10n.dayPart(part)}',
  };

  String _day(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(day.year, day.month, day.day);
    final ahead = date.difference(today).inDays;
    if (ahead == 0) return context.l10n.commonToday;
    if (ahead == 1) return l10n.tomorrow;
    if (ahead > 1 && ahead < 7) return format.weekdayShort(day.weekday);
    return format.dayMonth(day);
  }

  /// The days of a recurring ad in the week's order: "Every day",
  /// "Weekdays", "Weekends", runs of three or more as a range ("Sun–Thu"),
  /// else a list ("Mon, Wed").
  String days(Set<int> weekdays) {
    if (week.isEveryDay(weekdays)) return l10n.everyDay;
    if (week.isWeekdays(weekdays)) return l10n.weekdays;
    if (week.isWeekend(weekdays)) return l10n.weekends;
    String name(int day) =>
        _hebrew ? format.weekdayNarrow(day) : format.weekdayShort(day);
    final order = week.orderedDays;
    final runs = <List<int>>[];
    for (final day in order) {
      if (!weekdays.contains(day)) continue;
      if (runs.isNotEmpty &&
          order.indexOf(runs.last.last) == order.indexOf(day) - 1) {
        runs.last.add(day);
      } else {
        runs.add([day]);
      }
    }
    return [
      for (final run in runs)
        if (run.length >= 3)
          '${name(run.first)}–${name(run.last)}'
        else
          ...run.map(name),
    ].join(', ');
  }

  /// The tag of a going-now ad: "in 25 min", then "Out now".
  String goingTag(NowTime time, DateTime now) {
    final minutes = time.minutesUntil(now);
    return minutes > 0 ? l10n.goingInTag(minutes) : l10n.goingOutTag;
  }

  /// "about 5 km" between the area's centre and the ad.
  String distance(double metres) => metres < 1000
      ? l10n.distanceNear
      : l10n.distanceAbout(outdoors.distance(metres, language));

  /// The name of the author, or the friendly fallback.
  String author(String stored) => context.communityL10nMemberName(stored);

  /// The first message to the author, ready to edit.
  String draft(Meetup ad, {String? petName}) {
    final name = author(ad.authorName);
    final where = shortPlace(ad);
    return switch ((ad.kind, petName)) {
      (MeetupKind.walk, final pet?) => l10n.draftWalkPet(name, where, pet),
      (MeetupKind.walk, null) => l10n.draftWalk(name, where),
      (MeetupKind.play, final pet?) => l10n.draftPlayPet(name, where, pet),
      (MeetupKind.play, null) => l10n.draftPlay(name, where),
    };
  }

  /// The name of the responders' group: "Walk · Ahuza dog park" (a chat
  /// name holds 40 characters).
  String groupName(Meetup ad) {
    final name = '${l10n.kind(ad.kind)} · ${shortPlace(ad)}';
    return name.length <= 40 ? name : '${name.substring(0, 39)}…';
  }
}

extension on BuildContext {
  String communityL10nMemberName(String stored) =>
      stored.trim().isEmpty ? communityL10n.memberFallbackName : stored;
}
