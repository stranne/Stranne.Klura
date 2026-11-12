import 'package:klura/core/calendar_date.dart';

/// Builds the seed key for a puzzle of the day, for example
/// `bridges:v1:2026-11-11`.
///
/// The key uses the calendar date of [date] as given, so callers pass the
/// player's local date and a new puzzle starts at local midnight.
///
/// Increase [generatorVersion] whenever a generator change would produce a
/// different puzzle for an existing key, so saved progress never refers to a
/// puzzle that has silently changed.
String dailySeedKey({
  required String puzzleId,
  required int generatorVersion,
  required DateTime date,
}) => '$puzzleId:v$generatorVersion:${formatCalendarDate(date)}';
