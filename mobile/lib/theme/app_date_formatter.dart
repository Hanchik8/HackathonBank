class AppDateFormatter {
  AppDateFormatter._();

  static const List<String> _shortMonths = <String>[
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  static String shortDateTime(DateTime value) {
    final month = _shortMonths[value.month - 1];
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day $month, $hour:$minute';
  }
}
