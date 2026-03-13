import 'package:intl/intl.dart';

class SomFormatter {
  SomFormatter._();

  static final NumberFormat _whole = NumberFormat.decimalPattern('en_US');
  static final NumberFormat _fraction = NumberFormat('#,##0.00', 'en_US');

  static String amount(num value, {int fractionDigits = 2}) {
    final formatter = fractionDigits == 0 ? _whole : _fraction;
    return '${formatter.format(value)} KGS';
  }

  static String plain(num value, {int fractionDigits = 2}) {
    final formatter = fractionDigits == 0 ? _whole : _fraction;
    return formatter.format(value);
  }
}
