import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_bank_mobile/theme/app_date_formatter.dart';

void main() {
  test('formats short date without intl locale initialization', () {
    final formatted = AppDateFormatter.shortDateTime(
      DateTime(2026, 3, 12, 9, 5),
    );

    expect(formatted, '12 мар., 09:05');
  });
}
