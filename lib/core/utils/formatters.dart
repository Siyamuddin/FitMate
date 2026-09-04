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

  static const List<String> weekdayNames = <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static String weekdayName(int weekday) {
    return weekdayNames[weekday % 7];
  }

  static int? weekdayFrom(Object? value) {
    if (value is num) {
      final int n = value.toInt();
      if (n >= 0 && n <= 6) {
        return n;
      }
      return null;
    }
    if (value is String) {
      final String raw = value.trim();
      final int? parsed = int.tryParse(raw);
      if (parsed != null && parsed >= 0 && parsed <= 6) {
        return parsed;
      }
      final String key = raw.toLowerCase();
      const Map<String, int> names = <String, int>{
        'sunday': 0,
        'sun': 0,
        'monday': 1,
        'mon': 1,
        'tuesday': 2,
        'tue': 2,
        'tues': 2,
        'wednesday': 3,
        'wed': 3,
        'thursday': 4,
        'thu': 4,
        'thur': 4,
        'thurs': 4,
        'friday': 5,
        'fri': 5,
        'saturday': 6,
        'sat': 6,
      };
      return names[key];
    }
    return null;
  }
}
