import 'package:flutter/foundation.dart';

enum PeriodMode { today, week, month, quarter, year, custom }

class PeriodState extends ChangeNotifier {
  PeriodMode _mode = PeriodMode.month;
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime? _customStart;
  DateTime? _customEnd;

  PeriodMode get mode => _mode;
  DateTime get selectedMonth => _selectedMonth;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;

  DateTime get start {
    final now = DateTime.now();
    switch (_mode) {
      case PeriodMode.today:
        return DateTime(now.year, now.month, now.day);
      case PeriodMode.week:
        final d = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(d.year, d.month, d.day);
      case PeriodMode.month:
        return DateTime(_selectedMonth.year, _selectedMonth.month);
      case PeriodMode.quarter:
        final q = ((_selectedMonth.month - 1) ~/ 3) * 3 + 1;
        return DateTime(_selectedMonth.year, q);
      case PeriodMode.year:
        return DateTime(_selectedMonth.year);
      case PeriodMode.custom:
        return _customStart ?? DateTime(now.year, now.month);
    }
  }

  DateTime get end {
    final now = DateTime.now();
    switch (_mode) {
      case PeriodMode.today:
        return DateTime(now.year, now.month, now.day + 1);
      case PeriodMode.week:
        final s = start;
        return s.add(const Duration(days: 7));
      case PeriodMode.month:
        return DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      case PeriodMode.quarter:
        final s = start;
        return DateTime(s.year, s.month + 3);
      case PeriodMode.year:
        return DateTime(_selectedMonth.year + 1);
      case PeriodMode.custom:
        final e = _customEnd ?? now;
        return DateTime(e.year, e.month, e.day + 1);
    }
  }

  void setMode(PeriodMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _customStart = DateTime(start.year, start.month, start.day);
    _customEnd = DateTime(end.year, end.month, end.day);
    _mode = PeriodMode.custom;
    notifyListeners();
  }

  void nextMonth() {
    setMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1));
  }

  void previousMonth() {
    setMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1));
  }

  bool isCurrentMonth() {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }
}
