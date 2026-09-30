import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FinanceChart extends StatelessWidget {
  final List<FlSpot> income;
  final List<FlSpot> expenses;

  const FinanceChart({
    super.key,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: income,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: expenses,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
