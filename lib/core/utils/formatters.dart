import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static final NumberFormat _kg = NumberFormat('0.0');
  static final NumberFormat _int = NumberFormat('#,##0');

  static String kg(num value) => '${_kg.format(value)} kg';

  static String kcal(num value) => '${_int.format(value.round())} kcal';

  static String grams(num value) => '${value.round()}g';

  static String greeting(DateTime now) {
    final int hour = now.hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  static String weekdayName(int weekday) {
    const List<String> names = <String>[
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return names[weekday % 7];
  }
}
