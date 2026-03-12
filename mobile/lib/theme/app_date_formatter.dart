class AppDateFormatter {
  AppDateFormatter._();

  static const List<String> _shortMonths = <String>[
    'янв.',
    'февр.',
    'мар.',
    'апр.',
    'мая',
    'июн.',
    'июл.',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ];

  static String shortDate(DateTime value) {
    final month = _shortMonths[value.month - 1];
    final day = value.day.toString().padLeft(2, '0');
    return '$day $month';
  }

  static String shortDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${shortDate(value)}, $hour:$minute';
  }
}
