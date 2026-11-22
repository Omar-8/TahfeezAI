import 'package:hijri/hijri_calendar.dart';

/// A day of the Hijri calendar.
typedef HijriDate = ({int year, int month, int day});

/// [date]'s Hijri date by the Umm al-Qura calendar (the `hijri` package),
/// moved by [adjust] days (−1, 0, +1: where the month is sighted a day
/// apart — Settings).
HijriDate hijriOf(DateTime date, {int adjust = 0}) {
  final d = DateTime(date.year, date.month, date.day + adjust);
  final h = HijriCalendar.fromDate(d);
  return (year: h.hYear, month: h.hMonth, day: h.hDay);
}

const _arabicMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', //
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];
const _latinMonths = [
  'Muharram', 'Safar', 'Rabiʿ al-Awwal', 'Rabiʿ al-Akhir', //
  'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Shaʿban', 'Ramadan', //
  'Shawwal', 'Dhu al-Qaʿdah', 'Dhu al-Hijjah',
];

/// The languages written in the Arabic script: the months' Arabic names.
const _arabicScript = {'ar', 'ur', 'fa', 'ps', 'ckb'};

/// [month]'s name (1–12): Arabic in the Arabic-script languages, else its
/// common Latin spelling.
String hijriMonthName(int month, String languageCode) =>
    (_arabicScript.contains(languageCode)
    ? _arabicMonths
    : _latinMonths)[month - 1];

/// "13 Rajab 1448" (the year with AH outside Arabic script: «هـ» in it).
String formatHijri(HijriDate h, String languageCode) {
  final arabic = _arabicScript.contains(languageCode);
  return '${h.day} ${hijriMonthName(h.month, languageCode)} ${h.year}'
      '${arabic ? ' هـ' : ' AH'}';
}
