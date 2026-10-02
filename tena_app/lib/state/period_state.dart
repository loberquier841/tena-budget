import 'package:flutter/foundation.dart';

class PeriodState extends ChangeNotifier {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTime get selectedMonth => _selectedMonth;

  void setMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  void nextMonth() {
    setMonth(
      DateTime(_selectedMonth.year, _selectedMonth.month + 1),
    );
  }

  void previousMonth() {
    setMonth(
      DateTime(_selectedMonth.year, _selectedMonth.month - 1),
    );
  }

  bool isCurrentMonth() {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }
}
