import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/constants/date_constants.dart';

void main() {
  group('AppDateConstants (Friday & Saturday Weekend Logic)', () {
    test('weekendDays contains Friday (5) and Saturday (6)', () {
      expect(AppDateConstants.weekendDays, equals([DateTime.friday, DateTime.saturday]));
      expect(AppDateConstants.isWeekendDay(DateTime.friday), isTrue);
      expect(AppDateConstants.isWeekendDay(DateTime.saturday), isTrue);
      expect(AppDateConstants.isWeekendDay(DateTime.sunday), isFalse);
      expect(AppDateConstants.isWeekendDay(DateTime.thursday), isFalse);
    });

    test('workdays contains Sunday through Thursday', () {
      expect(
        AppDateConstants.workdays,
        equals([
          DateTime.sunday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
        ]),
      );
      for (final day in AppDateConstants.workdays) {
        expect(AppDateConstants.isWeekendDay(day), isFalse);
      }
    });

    test('isWeekend correctly identifies dates', () {
      final friday = DateTime(2026, 3, 27); // Friday
      final saturday = DateTime(2026, 3, 28); // Saturday
      final sunday = DateTime(2026, 3, 29); // Sunday
      final monday = DateTime(2026, 3, 30); // Monday

      expect(AppDateConstants.isWeekend(friday), isTrue);
      expect(AppDateConstants.isWeekend(saturday), isTrue);
      expect(AppDateConstants.isWeekend(sunday), isFalse);
      expect(AppDateConstants.isWeekend(monday), isFalse);
    });

    test('startOfWeek returns preceding Sunday', () {
      final wednesday = DateTime(2026, 3, 25);
      final sunday = AppDateConstants.startOfWeek(wednesday);
      expect(sunday.weekday, equals(DateTime.sunday));
      expect(sunday, equals(DateTime(2026, 3, 22)));

      final friday = DateTime(2026, 3, 27);
      expect(AppDateConstants.startOfWeek(friday), equals(DateTime(2026, 3, 22)));
    });
  });
}

