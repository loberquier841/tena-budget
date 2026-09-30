import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FinanceChart extends StatelessWidget {
  final List<FlSpot> income;
  final List<FlSpot> expenses;
  final List<String> labels;

  const FinanceChart({
    super.key,
    required this.income,
    required this.expenses,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withValues(alpha: 0.15),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()} €',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }

                  return Text(
                    labels[index],
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x.toInt();
                  final label =
                      index >= 0 && index < labels.length
                          ? labels[index]
                          : '';

                  return LineTooltipItem(
                    '$label\n${spot.y.toStringAsFixed(2).replaceAll('.', ',')} €',
                    const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: income,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            LineChartBarData(
              spots: expenses,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.red.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
