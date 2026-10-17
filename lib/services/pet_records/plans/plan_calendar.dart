/// The yearly plan's dates as a calendar file (iCalendar, RFC 5545) the
/// owner hands to their own calendar app through the share sheet: the app
/// never asks for calendar access.
library;

import 'dart:convert';

import '../data/health_models.dart';

/// How long each event lasts.
const planEventMinutes = 30;

/// The `.ics` text of [records] (planned records of the plan): one event
/// each, at its time for [planEventMinutes] minutes, with an alert the day
/// before, and no repeats (marking one done plans the next, so a repeating
/// event would drift). [summary] names an event, [description] adds one
/// line to it; [stamp] is when the file was made (UTC).
String planCalendar(
  List<HealthRecord> records, {
  required String Function(HealthRecord record) summary,
  required String description,
  required DateTime stamp,
}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//PetLoop//Yearly plan//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    for (final r in records) ...[
      'BEGIN:VEVENT',
      'UID:${r.id.isEmpty ? '${r.planItem}-${_local(r.scheduledAt)}' : r.id}@petloop.app',
      'DTSTAMP:${_utc(stamp)}',
      // Floating local times: the appointment is at 09:00 wherever the
      // phone is.
      'DTSTART:${_local(r.scheduledAt)}',
      'DTEND:${_local(r.scheduledAt.add(const Duration(minutes: planEventMinutes)))}',
      'SUMMARY:${_escape(summary(r))}',
      if (description.isNotEmpty) 'DESCRIPTION:${_escape(description)}',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_escape(summary(r))}',
      'TRIGGER:-P1D',
      'END:VALARM',
      'END:VEVENT',
    ],
    'END:VCALENDAR',
  ];
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _local(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}'
    'T${_two(t.hour)}${_two(t.minute)}00';

String _utc(DateTime t) => '${_local(t.toUtc())}Z';

/// Text values escape backslashes, semicolons, commas and line breaks.
String _escape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r?\n'), r'\n');

/// Lines longer than 75 octets continue on the next line after a space,
/// never in the middle of a character.
String _fold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final out = StringBuffer();
  var octets = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (octets + size > limit) {
      out.write('\r\n ');
      octets = 0;
      limit = 74;
    }
    out.write(char);
    octets += size;
  }
  return out.toString();
}
