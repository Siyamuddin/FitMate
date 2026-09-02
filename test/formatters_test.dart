import 'package:fitmate/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekdayFrom', () {
    test('accepts 0 through 6', () {
      for (int i = 0; i <= 6; i++) {
        expect(Formatters.weekdayFrom(i), i);
        expect(Formatters.weekdayFrom('$i'), i);
      }
    });

    test('accepts full and short names', () {
      expect(Formatters.weekdayFrom('Monday'), 1);
      expect(Formatters.weekdayFrom('mon'), 1);
      expect(Formatters.weekdayFrom('Thursday'), 4);
      expect(Formatters.weekdayFrom('thurs'), 4);
      expect(Formatters.weekdayFrom('Sunday'), 0);
    });

    test('returns null for invalid input', () {
      expect(Formatters.weekdayFrom(7), isNull);
      expect(Formatters.weekdayFrom(-1), isNull);
      expect(Formatters.weekdayFrom('funday'), isNull);
      expect(Formatters.weekdayFrom(null), isNull);
    });
  });

  test('weekdayName wraps with modulo 7', () {
    expect(Formatters.weekdayName(1), 'Monday');
    expect(Formatters.weekdayName(8), 'Monday');
  });
}
