import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/theme/som_formatter.dart';

void main() {
  test('formats amount with som suffix', () {
    final formatted = SomFormatter.amount(12345.6);

    expect(formatted, endsWith(' с'));
    expect(formatted, contains('12'));
    expect(formatted, contains('345'));
  });

  test('formats plain number without suffix', () {
    final formatted = SomFormatter.plain(5000, fractionDigits: 0);

    expect(formatted, contains('5'));
    expect(formatted, isNot(contains('с')));
  });
}
