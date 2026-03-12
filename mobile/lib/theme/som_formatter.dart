import 'package:intl/intl.dart';

class SomFormatter {
  SomFormatter._();

  static final NumberFormat _whole = NumberFormat.decimalPattern('ru_RU');
  static final NumberFormat _fraction = NumberFormat('#,##0.00', 'ru_RU');

  static String amount(num value, {int fractionDigits = 2}) {
    final formatter = fractionDigits == 0 ? _whole : _fraction;
    return '${formatter.format(value)} с';
  }

  static String plain(num value, {int fractionDigits = 2}) {
    final formatter = fractionDigits == 0 ? _whole : _fraction;
    return formatter.format(value);
  }
}
