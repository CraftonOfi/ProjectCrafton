import 'package:intl/intl.dart';

class Formatters {
  static String currency(num value,
      {String locale = 'es_ES', String symbol = '€'}) {
    final format = NumberFormat.currency(
        locale: locale, symbol: symbol, decimalDigits: value % 1 == 0 ? 0 : 2);
    return format.format(value);
  }

  static String dateTime(DateTime dt, {String locale = 'es_ES'}) {
    final df = DateFormat.yMMMMd(locale).add_Hm();
    return df.format(dt);
  }

  static String shortDateTime(DateTime dt, {String locale = 'es_ES'}) {
    final df = DateFormat('d MMM HH:mm', locale);
    return df.format(dt);
  }
}
