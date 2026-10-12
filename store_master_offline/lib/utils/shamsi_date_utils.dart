import 'package:shamsi_date/shamsi_date.dart';

class ShamsiDateUtils {
  static String faDigits(Object? value) => value.toString()
      .replaceAll('0', '۰').replaceAll('1', '۱').replaceAll('2', '۲')
      .replaceAll('3', '۳').replaceAll('4', '۴').replaceAll('5', '۵')
      .replaceAll('6', '۶').replaceAll('7', '۷').replaceAll('8', '۸')
      .replaceAll('9', '۹');

  static String date(DateTime date) {
    final f = Jalali.fromDateTime(date).formatter;
    return faDigits('${f.yyyy}/${f.mm}/${f.dd}');
  }

  static String dateTime(DateTime date) {
    final f = Jalali.fromDateTime(date).formatter;
    return faDigits('${f.yyyy}/${f.mm}/${f.dd} ${f.tHH}:${f.tMM}');
  }

  static String dateTimeSeconds(DateTime date) {
    final f = Jalali.fromDateTime(date).formatter;
    return faDigits('${f.yyyy}/${f.mm}/${f.dd} ${f.tHH}:${f.tMM}:${f.tSS}');
  }

  static String time(DateTime date) {
    final f = Jalali.fromDateTime(date).formatter;
    return faDigits('${f.tHH}:${f.tMM}');
  }

  static String timeSeconds(DateTime date) {
    final f = Jalali.fromDateTime(date).formatter;
    return faDigits('${f.tHH}:${f.tMM}:${f.tSS}');
  }

  static String shortMonthDay(DateTime date) {
    final f = Jalali.fromDateTime(date).formatter;
    return faDigits('${f.mm}/${f.dd}');
  }

  static String long(DateTime date) {
    final j = Jalali.fromDateTime(date);
    final f = j.formatter;
    return '${f.wN} ${faDigits(f.d)} ${f.mN} ${faDigits(f.yyyy)}';
  }

  static String fromMillisDate(int millis) =>
      date(DateTime.fromMillisecondsSinceEpoch(millis));

  static String fromMillisDateTime(int millis) =>
      dateTime(DateTime.fromMillisecondsSinceEpoch(millis));

  static String fromMillisDateTimeSeconds(int millis) =>
      dateTimeSeconds(DateTime.fromMillisecondsSinceEpoch(millis));

  static int jalaliYearOf(DateTime date) => Jalali.fromDateTime(date).year;
}

String faDate(DateTime date) => ShamsiDateUtils.date(date);
String faDateTime(DateTime date) => ShamsiDateUtils.dateTime(date);
String faDateTimeSeconds(DateTime date) => ShamsiDateUtils.dateTimeSeconds(date);
String faDateMillis(int millis) => ShamsiDateUtils.fromMillisDate(millis);
String faDateTimeMillis(int millis) => ShamsiDateUtils.fromMillisDateTime(millis);
String faDateTimeSecondsMillis(int millis) => ShamsiDateUtils.fromMillisDateTimeSeconds(millis);
String faTime(DateTime date) => ShamsiDateUtils.time(date);
String faTimeSeconds(DateTime date) => ShamsiDateUtils.timeSeconds(date);
String faShortDate(DateTime date) => ShamsiDateUtils.shortMonthDay(date);
