import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateExtensions on DateTime {
  DateTime get trimmed {
    return DateTime(year, month, day);
  }

  DateTime get trimmedUtc {
    return DateTime.utc(year, month, day);
  }

  bool isSameDate(DateTime other) {
    if (other.year != year) return false;
    if (other.month != month) return false;
    if (other.day != day) return false;
    return true;
  }

  bool isAfterDate(DateTime other) {
    return trimmedUtc.isAfter(other.trimmedUtc);
  }

  bool isSameDateOrAfter(DateTime other) {
    return isSameDate(other) || isAfterDate(other);
  }

  bool isBeforeDate(DateTime other) {
    return trimmedUtc.isBefore(other.trimmedUtc);
  }

  DateTime get previousDay {
    return trimmedUtc.subtract(const Duration(hours: 24)).trimmed;
  }

  DateTime get nextDay {
    return trimmedUtc.add(const Duration(hours: 24)).trimmed;
  }

  DateTime firstDateOfWeek(int firstDayOfWeek) {
    final delta = _weekdayDif(from: firstDayOfWeek, to: weekday);

    return trimmedUtc.subtract(Duration(days: delta)).trimmed;
  }

  DateTime lastDateOfWeek(int lastDayOfWeek) {
    final delta = _weekdayDif(from: weekday, to: lastDayOfWeek);
    return trimmedUtc.add(Duration(days: delta)).trimmed;
  }

  DateTime get firstDateOfMonth {
    return DateTime(year, month, 1);
  }

  DateTime get lastDayOfMonth {
    return DateTime(year, month + 1, 0);
  }

  DateTime addDays(int day) {
    return trimmedUtc.add(Duration(hours: 24 * day)).trimmed;
  }

  DateTime subtractDays(int day, [DateTime? minDate]) {
    final res = trimmedUtc.subtract(Duration(hours: 24 * day)).trimmed;
    if (minDate != null && res.isBeforeDate(minDate)) return minDate;
    return res;
  }

  int differenceInDays(DateTime to) {
    final from = trimmedUtc;
    to = to.trimmedUtc;

    return to.difference(from).inDays;
  }

  int _weekdayDif({required int from, required int to}) {
    return (to - from) % 7;
  }

  String formatDate(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final date = DateFormat.MMMd(locale.languageCode).format(this);
    final day = DateFormat('E', locale.languageCode).format(this);

    return '$day $date';
  }

  String getIntlTime(BuildContext context) {
    bool use24 = MediaQuery.of(context).alwaysUse24HourFormat;
    if (use24) {
      return DateFormat.Hm().format(this);
    } else {
      return DateFormat.jm().format(this);
    }
  }
}

int daysBetween({
  required DateTime from,
  required DateTime to,
  bool inclusive = false,
}) {
  return to.trimmedUtc.difference(from.trimmedUtc).inDays + (inclusive ? 1 : 0);
}
