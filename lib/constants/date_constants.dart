/// In Momentum, weekends are Friday (5) and Saturday (6).
/// Workdays are Sunday (7), Monday (1), Tuesday (2), Wednesday (3), Thursday (4).
abstract final class AppDateConstants {
  /// Weekend days in Dart [DateTime.weekday] format: Friday (5) & Saturday (6).
  static const List<int> weekendDays = [DateTime.friday, DateTime.saturday]; // [5, 6]

  /// Workdays in Dart [DateTime.weekday] format: Sunday (7) through Thursday (4).
  static const List<int> workdays = [
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  ]; // [7, 1, 2, 3, 4]

  /// All 7 days in week order starting from Sunday.
  static const List<int> weekDaysOrder = [
    DateTime.sunday,    // 7
    DateTime.monday,    // 1
    DateTime.tuesday,   // 2
    DateTime.wednesday, // 3
    DateTime.thursday,  // 4
    DateTime.friday,    // 5 (Weekend)
    DateTime.saturday,  // 6 (Weekend)
  ];

  /// Short day names ordered from Sunday to Saturday.
  static const List<String> shortDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// Single letter initials ordered from Sunday to Saturday.
  static const List<String> dayInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  /// Returns true if the given [DateTime] falls on a weekend (Friday or Saturday).
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.friday || date.weekday == DateTime.saturday;

  /// Returns true if the given [dayOfWeek] int (1..7) is a weekend day (5 or 6).
  static bool isWeekendDay(int dayOfWeek) =>
      dayOfWeek == DateTime.friday || dayOfWeek == DateTime.saturday;

  /// Returns the start of the week (Sunday at 00:00:00) for a given date.
  static DateTime startOfWeek(DateTime date) {
    final daysSinceSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysSinceSunday));
  }
}

